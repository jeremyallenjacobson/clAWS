output "cognito_user_pool_id" {
  description = "Cognito User Pool ID"
  value       = aws_cognito_user_pool.user_pool.id
}

output "cognito_user_pool_client_id" {
  description = "Cognito User Pool Client ID"
  value       = aws_cognito_user_pool_client.user_pool_client.id
}

output "cognito_identity_pool_id" {
  description = "Cognito Identity Pool ID"
  value       = aws_cognito_identity_pool.identity_pool.id
}

output "api" {
  description = "API resources"
  value       = module.genai_idp_accelerator.api
}

output "name_prefix" {
  description = "Name prefix used for resources"
  value       = module.genai_idp_accelerator.name_prefix
}

output "processor" {
  description = "Processor details"
  value       = module.genai_idp_accelerator.processor
}

output "processing_environment" {
  description = "Processing environment details"
  value       = module.genai_idp_accelerator.processing_environment
}
