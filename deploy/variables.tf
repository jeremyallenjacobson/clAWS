variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "prefix" {
  description = "Prefix for resource names"
  type        = string
  default     = "poc-idp"
}

variable "admin_email" {
  description = "Admin user email for Cognito"
  type        = string
}

variable "input_bucket_arn" {
  description = "ARN of pre-created input S3 bucket"
  type        = string
}

variable "output_bucket_arn" {
  description = "ARN of pre-created output S3 bucket"
  type        = string
}

variable "working_bucket_arn" {
  description = "ARN of pre-created working S3 bucket"
  type        = string
}

variable "assets_bucket_name" {
  description = "Name of pre-created assets S3 bucket"
  type        = string
}

variable "assets_bucket_arn" {
  description = "ARN of pre-created assets S3 bucket"
  type        = string
}

variable "encryption_key_arn" {
  description = "ARN of pre-created KMS key"
  type        = string
}

variable "config_file_path" {
  description = "Path to the YAML config file for the processor"
  type        = string
  default     = "./config/config.yaml"
}

variable "classification_model_id" {
  description = "Bedrock model ID for classification"
  type        = string
  default     = "us.amazon.nova-lite-v1:0"
}

variable "extraction_model_id" {
  description = "Bedrock model ID for extraction"
  type        = string
  default     = "us.amazon.nova-lite-v1:0"
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 1
}

variable "data_tracking_retention_days" {
  description = "Document tracking data retention in days"
  type        = number
  default     = 7
}

variable "tags" {
  description = "Tags for all resources"
  type        = map(string)
  default     = {}
}
