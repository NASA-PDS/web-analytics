data "aws_ssm_parameter" "opensearch_arn" {
  name = "/pds/observability/opensearch/opensearch_arn"
}

data "aws_iam_policy_document" "ec2_web_analytics_access" {
  statement {
    effect = "Allow"
    actions = [
      "s3:List*",
      "s3:GetObject*",
      "s3:GetBucket*"
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
      data.aws_ssm_parameter.opensearch_arn.value,
      "${data.aws_ssm_parameter.opensearch_arn.value}/*"
    ]
  }
}

resource "aws_iam_policy" "ec2_web_analytics_access" {
  name        = "${var.resource_prefix}-web-analytics-access-policy"
  description = "Allow EC2 role to read from ${var.logs_s3_bucket_name} and write to OpenSearch (ARN from SSM)"
  policy      = data.aws_iam_policy_document.ec2_web_analytics_access.json
  tags        = var.common_tags
}
