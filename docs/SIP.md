# Software Installation Plan (SIP)

**DID:** DI-IPSC-81427 (MIL-STD-498)
**System:** GenAI Intelligent Document Processing (IDP) POC
**Version:** 1.0 — 2026-03-17
**Status:** Draft — evolves with project execution

---

## 1. Scope

### 1.1 Identification

This document provides step-by-step procedures for installing (deploying) the GenAI IDP system into a fresh Vocareum-managed AWS sandbox account. The target audience is an evaluator (or their agent) who has been provisioned a Vocareum account with the standard SCP constraints.

### 1.2 System Overview

The IDP system is a serverless document processing pipeline deployed from the `awslabs/genai-idp-terraform` repository. It processes uploaded documents through OCR (Textract), classification (Bedrock), extraction (Bedrock), and assessment stages, producing structured JSON results. The web UI is served locally via a Vite development server because CloudFront is SCP-blocked.

### 1.3 Leave No Trace

All installation artifacts — credentials, Terraform state, binaries, configuration — reside within the `clAWS/` directory. No files are written to `~/.aws/`, no persistent environment variables are set, and no system-wide changes are made. Deleting the `clAWS/` directory removes all traces of the installation.

---

## 2. Referenced Documents

| # | Document | Source |
|---|----------|--------|
| 1 | PROCRV v1.0 | `../PROCRV.md` |
| 2 | SDP v1.0 | `../SDP.md` |
| 3 | SCOM v1.0 | `SCOM.md` |
| 4 | SCP Impact Analysis | `../vocareum/scp-impact-analysis.md` (local only — not committed) |

---

## 3. Prerequisites

### 3.1 What the Evaluator Needs

| Prerequisite | Detail |
|-------------|--------|
| Vocareum account | A lab session started in the "Credentials for AI Agents" assignment |
| AWS credentials | `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN` from Vocareum "AWS Details" page |
| Local machine | Linux or macOS with `git`, `curl`, `unzip`, `python3`, and `node` (≥22) installed |
| AWS CLI v2 | Installed on the local machine |
| Internet access | Required to clone repo, download Terraform, install npm packages, and reach AWS APIs |

### 3.2 What the Evaluator Does NOT Need

- AWS account of their own (Vocareum provides one)
- `~/.aws/` configuration (credentials are project-local)
- Terraform pre-installed (the setup script installs it into `clAWS/bin/`)
- Any prior deployment experience (this document provides all steps)

---

## 4. Installation Procedure

### 4.1 Clone and Configure Credentials

```bash
# Clone the repository
git clone https://github.com/jeremyallenjacobson/claws.git clAWS
cd clAWS

# Create credentials file from template
cp .env.example .env
```

Open `.env` in a text editor (not through the agent — credentials will be redacted). Paste the three credential values from Vocareum "AWS Details":

```
export AWS_ACCESS_KEY_ID="ASIA..."
export AWS_SECRET_ACCESS_KEY="..."
export AWS_SESSION_TOKEN="..."
```

Save the file. **Do not paste credentials into the agent chat.**

### 4.2 Run Setup

```bash
bin/voc-setup
```

The setup script:
1. Validates credential format (key ID starts with `ASIA`, token length > 100 chars)
2. Verifies AWS connectivity (`aws sts get-caller-identity`)
3. Confirms the account is a Vocareum account (role contains `voclabs`)
4. Installs Terraform into `bin/` if not present

Expected output:
```
✓ .env file found
✓ Credentials format validated
✓ Authenticated to AWS
    Account:  <your-account-id>
    Role:     arn:aws:sts::<id>:assumed-role/voclabs/user*
✓ Terraform found: v1.7.5
  Setup complete.
```

If setup fails, check:
- Credentials were pasted correctly (no truncation)
- Vocareum lab session is still active
- Internet connectivity is available

### 4.3 Source Credentials

Before running any AWS or Terraform command in a terminal session:

```bash
source .env
```

This sets credentials for the current terminal session only. Closing the terminal removes them. The `.env` file also sets `AWS_CONFIG_FILE=/dev/null` and `AWS_SHARED_CREDENTIALS_FILE=/dev/null` to prevent accidental use of any `~/.aws/` credentials.

---

## 5. Infrastructure Deployment

### 5.1 Pre-Create S3 Buckets

The Vocareum SCP denies `s3:GetBucketObjectLockConfiguration`, which the AWS Terraform provider v5+ calls on every `aws_s3_bucket` resource. All S3 buckets must be pre-created via CLI.

Generate a unique suffix and create the buckets:

