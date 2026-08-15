output "logstash_instance_id" {
  value       = aws_instance.logstash.id
  description = "Instance ID of the Logstash EC2"
}

output "logstash_ssm_document_name" {
  value       = aws_ssm_document.logstash_runas.name
  description = "Pass as --document-name to land an SSM session as the logstash user (no sudo)"
}
