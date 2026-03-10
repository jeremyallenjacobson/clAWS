# Software Development Plan (SDP)

## GenAI Intelligent Document Processing POC — Constrained AWS Deployment

---

## 1. Scope

### 1.1 Identification

- **System Title:** GenAI Intelligent Document Processing (IDP) POC
- **Source Repository:** `https://github.com/awslabs/genai-idp-terraform.git`
- **Deployment Pattern:** Pattern 2 — Bedrock LLM Processor
- **Target Environment:** Vocareum-managed AWS account (Ricoh USA Eval 2026), `us-east-1`
- **Budget:** $2.00 USD
- **SDP Version:** 1.0
- **Date:** 2026-03-10
- **Governing Document:** PROCRV v1.0 (`/home/cloudshell-user/PROCRV.md`)

### 1.2 System Overview

This SDP governs the deployment of a minimal Intelligent Document Processing (IDP) platform from the `awslabs/genai-idp-terraform` repository into a Vocareum-managed AWS sandbox. The system allows a single user to upload documents through a web interface, provide extraction instructions, and view structured extraction results. The upstream repository provides a full-featured IDP pipeline; this project deploys only the minimum viable subset: React web UI, AppSync GraphQL API, Cognito authentication, Step Functions processing pipeline (OCR → classification → extraction → assessment → results), and S3/DynamoDB storage.

The project sponsor, developer, operator, and user are the same person: the POC evaluator. The operating site is AWS `us-east-1`. Development is performed from AWS CloudShell within the Vocareum account.

### 1.3 Document Overview

This document describes the plan for deploying, validating, and tearing down the IDP POC system. It covers: repository acquisition, module patching, SCP constraint testing, Terraform deployment, web UI validation, document processing validation, and teardown. Every activity is planned against the $2 budget ceiling and Vocareum concurrency limits documented in the PROCRV.

### 1.4 Relationship to Other Plans

This SDP implements the operating concept described in the PROCRV (Pre-Requirements Operating Concept Rationale and Validation). The PROCRV establishes the constraints, assumptions, blockers, and theory of programming. This SDP translates those into executable work.

No other project management plans exist. The SDP is the sole planning document.

---

## 2. Referenced Documents

| # | Document | Revision | Source |
|---|----------|----------|--------|
| 1 | PROCRV — GenAI IDP POC | v1.0, 2026-03-10 | `/home/cloudshell-user/PROCRV.md` |
| 2 | genai-idp-terraform repository | HEAD | https://github.com/awslabs/genai-idp-terraform.git |
| 3 | MIL-STD-498 SDP DID (DI-IPSC-81427) | — | https://kkovacs.eu/mil-std-498/SDP.md |
| 4 | Vocareum Concurrency Limits | — | See PROCRV Appendix A |
| 5 | Vocareum SCPs | — | See PROCRV Appendix A |
| 6 | Vocareum IAM Policy (Allow All) | — | Course: Ricoh USA Eval 2026 |

---

## 3. Overview of Required Work

### 3.1 Requirements and Constraints on the System

The PROCRV (Sections 3.2, 4.2, 4.5, and 8) establishes the following binding constraints:

**Budget:** $2.00 total. No mechanism to add funds. Every AWS resource must be free-tier eligible or its cost must be quantified against this ceiling. Known cost threats: KMS customer-managed key ($1/month), WAFv2 Web ACL ($5/month), CloudWatch Logs ($0.50/GB ingestion).

**Concurrency limits (session-terminating):**

| Resource | Limit |
|----------|-------|
| Lambda Functions | 3 |
| Concurrent EC2 | 2 |
| CodeBuild Projects | 1 |
| Bedrock Input Tokens | 1,000 |
| Bedrock Output Tokens | 1,000 |
| S3 Total Size | 10 GB |
| DynamoDB R/W Capacity | 1,000 each |

**SCP denials:** CloudFront `CreateDistribution` (critical blocker for web UI), SES, Lightsail, Glacier, Route53 domains, S3 Object Lock, reserved instance purchases. Region locked to `us-east-1`. EC2 restricted to `*.nano` through `*.large`, `gp2` volumes only.

**Fraud limits (account-locking):** 3 EC2 instances.

### 3.2 Requirements on Project Documentation

Minimal. The PROCRV and this SDP are the only project documents. No separate SRS, SDD, STP, or STR are produced. Validation results are recorded as annotations in the SDP or as terminal output logs.

### 3.3 Position in System Life Cycle

This is a single-iteration POC. There is no maintenance phase, no operational phase beyond evaluation, and no transition to a support agency. The life cycle is: plan → deploy → validate → tear down.

### 3.4 Constraints on Schedule and Resources

**Schedule:** The deployment must complete within a single Vocareum lab session (typically 4 hours). Terraform apply is estimated at 10–20 minutes. Validation is estimated at 30 minutes. Teardown is 5–10 minutes.

**Resources:** One person, one AWS account, one CloudShell environment, $2 budget. No external compute, no CI/CD pipeline, no additional tooling beyond what CloudShell provides (git, terraform, aws cli, node/npm).

### 3.5 Other Constraints

**Theory of Programming (PROCRV Section 8):** Six survival principles govern all implementation decisions:

1. The budget is the program.
2. Concurrency limits are harder than budget.
3. The SCP is the real architecture.
4. Terraform state is fragile.
5. Every optional feature is a threat.
6. Test small or don't test at all.

---

## 4. Plans for Performing General Software Development Activities