```bash
SUFFIX=$(cat /dev/urandom | tr -dc 'a-z0-9' | head -c 8)
PREFIX="poc-idp"

for BUCKET in input output working assets; do
  aws s3 mb "s3://${PREFIX}-${BUCKET}-${SUFFIX}" --region us-east-1
done

# Enable EventBridge notifications on the input bucket (required for pipeline trigger)
aws s3api put-bucket-notification-configuration \
  --bucket "${PREFIX}-input-${SUFFIX}" \
  --notification-configuration '{"EventBridgeConfiguration": {}}'

echo "Suffix: $SUFFIX"
echo "Record this suffix — you will need it for terraform.tfvars"
```

### 5.2 Create KMS Key

```bash
KEY_ID=$(aws kms create-key \
  --description "IDP POC encryption key" \
  --region us-east-1 \
  --query 'KeyMetadata.KeyId' --output text)

aws kms create-alias \
  --alias-name "alias/${PREFIX}-${SUFFIX}" \
  --target-key-id "$KEY_ID" \
  --region us-east-1

echo "KMS Key ID: $KEY_ID"
```

### 5.3 Clone Upstream Repository

```bash
cd ~/Projects/clAWS  # or wherever clAWS is
git clone https://github.com/awslabs/genai-idp-terraform.git
cd genai-idp-terraform
```

### 5.4 Apply Patches

Three patches are required to work within the Vocareum SCP constraints.

**Patch 1: WAF disable** — WAFv2 costs $5/month (exceeds $2 budget):
```bash
# In modules/web-ui/variables.tf, change enable_waf default from true to false
sed -i '/variable "enable_waf"/,/^}/ s/default = true/default = false/' \
  modules/web-ui/variables.tf
```

**Patch 2: Assets bucket external mode** — Accept pre-created S3 bucket instead of creating one:

The `modules/assets-bucket` module must be patched to accept `external_bucket_name` and `external_bucket_arn` variables. When set, the module skips `aws_s3_bucket` creation and outputs the provided values. See `SPS.md` Section 5.3 for the exact diff.

**Patch 3: S3 bucket references** — The root module's S3-related variables must accept pre-created bucket ARNs. The `deploy/` wrapper handles this by passing `input_bucket_arn`, `output_bucket_arn`, `working_bucket_arn`, `assets_bucket_name`, `assets_bucket_arn`, and `encryption_key_arn` as variables.

### 5.5 Build Lambda Layers Locally

CodeBuild is killed by Vocareum during the PROVISIONING phase. Lambda layers must be built locally and uploaded to S3.

```bash
# Install uv locally (inside clAWS — not system-wide)
pip install --target="$(pwd)/bin/pylib" uv 2>/dev/null
export PYTHONPATH="$(pwd)/bin/pylib:${PYTHONPATH:-}"
export PATH="$(pwd)/bin/pylib/bin:$PATH"

# For each Lambda layer with a requirements.txt:
# (The exact layers and their requirements depend on the upstream repo version.
#  Check modules/processor/layers/ for the layer definitions.)

LAYER_DIR=$(mktemp -d)
uv pip install \
  --python-platform x86_64-manylinux2014 \
  --python-version 3.12 \
  --target "$LAYER_DIR/python" \
  <requirements-from-layer>

cd "$LAYER_DIR" && zip -r layer.zip python/

# Upload to the assets bucket at the path Terraform expects
aws s3 cp layer.zip "s3://${PREFIX}-assets-${SUFFIX}/<expected-path>"
```

The exact layer paths depend on the upstream repository version. Check the Terraform plan output for `aws_lambda_layer_version` resources to determine the expected S3 keys.

### 5.6 Configure terraform.tfvars

```bash
cd ~/Projects/clAWS/deploy

# Get AWS account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

cat > terraform.tfvars << EOF
region = "us-east-1"
prefix = "poc-idp"

admin_email = "admin@poc-idp.local"

# Pre-created S3 buckets
input_bucket_arn   = "arn:aws:s3:::${PREFIX}-input-${SUFFIX}"
output_bucket_arn  = "arn:aws:s3:::${PREFIX}-output-${SUFFIX}"
working_bucket_arn = "arn:aws:s3:::${PREFIX}-working-${SUFFIX}"

# Pre-created assets bucket
assets_bucket_name = "${PREFIX}-assets-${SUFFIX}"
assets_bucket_arn  = "arn:aws:s3:::${PREFIX}-assets-${SUFFIX}"

# Pre-created KMS key
encryption_key_arn = "arn:aws:kms:us-east-1:${ACCOUNT_ID}:key/${KEY_ID}"

classification_model_id = "us.amazon.nova-lite-v1:0"
extraction_model_id     = "us.amazon.nova-lite-v1:0"

log_retention_days           = 1
data_tracking_retention_days = 7

tags = {
  Environment = "poc"
  Project     = "idp-poc"
}
EOF
```

