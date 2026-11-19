provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  type    = string
  default = "eu-south-2"
}

variable "github_repo" {
  description = "Repositorio GitHub en formato org/repo"
  type        = string
}

variable "prod_bucket_name" {
  type = string
}

variable "lab_bucket_name" {
  type = string
}

variable "audit_worm_bucket_name" {
  description = "Nombre global unico del bucket S3 WORM para evidencias de auditoria"
  type        = string
}

variable "audit_worm_retention_days" {
  type    = number
  default = 365
}

variable "audit_worm_kms_key_arn" {
  type    = string
  default = null
}

# 1. Proveedor OIDC de GitHub Actions
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

# 2. Clave KMS para firma Cosign (ECC_NIST_P256)
resource "aws_kms_key" "cosign_sdm" {
  description              = "Clave asimetrica Cosign para firma de imagenes sdm-runner"
  customer_master_key_spec = "ECC_NIST_P256"
  key_usage                = "SIGN_VERIFY"
  deletion_window_in_days  = 30
}

resource "aws_kms_alias" "cosign_sdm" {
  name          = "alias/cosign-sdm-key"
  target_key_id = aws_kms_key.cosign_sdm.key_id
}

# 3. Repositorio ECR Inmutable
resource "aws_ecr_repository" "sdm_runner" {
  name                 = "sdm-runner"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

# 4. Bucket S3 Inmutable (Object Lock - COMPLIANCE 365 dias)
resource "aws_s3_bucket" "audit_worm" {
  bucket              = var.audit_worm_bucket_name
  object_lock_enabled = true
  force_destroy       = false

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Project    = "sdm-zero-pii"
    Purpose    = "audit-evidence-worm"
    Compliance = "ISO27001-ENS"
    ManagedBy  = "terraform"
  }
}

resource "aws_s3_bucket_ownership_controls" "audit_worm" {
  bucket = aws_s3_bucket.audit_worm.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_public_access_block" "audit_worm" {
  bucket                  = aws_s3_bucket.audit_worm.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "audit_worm" {
  bucket = aws_s3_bucket.audit_worm.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "audit_worm" {
  bucket = aws_s3_bucket.audit_worm.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.audit_worm_kms_key_arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_object_lock_configuration" "audit_worm" {
  bucket = aws_s3_bucket.audit_worm.id
  rule {
    default_retention {
      mode = "COMPLIANCE"
      days = var.audit_worm_retention_days
    }
  }
  depends_on = [aws_s3_bucket_versioning.audit_worm]
}

data "aws_iam_policy_document" "audit_worm_tls_only" {
  statement {
    sid     = "DenyInsecureTransport"
    effect  = "Deny"
    actions = ["s3:*"]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    resources = [aws_s3_bucket.audit_worm.arn, "${aws_s3_bucket.audit_worm.arn}/*"]
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "audit_worm" {
  bucket = aws_s3_bucket.audit_worm.id
  policy = data.aws_iam_policy_document.audit_worm_tls_only.json
}

# 5. Roles IAM OIDC de Minimo Privilegio (PROD RO, LAB RW, ECR Sign, Audit RO, Release RO)
data "aws_iam_policy_document" "gh_oidc_env_prod" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_repo}:environment:PROD-Data-Read"]
    }
  }
}

data "aws_iam_policy_document" "gh_oidc_main" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_repo}:ref:refs/heads/main"]
    }
  }
}

data "aws_iam_policy_document" "gh_oidc_tags" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_repo}:ref:refs/tags/v*"]
    }
  }
}

resource "aws_iam_role" "prod_ro" {
  name               = "role-gh-sdm-prod-ro"
  assume_role_policy = data.aws_iam_policy_document.gh_oidc_env_prod.json
}

resource "aws_iam_role" "lab_rw" {
  name               = "role-gh-sdm-lab-rw"
  assume_role_policy = data.aws_iam_policy_document.gh_oidc_env_prod.json
}

resource "aws_iam_role" "ecr_sign" {
  name               = "role-gh-sdm-ecr-sign"
  assume_role_policy = data.aws_iam_policy_document.gh_oidc_main.json
}

resource "aws_iam_role" "iam_audit" {
  name               = "role-gh-sdm-iam-audit"
  assume_role_policy = data.aws_iam_policy_document.gh_oidc_main.json
}

resource "aws_iam_role" "release_ro" {
  name               = "role-gh-sdm-release-ro"
  assume_role_policy = data.aws_iam_policy_document.gh_oidc_tags.json
}

data "aws_iam_policy_document" "iam_audit_ro" {
  statement {
    sid     = "ReadOnlySDMRolesAudit"
    effect  = "Allow"
    actions = ["iam:GetRole", "iam:ListRolePolicies", "iam:GetRolePolicy", "iam:ListAttachedRolePolicies"]
    resources = [
      aws_iam_role.prod_ro.arn,
      aws_iam_role.lab_rw.arn,
      aws_iam_role.ecr_sign.arn,
      aws_iam_role.release_ro.arn
    ]
  }
  statement {
    sid       = "WriteOnlyAuditEvidenceWORM"
    effect    = "Allow"
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.audit_worm.arn}/aws-iam-audit/*"]
  }
}

resource "aws_iam_role_policy" "iam_audit_ro" {
  name   = "sdm-iam-audit-readonly"
  role   = aws_iam_role.iam_audit.id
  policy = data.aws_iam_policy_document.iam_audit_ro.json
}

data "aws_iam_policy_document" "release_ro" {
  statement {
    sid       = "ECRAuthToken"
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }
  statement {
    sid       = "ECRReadOnlySDMRunner"
    effect    = "Allow"
    actions   = ["ecr:BatchCheckLayerAvailability", "ecr:GetDownloadUrlForLayer", "ecr:BatchGetImage", "ecr:DescribeImages"]
    resources = [aws_ecr_repository.sdm_runner.arn]
  }
  statement {
    sid       = "KMSVerifyCosignOnly"
    effect    = "Allow"
    actions   = ["kms:GetPublicKey", "kms:DescribeKey"]
    resources = [aws_kms_key.cosign_sdm.arn]
  }
}

resource "aws_iam_role_policy" "release_ro" {
  name   = "sdm-release-verify-readonly"
  role   = aws_iam_role.release_ro.id
  policy = data.aws_iam_policy_document.release_ro.json
}

output "aws_region" { value = var.aws_region }
output "cosign_kms_key_id" { value = aws_kms_key.cosign_sdm.key_id }
output "cosign_kms_key_arn" { value = aws_kms_key.cosign_sdm.arn }
output "role_prod_ro_arn" { value = aws_iam_role.prod_ro.arn }
output "role_lab_rw_arn" { value = aws_iam_role.lab_rw.arn }
output "role_ecr_sign_arn" { value = aws_iam_role.ecr_sign.arn }
output "role_iam_audit_arn" { value = aws_iam_role.iam_audit.arn }
output "role_release_ro_arn" { value = aws_iam_role.release_ro.arn }
output "audit_worm_bucket_name" { value = aws_s3_bucket.audit_worm.bucket }
