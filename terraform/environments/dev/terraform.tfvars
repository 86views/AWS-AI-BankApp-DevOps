# =============================================================================
# terraform.tfvars — DevSecOps Banking Application
# =============================================================================
# This file overrides defaults from variables.tf.
# Commit THIS file to git (it has no secrets — only non-sensitive config).
#
# Sensitive values (db_password, mysql_root_password) live in secrets.auto.tfvars
# which is gitignored. See secrets.auto.tfvars.example for the template.
# =============================================================================

# -----------------------------------------------------------------------------
# Core
# -----------------------------------------------------------------------------

aws_region   = "us-east-1"
project_name = "devsecops-bankapp"
environment  = "dev"

# Extra resource-specific tags (default_tags on the provider adds
# Project / Environment / ManagedBy / Owner automatically).
tags = {}

# -----------------------------------------------------------------------------
# GitHub OIDC — source repo for the GitHubActionsRole trust policy
# -----------------------------------------------------------------------------

github_org      = "86views" # ⚠️ replace with your GitHub user or org
github_repo     = "AWS-AI-BankApp-DevOps"
github_branch   = "main"
github_owner_id = "21120209"   # from step 1
github_repo_id  = "1383129666" # from step 1

# -----------------------------------------------------------------------------
# Networking (VPC module)
# -----------------------------------------------------------------------------

vpc_cidr = "10.0.0.0/16"

# Leave empty to auto-pick the first available AZ in the region.
# To pin specific AZs (needed later for an ALB), list them:
# availability_zones = ["us-east-1a", "us-east-1b"]
availability_zones = []

# -----------------------------------------------------------------------------
# Security Groups module
# -----------------------------------------------------------------------------

# ⚠️ Replace with YOUR public IP. Get it via:
#     curl -s ifconfig.me
# Example: ssh_cidr = "203.0.113.4/32"
#
# If you're using SSM deploy (enable_ssm_deploy = true below), you can close
# port 22 entirely by setting the SG module's enable_ssh_ingress = false.
ssh_cidr = "0.0.0.0/0"

app_port          = 8080
app_port_cidr     = "0.0.0.0/0"
enable_http_https = false
allow_all_egress  = true

# -----------------------------------------------------------------------------
# ECR module
# -----------------------------------------------------------------------------

# Empty → defaults to "<project_name>-bankapp"
ecr_repository_name = ""

keep_prod_images     = 3
keep_dev_images      = 3
untagged_expire_days = 1
ecr_force_delete     = false

# -----------------------------------------------------------------------------
# SSM Parameter Store (replaces Secrets Manager — free)
# -----------------------------------------------------------------------------

# Leave empty to use the AWS-managed alias/aws/ssm key (free).
# Only set this if you create a customer-managed KMS key later.
ssm_kms_key_id = ""

# NOTE: db_password and mysql_root_password live in secrets.auto.tfvars
#       (gitignored). See secrets.auto.tfvars.example.

# -----------------------------------------------------------------------------
# IAM module
# -----------------------------------------------------------------------------

# enable_ssm       — grants the EC2 instance Session Manager permissions
#                    (keyless shell access, no port 22 needed)
# enable_ssm_deploy — grants GitHub Actions Send-Command permissions
#                    (keyless deploy, no SSH key stored in GitHub)
#
# For the strongest DevSecOps story: set both to true and remove key_name.
# terraform.tfvars
enable_ssm               = true
enable_ssm_deploy        = true
permissions_boundary_arn = ""

# -----------------------------------------------------------------------------
# EC2 module
# -----------------------------------------------------------------------------

instance_type    = "t3.micro"
root_volume_size = 15

# ⚠️ Replace with the name of the SSH key pair you created in AWS.
# Leave empty to disable SSH entirely (recommended when using SSM).
key_name = ""

allocate_eip            = true
disable_api_termination = false
cpu_credits             = "standard"

# -----------------------------------------------------------------------------
# Application image tag
# -----------------------------------------------------------------------------
# The pipeline overrides this at deploy time via /opt/bankapp/.env.
# Keep "latest" as the placeholder for a fresh boot.

image_tag = "latest"

# -----------------------------------------------------------------------------
# AI (Ollama) — optional dedicated EC2
# -----------------------------------------------------------------------------
# false → Ollama runs co-located on the app instance (free-tier friendly).
# true  → creates a separate AI SG for a future dedicated AI instance.

create_ai_sg = false
ai_port      = 11434
