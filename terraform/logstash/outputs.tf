output "logstash_instance_id" {
  value       = aws_instance.logstash.id
  description = "Instance ID of the Logstash EC2"
}