### 5.7 Deploy

```bash
cd ~/Projects/clAWS/deploy

terraform init
terraform plan -out=plan.tfplan 2>&1 | tee plan-output.txt

# Review the plan:
# - No aws_s3_bucket resources (all pre-created)
# - No aws_wafv2_web_acl resources (WAF disabled)
# - No aws_cloudfront_distribution resources (web_ui disabled)
# - ~247 resources to create

terraform apply plan.tfplan 2>&1 | tee apply-output.txt
```

**Expected duration:** 15–25 minutes.

### 5.8 Post-Deployment Setup

```bash
# Capture outputs
terraform output -json > terraform-outputs.json

# Set admin password (SES is SCP-blocked, so invitation email never arrives)
POOL_ID=$(terraform output -raw cognito_user_pool_id 2>/dev/null || echo "check terraform-outputs.json")

aws cognito-idp admin-set-user-password \
  --user-pool-id "$POOL_ID" \
  --username "admin@poc-idp.local" \
  --password 'P0c-Idp!2026#Eval' \
  --permanent \
  --region us-east-1
```

### 5.9 Start Web UI

```bash
cd ~/Projects/clAWS/genai-idp-terraform/sources/src/ui

# Create environment file with deployment endpoints
cat > .env.local << EOF
VITE_AWS_REGION=us-east-1
VITE_USER_POOL_ID=$(cd ~/Projects/clAWS/deploy && terraform output -raw cognito_user_pool_id 2>/dev/null)
VITE_USER_POOL_CLIENT_ID=$(cd ~/Projects/clAWS/deploy && terraform output -raw cognito_user_pool_client_id 2>/dev/null)
VITE_IDENTITY_POOL_ID=$(cd ~/Projects/clAWS/deploy && terraform output -raw cognito_identity_pool_id 2>/dev/null)
VITE_APPSYNC_GRAPHQL_URL=$(cd ~/Projects/clAWS/deploy && terraform output -raw appsync_graphql_url 2>/dev/null)
EOF

# Install dependencies and start
npm install --force
npm run dev -- --host 0.0.0.0 --port 3000
```

Open `http://localhost:3000` in a browser. Log in with `admin@poc-idp.local` / `P0c-Idp!2026#Eval`.

**Security note:** The Vite dev server serves the React SPA over HTTP on localhost only. All API calls from the browser to AWS (AppSync, Cognito) use HTTPS. No credentials traverse the network in plaintext.

---

## 6. Installation Verification

After deployment, verify the installation using the procedures in STD.md Section 3. Quick smoke test:

```bash
source ~/Projects/clAWS/.env

# Upload a small test document
echo "INVOICE
Vendor: Test Corp
Invoice Number: TEST-001
Date: 01/01/2026
Total: \$100.00" > /tmp/test-doc.txt

aws s3 cp /tmp/test-doc.txt s3://${PREFIX}-input-${SUFFIX}/test-doc.txt --region us-east-1

# Wait 30 seconds, then check
sleep 30

aws stepfunctions list-executions \
  --state-machine-arn "$(cd ~/Projects/clAWS/deploy && terraform output -raw state_machine_arn 2>/dev/null)" \
  --max-results 1 --region us-east-1 \
  --query 'executions[0].status' --output text

# Expected: SUCCEEDED

# View results
aws s3 cp "s3://${PREFIX}-output-${SUFFIX}/test-doc.txt/sections/1/result.json" - \
  --region us-east-1 | python3 -m json.tool
```

---

## 7. Known SCP Constraints and Workarounds

The Vocareum environment enforces Service Control Policies (SCPs) and concurrency limits that prevent out-of-the-box deployment of the upstream repository. The full analysis is in `vocareum/scp-impact-analysis.md` (local file, not committed to git).

### 7.1 Critical Blockers

