# Software Center Operator Manual (SCOM)

**DID:** DI-IPSC-81445 (MIL-STD-498)
**System:** GenAI Intelligent Document Processing (IDP) POC
**Version:** 1.0 — 2026-03-17
**Status:** Draft — evolves with project execution

---

## 1. Scope

### 1.1 Identification

This manual provides operational procedures for deploying, monitoring, and tearing down the GenAI IDP POC in AWS account `198082850288` (us-east-1). The operator and developer are the same person.

### 1.2 System Overview

A serverless IDP platform deployed via Terraform. All infrastructure is ephemeral — designed to be deployed, used, and destroyed within a single lab session.

---

## 2. Referenced Documents

| # | Document | Source |
|---|----------|--------|
| 1 | SDP v1.0 | `../SDP.md` |
| 2 | PROCRV v1.0 | `../PROCRV.md` |

---

## 3. Credential Management

### 3.1 Obtaining Credentials

Credentials are provisioned by the Vocareum platform. After starting the lab session:

1. Navigate to the Vocareum course page.
2. Click "AWS Details" to reveal credentials.
3. Copy the `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, and `AWS_SESSION_TOKEN`.

### 3.2 Configuring Credentials

**Option A — Environment variables (recommended):**
```bash
export AWS_ACCESS_KEY_ID="[from Vocareum]"
export AWS_SECRET_ACCESS_KEY="[from Vocareum]"
export AWS_SESSION_TOKEN="[from Vocareum]"
export AWS_DEFAULT_REGION="us-east-1"
```

**Option B — Source from .env file in the clAWS directory:**
```bash
# Create .env file (DO NOT commit to git — already in .gitignore)
cat > ~/Projects/clAWS/.env << 'EOF'
export AWS_ACCESS_KEY_ID="..."
export AWS_SECRET_ACCESS_KEY="..."
export AWS_SESSION_TOKEN="..."
export AWS_DEFAULT_REGION="us-east-1"
EOF

source ~/Projects/clAWS/.env
```

**Option C — AWS CloudShell (credentials automatic):**
No credential configuration needed. CloudShell inherits the Vocareum session credentials.

### 3.3 Verifying Credentials

```bash
aws sts get-caller-identity
# Expected: Account 198082850288, role voclabs/user*
```

---

## 4. Deployment Procedure

### 4.1 Prerequisites

- Terraform installed (`terraform version` returns ≥ 1.5)
- AWS credentials configured and verified
- `genai-idp-terraform` repository cloned
- `terraform.tfvars` written (see PROCRV Appendix B)
- WAF patch applied (`modules/web-ui/variables.tf`: `enable_waf` default → `false`)
- `web_ui = { enabled = false }` set in tfvars (CloudFront is SCP-blocked)

### 4.2 Deploy

```bash
cd ~/Projects/clAWS/deploy
export PATH="$HOME/Projects/clAWS/bin:$PATH"

# Initialize Terraform providers and modules
terraform init

# Review the execution plan
terraform plan -out=plan.tfplan 2>&1 | tee ~/Projects/clAWS/deploy/plan-output.txt

# Review plan for:
# - No aws_wafv2_web_acl resources
# - No aws_cloudfront_distribution resources (if web_ui disabled)
# - Lambda function count (expect ~18)
# - KMS key count (expect 1)

# Apply the plan
terraform apply plan.tfplan 2>&1 | tee ~/Projects/clAWS/deploy/apply-output.txt
```

**Expected duration:** 15–25 minutes.

### 4.3 Post-Deployment

Capture Terraform outputs:
```bash
terraform output -json > ~/Projects/clAWS/deploy/terraform-outputs.json

# Key outputs to record:
terraform output api_endpoint
terraform output document_input_bucket
terraform output document_output_bucket
terraform output processing_state_machine_arn
```

---

## 5. Teardown Procedure

**Execute unconditionally after validation — do not leave resources running.**

```bash
cd ~/Projects/clAWS/deploy
export PATH="$HOME/Projects/clAWS/bin:$PATH"

# Empty and delete pre-created S3 buckets (not managed by Terraform)
for BUCKET in poc-idp-input-571e2c0p poc-idp-output-571e2c0p poc-idp-working-571e2c0p poc-idp-assets-571e2c0p; do
  aws s3 rm s3://$BUCKET --recursive
  aws s3 rb s3://$BUCKET
done

terraform destroy -auto-approve 2>&1 | tee ~/Projects/clAWS/deploy/destroy-output.txt
```

### 5.1 Post-Teardown Verification

```bash
# Verify no Lambda functions remain
aws lambda list-functions --query 'Functions[].FunctionName' --output text

