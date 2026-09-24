variable "repository_name" {
  description = "Name of the ECR repository (e.g. devsecops-bankapp)"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-_/]{1,255}$", var.repository_name))
    error_message = "ECR repository names must be lowercase alphanumeric with - _ / allowed."
  }
}

variable "environment" {
  description = "Deployment environment (used in tags)"
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

# -------- Lifecycle tuning (free-tier friendly defaults) --------

variable "keep_prod_images" {
  description = "Number of prod-* tagged images to retain"
  type        = number
  default     = 3

  validation {
    condition     = var.keep_prod_images >= 1 && var.keep_prod_images <= 10
    error_message = "keep_prod_images must be between 1 and 10."
  }
}

variable "keep_dev_images" {
  description = "Number of git-SHA tagged images to retain"
  type        = number
  default     = 5

  validation {
    condition     = var.keep_dev_images >= 1 && var.keep_dev_images <= 20
    error_message = "keep_dev_images must be between 1 and 20."
  }
}

variable "untagged_expire_days" {
  description = "Days after which untagged images are expired"
  type        = number
  default     = 1

  validation {
    condition     = var.untagged_expire_days >= 1 && var.untagged_expire_days <= 30
    error_message = "untagged_expire_days must be between 1 and 30."
  }
}

variable "force_delete" {
  description = "Allow terraform destroy to delete the repo even with images. Keep false unless you know what you're doing."
  type        = bool
  default     = false
}