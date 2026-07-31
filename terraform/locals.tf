locals {
  s3_bucket_name  = "${var.pds_resource_prefix}-web-analytics"
  ec2_name_prefix = var.ec2_name_prefix != "" ? var.ec2_name_prefix : "pds-${var.venue}"
}
