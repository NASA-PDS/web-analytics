variable "aws_region" {
  description = "The AWS region to deploy in"
  type        = string
  default     = "us-west-2"
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
  sensitive   = true
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
  description = "Tag value for applicaiton component"
  type        = string
}

variable "createdBy" {
  description = "Tag value for owner managing the resource (E.g. for PDS Team we have PDS Team Email Distro)"
  type        = string
}

variable "partition" {
  description = "AWS Partition"
  type        = string
  default     = "aws"
}

variable "pds_resource_prefix" {
  description = "PDS Resource prefix for Terrafrom Resources"
  type        = string
}

variable "ec2_role_name" {
  description = "Existing PDS EC2 IAM role name"
  type        = string
}

variable "aoss_collection_name" {
  description = "Exiting PDS OpenSearch Serverless collection name"
  type        = string
}

locals {
  s3_bucket_name = "${var.pds_resource_prefix}-web-analytics"
}
