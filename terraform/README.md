# PDS Web Analytics — Terraform

Deploys the infrastructure for the PDS Web Analytics pipeline:

- **S3 bucket** — log storage with versioning, SSE, and Intelligent-Tiering
- **IAM policy** — grants the Logstash EC2 role read access to S3 and write access to OpenSearch (admin-only)
- **Logstash EC2** — MCP Amazon Linux 2023 instance running Logstash in Docker via systemd
- **Managed OpenSearch domain** — VPC-only, no public endpoint, IAM resource-based access control
- **Visualization** — AWS-hosted [OpenSearch UI](https://docs.aws.amazon.com/opensearch-service/latest/developerguide/application.html) with IAM Identity Center (OpenSearch Dashboards not used)

```
terraform/
  ├── iam/policies/             # IAM policy + role attachment  — admin only
  ├── opensearch_managed/       # OpenSearch domain             — Step 1
  └── (root)                    # S3 (Step 2) + EC2 (Step 4)   — EC2 is admin only
```

---

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/downloads) >= 1.0
- [Task](https://taskfile.dev) — `brew install go-task/tap/go-task`
- AWS CLI + [Session Manager plugin](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html) — `brew install --cask session-manager-plugin`
- AWS credentials exported: `eval $(aws configure export-credentials --profile <profile> --format env)`

> **Permission requirements:**
> - `Project-Power-User` — Steps 1, 2
> - **System administrator** (`iam:CreatePolicy`, `iam:PassRole`) — Steps 3, 4. See [ADMIN_DEPLOY.md](ADMIN_DEPLOY.md).

---

## Setup

### 1. Create tfvars files

Each module has a `tfvars/` directory (gitignored). Copy the examples and fill in values:

```bash
cd terraform/

cp opensearch_managed/tfvars/dev.tfvars.example  opensearch_managed/tfvars/dev.tfvars
cp iam/policies/tfvars/dev.tfvars.example        iam/policies/tfvars/dev.tfvars
cp tfvars/dev.tfvars.example                     tfvars/dev.tfvars
```

Key values to fill in:

| File | Variable | Notes |
|---|---|---|
| `opensearch_managed/tfvars/dev.tfvars` | `vpc_id`, `vpc_subnet_ids`, `ec2_security_group_id` | VPC values for the domain |
| `opensearch_managed/tfvars/dev.tfvars` | `policy_json_file` | Path to filled-in `access_policy.json` (copy from `access_policy.json.example`) |
| `tfvars/dev.tfvars` | `vpc_id` | VPC ID for the EC2 |

### 2. Configure credentials

```bash
eval $(aws configure export-credentials --profile <your-profile> --format env)
```

---

## Deployment — step by step

### Step 1: OpenSearch domain — Power-User (~15-20 min)

```bash
cd terraform/

cp opensearch_managed/access_policy.json.example opensearch_managed/access_policy.json
# Edit access_policy.json — fill in your EC2 role name

task opensearch:init   VENUE=dev
task opensearch:plan   VENUE=dev
task opensearch:deploy VENUE=dev
task opensearch:endpoint VENUE=dev  # confirm endpoint in SSM
```

---

### Step 2: S3 bucket — Power-User

```bash
task s3:plan   VENUE=dev
task s3:deploy VENUE=dev
```

---

### Step 3 & 4: IAM + EC2 — admin only

See [ADMIN_DEPLOY.md](ADMIN_DEPLOY.md) for instructions to hand to a system administrator.

---

### Step 5: Initialize Logstash on the EC2

On **new EC2 deployments**, the userdata script runs `logstash-init.sh` automatically at first boot.

For an **already-running EC2**, SSM in and run the init script manually:

```bash
# SSM into the EC2
aws ssm start-session \
  --target $(aws ssm get-parameter \
    --name /pds/web-analytics/ec2/logstash_instance_id \
    --query Parameter.Value --output text) \
  --profile <your-profile>

# On the EC2 — run the init script
curl -O https://raw.githubusercontent.com/NASA-PDS/web-analytics/main/scripts/logstash-init.sh
bash logstash-init.sh
```

The script will:
1. Clone the web-analytics repo to `/opt/web-analytics`
2. Copy Logstash pipeline config to `/opt/logstash/config`
3. Apply the OpenSearch ECS index template
4. Start the Logstash systemd service

**Tail logs:**
```bash
sudo journalctl -u logstash -f
```

**Verify data is flowing:**
```bash
eval $(aws configure export-credentials --format env)
curl -s "https://<opensearch-endpoint>/_cat/indices?v" \
  --aws-sigv4 "aws:amz:us-west-2:es" \
  --user "${AWS_ACCESS_KEY_ID}:${AWS_SECRET_ACCESS_KEY}"
```

---

### Step 6 (optional): Grant Logstash access to CloudFront logs bucket

Required only if ingesting CloudFront logs. Apply in the `pdc-cds-infra` repo:

```bash
cd pdc-cds-infra/terraform/cloudfront/pds-main/
# Fill in tfvars/dev.tfvars: web_analytics_ec2_role_arn = "arn:aws:iam::<account>:role/<role>"
task plan   VENUE=dev
task deploy VENUE=dev
```

---

## Teardown

```bash
task ec2:destroy        VENUE=dev   # EC2 + launch template
task s3:destroy         VENUE=dev   # S3 bucket (does not delete objects)
task iam:destroy        VENUE=dev   # IAM policy + role attachment
task opensearch:destroy VENUE=dev   # OpenSearch domain (destroys all indexed data)
```

---

## Architecture notes

- **State files** stored in S3 (`pds-dev-gh01dc-infra`):
  - `web-analytics/terraform.tfstate` — S3 + EC2
  - `web-analytics/iam-policies.tfstate` — IAM
  - `web-analytics/opensearch.tfstate` — OpenSearch domain
- **Variable naming** — `s3_bucket_prefix` is used only for the S3 bucket name (may include CI/CD identifiers like `gh01dc`). `resource_prefix` is used for all other resources (EC2, IAM policy, etc.) and should not include CI/CD identifiers.
- **VPC/SG values** are in tfvars. TODO: source from SSM under `/pds/cds-infra/vpc/` once published.
- **Logstash sincedb** persists to `/var/lib/logstash/sincedb` on the EC2 EBS volume (`delete_on_termination = false`) — S3 read position survives restarts and redeployments.
- **TODO:** Document OpenSearch UI application setup (create in AWS console, connect domain, assign IAM Identity Center users/groups).
