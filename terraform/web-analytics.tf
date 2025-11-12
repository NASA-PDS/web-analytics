data "aws_iam_role" "ec2_instance_role" {
  name = var.ec2_role_name
}
resource "aws_s3_bucket" "web_analytics" {
  bucket = local.s3_bucket_name
  tags = {
    Name = "PDS Web Analytics Logs"
  }
}

/* resource "aws_s3_bucket_public_access_block" "pab" {
  bucket                  = aws_s3_bucket.web_analytics.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
} */

resource "aws_s3_bucket_server_side_encryption_configuration" "sse" {
  bucket = aws_s3_bucket.web_analytics.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "versioning" {
  bucket = aws_s3_bucket.web_analytics.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "lifecycle" {
  bucket = aws_s3_bucket.web_analytics.id
  rule {
    id     = "keep-logs"
    status = "Enabled"
    filter {
      prefix = "logs/"
    }
  }

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

resource "aws_s3_bucket_policy" "bucket_policy" {
  bucket = aws_s3_bucket.web_analytics.id

  policy = jsonencode({
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
}

data "aws_iam_policy_document" "ec2_web_analytics_access" {
  statement {
    effect = "Allow"
    actions = [
      "s3:List*",
      "s3:GetObject*",
      "s3:Bucket*"
    ]
    resources = [
      "arn:${var.partition}:s3:::${local.s3_bucket_name}"
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "aoss:APIAccessAll",
      "aoss:DashboardsAccessAll"
    ]
    resources = [
      "arn:aws:aoss:${var.aws_region}:${data.aws_caller_identity.current.account_id}:collection/${var.aoss_collection_name}"
    ]
  }
}

resource "aws_iam_policy" "ec2_web_analytics_access" {
  name        = "${local.s3_bucket_name}-access-policy"
  description = "Allow EC2 role to read from ${local.s3_bucket_name} and write to AOSS collection ${var.aoss_collection_name}"
  policy      = data.aws_iam_policy_document.ec2_web_analytics_access.json
}

# Attach the policy to the existing EC2 role
resource "aws_iam_role_policy_attachment" "attach_access_to_ec2_role" {
  role       = data.aws_iam_role.ec2_instance_role.name
  policy_arn = aws_iam_policy.ec2_web_analytics_access.arn
}
