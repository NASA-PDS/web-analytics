locals {
  s3_bucket_name  = "${var.s3_bucket_prefix}-web-analytics"
  resource_prefix = var.resource_prefix != "" ? var.resource_prefix : "pds-${var.venue}"
}
