# =============================================================================
# Security Groups
# =============================================================================
# Two SGs:
#   1. app_sg — attached to the app EC2 (SSH + app port + optional 80/443)
#   2. ai_sg  — attached to a dedicated Ollama EC2 (only if create_ai_sg = true)
#
# The AI SG accepts port 11434 ONLY from the app SG — never from 0.0.0.0/0.
#
# Note on style: this module uses inline `ingress`/`egress` blocks because
# there are only a handful of rules. If you later grow beyond ~10 rules per
# SG, switch to `aws_vpc_security_group_ingress_rule` / `_egress_rule`
# resources (AWS provider 5.x+ recommended pattern).
# =============================================================================

# -----------------------------------------------------------------------------
# App Security Group
# -----------------------------------------------------------------------------

resource "aws_security_group" "app" {
  name        = "${var.project_name}-app-sg"
  description = "App tier: SSH, HTTP(S), and Spring Boot app port"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, {
    Name        = "${var.project_name}-app-sg"
    Environment = var.environment
    Tier        = "app"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# --- Ingress: SSH (for GitHub Actions deploy + manual admin) ---
resource "aws_vpc_security_group_ingress_rule" "app_ssh" {
  security_group_id = aws_security_group.app.id
  description       = "SSH from allowed CIDR"
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
  cidr_ipv4         = var.ssh_cidr

  tags = merge(var.tags, { Name = "${var.project_name}-app-ssh" })
}

# --- Ingress: application port ---
resource "aws_vpc_security_group_ingress_rule" "app_port" {
  security_group_id = aws_security_group.app.id
  description       = "Bankapp HTTP port"
  ip_protocol       = "tcp"
  from_port         = var.app_port
  to_port           = var.app_port
  cidr_ipv4         = var.app_port_cidr

  tags = merge(var.tags, { Name = "${var.project_name}-app-port" })
}

# --- Ingress: HTTP/HTTPS (only if enable_http_https = true; for future ALB/nginx) ---
resource "aws_vpc_security_group_ingress_rule" "app_http" {
  count = var.enable_http_https ? 1 : 0

  security_group_id = aws_security_group.app.id
  description       = "HTTP (reverse proxy / ALB)"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = var.app_port_cidr

  tags = merge(var.tags, { Name = "${var.project_name}-app-http" })
}

resource "aws_vpc_security_group_ingress_rule" "app_https" {
  count = var.enable_http_https ? 1 : 0

  security_group_id = aws_security_group.app.id
  description       = "HTTPS (reverse proxy / ALB)"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = var.app_port_cidr

  tags = merge(var.tags, { Name = "${var.project_name}-app-https" })
}

# --- Egress ---
# Default: allow all outbound (simplest, and required for ECR, Secrets Manager,
# Docker Hub, apt repos, etc. which span many AWS CIDRs).
# Toggle to false if you want to lock down to specific ports — see commented
# rules below as a starting point.
resource "aws_vpc_security_group_egress_rule" "app_all" {
  count = var.allow_all_egress ? 1 : 0

  security_group_id = aws_security_group.app.id
  description       = "Allow all outbound"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"

  tags = merge(var.tags, { Name = "${var.project_name}-app-egress-all" })
}

# HTTPS egress — used when allow_all_egress = false
resource "aws_vpc_security_group_egress_rule" "app_https_out" {
  count = var.allow_all_egress ? 0 : 1

  security_group_id = aws_security_group.app.id
  description       = "HTTPS outbound (ECR, Secrets Manager, apt, Docker Hub)"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"

  tags = merge(var.tags, { Name = "${var.project_name}-app-egress-https" })
}

# HTTP egress — needed by some apt mirrors
resource "aws_vpc_security_group_egress_rule" "app_http_out" {
  count = var.allow_all_egress ? 0 : 1

  security_group_id = aws_security_group.app.id
  description       = "HTTP outbound (apt mirrors)"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = "0.0.0.0/0"

  tags = merge(var.tags, { Name = "${var.project_name}-app-egress-http" })
}

# DNS egress (UDP/TCP 53) — required if you restrict egress
resource "aws_vpc_security_group_egress_rule" "app_dns_out" {
  count = var.allow_all_egress ? 0 : 1

  security_group_id = aws_security_group.app.id
  description       = "DNS outbound"
  ip_protocol       = "udp"
  from_port         = 53
  to_port           = 53
  cidr_ipv4         = "0.0.0.0/0"

  tags = merge(var.tags, { Name = "${var.project_name}-app-egress-dns" })
}

# =============================================================================
# AI (Ollama) Security Group — optional
# =============================================================================
# Only needed if you split Ollama onto its own EC2 instance.
# When create_ai_sg = false, none of the resources below are created.

resource "aws_security_group" "ai" {
  count = var.create_ai_sg ? 1 : 0

  name        = "${var.project_name}-ai-sg"
  description = "AI tier: Ollama API accessible only from the app tier"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, {
    Name        = "${var.project_name}-ai-sg"
    Environment = var.environment
    Tier        = "ai"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# --- Ingress: 11434 from the APP SG only (not from 0.0.0.0/0) ---
resource "aws_vpc_security_group_ingress_rule" "ai_from_app" {
  count = var.create_ai_sg ? 1 : 0

  security_group_id            = aws_security_group.ai[0].id
  description                  = "Ollama API from app tier only"
  ip_protocol                  = "tcp"
  from_port                    = var.ai_port
  to_port                      = var.ai_port
  referenced_security_group_id = aws_security_group.app.id

  tags = merge(var.tags, { Name = "${var.project_name}-ai-from-app" })
}

# --- Egress: allow all (needed to pull models from ollama.com / Docker Hub) ---
resource "aws_vpc_security_group_egress_rule" "ai_all" {
  count = var.create_ai_sg ? 1 : 0

  security_group_id = aws_security_group.ai[0].id
  description       = "Allow all outbound (model pulls, apt, etc.)"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"

  tags = merge(var.tags, { Name = "${var.project_name}-ai-egress-all" })
}