### 4.1 Software Development Process

The development process is a single build with four phases executed sequentially within one lab session:

| Phase | Objective | Duration (est.) |
|-------|-----------|-----------------|
| **Phase 0: Constraint Testing** | Verify SCP assumptions before spending money | 10 min |
| **Phase 1: Acquire and Patch** | Clone repo, apply module patches, configure tfvars | 15 min |
| **Phase 2: Deploy** | `terraform init` + `terraform apply` | 15–25 min |
| **Phase 3: Validate** | Web UI login, document upload, extraction test | 20–30 min |
| **Phase 4: Teardown** | `terraform destroy` | 5–10 min |

**Go/no-go gates between phases:**

- Phase 0 → Phase 1: Proceed only if CloudFront `CreateDistribution` is permitted (or a viable fallback is identified) AND Lambda function creation is permitted (create a test function, then delete it).
- Phase 1 → Phase 2: Proceed only if all patches apply cleanly and `terraform plan` shows no SCP-incompatible resources.
- Phase 2 → Phase 3: Proceed only if `terraform apply` completes without error.
- Phase 3 → Phase 4: Always execute. Do not leave resources running.

### 4.2 General Plans for Software Development

#### 4.2.1 Software Development Methods

**Method:** Infrastructure-as-Code deployment with surgical patching.

No new software is written. The development work consists of:
1. Cloning an upstream Terraform repository.
2. Applying targeted patches to module defaults to disable costly features.
3. Writing a `terraform.tfvars` configuration file.
4. Running `terraform apply`.
5. Validating the deployed system through its web UI.

**Tools:**
- **Terraform** (version provided by CloudShell or installed manually): Infrastructure deployment and teardown.
- **git**: Repository acquisition.
- **AWS CLI**: SCP constraint testing and diagnostic queries.
- **Web browser**: Web UI validation.
- **Amp (AI coding agent)**: Patch generation, troubleshooting, and decision support.

**Automated testing:** None. Validation is manual. The system either works or it doesn't. The PROCRV establishes that this is a POC — reliability testing is not a requirement.

#### 4.2.2 Standards for Software Products

No new code is produced. Patches to existing Terraform modules must:
- Be minimal (change defaults, not logic).
- Be reversible (the upstream repo must remain functional if patches are reverted).
- Be documented in this SDP with rationale.

The `terraform.tfvars` file follows HCL syntax conventions as established by the upstream repository's existing examples.

#### 4.2.3 Reusable Software Products

##### 4.2.3.1 Incorporating Reusable Software Products

The entire system is a reusable software product: the `awslabs/genai-idp-terraform` repository. It provides:
- Terraform modules for all AWS infrastructure.
- A React web UI (pre-built via CodeBuild).
- Lambda function source code for the processing pipeline.
- Step Functions state machine definitions.

**Benefits:** Complete IDP solution with no custom development required. Well-tested by AWS Labs.

**Drawbacks:** Designed for unconstrained AWS accounts. Default configuration exceeds our budget ($7+/month). Assumes CloudFront availability. Creates ~18 Lambda functions.

**Restrictions:** Must be patched before deployment (WAF, KMS, optional features). CloudFront module may need to be replaced or bypassed.

##### 4.2.3.2 Developing Reusable Software Products

Not applicable. No reusable products are developed.

#### 4.2.4 Handling of Critical Requirements

##### 4.2.4.1 Safety Assurance

Not applicable. No safety-critical requirements.

##### 4.2.4.2 Security Assurance

Cognito handles authentication. S3 buckets are encrypted. No PII is uploaded during the POC. The Vocareum SCPs enforce platform security boundaries. No additional security measures are required.

##### 4.2.4.3 Privacy Assurance

No PII or sensitive data is processed. Test documents contain synthetic or public data only.

##### 4.2.4.4 Assurance of Other Critical Requirements

**Budget assurance:** Every resource is evaluated against the $2 ceiling before deployment. `terraform plan` output is reviewed for cost-bearing resources before `terraform apply` is executed.

**Concurrency assurance:** Documents are processed one at a time. No batch operations. No parallel Lambda invocations by design (Step Functions executes sequentially).

#### 4.2.5 Computer Hardware Resource Utilization

All compute is serverless (Lambda, Step Functions, CodeBuild, Textract, Bedrock). No EC2 instances are provisioned. No EBS volumes are created. S3 storage is estimated at <100 MB (web app assets + a few test documents + extraction results). DynamoDB usage is minimal (single-digit items in configuration and tracking tables).

#### 4.2.6 Recording Rationale

All key decisions are recorded in the PROCRV (Section 8: Theory of the Proposed System). Implementation decisions made during deployment that deviate from the PROCRV are recorded as amendments to this SDP.

The term "key decisions" for this project means: any decision that affects cost, any decision that responds to an SCP denial, and any decision that changes the system architecture from what the PROCRV describes.

#### 4.2.7 Access for Acquirer Review

Not applicable. Single-person project.

---

## 5. Plans for Performing Detailed Software Development Activities

### 5.1 Project Planning and Oversight

#### 5.1.1 Software Development Planning

This SDP is the sole planning document. Updates are made inline if Phase 0 testing reveals constraints that change the deployment approach (e.g., CloudFront is blocked and an alternative must be used).

#### 5.1.2 CSCI Test Planning

Not applicable. No CSCIs are developed.

#### 5.1.3 System Test Planning

