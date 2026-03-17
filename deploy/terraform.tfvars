region = "us-east-1"
prefix = "poc-idp"

admin_email = "admin@poc-idp.local"

# Pre-created S3 buckets (created via CLI to avoid Object Lock SCP issue)
input_bucket_arn   = "arn:aws:s3:::poc-idp-input-571e2c0p"
output_bucket_arn  = "arn:aws:s3:::poc-idp-output-571e2c0p"
working_bucket_arn = "arn:aws:s3:::poc-idp-working-571e2c0p"

# Pre-created assets bucket
assets_bucket_name = "poc-idp-assets-571e2c0p"
assets_bucket_arn  = "arn:aws:s3:::poc-idp-assets-571e2c0p"

# Pre-created KMS key
encryption_key_arn = "arn:aws:kms:us-east-1:198082850288:key/304d492f-7b7f-4bc5-849f-2bff67f3735f"

classification_model_id = "us.amazon.nova-lite-v1:0"
extraction_model_id     = "us.amazon.nova-lite-v1:0"

log_retention_days           = 1
data_tracking_retention_days = 7

tags = {
  Environment = "poc"
  Project     = "idp-poc"
}
