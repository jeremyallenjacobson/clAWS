###############################################################################
# GenAI IDP POC — Constrained AWS Deployment
#
# This deployment wrapper:
# 1. Creates Cognito resources (user pool, client, identity pool, roles)
# 2. Calls the root genai-idp-terraform module with pre-created S3 buckets
#    and KMS key (no aws_s3_bucket resources — avoids SCP Object Lock issue)
# 3. Disables web_ui (CloudFront blocked by SCP)
# 4. Disables all optional features (budget survival)
###############################################################################

provider "aws" {
  region = var.region
}

provider "aws" {
  alias  = "us-east-1"
  region = "us-east-1"
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_partition" "current" {}

# Random suffix for unique resource names
resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

locals {
  name_prefix = "${var.prefix}-${random_string.suffix.result}"
  config_yaml = file(var.config_file_path)
  config      = yamldecode(local.config_yaml)
}

###############################################################################
# Cognito User Identity (copied from examples/bedrock-llm-processor/main.tf)
###############################################################################

resource "aws_cognito_user_pool" "user_pool" {
  name                     = "${local.name_prefix}-user-pool"
  auto_verified_attributes = ["email"]
  deletion_protection      = "INACTIVE"

  password_policy {
    minimum_length                   = 8
    require_lowercase                = true
    require_numbers                  = true
    require_symbols                  = true
    require_uppercase                = true
    temporary_password_validity_days = 7
  }

  user_pool_add_ons {
    advanced_security_mode = "ENFORCED"
  }

  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  schema {
    attribute_data_type = "String"
    name                = "email"
    required            = true
    mutable             = true
  }

  admin_create_user_config {
    allow_admin_create_user_only = true
    invite_message_template {
      email_message = "Your username is {username} and temporary password is {####}."
      email_subject = "GenAI IDP POC - Temporary Password"
      sms_message   = "Your username is {username} and temporary password is {####}"
    }
  }

  tags = {
    Name = "${local.name_prefix}-user-pool"
  }
}

resource "aws_cognito_user_pool_client" "user_pool_client" {
  name         = "${local.name_prefix}-user-pool-client"
  user_pool_id = aws_cognito_user_pool.user_pool.id

  allowed_oauth_flows                  = ["code"]
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_scopes                 = ["email", "openid", "profile"]
  callback_urls                        = ["http://localhost:3000"]
  logout_urls                          = ["http://localhost:3000"]
  supported_identity_providers         = ["COGNITO"]

  access_token_validity  = 60
  id_token_validity      = 60
  refresh_token_validity = 30

  token_validity_units {
    access_token  = "minutes"
    id_token      = "minutes"
    refresh_token = "days"
  }

  generate_secret = false

  explicit_auth_flows = [
    "ALLOW_ADMIN_USER_PASSWORD_AUTH",
    "ALLOW_CUSTOM_AUTH",
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_USER_SRP_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH"
  ]
}

resource "aws_cognito_identity_pool" "identity_pool" {
  identity_pool_name               = "${local.name_prefix}-identity-pool"
  allow_unauthenticated_identities = false

  cognito_identity_providers {
    client_id               = aws_cognito_user_pool_client.user_pool_client.id
    provider_name           = aws_cognito_user_pool.user_pool.endpoint
    server_side_token_check = false
  }

  tags = {
    Name = "${local.name_prefix}-identity-pool"
  }
}

resource "aws_iam_role" "authenticated_role" {
  name = "${local.name_prefix}-auth-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = "cognito-identity.amazonaws.com"
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "cognito-identity.amazonaws.com:aud" = aws_cognito_identity_pool.identity_pool.id
          }
          "ForAnyValue:StringLike" = {
            "cognito-identity.amazonaws.com:amr" = "authenticated"
          }
        }
      }
    ]
  })

  tags = {
    Name = "${local.name_prefix}-auth-role"
  }
}

resource "aws_iam_role" "unauthenticated_role" {
  name = "${local.name_prefix}-unauth-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = "cognito-identity.amazonaws.com"
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "cognito-identity.amazonaws.com:aud" = aws_cognito_identity_pool.identity_pool.id
          }
          "ForAnyValue:StringLike" = {
            "cognito-identity.amazonaws.com:amr" = "unauthenticated"
          }
        }
      }
    ]
  })

  tags = {
    Name = "${local.name_prefix}-unauth-role"
  }
}