System testing consists of the Phase 3 validation described in Section 5.9 of this SDP. It is a manual end-to-end test: log in → configure extraction → upload document → verify results.

#### 5.1.4 Software Installation Planning

Installation is `terraform apply`. See Phase 2 (Section 5.7.1).

#### 5.1.5 Software Transition Planning

Not applicable. No transition to a support site. The system is destroyed after evaluation.

#### 5.1.6 Following and Updating Plans

The evaluator reviews this SDP before each phase. If a go/no-go gate fails, the evaluator updates the SDP with the failure reason, the alternative approach selected, and proceeds (or aborts).

### 5.2 Establishing a Software Development Environment

#### 5.2.1 Software Engineering Environment

**Platform:** AWS CloudShell (`us-east-1`).

**Pre-installed tools:** AWS CLI v2, git, Python 3.x, Node.js (version varies — must verify ≥18 for Terraform CDK compatibility, though we use HCL directly).

**Required tools not pre-installed:**
- **Terraform:** Must be installed manually in CloudShell. CloudShell provides 1 GB persistent home directory storage. Terraform binary is ~80 MB.

**Installation procedure:**
```bash
# Install Terraform in CloudShell
TERRAFORM_VERSION="1.7.5"
curl -fsSL "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip" -o /tmp/terraform.zip
unzip -o /tmp/terraform.zip -d ~/bin
export PATH="$HOME/bin:$PATH"
echo 'export PATH="$HOME/bin:$PATH"' >> ~/.bashrc
terraform version
```

**Persistent storage:** CloudShell's `$HOME` directory (~1 GB) persists across sessions. The cloned repository, Terraform state, and tfvars file are stored here.

#### 5.2.2 Software Test Environment

The test environment is the deployed AWS infrastructure itself. There is no separate test environment.

#### 5.2.3 Software Development Library

The cloned `genai-idp-terraform` repository at `~/genai-idp-terraform/` serves as the development library. No version control beyond the upstream git repository is needed.

#### 5.2.4 Software Development Files

| File | Location | Purpose |
|------|----------|---------|
| PROCRV | `~/PROCRV.md` | Operating concept and constraints |
| SDP | `~/SDP.md` | This plan |
| terraform.tfvars | `~/genai-idp-terraform/terraform.tfvars` | Deployment configuration |
| Upstream repo | `~/genai-idp-terraform/` | All Terraform modules and source |

#### 5.2.5 Non-Deliverable Software

Not applicable. No software is delivered. The deployed infrastructure is ephemeral.

### 5.3 System Requirements Analysis

#### 5.3.1 Analysis of User Input

The sole user requirement is: "Evaluate whether `genai-idp-terraform` can provide a working document extraction workflow within the Vocareum account constraints." This requirement is documented in the PROCRV Section 4.1.

#### 5.3.2 Operational Concept

The operational concept is documented in the PROCRV Sections 5 and 6. This SDP does not duplicate it.

#### 5.3.3 System Requirements

The system requirements are the PROCRV's Section 5.3 (description of the new system) filtered through the constraint analysis of Sections 3.2 and 4.5.

Functional requirements:
1. Upload a document (PDF or image) through a web interface.
2. Configure extraction instructions (document classes, field definitions).
3. Process the document through OCR → classification → extraction → assessment.
4. Display structured extraction results in the web interface.

Non-functional requirements:
1. Total AWS cost ≤ $2.00.
2. No concurrency limit violations during normal operation.
3. Deploy and validate within one lab session (~4 hours).

### 5.4 System Design

#### 5.4.1 System-Wide Design Decisions

All system-wide design decisions are inherited from the upstream `genai-idp-terraform` repository with the following overrides:

| Decision | Upstream Default | POC Override | Rationale |
|----------|-----------------|--------------|-----------|
| WAF | Enabled | **Disabled** | $5/month — exceeds budget |
| KMS encryption | Customer-managed key | **Patch to SSE-S3 (AES256) if feasible; else accept $1/month** | $1/month = 50% of budget |
| Bedrock model | Varies | **Nova Lite (`us.amazon.nova-lite-v1:0`)** | Cheapest available |
| CloudWatch retention | 30+ days | **1 day** | Minimize ingestion cost |
| Data tracking retention | 90 days | **7 days** | Minimize storage |
| Optional features | Mixed | **All disabled** | Every feature is a cost/concurrency threat |
| CloudFront | Enabled | **Enabled if SCP permits; else fallback** | SCP may block `CreateDistribution` |

#### 5.4.2 System Architectural Design

The architecture is as described in PROCRV Section 5.3. No modifications to the architectural design beyond disabling optional components and substituting cheaper models.

### 5.5 Software Requirements Analysis

Not applicable. No new software requirements are defined. The upstream repository's functionality is accepted as-is.

### 5.6 Software Design

#### 5.6.1 CSCI-Wide Design Decisions

Not applicable. No CSCIs are developed.

#### 5.6.2 CSCI Architectural Design

Not applicable.

#### 5.6.3 CSCI Detailed Design

Not applicable.

### 5.7 Software Implementation and Unit Testing

#### 5.7.1 Software Implementation

Implementation consists of four work packages executed sequentially.

---

**WORK PACKAGE 0: SCP Constraint Testing**

*Objective:* Verify that critical AWS actions are permitted before committing budget to deployment.

*Procedure:*

