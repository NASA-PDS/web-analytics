data "aws_caller_identity" "current" {}

locals {
  access_policies      = jsondecode(file(var.policy_json_file))
  module_relative_path = replace(abspath(path.module), "/^.*\\/terraform\\//", "")
  ssm_prefix           = "/pds/web-analytics/${local.module_relative_path}"
}

# Security group for the OpenSearch domain VPC endpoint.
# Allows HTTPS inbound only from the Logstash EC2 security group.
# Only created when vpc_enabled = true.
resource "aws_security_group" "opensearch" {
  count       = var.vpc_enabled ? 1 : 0
  name        = "${var.domain_name}-opensearch-sg"
  description = "OpenSearch domain VPC endpoint - HTTPS inbound from Logstash EC2 only"
  vpc_id      = var.vpc_id

  ingress {
    description     = "HTTPS from Logstash EC2"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [var.ec2_security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name      = "${var.domain_name}-opensearch-sg"
    venue     = var.venue
    tenant    = var.tenant
    component = var.component
    managedby = var.managedby
  }
}

resource "aws_opensearch_domain" "pds_opensearch_domain" {
  domain_name    = var.domain_name
  engine_version = var.engine_version

  cluster_config {
    instance_type  = var.data_node_instance_type
    instance_count = var.data_node_count

    dedicated_master_enabled = var.dedicated_master_enabled
    dedicated_master_type    = var.master_node_instance_type
    dedicated_master_count   = var.master_node_count

    zone_awareness_enabled = var.zone_awareness_enabled
    dynamic "zone_awareness_config" {
      for_each = var.zone_awareness_enabled ? [1] : []
      content {
        availability_zone_count = var.availability_zone_count
      }
    }
  }

  ebs_options {
    ebs_enabled = true
    volume_type = var.ebs_volume_type
    volume_size = var.ebs_volume_gb
  }

  encrypt_at_rest {
    enabled = var.encryption_at_rest
  }

  node_to_node_encryption {
    enabled = var.n2n_encryption
  }

  domain_endpoint_options {
    enforce_https       = true
    tls_security_policy = "Policy-Min-TLS-1-2-2019-07"
  }

  advanced_security_options {
    enabled = false
  }

  dynamic "vpc_options" {
    for_each = var.vpc_enabled ? [1] : []
    content {
      subnet_ids         = var.vpc_subnet_ids
      security_group_ids = [aws_security_group.opensearch[0].id]
    }
  }

  tags = {
    Name = var.domain_name
  }
}


data "aws_iam_policy_document" "domain_access_policy" {
  dynamic "statement" {
    for_each = local.access_policies

    content {
      sid     = statement.value.Sid
      effect  = statement.value.Effect
      actions = statement.value.Action
      resources = [
        for resource in statement.value.Resource :
        replace(
          replace(
            replace(resource, "{account_id}", data.aws_caller_identity.current.account_id),
            "{region}", var.aws_region
          ),
          "{domain_name}", var.domain_name
        )
      ]
      principals {
        type = "AWS"
        identifiers = [
          for principal in statement.value.Principal :
          replace(principal, "{account_id}", data.aws_caller_identity.current.account_id)
        ]
      }
    }
  }
}

resource "aws_opensearch_domain_policy" "domain_access_policy" {
  domain_name     = var.domain_name
  access_policies = data.aws_iam_policy_document.domain_access_policy.json

  depends_on = [aws_opensearch_domain.pds_opensearch_domain]
}
