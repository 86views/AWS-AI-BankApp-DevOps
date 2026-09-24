variable "project_name" {
  description = "Project name used in resource names and tags"
  type        = string
}

variable "environment" {
  description = "Deployment environment (dev, staging, prod)"
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
# VPC / Networking
# =============================================================================

variable "vpc_cidr" {
  description = "CIDR block for the VPC (e.g. 10.0.0.0/16)"
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a valid CIDR block."
  }
}

variable "availability_zones" {
  description = "List of AZs to create subnets in. Defaults to a single AZ for free-tier simplicity."
  type        = list(string)

  validation {
    condition     = length(var.availability_zones) >= 1 && length(var.availability_zones) <= 3
    error_message = "Provide 1 to 3 availability zones."
  }
}

variable "map_public_ip_on_launch" {
  description = "Auto-assign a public IPv4 address to instances launched in public subnets. Set false when using EIPs."
  type        = bool
  default     = false
}

# =============================================================================
# Private subnets (optional — cost money if enabled)
# =============================================================================

variable "create_private_subnets" {
  description = "Create private subnets. Keep false on free tier — instances there cannot reach the internet without a NAT Gateway."
  type        = bool
  default     = false
}

variable "enable_nat_gateway" {
  description = "Create a NAT Gateway (~$32/month + data). Requires create_private_subnets = true. Leave false on free tier."
  type        = bool
  default     = false
}