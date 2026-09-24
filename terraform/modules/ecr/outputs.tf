output "repository_url" {
  description = "Full ECR repository URL — used in cloud-init and CI to tag/push images"
  value       = aws_ecr_repository.bankapp.repository_url
}

output "repository_name" {
  description = "ECR repository name"
  value       = aws_ecr_repository.bankapp.name
}

output "repository_arn" {
  description = "ECR repository ARN — used in IAM policies for GitHubActionsRole and EC2 instance profile"
  value       = aws_ecr_repository.bankapp.arn
}

output "registry_id" {
  description = "AWS account ID owning the registry"
  value       = aws_ecr_repository.bankapp.registry_id
}

output "repository_uri" {
  description = "Alias for repository_url (Convenience)"
  value       = aws_ecr_repository.bankapp.repository_url
}