# =============================================================================
# Root Outputs — DevSecOps Banking Application
# =============================================================================
# These are the values you'll need to:
#   - Configure GitHub Actions secrets
#   - SSH into the instance (or start an SSM session)
#   - Verify the deployment
# =============================================================================

# =============================================================================
# Project reference
# =============================================================================

output "project_name" {
  description = "Project name (used as the SSM path prefix)"
  value       = var.project_name
}

output "environment" {
  description = "Deployment environment"
  value       = var.environment
}

# =============================================================================
# Networking
# =============================================================================

output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "public_subnet_id" {
  description = "ID of the public subnet used by the app EC2"
  value       = module.vpc.public_subnet_id
}

# =============================================================================
# Security Groups
# =============================================================================

output "app_sg_id" {
  description = "ID of the app security group"
  value       = module.security_groups.app_sg_id
}

output "ai_sg_id" {
  description = "ID of the AI security group (empty if not created)"
  value       = module.security_groups.ai_sg_id
}

# =============================================================================
# ECR
# =============================================================================

output "ecr_repository_url" {
  description = "Full ECR repository URL (used in cloud-init and CI: docker push/pull target)"
  value       = module.ecr.repository_url
}

output "ecr_repository_arn" {
  description = "ARN of the ECR repository"
  value       = module.ecr.repository_arn
}

output "ecr_repository_name" {
  description = "Name of the ECR repository"
  value       = module.ecr.repository_name
}

# =============================================================================
# IAM — values for GitHub Secrets
# =============================================================================

output "github_actions_role_arn" {
  description = "ARN of the GitHub Actions OIDC role → put in GitHub Secret AWS_ROLE_ARN"
  value       = module.iam.github_actions_role_arn
}

output "instance_profile_name" {
  description = "Name of the EC2 instance profile (for reference/debugging)"
  value       = module.iam.instance_profile_name
}

# =============================================================================
# EC2 — values for GitHub Secrets and access
# =============================================================================

output "instance_id" {
  description = "ID of the app EC2 instance → put in GitHub Secret EC2_INSTANCE_ID (SSM deploy)"
  value       = module.ec2.instance_id
}

output "ec2_public_ip" {
  description = "Public IP of the app EC2 (EIP if allocated) → put in GitHub Secret EC2_HOST (SSH deploy)"
  value       = module.ec2.public_ip
}

output "ec2_public_dns" {
  description = "Public DNS of the app EC2"
  value       = module.ec2.public_dns
}

output "ec2_private_ip" {
  description = "Private IP of the app EC2 (used internally by the AI tier, if split)"
  value       = module.ec2.private_ip
}

output "elastic_ip" {
  description = "Elastic IP address (empty if not allocated)"
  value       = module.ec2.elastic_ip
}

output "ssh_command" {
  description = "Ready-to-copy SSH hint (only valid when key_name is set and port 22 is open)"
  value       = module.ec2.ssh_connection_hint
}

output "ssm_session_command" {
  description = "Ready-to-copy SSM Session Manager command (requires enable_ssm = true and aws cli locally)"
  value       = "aws ssm start-session --target ${module.ec2.instance_id}"
}

# =============================================================================
# SSM Parameter Store — replaces Secrets Manager (free)
# =============================================================================

output "ssm_base_path" {
  description = "SSM Parameter Store base path (e.g. /devsecops-bankapp/dev)"
  value       = module.ssm.base_path
}

output "ssm_parameter_paths" {
  description = "Map of logical name → SSM parameter path (for manual aws ssm get-parameter use)"
  value       = module.ssm.parameter_paths
}

output "ssm_parameter_arn_prefix" {
  description = "Wildcard ARN covering all parameters under the project path (for IAM policies)"
  value       = module.ssm.parameter_arn_prefix
}

# =============================================================================
# Pipeline Quick Reference — GitHub Secrets
# =============================================================================
# SSH deploy (uses EC2_HOST + EC2_SSH_KEY):
#   AWS_ROLE_ARN      ← github_actions_role_arn
#   AWS_REGION        ← aws_region
#   ECR_REPO          ← ecr_repository_url
#   EC2_HOST          ← ec2_public_ip
#   EC2_SSH_KEY       ← contents of the .pem (added manually — Terraform can't read it)
#
# SSM deploy (uses EC2_INSTANCE_ID, keyless):
#   AWS_ROLE_ARN      ← github_actions_role_arn
#   AWS_REGION        ← aws_region
#   ECR_REPO          ← ecr_repository_url
#   EC2_INSTANCE_ID   ← instance_id
# =============================================================================

output "github_secrets_reference" {
  description = "Convenience map of values to put into GitHub repo Secrets"
  value = {
    AWS_ROLE_ARN    = module.iam.github_actions_role_arn
    AWS_REGION      = var.aws_region
    ECR_REPO        = module.ecr.repository_url
    EC2_HOST        = module.ec2.public_ip   # for SSH deploy
    EC2_INSTANCE_ID = module.ec2.instance_id # for SSM deploy
  }
  # Note: EC2_SSH_KEY must be added manually — Terraform can't read your private key.
}

# =============================================================================
# App access
# =============================================================================

output "app_url" {
  description = "URL to reach the running Spring Boot app"
  value       = "http://${module.ec2.public_ip}:${var.app_port}"
}