variable "aws_region" {
  type    = string
  default = "us-west-2"
}

variable "partition" {
  type    = string
  default = "aws"
}

variable "logs_s3_bucket_name" {
  type        = string
  description = "Full name of the S3 logs bucket (e.g. pds-logs-dev)"
}

variable "resource_prefix" {
  type        = string
  description = "Prefix for IAM policy names and all non-S3 resources (e.g. pds-dev)."
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