**Test 0.1 — CloudFront CreateDistribution:**
```bash
# Test whether the SCP blocks CloudFront distribution creation.
# Use a dry-run approach: attempt to create a minimal distribution and expect
# either success (which we immediately delete) or an AccessDenied error.
aws cloudfront create-distribution \
  --distribution-config '{
    "CallerReference": "scp-test-'$(date +%s)'",
    "Origins": {
      "Quantity": 1,
      "Items": [
        {
          "Id": "test-origin",
          "DomainName": "example.com",
          "CustomOriginConfig": {
            "HTTPPort": 80,
            "HTTPSPort": 443,
            "OriginProtocolPolicy": "https-only"
          }
        }
      ]
    },
    "DefaultCacheBehavior": {
      "TargetOriginId": "test-origin",
      "ViewerProtocolPolicy": "redirect-to-https",
      "ForwardedValues": { "QueryString": false, "Cookies": { "Forward": "none" } },
      "MinTTL": 0
    },
    "Comment": "SCP test - delete immediately",
    "Enabled": false
  }' 2>&1
# If AccessDenied → CloudFront is blocked. Record result and plan fallback.
# If success → immediately delete the distribution. CloudFront is available.
```

**Decision tree for Test 0.1:**
- **CloudFront PERMITTED:** Proceed with the upstream `web-ui` module as-is (with WAF disabled). The web UI will be served via CloudFront.
- **CloudFront BLOCKED:** Activate Fallback Plan A — run the React app locally against the deployed AppSync API. Skip the `web-ui` Terraform module entirely by setting `web_ui = { enabled = false }` in tfvars. The evaluator runs `npm start` locally with Cognito/AppSync endpoints configured as environment variables.

**Test 0.2 — Lambda Function Creation:**
```bash
# Create a minimal Lambda function to test if function creation is permitted
# and to clarify the "Lambda Limit 3" meaning.
aws lambda create-function \
  --function-name scp-test-lambda-1 \
  --runtime python3.12 \
  --role "arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/vocuser" \
  --handler index.handler \
  --zip-file fileb://<(python3 -c "
import zipfile, io
buf = io.BytesIO()
with zipfile.ZipFile(buf, 'w') as zf:
    zf.writestr('index.py', 'def handler(e,c): return {\"ok\":True}')
buf.seek(0)
import sys; sys.stdout.buffer.write(buf.read())
") 2>&1

# If successful, try creating 2 more to test if "3" is a total function limit.
# Then delete all test functions immediately.
aws lambda delete-function --function-name scp-test-lambda-1 2>/dev/null
```

**Decision tree for Test 0.2:**
- **Lambda creation permitted AND limit appears to be concurrency (not count):** Proceed with deployment. The Step Functions pipeline processes documents sequentially, so concurrent Lambda executions stay ≤3.
- **Lambda creation limited to 3 total functions:** **STOP.** The deployment requires ~18 Lambda functions. This is a hard blocker. Record the finding and abort deployment. Alternative: investigate consolidating the pipeline into fewer functions (significant re-architecture, not planned in this POC).

**Test 0.3 — Bedrock Model Access:**
```bash
# Verify Nova Lite model is accessible
aws bedrock invoke-model \
  --model-id us.amazon.nova-lite-v1:0 \
  --content-type application/json \
  --accept application/json \
  --body '{"inputText":"Hello","textGenerationConfig":{"maxTokenCount":10}}' \
  /dev/stdout 2>&1 | head -c 500
# If AccessDeniedException → model access not enabled. Enable it via Bedrock console.
# If success → model is available. Note token consumption against limits.
```

**Test 0.4 — KMS Key Creation Cost Check:**
```bash
# Check if any KMS keys already exist (Vocareum might pre-provision some)
aws kms list-keys --query 'Keys[].KeyId' --output text
# If keys exist, they may already be incurring cost. Note for budget tracking.
```

---

**WORK PACKAGE 1: Repository Acquisition and Patching**

*Prerequisite:* Phase 0 tests pass (or fallbacks are activated).

*Step 1.1 — Clone the repository:*
```bash
cd ~
git clone https://github.com/awslabs/genai-idp-terraform.git
cd genai-idp-terraform
```

*Step 1.2 — Patch WAF default:*

File: `modules/web-ui/variables.tf`

Find the `enable_waf` variable and change its default from `true` to `false`:
```hcl
# Before:
variable "enable_waf" {
  type    = bool
  default = true
}

# After:
variable "enable_waf" {
  type    = bool
  default = false
}
```

Rationale: WAFv2 Web ACL costs $5/month base. This is 2.5× the total budget.

*Step 1.3 — Patch KMS (if cost reduction is chosen over acceptance):*

Locate all S3 bucket resources that reference a KMS key for server-side encryption. Replace `aws:kms` with `AES256` and remove the `kms_master_key_id` reference. This requires identifying:
- `modules/*/main.tf` or `modules/*/s3.tf` files that define `aws_s3_bucket_server_side_encryption_configuration` resources.
- Any references to `aws_kms_key` resources.

**Caution:** This is "significant module surgery" (PROCRV Appendix B). If the patches are too complex or risk breaking the deployment, accept the $1/month KMS cost and proceed. The budget allows ~2 months of operation with KMS — but the plan is to deploy, test, and destroy within hours, so the prorated KMS cost may be negligible ($1/month ÷ 730 hours = $0.00137/hour).

**Decision:** Accept the KMS cost. The system will be deployed for <1 hour. Prorated cost: <$0.01. This is within budget. Do not patch KMS.

