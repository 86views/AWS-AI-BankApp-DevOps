output "base_path" {
  description = "Base SSM path prefix (e.g. /devsecops-bankapp/dev)"
  value       = local.base_path
}

output "parameter_arns" {
  description = "Map of parameter name → ARN (used by IAM policy)"
  value = {
    db_host             = aws_ssm_parameter.db_host.arn
    db_port             = aws_ssm_parameter.db_port.arn
    db_name             = aws_ssm_parameter.db_name.arn
    db_user             = aws_ssm_parameter.db_user.arn
    db_password         = aws_ssm_parameter.db_password.arn
    mysql_root_password = aws_ssm_parameter.mysql_root_password.arn
    ollama_url          = aws_ssm_parameter.ollama_url.arn
  }
}

output "parameter_paths" {
  description = "Map of logical name → SSM path (useful for cloud-init templating)"
  value = {
    db_host             = aws_ssm_parameter.db_host.name
    db_port             = aws_ssm_parameter.db_port.name
    db_name             = aws_ssm_parameter.db_name.name
    db_user             = aws_ssm_parameter.db_user.name
    db_password         = aws_ssm_parameter.db_password.name
    mysql_root_password = aws_ssm_parameter.mysql_root_password.name
    ollama_url          = aws_ssm_parameter.ollama_url.name
  }
}

# Convenience: wildcard ARN for IAM policy (all params under the project path)
output "parameter_arn_prefix" {
  description = "Wildcard ARN for all parameters under this project's path (use in IAM policy)"
  value       = "arn:aws:ssm:*:*:parameter${local.base_path}/*"
}