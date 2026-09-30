# =============================================================================
# Reference your EXISTING GitHub OIDC provider
# =============================================================================
data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

# Used to build ARNs scoped to this account
data "aws_caller_identity" "current" {}

# =============================================================================
# EC2 Instance Role — ECR pull + SSM Parameter Store read (+ optional SSM Session Manager)
# =============================================================================

data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ec2" {
  name                 = "${var.project_name}-ec2-role"
  assume_role_policy   = data.aws_iam_policy_document.ec2_assume_role.json
  permissions_boundary = var.permissions_boundary_arn != "" ? var.permissions_boundary_arn : null

  tags = merge(var.tags, {
    Name = "${var.project_name}-ec2-role"
  })
}

data "aws_iam_policy_document" "ec2_policy" {
  # ---------------------------------------------------------------------------
  # ECR — pull images
  # ---------------------------------------------------------------------------

  # Account-level action — must use "*"
  statement {
    sid       = "ECRAuthToken"
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  # Repository-scoped pull actions
  statement {
    sid    = "ECRPull"
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "ecr:DescribeImages", # required by cloud-init ECR-empty check
    ]
    resources = [var.ecr_repository_arn]
  }

  # ---------------------------------------------------------------------------
  # SSM Parameter Store — read app config (replaces Secrets Manager)
  # ---------------------------------------------------------------------------

  statement {
    sid    = "SSMReadAppParams"
    effect = "Allow"
    actions = [
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:GetParametersByPath",
    ]
    resources = [
      "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/${var.project_name}/${var.environment}/*",
    ]
  }

  # Decrypt SecureString parameters (uses the free AWS-managed key)
  statement {
    sid       = "KMSDecryptSSM"
    effect    = "Allow"
    actions   = ["kms:Decrypt"]
    resources = ["arn:aws:kms:${var.aws_region}:${data.aws_caller_identity.current.account_id}:alias/aws/ssm"]
  }

  # ---------------------------------------------------------------------------
  # SSM Session Manager — keyless shell access (no port 22)
  # ---------------------------------------------------------------------------

  dynamic "statement" {
    for_each = var.enable_ssm ? [1] : []
    content {
      sid    = "SSMSessionManager"
      effect = "Allow"
      actions = [
        "ssmmessages:CreateControlChannel",
        "ssmmessages:CreateDataChannel",
        "ssmmessages:OpenControlChannel",
        "ssmmessages:OpenDataChannel",
        "ssm:UpdateInstanceInformation",
      ]
      resources = ["*"]
    }
  }
}

resource "aws_iam_role_policy" "ec2" {
  name   = "${var.project_name}-ec2-policy"
  role   = aws_iam_role.ec2.id
  policy = data.aws_iam_policy_document.ec2_policy.json
}

resource "aws_iam_instance_profile" "ec2" {
  name = "${var.project_name}-ec2-profile"
  role = aws_iam_role.ec2.name

  tags = merge(var.tags, {
    Name = "${var.project_name}-ec2-profile"
  })
}

# =============================================================================
# GitHub Actions OIDC Role — keyless CI/CD (no long-lived AWS keys)
# =============================================================================
# Trust is scoped to a specific repo + branch, using your EXISTING provider.
# UNCHANGED — do not modify this block.

data "aws_iam_policy_document" "github_assume_role" {
  statement {
    sid     = "GitHubActionsOIDC"
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "repo:${var.github_org}@${var.github_owner_id}/${var.github_repo}@${var.github_repo_id}:ref:refs/heads/${var.github_branch}",
        "repo:${var.github_org}/${var.github_repo}:ref:refs/heads/${var.github_branch}",
        "repo:${var.github_org}@${var.github_owner_id}/${var.github_repo}@${var.github_repo_id}:pull_request",
        "repo:${var.github_org}/${var.github_repo}:pull_request",
      ]
    }
  }
}

