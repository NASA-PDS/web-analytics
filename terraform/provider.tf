# AWS
# ===
#
# Amazon Web Services: the basics.

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      tenant    = var.tenant
      venue     = var.venue
      component = var.component
      createdBy = var.createdBy
      cicd      = var.cicd
    }
  }
}

# Fetch the default VPC and subnet to keep things simple
data "aws_vpc" "default" {
  id = var.vpc_id
}
