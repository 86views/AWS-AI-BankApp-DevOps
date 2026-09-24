# =============================================================================
# ECR Repository — free tier: 500 MB private storage (first 12 months)
# =============================================================================
#
# IMPORTANT: image_tag_mutability = "IMMUTABLE"
#   Your pipeline MUST tag images by commit SHA (e.g. git-abc123) or semver
#   (e.g. v1.0.4). It must NEVER push :latest — the second push will fail
#   with TagAlreadyExistsException. This is intentional: every deployed
#   image has a unique, verifiable tag tied to a commit that passed all
#   security gates.
# =============================================================================

resource "aws_ecr_repository" "bankapp" {
  name                 = var.repository_name
  image_tag_mutability = "IMMUTABLE"
  force_delete         = var.force_delete

  image_scanning_configuration {
    scan_on_push = true # free basic scanning (OS + library CVEs)
  }

  encryption_configuration {
    encryption_type = "AES256" # KMS would cost extra; AES256 is fine for free tier
  }

  tags = merge(var.tags, {
    Name        = var.repository_name
    Environment = var.environment
  })
}

# =============================================================================
# Lifecycle Policy — keep storage within free-tier limits
# =============================================================================
# Evaluation order (top = highest priority):
#   1. Keep last 3 prod-* images (release tags)
#   2. Expire untagged images after 1 day (dangling layer cleanup)
#   3. Keep last 5 of any other tagged image (git-SHA build tags)
#
# Note: rule 1 wins over rule 3 for prod-* tags because of priority order.
# =============================================================================

resource "aws_ecr_lifecycle_policy" "bankapp" {
  repository = aws_ecr_repository.bankapp.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last ${var.keep_prod_images} prod-* images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["prod-"]
          countType     = "imageCountMoreThan"
          countNumber   = var.keep_prod_images
        }
        action = { type = "expire" }
      },
      {
        rulePriority = 2
        description  = "Expire untagged images after ${var.untagged_expire_days} day(s)"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = var.untagged_expire_days
        }
        action = { type = "expire" }
      },
      {
        rulePriority = 3
        description  = "Keep last ${var.keep_dev_images} dev/build (git-SHA) images"
        selection = {
          tagStatus      = "tagged"
          tagPatternList = ["*"]     # ← FIX: wildcard pattern satisfies AWS
          countType      = "imageCountMoreThan"
          countNumber    = var.keep_dev_images
        }
        action = { type = "expire" }
      }
    ]
  })
}

# =============================================================================
# Repository Policy — deny non-TLS pushes (defense in depth)
# =============================================================================
# Optional but cheap. Ensures images can only be pushed over HTTPS.

resource "aws_ecr_repository_policy" "bankapp" {
  repository = aws_ecr_repository.bankapp.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyNonTLS"
        Effect    = "Deny"
        Principal = "*"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ]
        Condition = {
          Bool = { "aws:SecureTransport" = "false" }
        }
      }
    ]
  })
}