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
  description = "Tag value for applicaiton component"
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

variable "pds_resource_prefix" {
  description = "PDS Resource prefix for Terrafrom Resources"
  type        = string
}

variable "ec2_role_name" {
  description = "Existing PDS EC2 IAM role name"
  type        = string
}

variable "opensearch_domain_name" {
  description = "Name of the managed OpenSearch domain"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID for the Logstash EC2 and security group lookup. TODO: replace with SSM data source under /pds/cds-infra/vpc/id once published."
  type        = string
  sensitive   = true
}

variable "ec2_security_group_name" {
  description = "Name of the existing MCP EC2 security group to attach to the Logstash instance. TODO: replace with SSM lookup under /pds/cds-infra/vpc/security_groups/ once published."
  type        = string
  default     = "pdsmcp-dev-ec2-sg"
}

variable "ec2_name_prefix" {
  description = "Name prefix for the Logstash EC2 and launch template. Excludes CI/CD pipeline identifiers like gh01dc."
  type        = string
  default     = ""
}

variable "logstash_instance_type" {
  description = "EC2 instance type for the Logstash instance. t3.large provides 8GB RAM, sufficient for a 4GB JVM heap."
  type        = string
  default     = "t3.large"
}

variable "logstash_version" {
  description = "Logstash Docker image version tag"
  type        = string
  default     = "8.17.0"
}