*Step 1.4 — Write `terraform.tfvars`:*

Create `~/genai-idp-terraform/terraform.tfvars` with the content specified in PROCRV Appendix B:

```hcl
region = "us-east-1"
prefix = "poc-idp"

admin_email = "<evaluator-email>"

classification_model_id = "us.amazon.nova-lite-v1:0"
extraction_model_id     = "us.amazon.nova-lite-v1:0"
summarization_enabled   = false

log_retention_days           = 1
data_tracking_retention_days = 7

enable_evaluation = false
enable_reporting  = false

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

web_ui = {
  enabled = true
}

tags = {
  Environment = "poc"
  Project     = "idp-poc"
}
```

**Note:** Replace `<evaluator-email>` with the actual email address. If Phase 0 determined CloudFront is blocked, set `web_ui = { enabled = false }`.

*Step 1.5 — Review `terraform plan`:*
```bash
cd ~/genai-idp-terraform
terraform init
terraform plan -out=plan.tfplan 2>&1 | tee ~/plan-output.txt
```

Review the plan output for:
- Any `aws_cloudfront_distribution` resources (should be present if CloudFront is permitted; absent if `web_ui` is disabled).
- Any `aws_wafv2_web_acl` resources (should be absent — WAF is disabled).
- Count of `aws_lambda_function` resources (note the count for comparison against the Lambda limit).
- Any `aws_kms_key` resources (note for cost tracking).
- Any resources in regions other than `us-east-1` (should be none).
- Any EC2, EKS, SageMaker, or RDS resources (should be none).

**Go/no-go:** If the plan shows SCP-incompatible resources or unexpected costs, do not apply. Return to patching.

---

**WORK PACKAGE 2: Deployment**

*Prerequisite:* `terraform plan` output reviewed and approved.

```bash
cd ~/genai-idp-terraform
terraform apply plan.tfplan 2>&1 | tee ~/apply-output.txt
```

**Expected duration:** 15–25 minutes. The longest operations are:
- CodeBuild: Lambda layer build (~2–5 min).
- CodeBuild: React web app build (~3–5 min).
- CloudFront distribution provisioning (~5–10 min, if enabled).
- Cognito User Pool and Identity Pool creation (~1 min).

**Monitoring during apply:**
- Watch for `AccessDeniedException` or `AccessDenied` errors in the output — these indicate SCP blocks.
- Watch for rate-limiting or throttling errors — these indicate concurrency limit proximity.
- If the apply fails partway, run `terraform destroy` immediately to clean up partial resources before they accrue cost.

**Post-apply outputs:** Capture the following from Terraform outputs:
- CloudFront URL (or S3 website URL) — the web UI endpoint.
- Cognito User Pool ID and App Client ID — for authentication.
- AppSync API URL — for GraphQL queries.
- S3 bucket names — for document storage.

---

**WORK PACKAGE 3: Validation**

*Prerequisite:* `terraform apply` completed successfully.

**Validation Test 1 — Web UI Access:**
1. Open the CloudFront URL (or S3 website URL) in a browser.
2. Verify the React SPA loads.
3. Verify the Cognito login screen appears.

**Validation Test 2 — User Registration:**
1. Register a new user with the evaluator's email address.
2. Check email for the Cognito verification code.
3. Complete registration and log in.
4. Verify the IDP dashboard loads.

**Validation Test 3 — Extraction Configuration:**
1. Navigate to the configuration section.
2. Define a document class (e.g., "Invoice").
3. Define extraction fields:
   - `vendor_name` (string)
   - `invoice_number` (string)
   - `total_amount` (number)
   - `invoice_date` (date)
4. Save the configuration.

**Validation Test 4 — Document Processing:**
1. Prepare a test document: a single-page invoice image (PNG or JPEG) or a 1-page PDF. Use a simple, clearly formatted document with the fields defined above.
2. Upload the document through the web UI.
3. Monitor the document status as it progresses through: Uploaded → OCR → Classification → Extraction → Assessment → Complete.
4. Verify structured extraction results appear in the UI.
5. Verify the extracted field values are reasonable (correct vendor name, invoice number, etc.).

**Validation Test 5 — Budget Check:**
```bash
# Check current account spend (if Cost Explorer is available)
aws ce get-cost-and-usage \
  --time-period Start=$(date +%Y-%m-01),End=$(date +%Y-%m-%d) \
  --granularity DAILY \
  --metrics BlendedCost 2>&1
```

**Pass criteria:** All five tests pass. The system is validated.

**Fail criteria:** Any test fails. Record the failure, check CloudWatch Logs (1-day retention) for diagnostics, and determine if a fix is possible within the remaining budget. If not, proceed directly to teardown.

---

**WORK PACKAGE 4: Teardown**

*Execute unconditionally after validation (pass or fail).*

```bash
cd ~/genai-idp-terraform
terraform destroy -auto-approve 2>&1 | tee ~/destroy-output.txt
```

**Post-teardown verification:**
```bash
# Verify no Lambda functions remain
aws lambda list-functions --query 'Functions[].FunctionName' --output text

# Verify no S3 buckets remain (beyond any Vocareum-managed ones)
aws s3 ls

# Verify no KMS keys remain in active state
aws kms list-keys --query 'Keys[].KeyId' --output text
```

**Note:** KMS keys enter a 7-day deletion pending window after `terraform destroy`. They are not immediately deleted but stop incurring charges once scheduled for deletion. Verify the key is in `PendingDeletion` state:
```bash
aws kms describe-key --key-id <key-id> --query 'KeyMetadata.KeyState' --output text
# Expected: "PendingDeletion"
```

