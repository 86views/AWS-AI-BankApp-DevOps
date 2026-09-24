# =============================================================================
# EC2 role outputs
# =============================================================================

output "instance_profile_name" {
  description = "Name of the EC2 instance profile (pass to EC2 module's instance_profile_name)"
  value       = aws_iam_instance_profile.ec2.name
}

output "instance_profile_arn" {
  description = "ARN of the EC2 instance profile"
  value       = aws_iam_instance_profile.ec2.arn
}

output "ec2_role_name" {
  description = "Name of the EC2 IAM role"
  value       = aws_iam_role.ec2.name
}

output "ec2_role_arn" {
  description = "ARN of the EC2 IAM role"
  value       = aws_iam_role.ec2.arn
}

# =============================================================================
# GitHub Actions role outputs (used by GitHub Actions workflow)
# =============================================================================

output "github_actions_role_arn" {
  description = "ARN of the GitHub Actions role — put this in GitHub Secret AWS_ROLE_ARN"
  value       = aws_iam_role.github_actions.arn
}

output "github_actions_role_name" {
  description = "Name of the GitHub Actions role"
  value       = aws_iam_role.github_actions.name
}

output "github_oidc_provider_arn" {
  description = "ARN of the existing GitHub OIDC provider (referenced, not created)"
  value       = data.aws_iam_openid_connect_provider.github.arn
}