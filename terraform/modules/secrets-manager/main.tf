# =============================================================================
# SSM Parameter Store — free alternative to Secrets Manager
# =============================================================================
# Stores DB credentials as SecureString parameters. Encrypted with the
# AWS-managed key (free). No per-secret charge.
#
# Naming convention:
#   /<project_name>/<environment>/db/host
#   /<project_name>/<environment>/db/port
#   /<project_name>/<environment>/db/name
#   /<project_name>/<environment>/db/user
#   /<project_name>/<environment>/db/password   (SecureString)
#   /<project_name>/<environment>/db/root_password (SecureString)
#   /<project_name>/<environment>/ollama/url
#
# cloud-init reads each with `aws ssm get-parameter --with-decryption`.
# =============================================================================

locals {
  base_path = "/${var.project_name}/${var.environment}"
}

# --- Non-sensitive parameters ---

resource "aws_ssm_parameter" "db_host" {
  name  = "${local.base_path}/db/host"
  type  = "String"
  value = var.db_host

  tags = merge(var.tags, { Name = "${var.project_name}-db-host" })
}

resource "aws_ssm_parameter" "db_port" {
  name  = "${local.base_path}/db/port"
  type  = "String"
  value = var.db_port

  tags = merge(var.tags, { Name = "${var.project_name}-db-port" })
}

resource "aws_ssm_parameter" "db_name" {
  name  = "${local.base_path}/db/name"
  type  = "String"
  value = var.db_name

  tags = merge(var.tags, { Name = "${var.project_name}-db-name" })
}

resource "aws_ssm_parameter" "db_user" {
  name  = "${local.base_path}/db/user"
  type  = "String"
  value = var.db_user

  tags = merge(var.tags, { Name = "${var.project_name}-db-user" })
}

resource "aws_ssm_parameter" "ollama_url" {
  name  = "${local.base_path}/ollama/url"
  type  = "String"
  value = var.ollama_url

  tags = merge(var.tags, { Name = "${var.project_name}-ollama-url" })
}

# --- Sensitive parameters (SecureString, KMS-encrypted) ---

resource "aws_ssm_parameter" "db_password" {
  name   = "${local.base_path}/db/password"
  type   = "SecureString"
  value  = var.db_password
  key_id = var.kms_key_id != "" ? var.kms_key_id : "alias/aws/ssm" # AWS-managed key = free

  tags = merge(var.tags, { Name = "${var.project_name}-db-password" })

  lifecycle {
    ignore_changes = [value] # allow out-of-band rotation
  }
}

resource "aws_ssm_parameter" "mysql_root_password" {
  name   = "${local.base_path}/db/root_password"
  type   = "SecureString"
  value  = var.mysql_root_password
  key_id = var.kms_key_id != "" ? var.kms_key_id : "alias/aws/ssm"

  tags = merge(var.tags, { Name = "${var.project_name}-mysql-root-password" })

  lifecycle {
    ignore_changes = [value]
  }
}