#### 5.7.2 Preparing for Unit Testing

Not applicable. No units are developed.

#### 5.7.3 Performing Unit Testing

Not applicable.

#### 5.7.4 Revision and Retesting

If `terraform apply` fails due to an SCP denial or resource constraint:
1. Run `terraform destroy` to clean up partial resources.
2. Identify the blocking resource from the error message.
3. Patch the relevant module to remove or modify the resource.
4. Re-run `terraform plan` and review.
5. Re-run `terraform apply`.

Each retry consumes time and may consume budget. Limit retries to 2 attempts before aborting.

#### 5.7.5 Analyzing and Recording Unit Test Results

Not applicable.

### 5.8 Unit Integration and Testing

Not applicable. No units are developed or integrated.

### 5.9 CSCI Qualification Testing

Not applicable.

### 5.10 CSCI/HWCI Integration and Testing

Not applicable.

### 5.11 System Qualification Testing

System qualification is the Phase 3 validation (Work Package 3 in Section 5.7.1). The system is qualified if:
1. The web UI loads and is accessible.
2. A user can register and log in via Cognito.
3. An extraction configuration can be saved.
4. A document can be uploaded, processed, and extraction results displayed.
5. Total cost remains ≤ $2.00.

### 5.12 Preparing for Software Use

#### 5.12.1 Preparing the Executable Software

The executable software is the deployed AWS infrastructure. No separate executable is prepared.

#### 5.12.2 Preparing Version Descriptions for User Sites

Not applicable.

#### 5.12.3 Preparing User Manuals

Not applicable. The upstream repository's documentation serves as the user manual.

#### 5.12.4 Installation at User Sites

Installation is `terraform apply` as described in Work Package 2.

### 5.13 Preparing for Software Transition

Not applicable. The system is destroyed after evaluation. There is no transition.

### 5.14 Software Configuration Management

#### 5.14.1 Configuration Identification

Configuration items:

| Item | Identifier | Location |
|------|-----------|----------|
| Upstream repository | git commit SHA at clone time | `~/genai-idp-terraform/.git` |
| WAF patch | Diff of `modules/web-ui/variables.tf` | In-repo modification |
| terraform.tfvars | PROCRV Appendix B | `~/genai-idp-terraform/terraform.tfvars` |
| Terraform state | `terraform.tfstate` | `~/genai-idp-terraform/terraform.tfstate` |
| PROCRV | v1.0 | `~/PROCRV.md` |
| SDP | v1.0 | `~/SDP.md` |

#### 5.14.2 Configuration Control

No formal change control. The evaluator is the sole developer. Changes to the upstream repository patches are recorded as git commits in the local clone.

#### 5.14.3 Configuration Status Accounting

The evaluator records:
- The git commit SHA of the upstream repository at clone time.
- All patches applied (as local git commits or as documented diffs).
- The `terraform.tfvars` content.
- The results of Phase 0 SCP tests.
- The `terraform plan` output.
- The `terraform apply` output.
- The validation test results.

#### 5.14.4 Configuration Audits

Not applicable.

#### 5.14.5 Packaging, Storage, Handling, and Delivery

Not applicable. No software is delivered.

### 5.15 Software Product Evaluation

#### 5.15.1 In-Process and Final Software Product Evaluations

The final evaluation is the Phase 3 validation. The evaluation criteria are:

| Criterion | Measure | Threshold |
|-----------|---------|-----------|
| Functional completeness | All 4 workflow steps complete | Upload + Configure + Process + View |
| Cost compliance | Total AWS spend | ≤ $2.00 |
| Constraint compliance | No session terminations during validation | 0 terminations |
| Time compliance | Total deployment-to-teardown time | ≤ 4 hours |

#### 5.15.2 Software Product Evaluation Records

The evaluator captures:
- Terminal output from all `terraform` and `aws` commands (via `tee` to log files).
- Screenshots of the web UI at each validation step (optional but recommended).
- The final cost report from AWS Cost Explorer (if available).

#### 5.15.3 Independence in Software Product Evaluation

Not applicable. Single-person project.

### 5.16 Software Quality Assurance

#### 5.16.1 Software Quality Assurance Evaluations

Quality assurance for this POC consists of:
1. Reviewing `terraform plan` output before applying.
2. Monitoring `terraform apply` for errors.
3. Executing all Phase 3 validation tests.
4. Confirming teardown completes successfully.

#### 5.16.2 Software Quality Assurance Records

All terminal output is logged to `~/plan-output.txt`, `~/apply-output.txt`, and `~/destroy-output.txt`.

#### 5.16.3 Independence in Software Quality Assurance

Not applicable. Single-person project.

### 5.17 Corrective Action

#### 5.17.1 Problem/Change Reports

Problems encountered during deployment are recorded informally in notes. The following information is captured for each problem:
- Error message (from Terraform or AWS CLI).
- Root cause (SCP denial, concurrency limit, missing configuration, etc.).
- Resolution (patch, configuration change, fallback activation, or abort).
- Budget impact (if any).

#### 5.17.2 Corrective Action System

The corrective action system is the evaluator's judgment applied to the PROCRV's theory of programming. When a problem occurs:
1. Identify whether it is a cost issue, a concurrency issue, or an SCP issue.
2. Apply the relevant principle from PROCRV Section 8.
3. Implement the cheapest fix that works.
4. If no fix is possible within budget, abort and record the finding.

