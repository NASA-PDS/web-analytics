output "s3_bucket_name" {
  value       = aws_s3_bucket.web_analytics.id
  description = "Name of the S3 bucket created for web analytics logs."
}

output "s3_bucket_arn" {
  value       = aws_s3_bucket.web_analytics.arn
  description = "ARN of the S3 bucket."
}
