data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "ec2_web_analytics_access" {
  statement {
    effect = "Allow"
    actions = [
      "s3:List*",
      "s3:GetObject*",
      "s3:Bucket*"
    ]
    resources = [
      "arn:${var.partition}:s3:::${var.logs_s3_bucket_name}",
      "arn:${var.partition}:s3:::${var.logs_s3_bucket_name}/*"
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "es:ESHttp*",
      "es:DescribeElasticsearchDomain",
      "es:DescribeDomain"
    ]
    resources = [
      "arn:${var.partition}:es:${var.aws_region}:${data.aws_caller_identity.current.account_id}:domain/${var.opensearch_domain_name}",
      "arn:${var.partition}:es:${var.aws_region}:${data.aws_caller_identity.current.account_id}:domain/${var.opensearch_domain_name}/*"
    ]
  }
}

resource "aws_iam_policy" "ec2_web_analytics_access" {
  name        = "${var.resource_prefix}-web-analytics-access-policy"
  description = "Allow EC2 role to read from ${var.logs_s3_bucket_name} and write to OpenSearch domain ${var.opensearch_domain_name}"
  policy      = data.aws_iam_policy_document.ec2_web_analytics_access.json
  tags        = var.common_tags
}
