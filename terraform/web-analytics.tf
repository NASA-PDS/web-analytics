module "s3_bucket" {
  source      = "git@github.com:NASA-PDS/pds-tf-modules.git//terraform/modules/s3/bucket"
  bucket_name = local.s3_bucket_name
  partition   = var.partition
  versioning  = "Enabled"

  # MCP enforces public access blocks at the account level; enable_blocks=false avoids a redundant conflict
  enable_blocks = false
  enable_policy = true

  bucket_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "AllowOnlyMCPTenantOperator",
        Effect = "Allow",
        Principal = {
          AWS = [
            "arn:${var.partition}:iam::${data.aws_caller_identity.current.account_id}:role/mcp-tenantOperator",
            "arn:${var.partition}:iam::${data.aws_caller_identity.current.account_id}:role/${var.ec2_role_name}"
          ]
        },
        Action = "s3:*",
        Resource = [
          "arn:${var.partition}:s3:::${local.s3_bucket_name}",
          "arn:${var.partition}:s3:::${local.s3_bucket_name}/*"
        ]
      },
      {
        Sid       = "AllowSSLRequestsOnly",
        Effect    = "Deny",
        Principal = "*",
        Action    = "s3:*",
        Resource = [
          "arn:${var.partition}:s3:::${local.s3_bucket_name}",
          "arn:${var.partition}:s3:::${local.s3_bucket_name}/*"
        ],
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })

  required_tags = {
    tenant    = var.tenant
    venue     = var.venue
    component = var.component
    cicd      = var.cicd
    managedby = var.managedby
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "lifecycle" {
  bucket = module.s3_bucket.bucket_name

  rule {
    id     = "transition-to-intelligent-tiering"
    status = "Enabled"

    filter {}

    transition {
      days          = 0
      storage_class = "INTELLIGENT_TIERING"
    }

    noncurrent_version_transition {
      noncurrent_days = 0
      storage_class   = "INTELLIGENT_TIERING"
    }
  }
}

