# =============================================================================
# Root main.tf — DevSecOps Banking Application
# =============================================================================
# Free-tier deployment:
#   - Single public subnet, single AZ
#   - NO NAT Gateway (would cost ~$32/month)
#   - NO private subnets (would require the NAT Gateway to be useful)
#   - App EC2 lives in the public subnet with an Elastic IP
#   - App config stored in SSM Parameter Store (free) instead of Secrets Manager
# =============================================================================

# =============================================================================
# Locals
# =============================================================================

locals {
  common_tags = merge(var.tags, {
    Project = var.project_name
    # Environment / ManagedBy / Owner handled by provider default_tags
  })
}

# =============================================================================
# Data sources
# =============================================================================

data "aws_availability_zones" "available" {
  state = "available"

  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

# =============================================================================
# VPC — free-tier: public-only, single AZ
# =============================================================================

module "vpc" {
  source = "../../modules/vpc"

  project_name = var.project_name
  environment  = var.environment
  tags         = local.common_tags

  vpc_cidr = var.vpc_cidr

  # Auto-pick first AZ unless the user explicitly lists AZs in terraform.tfvars
  availability_zones = length(var.availability_zones) > 0 ? var.availability_zones : [data.aws_availability_zones.available.names[0]]

  map_public_ip_on_launch = false # EIPs handle public addressing

  # --- HARDCODED OFF: free-tier protection ---
  create_private_subnets = false
  enable_nat_gateway     = false
}

# =============================================================================
# Security Groups
# =============================================================================

module "security_groups" {
  source = "../../modules/security_groups"

  project_name = var.project_name
  environment  = var.environment
  tags         = local.common_tags
  vpc_id       = module.vpc.vpc_id

  ssh_cidr          = var.ssh_cidr
  app_port          = var.app_port
  app_port_cidr     = var.app_port_cidr
  enable_http_https = var.enable_http_https
  allow_all_egress  = var.allow_all_egress

  create_ai_sg = var.create_ai_sg
  ai_port      = var.ai_port
}

# =============================================================================
# ECR
# =============================================================================

module "ecr" {
  source = "../../modules/ecr"

  repository_name = var.ecr_repository_name != "" ? var.ecr_repository_name : "${var.project_name}-bankapp"
  environment     = var.environment
  tags            = local.common_tags

  keep_prod_images     = var.keep_prod_images
  keep_dev_images      = var.keep_dev_images
  untagged_expire_days = var.untagged_expire_days
  force_delete         = var.ecr_force_delete
}

# =============================================================================
# SSM Parameter Store (free alternative to Secrets Manager)
# =============================================================================
# Stores DB + Ollama config under:
#   /<project_name>/<environment>/db/host
#   /<project_name>/<environment>/db/port
#   /<project_name>/<environment>/db/name
#   /<project_name>/<environment>/db/user
#   /<project_name>/<environment>/db/password        (SecureString)
#   /<project_name>/<environment>/db/root_password   (SecureString)
#   /<project_name>/<environment>/ollama/url
#
# cloud-init reads these with `aws ssm get-parameter --with-decryption`.

module "ssm" {
  source = "../../modules/secrets-manager"

  project_name = var.project_name
  environment  = var.environment
  tags         = local.common_tags

  # "" = use AWS-managed alias/aws/ssm (free)
  kms_key_id = var.ssm_kms_key_id

  db_host             = "mysql"
  db_port             = "3306"
  db_name             = "bankappdb"
  db_user             = "bankuser"
  db_password         = var.db_password
  mysql_root_password = var.mysql_root_password
  ollama_url          = "http://ollama:11434"
}

# =============================================================================
# IAM
# =============================================================================

module "iam" {
  source = "../../modules/iam"

  project_name = var.project_name
  tags         = local.common_tags
  aws_region   = var.aws_region
  environment  = var.environment

  ecr_repository_arn       = module.ecr.repository_arn
  enable_ssm               = var.enable_ssm
  enable_ssm_deploy        = var.enable_ssm_deploy
  permissions_boundary_arn = var.permissions_boundary_arn

  github_org      = var.github_org
  github_repo     = var.github_repo
  github_branch   = var.github_branch
  github_owner_id = var.github_owner_id
  github_repo_id  = var.github_repo_id

}

# =============================================================================
# EC2 (App instance)
# =============================================================================

module "ec2" {
  source = "../../modules/ec2"

  project_name = var.project_name
  environment  = var.environment
  tags         = local.common_tags

  instance_type           = var.instance_type
  subnet_id               = module.vpc.public_subnet_id
  security_group_id       = module.security_groups.app_sg_id
  instance_profile_name   = module.iam.instance_profile_name
  key_name                = var.key_name
  root_volume_size        = var.root_volume_size
  allocate_eip            = var.allocate_eip
  disable_api_termination = var.disable_api_termination
  cpu_credits             = var.cpu_credits

  # Values passed into cloud-init template
  ecr_repository_url = module.ecr.repository_url
  aws_region         = var.aws_region
  image_tag          = var.image_tag
  # secret_id removed — cloud-init now reads from SSM using
  # project_name + environment (already passed above)

  depends_on = [module.iam, module.ssm]
}