resource "aws_cognito_identity_pool_roles_attachment" "identity_pool_roles" {
  identity_pool_id = aws_cognito_identity_pool.identity_pool.id

  roles = {
    "authenticated"   = aws_iam_role.authenticated_role.arn
    "unauthenticated" = aws_iam_role.unauthenticated_role.arn
  }
}

# Admin user — SES is blocked so invitation email won't send.
# Password must be set via CLI: aws cognito-idp admin-set-user-password
resource "aws_cognito_user" "admin_user" {
  user_pool_id = aws_cognito_user_pool.user_pool.id
  username     = var.admin_email

  desired_delivery_mediums = ["EMAIL"]

  attributes = {
    email          = var.admin_email
    email_verified = "true"
    given_name     = "Admin"
    family_name    = "User"
  }

  lifecycle {
    ignore_changes = [
      password,
      temporary_password
    ]
  }
}

resource "aws_cognito_user_group" "admin_group" {
  name         = "Admin"
  user_pool_id = aws_cognito_user_pool.user_pool.id
  description  = "Administrators"
  precedence   = 0
}

resource "aws_cognito_user_in_group" "admin_user_in_group" {
  user_pool_id = aws_cognito_user_pool.user_pool.id
  group_name   = aws_cognito_user_group.admin_group.name
  username     = aws_cognito_user.admin_user.username
}

###############################################################################
# GenAI IDP Accelerator — Root Module
###############################################################################

module "genai_idp_accelerator" {
  source = "../genai-idp-terraform"

  providers = {
    aws.us-east-1 = aws.us-east-1
  }

  # Processor: Bedrock LLM (Pattern 2)
  bedrock_llm_processor = {
    classification_model_id = var.classification_model_id
    extraction_model_id     = var.extraction_model_id
    summarization = {
      enabled  = false
      model_id = null
    }
    enable_hitl = false
    config      = local.config
  }

  # External user identity (Cognito created above)
  user_identity = {
    user_pool_arn          = aws_cognito_user_pool.user_pool.arn
    user_pool_client_id    = aws_cognito_user_pool_client.user_pool_client.id
    identity_pool_id       = aws_cognito_identity_pool.identity_pool.id
    authenticated_role_arn = aws_iam_role.authenticated_role.arn
  }

  # Pre-created S3 bucket ARNs (no aws_s3_bucket resources — avoids Object Lock SCP)
  input_bucket_arn   = var.input_bucket_arn
  output_bucket_arn  = var.output_bucket_arn
  working_bucket_arn = var.working_bucket_arn

  # Pre-created assets bucket (avoids aws_s3_bucket in assets-bucket module)
  assets_bucket_name = var.assets_bucket_name
  assets_bucket_arn  = var.assets_bucket_arn

  # Pre-created KMS key
  encryption_key_arn = var.encryption_key_arn

  # Web UI: DISABLED (CloudFront blocked by SCP)
  web_ui = {
    enabled = false
  }

  # API: enabled (needed for document processing workflow)
  api = {
    enabled                     = true
    agent_analytics             = { enabled = false }
    discovery                   = { enabled = false }
    chat_with_document          = { enabled = false }
    process_changes             = { enabled = false }
    knowledge_base              = { enabled = false }
    enable_agent_companion_chat = false
    enable_test_studio          = false
    enable_fcc_dataset          = false
    enable_error_analyzer       = false
    enable_mcp                  = false
  }

  # Evaluation & reporting: DISABLED
  evaluation = { enabled = false }
  reporting  = { enabled = false }

  # Human review: DISABLED
  human_review = { enabled = false }

  # General config
  prefix                       = var.prefix
  region                       = var.region
  deletion_protection          = false
  log_level                    = "INFO"
  log_retention_days           = var.log_retention_days
  data_tracking_retention_days = var.data_tracking_retention_days
  lambda_tracing_mode          = "PassThrough"

  tags = var.tags
}
