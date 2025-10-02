output "s3_bucket_name" {
  value       = aws_s3_bucket.web_analytics.id
  description = "Name of the S3 bucket created for web analytics logs."
}

output "s3_bucket_arn" {
  value       = aws_s3_bucket.web_analytics.arn
  description = "ARN of the S3 bucket."
}

output "ec2_role_name" {
  value       = data.aws_iam_role.ec2_instance_role.name
  description = "Existing EC2 IAM role attached to the policy"
}

output "ec2_policy_name" {
  value       = aws_iam_policy.ec2_web_analytics_access.name
  description = "IAM policy name granting acccess to S3 and AOSS"
}
