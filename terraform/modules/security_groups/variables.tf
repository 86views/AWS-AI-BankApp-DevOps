variable "project_name" {
  description = "Project name used in SG names and tags"
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

variable "vpc_id" {
  description = "VPC ID where the security groups will be created"
  type        = string
}

variable "tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default     = {}
}

# =============================================================================
# App SG
# =============================================================================

variable "ssh_cidr" {
  description = "CIDR allowed to SSH into the app instance. Tighten this to your office/home IP or GitHub Actions IP ranges for production."
  type        = string
  default     = "0.0.0.0/0"

  validation {
    condition     = can(cidrhost(var.ssh_cidr, 0))
    error_message = "ssh_cidr must be a valid CIDR block, e.g. 203.0.113.4/32."
  }
}

variable "app_port" {
  description = "Port the Spring Boot app listens on"
  type        = number
  default     = 8080
}

variable "app_port_cidr" {
  description = "CIDR allowed to reach the app port. Use 0.0.0.0/0 for demo, or an ALB SG/prefix list for production."
  type        = string
  default     = "0.0.0.0/0"

  validation {
    condition     = can(cidrhost(var.app_port_cidr, 0))
    error_message = "app_port_cidr must be a valid CIDR block."
  }
}

variable "enable_http_https" {
  description = "Open 80 and 443 on the app SG (for a future reverse proxy or ALB)"
  type        = bool
  default     = false
}

variable "allow_all_egress" {
  description = "Allow all outbound traffic from the app SG (true) or restrict to 80/443/53 (false)"
  type        = bool
  default     = true
}

# =============================================================================
# AI SG
# =============================================================================

variable "create_ai_sg" {
  description = "Create the AI (Ollama) security group. Set true if Ollama runs on its own EC2 instance."
  type        = bool
  default     = false
}

variable "ai_port" {
  description = "Port Ollama listens on"
  type        = number
  default     = 11434
}