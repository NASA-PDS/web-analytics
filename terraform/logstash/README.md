# Logstash Module

Deploys a Logstash EC2 instance (MCP Amazon Linux 2023, RPM install) that reads logs from S3 and writes to OpenSearch.

Reads the S3 bucket name and OpenSearch endpoint from SSM at plan time — deploy the S3 and pdc-observability OpenSearch modules first.

> **Requires `iam:PassRole`** — must be applied by a system administrator.

## Resources

- `aws_launch_template.logstash` — EC2 launch template; userdata installs Logstash via RPM and runs `logstash-init.sh`
- `aws_instance.logstash` — EC2 instance (no SSH; access via SSM Session Manager)
- `aws_ssm_parameter.ec2_role_arn` — publishes EC2 role ARN to `/pds/web-analytics/iam/ec2_role_arn`
- `aws_ssm_parameter.logstash_instance_id` — publishes instance ID to `/pds/web-analytics/ec2/logstash_instance_id`

## SSM dependencies (read at plan time)

| Parameter | Published by |
|---|---|
| `/pds/web-analytics/s3/bucket_name` | `s3` module |
| `/pds/observability/opensearch/opensearch_endpoint` | `pdc-observability` repo |

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `vpc_id` | `string` | — | VPC ID for subnet and security group lookup. |
| `ec2_security_group_name` | `string` | — | Name of the MCP EC2 security group to attach. |
| `ec2_role_name` | `string` | — | Existing EC2 IAM role / instance profile name. |
| `resource_prefix` | `string` | — | Prefix for all resource names (e.g. `pds-dev`). No CI/CD identifiers. |
| `s3_cf_bucket_name` | `string` | `""` | S3 bucket containing CloudFront logs (EN node only). Leave empty to skip. |
| `logstash_instance_type` | `string` | `t3.large` | EC2 instance type. |
| `logstash_version` | `string` | `8.17.0` | Logstash RPM version to install. |
| `mcp_ami_owner_id` | `string` | `794625662971` | AWS account ID that owns the MCP Amazon Linux 2023 AMIs. |
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

## Deploy

```bash
cp tfvars/dev.tfvars.example tfvars/dev.tfvars
# edit tfvars/dev.tfvars

task logstash:plan   VENUE=dev
task logstash:deploy VENUE=dev
```

Shared values come from `../tfvars/common-<venue>.tfvars`.
