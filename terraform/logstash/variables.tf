variable "aws_region" {
  description = "The AWS region to deploy in"
  type        = string
  default     = "us-west-2"
}

variable "tenant" {
  description = "Tag value for Tenant"
  type        = string
}

variable "cicd" {
  description = "Tag value for CICD deployment method"
  type        = string
}

variable "venue" {
  description = "Tag value for Venue"
  type        = string
}

variable "component" {
  description = "Tag value for application component"
  type        = string
}

variable "managedby" {
  description = "Tag value for owner managing the resource"
  type        = string
}

variable "resource_prefix" {
  description = "Prefix for all resources (e.g. pds-dev). No CI/CD pipeline identifiers."
  type        = string
}

variable "ec2_role_name" {
  description = "Existing PDS EC2 IAM role name (used as instance profile)"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID for the Logstash EC2 and security group lookup. TODO: replace with SSM data source under /pds/cds-infra/vpc/id once published."
  type        = string
  sensitive   = true
}

variable "ec2_security_group_id" {
  description = "Security group ID of the MCP EC2 security group to attach to the Logstash instance. TODO: replace with SSM lookup under /pds/cds-infra/vpc/security_groups/ once published."
  type        = string
}

variable "logstash_instance_type" {
  description = "EC2 instance type for the Logstash instance. t3.large provides 8GB RAM, sufficient for a 4GB JVM heap."
  type        = string
  default     = "t3.large"
}

variable "logstash_version" {
  description = "Logstash RPM version to install"
  type        = string
  default     = "8.17.0"
}

variable "s3_cf_bucket_name" {
  description = "Name of the S3 bucket containing CloudFront access logs (EN node only). Leave empty to skip CloudFront log ingestion."
  type        = string
  default     = ""
}
