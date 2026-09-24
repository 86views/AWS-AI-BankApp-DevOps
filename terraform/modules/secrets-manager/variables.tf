variable "project_name" {
  description = "Project name (used as the SSM path prefix)"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}

variable "kms_key_id" {
  description = "Optional KMS key ARN. Leave empty to use alias/aws/ssm (free, AWS-managed)."
  type        = string
  default     = ""
}

# --- Payload ---

variable "db_host" {
  description = "DB host (Docker service name, e.g. 'mysql')"
  type        = string
  default     = "mysql"
}

variable "db_port" {
  description = "DB port"
  type        = string
  default     = "3306"
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = "bankappdb"
}

variable "db_user" {
  description = "Database user"
  type        = string
  default     = "bankuser"
}

variable "db_password" {
  description = "Database password (stored as SecureString)"
  type        = string
  sensitive   = true
}

variable "mysql_root_password" {
  description = "MySQL root password (stored as SecureString)"
  type        = string
  sensitive   = true
}

variable "ollama_url" {
  description = "Ollama base URL"
  type        = string
  default     = "http://ollama:11434"
}