resource "aws_iam_role" "github_actions" {
  name                 = "${var.project_name}-GitHubActionsRole"
  description          = "Keyless CI/CD role for ${var.github_org}/${var.github_repo} (branch: ${var.github_branch})"
  assume_role_policy   = data.aws_iam_policy_document.github_assume_role.json
  permissions_boundary = var.permissions_boundary_arn != "" ? var.permissions_boundary_arn : null

  tags = merge(var.tags, {
    Name = "${var.project_name}-GitHubActionsRole"
  })
}

# -----------------------------------------------------------------------------
# Pipeline policy — ECR push + SSM read + (optional) SSM send-command for deploy
# -----------------------------------------------------------------------------

data "aws_iam_policy_document" "github_actions_policy" {
  # ---------------------------------------------------------------------------
  # ECR — push images
  # ---------------------------------------------------------------------------

  statement {
    sid       = "ECRAuthToken"
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  # ---------------------------------------------------------------------------
  # ECR Public — auth to the public.ecr.aws mirror (raises Trivy's anonymous
  # pull rate limit when downloading the vulnerability DB in Gate 7)
  # ---------------------------------------------------------------------------

  statement {
    sid       = "ECRPublicAuthToken"
    effect    = "Allow"
    actions   = ["ecr-public:GetAuthorizationToken", "sts:GetServiceBearerToken"]
    resources = ["*"]
  }

  # ---------------------------------------------------------------------------
  # EC2 — describe instances for DAST gate target validation
  # ---------------------------------------------------------------------------
  statement {
    sid       = "EC2Describe"
    effect    = "Allow"
    actions   = ["ec2:DescribeInstances"]
    resources = ["*"] # DescribeInstances doesn't support resource ARNs
  }

  statement {
    sid    = "ECRPushPull"
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
      "ecr:PutImage",
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer",
      "ecr:DescribeImages",
      "ecr:ListImages",
    ]
    resources = [var.ecr_repository_arn]
  }

  # ---------------------------------------------------------------------------
  # SSM Parameter Store — read app config (e.g. for integration tests / DAST)
  # Comment out if you don't want the pipeline reading app config.
  # ---------------------------------------------------------------------------

  statement {
    sid    = "SSMReadAppParams"
    effect = "Allow"
    actions = [
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:GetParametersByPath",
    ]
    resources = [
      "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/${var.project_name}/${var.environment}/*",
    ]
  }

  statement {
    sid       = "KMSDecryptSSM"
    effect    = "Allow"
    actions   = ["kms:Decrypt"]
    resources = ["arn:aws:kms:${var.aws_region}:${data.aws_caller_identity.current.account_id}:alias/aws/ssm"]
  }

  # ---------------------------------------------------------------------------
  # SSM Send-Command — keyless deploy to the EC2 instance (Gate 8).
  # SendCommand can be scoped to specific instance/document ARNs, but
  # GetCommandInvocation and ListCommandInvocations do NOT support
  # resource-level permissions — AWS requires "*" for those or they are
  # silently denied. Split into two statements accordingly.
  # ---------------------------------------------------------------------------

  dynamic "statement" {
    for_each = var.enable_ssm_deploy ? [1] : []
    content {
      sid    = "SSMSendCommand"
      effect = "Allow"
      actions = [
        "ssm:SendCommand",
      ]
      resources = [
        "arn:aws:ec2:${var.aws_region}:${data.aws_caller_identity.current.account_id}:instance/*",
        "arn:aws:ssm:${var.aws_region}::document/AWS-RunShellScript",
      ]
    }
  }

  dynamic "statement" {
    for_each = var.enable_ssm_deploy ? [1] : []
    content {
      sid    = "SSMCommandStatus"
      effect = "Allow"
      actions = [
        "ssm:GetCommandInvocation",
        "ssm:ListCommandInvocations",
      ]
      resources = ["*"]
    }
  }
}

resource "aws_iam_role_policy" "github_actions" {
  name   = "${var.project_name}-github-actions-policy"
  role   = aws_iam_role.github_actions.id
  policy = data.aws_iam_policy_document.github_actions_policy.json
}