### 5.18 Joint Technical and Management Reviews

Not applicable. Single-person project.

### 5.19 Other Software Development Activities

#### 5.19.1 Risk Management

| # | Risk | Likelihood | Impact | Strategy | Trigger |
|---|------|------------|--------|----------|---------|
| R1 | CloudFront `CreateDistribution` blocked by SCP | High | Critical — no web UI | **Mitigate:** Test in Phase 0. Fallback: run React locally or use S3 website hosting | Phase 0 Test 0.1 fails |
| R2 | Lambda limit means total function count (not concurrency) | Medium | Critical — deployment blocked | **Mitigate:** Test in Phase 0. Fallback: abort POC or consolidate functions | Phase 0 Test 0.2 shows limit is on count |
| R3 | Bedrock token limit is per-session lifetime | Medium | High — limits testing to 1–2 documents | **Accept:** Test with smallest possible documents. One successful extraction validates the POC | Bedrock call fails with token limit error |
| R4 | KMS key cost exceeds acceptable fraction of budget | Low (accepted) | Medium — $1/month but system runs <1 hour | **Accept:** Prorated cost is <$0.01. Do not patch | Budget check shows unexpected charge |
| R5 | `terraform apply` fails partway, leaving orphaned resources | Medium | Medium — orphaned resources cost money | **Mitigate:** Run `terraform destroy` immediately on failure. Verify cleanup manually | Apply fails with error |
| R6 | Session termination destroys Terraform state | Medium | Medium — must redeploy from scratch | **Accept:** CloudShell home directory persists across sessions. State file survives unless session termination wipes storage | Session terminates during operation |
| R7 | CodeBuild times out or fails | Low | Medium — Lambda layer and web app not built | **Mitigate:** Check CodeBuild logs. Retry once. If second failure, abort | CodeBuild build fails |
| R8 | Cognito email delivery fails (SES blocked) | Medium | Low — can manually confirm user via CLI | **Mitigate:** If email not received, confirm user via `aws cognito-idp admin-confirm-sign-up` | No verification email after 5 min |

#### 5.19.2 Software Management Indicators

| Indicator | Measurement | Target |
|-----------|-------------|--------|
| Cumulative AWS cost | AWS Cost Explorer or billing dashboard | ≤ $2.00 |
| Terraform apply duration | Wall clock time | ≤ 25 minutes |
| Validation test pass rate | Tests passed / Tests attempted | 5/5 |
| Deployment attempts | Count of `terraform apply` runs | ≤ 2 |

#### 5.19.3 Security and Privacy

See Section 4.2.4. No additional security or privacy measures beyond Cognito authentication and S3 encryption.

#### 5.19.4 Subcontractor Management

Not applicable.

#### 5.19.5 Interface with Software IV&V Agents

Not applicable.

#### 5.19.6 Coordination with Associate Developers

Not applicable.

#### 5.19.7 Improvement of Project Processes

Not applicable. Single-iteration POC.

#### 5.19.8 Other Activities

**Fallback Plan A — Local React Development Server (if CloudFront is blocked):**

If Phase 0 determines CloudFront `CreateDistribution` is blocked by SCP:

1. Set `web_ui = { enabled = false }` in `terraform.tfvars`.
2. Deploy backend only (`terraform apply` — skips CloudFront, WAF, and web app S3 bucket).
3. After deployment, extract Cognito and AppSync configuration from Terraform outputs.
4. Clone or copy the React web app source from the repository.
5. Configure the React app's environment to point at the deployed Cognito User Pool and AppSync API endpoint.
6. Run `npm install && npm start` locally (or in CloudShell if a port-forwarding mechanism is available).
7. Access the web UI at `localhost:3000`.

**Limitations of Fallback Plan A:**
- CloudShell does not expose localhost ports to the browser. The evaluator must either: (a) run the React app on a local machine with AWS credentials, or (b) use CloudShell's web preview if available.
- CORS configuration on AppSync and Cognito must allow the localhost origin.

**Fallback Plan B — S3 Static Website Hosting (if CloudFront is blocked):**

1. Create an S3 bucket with static website hosting enabled.
2. Build the React app and upload the built assets to the bucket.
3. Configure the bucket policy for public read access (or use pre-signed URLs).
4. Access the web UI at the S3 website endpoint.

**Limitations of Fallback Plan B:**
- S3 website hosting does not support HTTPS (HTTP only). Cognito and AppSync require HTTPS origins for CORS.
- This fallback may not work without additional API Gateway or Lambda@Edge configuration.
- **Recommendation:** Prefer Fallback Plan A over Plan B.

---

## 6. Schedules and Activity Network

### 6.1 Activity Sequence

