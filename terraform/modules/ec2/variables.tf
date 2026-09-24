# =============================================================================
# Identity & Naming
# =============================================================================

variable "project_name" {
  description = "Project name (used in resource names and tags). Lowercase, alphanumeric, hyphens only."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]{3,32}$", var.project_name))
    error_message = "project_name must be 3-32 characters, lowercase alphanumeric and hyphens only."
  }
}

variable "environment" {
  description = "Deployment environment (e.g., dev, staging, prod)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}

variable "tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default     = {}
}

# =============================================================================
# Region / Networking
# =============================================================================

variable "aws_region" {
  description = "AWS region for resource deployment"
  type        = string

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]$", var.aws_region))
    error_message = "aws_region must be a valid AWS region, e.g. us-east-1, eu-west-2."
  }
}

variable "subnet_id" {
  description = "Subnet ID where the EC2 instance will be launched"
  type        = string
}

variable "security_group_id" {
  description = "Security group ID attached to the instance"
  type        = string
}

# =============================================================================
# EC2 Instance
# =============================================================================

variable "instance_type" {
  description = "EC2 instance type. Only free-tier eligible types allowed."
  type        = string
  default     = "t3.micro"

  validation {
    condition     = contains(["t2.micro", "t3.micro"], var.instance_type)
    error_message = "instance_type must be a free-tier eligible type: t2.micro or t3.micro."
  }
}

variable "root_volume_size" {
  description = "Root EBS volume size in GB. Free tier = 30 GB total across ALL volumes."
  type        = number
  default     = 15

  validation {
    condition     = var.root_volume_size >= 8 && var.root_volume_size <= 20
    error_message = "root_volume_size must be between 8 and 20 GB to remain within the 30 GB free-tier budget when paired with the AI instance."
  }
}

variable "cpu_credits" {
  description = "CPU credit mode for burstable instances (standard = safer for free tier, unlimited = possible extra charges)"
  type        = string
  default     = "standard"

  validation {
    condition     = contains(["standard", "unlimited"], var.cpu_credits)
    error_message = "cpu_credits must be either 'standard' or 'unlimited'."
  }
}

variable "key_name" {
  description = "EC2 key pair name for SSH access. Leave empty to disable SSH key (recommended: use SSM Session Manager)."
  type        = string
  default     = ""
}

variable "allocate_eip" {
  description = "Allocate an Elastic IP. Free ONLY while attached to a running instance."
  type        = bool
  default     = true
}

variable "disable_api_termination" {
  description = "Prevent accidental termination of the instance (recommended true for prod)"
  type        = bool
  default     = false
}

variable "associate_public_ip" {
  description = "Associate a public IP. Set false when using EIP or a private subnet + NAT/SSM."
  type        = bool
  default     = false
}

# =============================================================================
# IAM
# =============================================================================

variable "instance_profile_name" {
  description = "IAM instance profile name granting ECR pull + Secrets Manager read"
  type        = string
}

variable "image_tag" {
  description = "Container image tag to deploy (git SHA, semver, or 'latest')"
  type        = string
  default     = "latest"
}



# =============================================================================
# Container Registry
# =============================================================================

variable "ecr_repository_url" {
  description = "Full ECR repository URL for the bankapp image"
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}\\.dkr\\.ecr\\.[a-z0-9-]+\\.amazonaws\\.com/.+$", var.ecr_repository_url))
    error_message = "ecr_repository_url must match: <account-id>.dkr.ecr.<region>.amazonaws.com/<repo>."
  }
}