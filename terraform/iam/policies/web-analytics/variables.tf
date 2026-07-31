variable "aws_region" {
  type    = string
  default = "us-west-2"
}

variable "partition" {
  type    = string
  default = "aws"
}

variable "pds_resource_prefix" {
  type        = string
  description = "PDS resource prefix (e.g. pds-dev-gh01dc)"
}

variable "ec2_role_name" {
  type        = string
  description = "Name of the existing EC2 IAM role to attach the policy to"
}

variable "opensearch_domain_name" {
  type        = string
  description = "Name of the managed OpenSearch domain"
}

variable "common_tags" {
  type        = map(string)
  description = "Common tags to apply to all resources"
  default     = {}
}
