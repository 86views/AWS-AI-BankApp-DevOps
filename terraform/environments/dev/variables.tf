# =============================================================================
# Root Variables — DevSecOps Banking Application
# =============================================================================
# All module inputs are surfaced here so terraform.tfvars stays flat and simple.
# =============================================================================

# =============================================================================
# Core / Project
# =============================================================================

variable "aws_region" {
  description = "AWS region to deploy all resources into"
  type        = string
  default     = "us-east-1"

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]$", var.aws_region))
    error_message = "aws_region must be a valid AWS region, e.g. us-east-1."
  }
}

variable "project_name" {
  description = "Project name used in resource names and tags (lowercase, alphanumeric, hyphens)"
  type        = string
  default     = "devsecops-bankapp"

  validation {
    condition     = can(regex("^[a-z0-9-]{3,32}$", var.project_name))
    error_message = "project_name must be 3-32 chars, lowercase alphanumeric and hyphens only."
  }
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
  description = "Additional tags applied to all resources"
  type        = map(string)
  default     = {}
}

# =============================================================================
# GitHub OIDC — source repo for the GitHubActionsRole trust policy
# =============================================================================

variable "github_org" {
  description = "GitHub username or organization that owns the repository"
  type        = string
  # e.g. "your-github-username"
}

variable "github_repo" {
  description = "GitHub repository name (without the org prefix)"
  type        = string
  default     = "DevSecOps-Bankapp"
}

variable "github_branch" {
  description = "Git branch allowed to assume the GitHub Actions role"
  type        = string
  default     = "devsecops"
}

# =============================================================================
# Networking (VPC module)
# =============================================================================

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a valid CIDR block, e.g. 10.0.0.0/16."
  }
}

variable "availability_zones" {
  description = "AZs to create subnets in. Leave empty to auto-pick the first available AZ."
  type        = list(string)
  default     = []
}

# =============================================================================
# Security Groups module
# =============================================================================

variable "ssh_cidr" {
  description = "CIDR allowed to SSH into the app instance. Tighten to your IP for safety (e.g. 203.0.113.4/32)."
  type        = string
  default     = "0.0.0.0/0"

  validation {
    condition     = can(cidrhost(var.ssh_cidr, 0))
    error_message = "ssh_cidr must be a valid CIDR block."
  }
}

variable "app_port" {
  description = "Port the Spring Boot app listens on"
  type        = number
  default     = 8080
}

variable "app_port_cidr" {
  description = "CIDR allowed to reach the app port (0.0.0.0/0 for demo; ALB SG in prod)"
  type        = string
  default     = "0.0.0.0/0"
}

variable "enable_http_https" {
  description = "Open ports 80 and 443 on the app SG (for future ALB / reverse proxy)"
  type        = bool
  default     = false
}

variable "allow_all_egress" {
  description = "Allow all outbound from app SG. Keep true on free tier (needed for ECR, SSM, apt, Docker Hub)."
  type        = bool
  default     = true
}

# =============================================================================
# ECR module
# =============================================================================

variable "ecr_repository_name" {
  description = "ECR repository name. Leave empty to default to '<project_name>-bankapp'."
  type        = string
  default     = ""
}

variable "keep_prod_images" {
  description = "Number of prod-* tagged images to retain in ECR"
  type        = number
  default     = 3
}

variable "keep_dev_images" {
  description = "Number of git-SHA tagged images to retain in ECR"
  type        = number
  default     = 3
}

variable "untagged_expire_days" {
  description = "Days before untagged ECR images expire"
  type        = number
  default     = 1
}

variable "ecr_force_delete" {
  description = "Allow terraform destroy to delete the ECR repo even when it contains images. Keep false."
  type        = bool
  default     = false
}

# =============================================================================
# SSM Parameter Store — replaces Secrets Manager (free)
# =============================================================================

variable "ssm_kms_key_id" {
  description = "Optional KMS key ARN for SSM SecureString params. Leave empty to use alias/aws/ssm (free)."
  type        = string
  default     = ""
}

variable "db_password" {
  description = "Database password for the app user (stored as SecureString in SSM)."
  type        = string
  sensitive   = true
  # No default — supply via secrets.auto.tfvars or TF_VAR_db_password
}

variable "mysql_root_password" {
  description = "MySQL root password (stored as SecureString in SSM). Should differ from db_password."
  type        = string
  sensitive   = true
  # No default — supply via secrets.auto.tfvars or TF_VAR_mysql_root_password
}

# =============================================================================
# IAM module
# =============================================================================

variable "enable_ssm" {
  description = "Attach SSM Session Manager permissions to the EC2 role (allows session-based access without SSH)"
  type        = bool
  default     = false
}

variable "enable_ssm_deploy" {
  description = "Allow GitHub Actions to deploy via SSM Send-Command (no SSH key). Requires enable_ssm = true on the instance."
  type        = bool
  default     = false
}

variable "permissions_boundary_arn" {
  description = "Optional permissions boundary ARN. Leave empty to disable."
  type        = string
  default     = ""
}

# =============================================================================
# EC2 module
# =============================================================================

variable "instance_type" {
  description = "EC2 instance type (free tier: t2.micro or t3.micro)"
  type        = string
  default     = "t3.micro"

  validation {
    condition     = contains(["t2.micro", "t3.micro"], var.instance_type)
    error_message = "instance_type must be a free-tier eligible type: t2.micro or t3.micro."
  }
}

variable "root_volume_size" {
  description = "Root EBS volume size in GB. Free tier = 30 GB TOTAL across all volumes."
  type        = number
  default     = 15

  validation {
    condition     = var.root_volume_size >= 8 && var.root_volume_size <= 20
    error_message = "root_volume_size must be between 8 and 20 GB."
  }
}

variable "key_name" {
  description = "EC2 key pair name for SSH access. Leave empty to disable SSH key."
  type        = string
  default     = ""
}

variable "allocate_eip" {
  description = "Allocate an Elastic IP for a stable public address (needed for GitHub Actions SSH deploy)"
  type        = bool
  default     = true
}

variable "disable_api_termination" {
  description = "Prevent accidental termination of the EC2 instance. Recommended true for prod."
  type        = bool
  default     = false
}

variable "cpu_credits" {
  description = "CPU credit mode for burstable instances (standard | unlimited)"
  type        = string
  default     = "standard"

  validation {
    condition     = contains(["standard", "unlimited"], var.cpu_credits)
    error_message = "cpu_credits must be 'standard' or 'unlimited'."
  }
}

# =============================================================================
# Application image tag (set by pipeline during redeploy)
# =============================================================================

variable "image_tag" {
  description = "Container image tag the instance boots with. Pipeline overrides this on redeploy via .env."
  type        = string
  default     = "latest"
}

# =============================================================================
# AI (Ollama) — optional dedicated EC2 (off by default, merged on app instance)
# =============================================================================

variable "create_ai_sg" {
  description = "Create the AI (Ollama) security group. Set true only if Ollama runs on its own EC2."
  type        = bool
  default     = false
}

variable "ai_port" {
  description = "Port Ollama listens on"
  type        = number
  default     = 11434
}