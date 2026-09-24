# =============================================================================
# Instance Identity
# =============================================================================

output "instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.app.id
}

output "instance_arn" {
  description = "ARN of the EC2 instance (useful for IAM/CloudWatch attachments)"
  value       = aws_instance.app.arn
}

output "ami_id" {
  description = "AMI ID actually used for the instance (debugging aid)"
  value       = aws_instance.app.ami
}

output "availability_zone" {
  description = "AZ where the instance is running"
  value       = aws_instance.app.availability_zone
}

# =============================================================================
# Networking
# =============================================================================

output "public_ip" {
  description = "Public IP of the instance (EIP if allocated, otherwise instance public IP)"
  value       = var.allocate_eip ? aws_eip.app[0].public_ip : aws_instance.app.public_ip
}

output "elastic_ip" {
  description = "Elastic IP address (empty string if not allocated)"
  value       = var.allocate_eip ? aws_eip.app[0].public_ip : ""
}

output "public_dns" {
  description = "Public DNS name (EIP DNS if allocated, otherwise instance public DNS)"
  value       = var.allocate_eip ? aws_eip.app[0].public_dns : aws_instance.app.public_dns
}

output "private_ip" {
  description = "Private IP of the instance (used by the Ollama tier, internal services, etc.)"
  value       = aws_instance.app.private_ip
}

output "private_dns" {
  description = "Private DNS name of the instance (more stable than private IP across restarts)"
  value       = aws_instance.app.private_dns
}

# =============================================================================
# Downstream / Pipeline Convenience
# =============================================================================

output "ecr_repository_url" {
  description = "ECR repository URL used by this instance (passthrough for deploy stage)"
  value       = var.ecr_repository_url
}

output "ssh_connection_hint" {
  description = "Ready-to-copy SSH hint (only valid when key_name is set and port 22 is open)"
  value       = var.key_name != "" ? "ssh -i <path-to-${var.key_name}.pem> ubuntu@${var.allocate_eip ? aws_eip.app[0].public_ip : aws_instance.app.public_ip}" : "SSH disabled — use AWS SSM Session Manager."
}