# =============================================================================
# App SG outputs
# =============================================================================

output "app_sg_id" {
  description = "ID of the app security group (pass to EC2 module's security_group_id)"
  value       = aws_security_group.app.id
}

output "app_sg_arn" {
  description = "ARN of the app security group"
  value       = aws_security_group.app.arn
}

output "app_sg_name" {
  description = "Name of the app security group"
  value       = aws_security_group.app.name
}

# =============================================================================
# AI SG outputs (empty when create_ai_sg = false)
# =============================================================================

output "ai_sg_id" {
  description = "ID of the AI security group (empty string if not created)"
  value       = var.create_ai_sg ? aws_security_group.ai[0].id : ""
}

output "ai_sg_arn" {
  description = "ARN of the AI security group (empty string if not created)"
  value       = var.create_ai_sg ? aws_security_group.ai[0].arn : ""
}

output "ai_sg_name" {
  description = "Name of the AI security group (empty string if not created)"
  value       = var.create_ai_sg ? aws_security_group.ai[0].name : ""
}