```
Phase 0: Constraint Testing ──────────────────────► GO/NO-GO GATE 0
  │ Test 0.1: CloudFront SCP                         │
  │ Test 0.2: Lambda limit                            │
  │ Test 0.3: Bedrock model access                    │
  │ Test 0.4: KMS key check                           │
  │                                                   │
  ▼                                                   ▼
Phase 1: Acquire & Patch ─────────────────────────► GO/NO-GO GATE 1
  │ Step 1.1: Clone repo                              │
  │ Step 1.2: Patch WAF                               │
  │ Step 1.3: KMS decision (accept cost)              │
  │ Step 1.4: Write terraform.tfvars                  │
  │ Step 1.5: terraform plan review                   │
  │                                                   │
  ▼                                                   ▼
Phase 2: Deploy ──────────────────────────────────► GO/NO-GO GATE 2
  │ terraform apply                                   │
  │                                                   │
  ▼                                                   ▼
Phase 3: Validate ────────────────────────────────► RECORD RESULTS
  │ Test 1: Web UI access                             │
  │ Test 2: User registration                         │
  │ Test 3: Extraction config                         │
  │ Test 4: Document processing                       │
  │ Test 5: Budget check                              │
  │                                                   │
  ▼                                                   ▼
Phase 4: Teardown ────────────────────────────────► DONE
  │ terraform destroy                                 │
  │ Post-teardown verification                        │
```

### 6.2 Time Estimates

| Phase | Estimated Duration | Cumulative |
|-------|--------------------|------------|
| Phase 0 | 10 min | 10 min |
| Phase 1 | 15 min | 25 min |
| Phase 2 | 15–25 min | 40–50 min |
| Phase 3 | 20–30 min | 60–80 min |
| Phase 4 | 5–10 min | 65–90 min |
| **Total** | **65–90 min** | |

Buffer for troubleshooting: 90 min. **Total session time required: ~3 hours** (within the 4-hour lab session limit).

---

## 7. Project Organization and Resources

### 7.1 Project Organization

One person: the POC evaluator. Roles held simultaneously:
- Project manager
- Developer
- Tester
- Operator
- Support

No organizational hierarchy. No reporting relationships. No external dependencies.

### 7.2 Project Resources

**Personnel:** 1 person, ~3 hours.

**Facilities:** AWS CloudShell (web-based terminal in `us-east-1`).

**Equipment:**
- Web browser (Chrome, Firefox, or Edge) for CloudShell access and web UI validation.
- Internet connection for CloudShell and browser access.

**AWS resources (budget: $2.00):**

| Service | Estimated Cost | Free Tier? |
|---------|---------------|------------|
| Lambda | $0.00 | Yes (1M requests/month) |
| DynamoDB | $0.00 | Yes (25 GB, 25 RCU/WCU) |
| S3 | $0.00 | Yes (5 GB, first year) |
| Cognito | $0.00 | Yes (50K MAU) |
| AppSync | $0.00 | Yes (250K queries/month) |
| Step Functions | $0.00 | Yes (4K transitions/month) |
| Textract | $0.00 | Yes (first 1K pages/month) |
| Bedrock (Nova Lite) | ~$0.01 | No (pay-per-token) |
| CloudFront | $0.00 | Yes (1 TB transfer/month) |
| KMS | ~$0.01 (prorated) | No ($1/month per key) |
| CloudWatch Logs | ~$0.01 | Partial |
| CodeBuild | $0.00 | Yes (100 min/month) |
| EventBridge | $0.00 | Yes |
| SQS | $0.00 | Yes (1M requests/month) |
| **Total estimated** | **~$0.03** | |

**Required acquirer-furnished items:** None. All resources are provisioned by Terraform within the Vocareum account.

---

## Appendix: Execution Checklist

This checklist is the operational condensation of the SDP. Execute in order.

```
[ ] PHASE 0: CONSTRAINT TESTING
    [ ] Install Terraform in CloudShell
    [ ] Test 0.1: CloudFront CreateDistribution → PERMITTED / BLOCKED
    [ ] Test 0.2: Lambda function creation → COUNT LIMIT / CONCURRENCY LIMIT
    [ ] Test 0.3: Bedrock Nova Lite access → AVAILABLE / UNAVAILABLE
    [ ] Test 0.4: Existing KMS keys → COUNT: ___
    [ ] GO/NO-GO decision recorded

[ ] PHASE 1: ACQUIRE AND PATCH
    [ ] Clone genai-idp-terraform repository
    [ ] Record upstream git commit SHA: _______________
    [ ] Patch modules/web-ui/variables.tf (WAF default → false)
    [ ] Write terraform.tfvars (from PROCRV Appendix B)
    [ ] Set actual admin_email in terraform.tfvars
    [ ] If CloudFront blocked: set web_ui.enabled = false
    [ ] terraform init — success
    [ ] terraform plan — review output
    [ ] Count Lambda functions in plan: ___
    [ ] Count KMS keys in plan: ___
    [ ] Confirm no WAF resources in plan
    [ ] Confirm no SCP-incompatible resources
    [ ] GO/NO-GO decision recorded

[ ] PHASE 2: DEPLOY
    [ ] terraform apply — success
    [ ] Record CloudFront/Web URL: _______________
    [ ] Record Cognito User Pool ID: _______________
    [ ] Record AppSync API URL: _______________
    [ ] Apply duration: ___ minutes

[ ] PHASE 3: VALIDATE
    [ ] Test 1: Web UI loads in browser — PASS / FAIL
    [ ] Test 2: Cognito registration + login — PASS / FAIL
    [ ] Test 3: Extraction config saved — PASS / FAIL
    [ ] Test 4: Document uploaded + processed + results displayed — PASS / FAIL
    [ ] Test 5: Budget check — current spend: $___
    [ ] Overall validation: PASS / FAIL

[ ] PHASE 4: TEARDOWN
    [ ] terraform destroy — success
    [ ] Verify no Lambda functions remain
    [ ] Verify no unexpected S3 buckets remain
    [ ] Verify KMS key in PendingDeletion state
    [ ] Final budget check: $___
    [ ] DONE
```
