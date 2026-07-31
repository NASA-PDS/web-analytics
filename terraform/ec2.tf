# ---------------------------------------------------------------------------
# Logstash EC2 instance
# ---------------------------------------------------------------------------
# AMI: MCP-managed Amazon Linux 2 (owner 794625662971), consistent with
# the pattern used in pds-tf-modules/terraform/modules/ec2/main.tf.
#
# Access: AWS Systems Manager (MCP-SSM-CloudWatch instance profile).
# No SSH key or inbound security group rules needed.
#
# TODO: vpc_id and ec2_security_group_name should be sourced from SSM once
# parameters are published under /pds/cds-infra/vpc/ — matching the pattern
# at /pds/cds-infra/vpc/security_groups/registry_api_ecs_app_sg_id etc.

data "aws_ami" "mcp_amazon_linux" {
  most_recent = true

  filter {
    name   = "name"
    values = ["MCP Amazon Linux 2023 2*"]
  }
  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["794625662971"]
}

data "aws_security_group" "mcp_ec2" {
  name   = var.ec2_security_group_name
  vpc_id = var.vpc_id
}

# Auto-select a private subnet — filters by map-public-ip-on-launch=false.
# No hardcoded subnet IDs required.
data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }
  filter {
    name   = "map-public-ip-on-launch"
    values = ["false"]
  }
}

data "aws_ssm_parameter" "opensearch_endpoint" {
  name = "/pds/observability/opensearch_managed/opensearch_endpoint"
}

locals {
  ec2_name = "${local.resource_prefix}-observability"
  logstash_tags = {
    tenant    = var.tenant
    venue     = var.venue
    component = var.component
    managedby = var.managedby
    cicd      = var.cicd
    Name      = local.ec2_name
  }
}

resource "aws_launch_template" "logstash" {
  name_prefix   = "${local.ec2_name}-"
  image_id      = data.aws_ami.mcp_amazon_linux.id
  instance_type = var.logstash_instance_type

  network_interfaces {
    associate_public_ip_address = false
    subnet_id                   = data.aws_subnets.private.ids[0]
    security_groups             = [data.aws_security_group.mcp_ec2.id]
  }

  iam_instance_profile {
    name = var.ec2_role_name
  }

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = 30
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = false
    }
  }

  user_data = base64encode(templatefile("${path.module}/templates/logstash-userdata.sh.tpl", {
    logstash_version    = var.logstash_version
    aws_region          = var.aws_region
    s3_bucket_name      = local.s3_bucket_name
    opensearch_endpoint = data.aws_ssm_parameter.opensearch_endpoint.value
    index_prefix        = local.resource_prefix
    s3_cf_bucket_name   = var.s3_cf_bucket_name
  }))

  tag_specifications {
    resource_type = "instance"
    tags          = local.logstash_tags
  }

  tag_specifications {
    resource_type = "volume"
    tags          = local.logstash_tags
  }

  tags = local.logstash_tags
}

resource "aws_instance" "logstash" {
  launch_template {
    id      = aws_launch_template.logstash.id
    version = "$Latest"
  }

  tags = local.logstash_tags
}

resource "aws_ssm_parameter" "logstash_instance_id" {
  name        = "/pds/web-analytics/ec2/logstash_instance_id"
  type        = "String"
  value       = aws_instance.logstash.id
  description = "Instance ID of the web-analytics Logstash EC2"
  overwrite   = true
}
