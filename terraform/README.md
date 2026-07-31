# PDS Web Analytics — Terraform

Deploys the infrastructure for the PDS Web Analytics pipeline:

- **S3 bucket** — log storage with versioning, SSE, and Intelligent-Tiering
- **IAM policy** — grants the Logstash EC2 role read access to S3 and write access to OpenSearch (admin-only)
- **Logstash EC2** — MCP Amazon Linux 2023 instance running Logstash in Docker via systemd
- **Managed OpenSearch domain** — stores and indexes log data; deployed inside the VPC, accessible via OpenSearch UI (AWS-hosted) with IAM Identity Center
- **OpenSearch index templates** — ECS v8 field mappings applied to the domain from within the VPC

Modules must be applied in order. IAM requires elevated permissions and is managed separately.

```
terraform/
  ├── iam/
  │     └── policies/
  │           └── web-analytics/  # IAM policy definition (submodule)
  │           role_attachments.tf # Role → policy attachment     → admin only
  ├── opensearch_managed/         # OpenSearch domain            → Step 1 (~15-20 min)
  └── (root)                      # S3 (Step 2) + EC2 (Step 4, admin only)
```
> Index templates are applied via curl from the Logstash EC2 — see Step 5.

---

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/downloads) >= 1.0
- [Task](https://taskfile.dev) — `brew install go-task/tap/go-task`
- AWS CLI configured with a profile that has permissions to create EC2, S3, OpenSearch, IAM, and SSM resources
- `access_policy.json` created from `opensearch_managed/access_policy.json.example` with real role names filled in (see Chunk 2 below)

---

## Setup

### 1. Configure AWS credentials

```bash
export AWS_PROFILE=<your-profile>
export AWS_DEFAULT_REGION=us-west-2
task aws    # confirms credentials are working
```

### 2. Review and fill in tfvars

Each module has a `tfvars/` directory. The files are gitignored — never commit real values.

```
terraform/iam/policies/tfvars/dev.tfvars
terraform/tfvars/dev.tfvars
terraform/opensearch_managed/tfvars/dev.tfvars
```

Sensitive values that must be filled in before deploying:

| File | Variable | Notes |
|---|---|---|
| `opensearch_managed/tfvars/dev.tfvars` | `opensearch_master_user_arn` | IAM role ARN for OpenSearch FGAC master (SSO Power-User role ARN) |
| `opensearch_managed/tfvars/dev.tfvars` | `engine_version` | Defaults to `OpenSearch_2.19` |
| `opensearch_managed/tfvars/dev.tfvars` | `policy_json_file` | Path to your filled-in `access_policy.json` |
| `pdc-cds-infra` cloudfront tfvars | `web_analytics_ec2_role_arn` | ARN of the Logstash EC2 IAM role |

---

## Deployment — step by step

> **Permission requirements:**
> - `Project-Power-User`: can run S3 and OpenSearch steps
> - **System administrator required** for: `iam:deploy` and `ec2:deploy` (needs `iam:CreatePolicy` and `iam:PassRole`)

---

### Step 1: OpenSearch domain — Power-User (~15-20 min)

```bash
cd terraform/

# Create your access policy file from the example
cp opensearch_managed/access_policy.json.example opensearch_managed/access_policy.json
# Edit access_policy.json — replace <your-ec2-instance-role-name> with the real role name

task opensearch:init   VENUE=dev
task opensearch:plan   VENUE=dev
task opensearch:deploy VENUE=dev   # ~15-20 min
task opensearch:endpoint VENUE=dev  # confirm endpoint in SSM
```

---

### Step 2: S3 bucket — Power-User

```bash
task s3:plan   VENUE=dev
task s3:deploy VENUE=dev
```

---

### Step 3: IAM policies — admin only

> Requires `iam:CreatePolicy` and `iam:AttachRolePolicy`. Must be run by a system administrator.

```bash
task iam:plan   VENUE=dev
task iam:deploy VENUE=dev
```

---

### Step 4: EC2 Logstash instance — admin only

> Requires `iam:PassRole`. Must be run by a system administrator.
> Depends on Step 1 (OpenSearch endpoint in SSM) and Step 3 (IAM policy attached).

```bash
task ec2:plan   VENUE=dev
task ec2:deploy VENUE=dev
```

---

### Step 5: Index template — run from Logstash EC2

The OpenSearch domain is VPC-only — the template must be applied from inside the VPC.
SSM into the EC2 after Step 4, then:

```bash
aws ssm start-session \
  --target $(aws ssm get-parameter \
    --name /pds/web-analytics/ec2/logstash_instance_id \
    --query Parameter.Value --output text)

# On the EC2:
curl -X PUT "https://<opensearch-endpoint>/_index_template/pds-web-analytics" \
  -H 'Content-Type: application/json' \
  --aws-sigv4 "aws:amz:us-west-2:es" \
  --user "${AWS_ACCESS_KEY_ID}:${AWS_SECRET_ACCESS_KEY}" \
  -d @/opt/logstash/config/opensearch/ecs-8.17-custom-template.json
```

> **Visualization:** Use the AWS-hosted [OpenSearch UI](https://docs.aws.amazon.com/opensearch-service/latest/developerguide/application.html)
> with IAM Identity Center. OpenSearch Dashboards is not used — the domain has no public endpoint.
>
> TODO: document OpenSearch UI application setup.

---

### pdc-cds-infra: grant Logstash read access to the CloudFront logs bucket

This must be applied in the `pdc-cds-infra` repo before the EC2 can read CloudFront logs.

```bash
cd pdc-cds-infra/terraform/cloudfront/pds-main/

# Fill in tfvars/dev.tfvars:
#   web_analytics_ec2_role_arn = "arn:aws:iam::<account>:role/<role-name>"

task init   VENUE=dev
task plan   VENUE=dev   # verify only the pds-logs bucket policy changes
task deploy VENUE=dev
```

---

### Chunk 1: S3 bucket, IAM policy, and Logstash EC2 (run last)

Depends on the OpenSearch endpoint SSM parameter from Chunk 2.

```bash
cd terraform/

task init    VENUE=dev
task plan    VENUE=dev   # review: S3 bucket, IAM policy update (es:ESHttp*), EC2 instance
task deploy  VENUE=dev
```

After apply, the EC2 instance ID is published to SSM at:
- `/pds/web-analytics/ec2/logstash_instance_id`

---

## Post-deploy: start Logstash

The EC2 bootstrap installs Docker and the Logstash systemd service, but does **not**
auto-start it — the pipeline config must be deployed first.

```bash
# Connect via Systems Manager Session Manager (no SSH key needed)
aws ssm start-session \
  --target $(aws ssm get-parameter \
    --name /pds/web-analytics/ec2/logstash_instance_id \
    --query Parameter.Value --output text)

# On the EC2 — deploy the pipeline config from this repo
sudo cp -r /path/to/web-analytics/config/logstash/config/* /opt/logstash/config/

# Start Logstash
sudo systemctl start logstash
sudo systemctl status logstash
sudo journalctl -u logstash -f   # tail logs
```

Verify a document reached OpenSearch:
```bash
curl -X GET "https://<endpoint>/_cat/indices?v" \
  -u "<master_user>:<master_password>"
```

---

## Teardown order

Reverse of deployment — destroy Chunk 1 first, then templates, then the domain last
(domain destruction also removes all indexed data).

```bash
task destroy           VENUE=dev   # Chunk 1: EC2 + IAM + S3
task templates:destroy VENUE=dev   # Chunk 3: index templates
task opensearch:destroy VENUE=dev  # Chunk 2: domain (destroys all data)
```

---

## Architecture notes

- **State files** are stored in `pds-<venue>-infra` S3 bucket, one per module:
  - `web-analytics/terraform.tfstate`
  - `web-analytics/opensearch.tfstate`
  - `web-analytics/opensearch-index-templates.tfstate`
- **VPC/SG values** are currently in tfvars. TODO: move to SSM under `/pds/cds-infra/vpc/` once published, matching the pattern at `/pds/cds-infra/vpc/security_groups/`.
- **OpenSearch** is deployed inside the VPC with no public endpoint. FGAC is enabled with an IAM role as master user (`AWSReservedSSO_Project-Power-User`). Visualization is via AWS-hosted OpenSearch UI with IAM Identity Center — OpenSearch Dashboards is not used.
- **TODO:** Document OpenSearch UI application setup (create application in AWS console, connect domain as data source, assign IAM Identity Center users/groups).
- **Logstash sincedb** files persist to `/var/lib/logstash/sincedb` on the EC2 EBS volume (`delete_on_termination = false`) — S3 read position is preserved across restarts and redeployments.
