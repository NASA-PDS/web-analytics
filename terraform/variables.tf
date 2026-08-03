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
  description = "Tag value for owner managing the resource (E.g. for PDS Team we have PDS Team Email Distro)"
  type        = string
}

variable "partition" {
  description = "AWS Partition"
  type        = string
  default     = "aws"
}

variable "s3_bucket_prefix" {
  description = "Prefix for the S3 bucket name only (e.g. pds-dev-gh01dc). May include CI/CD pipeline identifiers for existing buckets."
  type        = string
}

variable "ec2_role_name" {
  description = "Existing PDS EC2 IAM role name — used in the S3 bucket policy AllowEC2Role statement"
  type        = string
}
