output "instance_ids" {
  description = "Map of Instance Name -> Instance ID"
  value       = { for k, v in aws_instance.cluster : k => v.id }
}

output "private_ips" {
  description = "Map of Instance Name -> Private IP"
  value       = { for k, v in aws_instance.cluster : k => v.private_ip }
}