| # | Blocker | Root Cause | Workaround | SIP Section |
|---|---------|-----------|------------|-------------|
| 1 | S3 Terraform refresh fails | SCP denies `s3:GetBucketObjectLockConfiguration` | Pre-create buckets via CLI | 5.1 |
| 2 | CloudFront blocked | SCP denies `cloudfront:CreateDistribution` | Disable web-ui module; use localhost dev server | 5.4, 5.9 |
| 3 | CodeBuild killed | Vocareum kills builds during PROVISIONING | Build Lambda layers locally with `uv` | 5.5 |
| 4 | SES blocked | SCP denies `ses:*` | Set admin password via CLI | 5.8 |
| 5 | WAF too expensive | $5/month base exceeds $2 budget | Patch `enable_waf` default to `false` | 5.4 |

### 7.2 Operational Limits — Do Not Exceed

| Limit | Value | Consequence |
|-------|-------|-------------|
| Lambda concurrent executions | 3 | Session terminated, resources destroyed |
| Bedrock tokens per invocation | 1,000 in / 1,000 out | Session terminated |
| EC2 concurrent instances | 2 (3 = fraud lock) | Account locked |
| S3 aggregate size | 10 GB | Session terminated |
| Total spend | $2.00 | Account unusable |

Process **one document at a time**. Use **small documents** (1 page). **Destroy infrastructure** when done to stop KMS charges.

---

## 8. Uninstallation (Teardown)

### 8.1 Destroy Terraform Resources

```bash
source ~/Projects/clAWS/.env
cd ~/Projects/clAWS/deploy

terraform destroy -auto-approve 2>&1 | tee destroy-output.txt
```

### 8.2 Clean Up Pre-Created Resources

S3 buckets and KMS key were created outside Terraform and must be removed manually:

```bash
# Empty and delete pre-created S3 buckets
for BUCKET in ${PREFIX}-input-${SUFFIX} ${PREFIX}-output-${SUFFIX} ${PREFIX}-working-${SUFFIX} ${PREFIX}-assets-${SUFFIX}; do
  aws s3 rm "s3://$BUCKET" --recursive --region us-east-1
  aws s3 rb "s3://$BUCKET" --region us-east-1
done

# Schedule KMS key deletion (7-day minimum waiting period)
aws kms schedule-key-deletion \
  --key-id "$KEY_ID" \
  --pending-window-in-days 7 \
  --region us-east-1
```

### 8.3 Verify Cleanup

```bash
# No Lambda functions with our prefix
aws lambda list-functions \
  --query "Functions[?starts_with(FunctionName, 'poc-idp')].FunctionName" \
  --output text --region us-east-1

# No S3 buckets with our prefix
aws s3 ls | grep poc-idp

# KMS key in PendingDeletion state
aws kms describe-key --key-id "$KEY_ID" \
  --query 'KeyMetadata.KeyState' --output text --region us-east-1
# Expected: PendingDeletion
```

### 8.4 Remove Local Files

```bash
cd ~
rm -rf ~/Projects/clAWS  # or wherever you cloned it
```

This removes all traces: credentials, Terraform state, binaries, configuration, and documentation. Nothing was written outside this directory.

---

## 9. Troubleshooting

### 9.1 Terraform Apply Fails

| Error | Cause | Fix |
|-------|-------|-----|
| `AccessDenied` on S3 operations | S3 Object Lock SCP | Ensure all S3 buckets are pre-created (Section 5.1), not managed by Terraform |
| `AccessDeniedException` on CloudFront | CloudFront SCP | Ensure `web_ui = { enabled = false }` in main.tf |
| `ResourceNotFoundException` on Lambda layer | CodeBuild didn't run | Build and upload layers manually (Section 5.5) |
| `InvalidParameterValue` on Cognito | Admin email format | Use a valid email format in `admin_email` |
| Timeout during apply | Large deployment | Normal — 15-25 minutes expected. Do not interrupt. |

### 9.2 Credentials Expired

Vocareum session credentials expire when the lab session ends. If you see `ExpiredToken` errors:
1. Return to Vocareum and start a new lab session
2. Copy new credentials from "AWS Details"
3. Update `.env` with new values
4. Run `bin/voc-setup` to verify
5. Re-source: `source .env`

### 9.3 Session Terminated (Concurrency Limit Exceeded)

If Vocareum terminates the session, all AWS resources are destroyed. Recovery:
1. Wait ~10 minutes for the account to become available
2. Start a new lab session
3. Update credentials in `.env`
4. The `clAWS/` directory still has all code and docs (it's on your local machine)
5. Terraform state in `deploy/` is now stale — delete `deploy/terraform.tfstate*`
6. Re-run the deployment from Section 5.1

---

## 10. Version History

| Version | Date | Change |
|---------|------|--------|
| 1.0 | 2026-03-17 | Initial draft based on first successful deployment |
