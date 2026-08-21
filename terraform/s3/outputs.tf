output "s3_bucket_name" {
  value       = module.s3_bucket.bucket_name
  description = "Name of the S3 bucket created for web analytics logs."
}

output "s3_bucket_arn" {
  value       = module.s3_bucket.bucket_arn
  description = "ARN of the S3 bucket."
}
