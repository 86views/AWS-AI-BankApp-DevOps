# =============================================================================
# Common
# =============================================================================

variable "project_name" {
  description = "Project name used in resource names"
  type        = string
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}

variable "permissions_boundary_arn" {
  description = "Optional permissions boundary ARN. Set to empty string to disable."
  type        = string
  default     = ""
}

# =============================================================================
# EC2 role inputs
# =============================================================================

variable "ecr_repository_arn" {
  description = "ARN of the ECR repository the instance can pull from (from ECR module output)"
  type        = string

  validation {
    condition     = can(regex("^arn:aws:ecr:[a-z0-9-]+:[0-9]{12}:repository/.+$", var.ecr_repository_arn))
    error_message = "ecr_repository_arn must be a valid ECR repository ARN."
  }
}



variable "enable_ssm" {
  description = "Attach SSM Session Manager permissions to the EC2 role"
  type        = bool
  default     = false
}

# =============================================================================
# GitHub OIDC role inputs
# =============================================================================

variable "github_org" {
  description = "GitHub organization or username that owns the repo"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name (without org prefix)"
  type        = string
}

variable "github_branch" {
  description = "Branch allowed to assume the GitHub Actions role"
  type        = string
  default     = "main"
}

variable "github_owner_id" {
  description = "GitHub owner numeric ID"
  type        = string
}

variable "github_repo_id" {
  description = "GitHub repository numeric ID"
  type        = string
}


# =============================================================================
# Existing (already declared in your file)
# =============================================================================


variable "aws_region" {
  description = "AWS region — used to build SSM and KMS ARNs"
  type        = string
}

variable "environment" {
  description = "Deployment environment — used in the SSM path prefix"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}

# =============================================================================
# REMOVE — no longer needed with SSM
# =============================================================================



# =============================================================================
# NEW — optional SSM-based deploy (Gate 8)
# =============================================================================

variable "enable_ssm_deploy" {
  description = "Allow GitHub Actions to send commands via SSM (keyless deploy, no SSH). Set true when you disable SSH ingress."
  type        = bool
  default     = false
}
