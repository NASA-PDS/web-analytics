# Logstash Module

Deploys a Logstash EC2 instance (Amazon Linux 2023, RPM install) that reads logs from S3 and writes to OpenSearch.

Reads the S3 bucket name and OpenSearch endpoint from SSM at plan time — deploy the S3 and pdc-observability OpenSearch modules first.

> **Requires `iam:PassRole`** — must be applied by a system administrator.

## Resources

- `aws_launch_template.logstash` — EC2 launch template; userdata installs Logstash via RPM (root, `logstash-bootstrap.sh`) then deploys config and starts Logstash as a `systemd --user` service under the `logstash` account (`logstash-deploy.sh`)
- `aws_instance.logstash` — EC2 instance (no SSH; access via SSM Session Manager)
- `aws_ssm_document.logstash_runas` — custom SSM Session document (Run-As `logstash`) so operators never need sudo for day-2 ops
- `aws_ssm_parameter.ec2_role_arn` — publishes EC2 role ARN to `/pds/web-analytics/iam/ec2_role_arn`
- `aws_ssm_parameter.logstash_instance_id` — publishes instance ID to `/pds/web-analytics/ec2/logstash_instance_id`
- `aws_ssm_parameter.logstash_runas_document` — publishes the Run-As document name to `/pds/web-analytics/ssm/logstash_runas_document`

### Access model

Session access is SSM Session Manager only (no SSH keys, no inbound security
group rules). Sessions started with `--document-name` set to the
`logstash_runas` document land directly as the shared `logstash` OS account
— execution, logging, monitoring, and git-based config updates are all done
by that account with **no sudo**. The only step that still requires root is
`scripts/logstash-bootstrap.sh` (package/RPM install and initial account
provisioning), run automatically at first boot and otherwise only for
deliberate admin actions like a Logstash version upgrade.

> Granting operators `ssm:StartSession` on the `logstash_runas` document's
> ARN (in addition to the instance ARN) is an IAM/SSO concern owned outside
> this repo — this module only manages the EC2 instance role.

## SSM dependencies (read at plan time)

| Parameter | Published by |
|---|---|
| `/pds/web-analytics/s3/bucket_name` | `s3` module |
| `/pds/observability/opensearch/opensearch_endpoint` | `pdc-observability` repo |

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `vpc_id` | `string` | — | VPC ID for subnet and security group lookup. |
| `ec2_security_group_name` | `string` | — | Name of the EC2 security group to attach. |
| `ec2_role_name` | `string` | — | Existing EC2 IAM role / instance profile name. |
| `resource_prefix` | `string` | — | Prefix for all resource names (e.g. `pds-dev`). No CI/CD identifiers. |
| `s3_cf_bucket_name` | `string` | `""` | S3 bucket containing CloudFront logs (EN node only). Leave empty to skip. |
| `logstash_instance_type` | `string` | `t3.large` | EC2 instance type. |
| `logstash_version` | `string` | `8.17.0` | Logstash RPM version to install. |
| `mcp_ami_owner_id` | `string` | `794625662971` | AWS account ID that owns the Amazon Linux 2023 AMIs. |
| `aws_region` | `string` | `us-west-2` | AWS region. |
| `partition` | `string` | `aws` | AWS partition. |
| `venue` | `string` | — | Deployment venue (`dev`, `test`, `prod`). |
| `tenant` | `string` | — | Tag: tenant identifier. |
| `component` | `string` | — | Tag: component name. |
| `cicd` | `string` | — | Tag: CI/CD method. |
| `managedby` | `string` | — | Tag: owner contact. |

## Outputs

| Name | Description |
|---|---|
| `logstash_instance_id` | EC2 instance ID of the Logstash instance. |
| `logstash_ssm_document_name` | Pass as `--document-name` to land an SSM session as the `logstash` user (no sudo). |

## Deploy

```bash
cp tfvars/dev.tfvars.example tfvars/dev.tfvars
# edit tfvars/dev.tfvars

task logstash:plan   VENUE=dev
task logstash:deploy VENUE=dev
```

Shared values come from `../tfvars/common-<venue>.tfvars`.