# Verify no unexpected S3 buckets remain
aws s3 ls

# Verify KMS key is in PendingDeletion state
aws kms list-keys --query 'Keys[].KeyId' --output text
# For each key:
aws kms describe-key --key-id <KEY_ID> --query 'KeyMetadata.KeyState' --output text
# Expected: "PendingDeletion"
```

### 5.2 Handling Terraform Destroy Failures

If `terraform destroy` fails (e.g., non-empty S3 bucket):

```bash
# Force-empty the S3 bucket, then retry destroy
aws s3 rb s3://<bucket-name> --force
terraform destroy -auto-approve
```

If Terraform state is corrupted:
```bash
# Manual cleanup — list and delete resources by type
aws lambda list-functions --query 'Functions[?starts_with(FunctionName, `poc-idp`)].FunctionName' --output text
# Delete each function manually
aws lambda delete-function --function-name <name>

# Repeat for DynamoDB tables, S3 buckets, etc.
```

---

## 6. Monitoring

### 6.1 CloudWatch Logs

```bash
# List log groups for the deployment
aws logs describe-log-groups \
  --log-group-name-prefix "/aws/lambda/poc-idp" \
  --query 'logGroups[].logGroupName' --output text

# Tail recent logs from a specific Lambda
aws logs filter-log-events \
  --log-group-name "/aws/lambda/poc-idp-5ayd6ree" \
  --start-time $(date -d '10 minutes ago' +%s000)
```

Log retention is set to 1 day to minimize CloudWatch Logs ingestion costs.

### 6.2 Step Functions Monitoring

```bash
# List recent executions
aws stepfunctions list-executions \
  --state-machine-arn arn:aws:states:us-east-1:198082850288:stateMachine:poc-idp-5ayd6ree-processor-document-processing \
  --max-results 5

# Get details on the most recent execution
aws stepfunctions describe-execution \
  --execution-arn $(aws stepfunctions list-executions \
    --state-machine-arn arn:aws:states:us-east-1:198082850288:stateMachine:poc-idp-5ayd6ree-processor-document-processing \
    --max-results 1 --query 'executions[0].executionArn' --output text)
```

### 6.3 Cost Tracking

```bash
# Check current period spend (may lag 8–24 hours)
aws ce get-cost-and-usage \
  --time-period Start=$(date +%Y-%m-01),End=$(date -d '+1 day' +%Y-%m-%d) \
  --granularity DAILY \
  --metrics BlendedCost
```

**Budget ceiling:** $2.00. If spend approaches this, stop all testing and proceed immediately to teardown.

---

## 7. Recovery Procedures

### 7.1 Session Termination (Concurrency Limit Exceeded)

If a Vocareum concurrency limit is exceeded, the platform terminates the lab session and destroys all AWS resources.

**Recovery procedure:**
1. Wait ~10 minutes for the session to become available again.
2. Start a new lab session.
3. **CloudShell home directory may be wiped.** If Terraform state was stored there, it is lost.
4. Re-obtain credentials from Vocareum.
5. Re-clone the repository and re-apply patches.
6. Run `terraform init` and `terraform apply` from scratch.
7. Previous resources were destroyed by Vocareum — no orphaned resource cleanup needed.

### 7.2 Terraform Apply Failure (Partial Deployment)

If `terraform apply` fails partway:
1. Review the error message for the cause (SCP denial, resource limit, etc.).
2. Run `terraform destroy -auto-approve` immediately to clean up partial resources.
3. Fix the root cause (patch module, adjust tfvars).
4. Re-run `terraform plan` and `terraform apply`.
5. Limit retries to 2 attempts before aborting.

### 7.3 Budget Exhaustion

If the $2.00 budget is exhausted:
1. The account becomes unusable for cost-bearing operations.
2. Run `terraform destroy` — this operation itself is free.
3. Record findings and abort the POC.

---

## 8. Operational Limits — Do Not Exceed

| Limit | Value | Consequence |
|-------|-------|-------------|
| Concurrent Lambda executions | 3 | Session terminated |
| Concurrent EC2 instances | 2 (3 = fraud lock) | Session terminated / account locked |
| Bedrock tokens per invocation | 1,000 in / 1,000 out | Session terminated |
| S3 total size | 10 GB | Session terminated |
| Documents in processing simultaneously | 1 | Exceeding risks concurrency violation |
| Total AWS spend | $2.00 | Account unusable |
