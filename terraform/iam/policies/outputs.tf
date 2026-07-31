output "policy_arn" {
  value       = module.web_analytics.policy_arn
  description = "ARN of the web-analytics EC2 access policy"
}

output "policy_name" {
  value       = module.web_analytics.policy_name
  description = "Name of the web-analytics EC2 access policy"
}
