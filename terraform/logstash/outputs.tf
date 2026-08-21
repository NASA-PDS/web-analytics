output "logstash_instance_id" {
  value       = aws_ssm_parameter.logstash_instance_id.value
  description = "Instance ID of the Logstash EC2 (created by this module, or existing_instance_id when manage_ec2_instance = false)"
}

output "logstash_ssm_document_name" {
  value       = aws_ssm_document.logstash_runas.name
  description = "Pass as --document-name to land an SSM session as the logstash user (no sudo)"
}
