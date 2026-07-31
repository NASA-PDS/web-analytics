variable "aws_region" {
  type        = string
  description = "AWS region"
  default     = "us-west-2"
}

variable "partition" {
  type        = string
  description = "AWS partition"
  default     = "aws"
}

variable "s3_bucket_prefix" {
  type        = string
  description = "Prefix for the S3 bucket name (e.g. pds-dev-gh01dc). Must match deployed bucket."
}

variable "resource_prefix" {
  type        = string
  description = "Prefix for IAM policy names and all non-S3 resources (e.g. pds-dev). No CI/CD identifiers."
}

variable "ec2_role_name" {
  type        = string
  description = "Name of the existing EC2 IAM role to attach the policy to"
}

variable "opensearch_domain_name" {
  type        = string
  description = "Name of the managed OpenSearch domain"
}

variable "venue" {
  type        = string
  description = "Deployment venue (dev, test, prod)"
}

variable "tenant" {
  type    = string
  default = "en"
}

variable "component" {
  type    = string
  default = "web-analytics"
}

variable "cicd" {
  type    = string
  default = "terraform"
}

variable "managedby" {
  type    = string
  default = "pdsoperator@jpl.nasa.gov"
}
