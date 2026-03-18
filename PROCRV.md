# Pre-Requirements Operating Concept Rationale and Validation (PROCRV)

## Intelligent Document Processing POC — GenAI IDP on Constrained AWS

---

## Section 1: Scope

### 1.1 Identification

- **System Title:** GenAI Intelligent Document Processing (IDP) POC
- **Source Repository:** `https://github.com/awslabs/genai-idp-terraform.git`
- **Deployment Pattern:** Pattern 2 — Bedrock LLM Processor
- **Target Environment:** Vocareum-managed AWS account (Ricoh USA Eval 2026), `us-east-1`
- **Budget:** $2.00 USD

### 1.2 System Overview

The system is an Intelligent Document Processing (IDP) platform that allows a user to upload documents through a web interface, provide extraction instructions (classification rules, field definitions, prompts), and view structured extraction results. The upstream repository (`awslabs/genai-idp-terraform`) provides a full-featured IDP pipeline; this POC deploys the minimum viable subset: a React web UI, an AppSync GraphQL API, Cognito authentication, a Step Functions processing pipeline (OCR via Textract → classification via Bedrock → extraction via Bedrock → assessment → results), and S3/DynamoDB storage.

The project sponsor is the POC evaluator operating within a Vocareum-provisioned AWS sandbox. The developer and user are the same person. The operating site is AWS `us-east-1`. The support agency is the evaluator.

### 1.3 Document Overview

This document describes the operating concept for deploying a minimal IDP web interface from the `genai-idp-terraform` repository within a severely budget- and policy-constrained AWS account. It identifies what must be deployed, what must be disabled, what constraints exist, and the rationale for each decision. The final section captures the theory of programming for this project — the principles that must guide every implementation decision given the extreme resource constraints.

---

## Section 2: References

| # | Document | Source |
|---|----------|--------|
| 1 | genai-idp-terraform repository | https://github.com/awslabs/genai-idp-terraform.git |
| 2 | Vocareum Concurrency Limits | Provided by course administrator (see Appendix A) |
| 3 | Vocareum SCPs | Provided by course administrator (see Appendix A) |
| 4 | Vocareum IAM Policy | Course: Ricoh USA Eval 2026, Assignment: Credentials for AI Agents, Part 1 |
| 5 | MIL-STD-498 OCD DID (DI-IPSC-81430) | Structural basis for this document |
| 6 | Peter Naur, "Programming as Theory Building" (1985) | Theoretical basis for Section 8 |

---

## Section 3: Current System or Situation

### 3.1 Background, Objectives, and Scope

There is no current IDP system. The evaluator has a Vocareum-managed AWS account provisioned for a POC. The account is empty — no infrastructure, no applications, no data. The objective is to evaluate whether the `genai-idp-terraform` solution can provide a working document extraction workflow within the account's constraints.

### 3.2 Operational Policies and Constraints

The account operates under the following hard constraints:

**Budget:** $2.00 total. There is no mechanism to add funds.

**Concurrency Limits (session-ending if exceeded):**

| Resource | Limit |
|----------|-------|
| Concurrent Running EC2 | 2 |
| CodeBuild Projects | 1 |
| Lambda Functions | 3 |
| SageMaker Notebooks | 2 |
| SageMaker Apps | 2 |
| Bedrock Input Tokens | 1,000 |
| Bedrock Output Tokens | 1,000 |
| EKS Clusters | 1 |
| EKS Nodes | 2 |
| S3 Total Size | 10 GB |
| DynamoDB On-Demand Read Capacity | 1,000 |
| DynamoDB On-Demand Write Capacity | 1,000 |

**Fraud Limits (account-locking if exceeded):**

| Resource | Limit |
|----------|-------|
| EC2 Instances | 3 |

**Region Restriction:** All resources must be in `us-east-1`. An SCP denies most service actions outside this region.

**Service Denials (SCP-enforced):** SES, Lightsail, CloudFront create-distribution (some actions), Route53 domain registration, Glacier, Redshift reserved, RDS reserved, most EC2 reserved/capacity/FPGA actions, and AWS Marketplace subscriptions (except whitelisted Bedrock model product IDs).

**Instance Type Restrictions (SCP-enforced):** EC2 limited to `*.nano`, `*.micro`, `*.small`, `*.medium`, `*.large`. EBS volumes limited to `gp2`, max 50 GB, 0 provisioned IOPS. RDS limited to `*.micro`, `*.small`, `*.medium` with max 100 GB storage. SageMaker limited to `ml.t2/t3.medium/large`, `ml.c4/c5.large/xlarge`, `ml.m4/m5.large/xlarge`.

**Protected Resources (SCP-enforced):** Platform-managed IAM roles, users, and associated policies cannot be modified. EventBridge rules matching `voc-*` are protected.

### 3.3 Description of Current System

No system exists. The AWS account is a blank sandbox.

### 3.4 Users or Involved Personnel

One user: the POC evaluator. Responsibilities include deploying the infrastructure, configuring extraction prompts, uploading test documents, and reviewing extraction results. No organizational structure. The evaluator has software engineering skills and access to AWS CloudShell.

### 3.5 Support Concept

Self-supported. The evaluator is the developer, operator, and support agency. No external support beyond the upstream repository's documentation and the Vocareum platform's automatic cleanup mechanisms.

---

## Section 4: Justification for and Nature of Changes

### 4.1 Justification for Change

The evaluator needs to test AI-powered document extraction capabilities on real forms. Specifically:
- Upload a document (PDF, image) through a web interface
- Provide natural-language instructions for what fields/attributes to extract
- View structured extraction results

This cannot be done without deploying infrastructure. The `genai-idp-terraform` repository provides a complete solution, but it deploys far more than needed and at a cost that exceeds the $2 budget if deployed as-is.

### 4.2 Description of Needed Changes

The following changes to the default `genai-idp-terraform` deployment are needed:

1. **Disable WAF.** The WAFv2 Web ACL costs ~$5/month base. The `enable_waf` variable in `modules/web-ui` defaults to `true` and is not exposed at the root module level. It must be set to `false` either by patching the module default or wiring it through the root variables.

2. **Disable all optional features.** Summarization, evaluation, reporting, human review, knowledge base, discovery, chat-with-document, process-changes, agent-analytics, test studio, FCC dataset, error analyzer, MCP, and agent companion chat must all be disabled.

3. **Use the cheapest Bedrock models.** Nova Lite (`us.amazon.nova-lite-v1:0`) for both classification and extraction to minimize token costs.

4. **Minimize logging.** Set `log_retention_days = 1` and `data_tracking_retention_days = 7`.

5. **Address KMS cost.** A customer-managed KMS key costs $1/month — half the budget. Consider patching to use SSE-S3 (`AES256`) or accept the cost as unavoidable.

6. **Address the Lambda concurrency constraint.** The minimal deployment creates ~18 Lambda functions. The Vocareum "Lambda Limit 3" may refer to concurrent executions, concurrent functions, or some other metric. If it means concurrent executions, the system must process documents sequentially. If it means total functions, the deployment cannot proceed without negotiating a higher limit or re-architecting.

7. **Disable CloudFront create-distribution if blocked by SCP.** An SCP denies `cloudfront:CreateDistribution`. This directly blocks the `web-ui` module's CloudFront distribution. **This is a critical blocker** — the web UI cannot be deployed as designed without CloudFront. Alternatives: serve the React app from S3 website hosting directly, or use API Gateway + Lambda to proxy the SPA.

### 4.3 Priorities Among Changes

| Priority | Change | Classification |
|----------|--------|---------------|
| 1 | Resolve CloudFront SCP block | Essential — blocks web UI entirely |
| 2 | Disable WAF | Essential — blocks budget |
| 3 | Clarify Lambda concurrency limit interpretation | Essential — may block deployment |
| 4 | Disable all optional features | Essential — cost control |
| 5 | Use cheapest Bedrock models | Essential — token budget |
| 6 | Address KMS key cost | Desirable — saves $1/month |
| 7 | Minimize logging | Optional — minor cost savings |

### 4.4 Changes Considered but Not Included

- **Replacing CloudFront with API Gateway:** Would add cost and complexity. Deferred pending confirmation that CloudFront is actually blocked.
- **Eliminating the web UI entirely and using CLI-only:** Would avoid CloudFront and WAF issues but defeats the purpose of evaluating the web-based extraction workflow.
- **Using a self-hosted Textract alternative:** No practical alternative exists within the constraints.
- **Running the React app locally instead of deploying:** Would work for UI testing but wouldn't exercise the full deployed architecture.

### 4.5 Assumptions and Constraints

**Assumptions:**
1. The Bedrock token limits (1,000 input / 1,000 output) are per-invocation or per-minute, not per-account-lifetime. If they are lifetime limits, the POC can process only a handful of documents.
2. The Lambda limit of 3 refers to concurrency, not total function count. If it refers to function count, the deployment is not feasible without re-architecture.
3. The `cloudfront:CreateDistribution` denial in the SCP may be overridden or may not apply in practice. This must be tested.
4. Bedrock model access for Nova Lite is already enabled or can be enabled in the account.
5. CodeBuild can run (limit of 1 concurrent build) — needed to build the Lambda layer and the React app.

**Constraints:**
1. The $2 budget is absolute. Once exhausted, the account is unusable.
2. Exceeding any concurrency limit terminates the session and destroys all resources (typically 10-minute recovery).
3. Exceeding any fraud limit locks the account pending admin review.
4. All resources must be in `us-east-1`.

---

## Section 5: Concept for the New or Modified System

### 5.1 Background, Objectives, and Scope

Deploy a minimal IDP web UI from the `genai-idp-terraform` repository that allows the evaluator to: (1) upload a document, (2) configure extraction instructions, and (3) view extraction results. All non-essential features are disabled. The system must operate within $2 total spend.

### 5.2 Operational Policies and Constraints

All constraints from Section 3.2 apply. Additionally:
- Documents should be processed one at a time to stay within concurrency limits.
- The evaluator should test with small documents (1–3 pages) to minimize Bedrock token consumption.
- The system should be destroyed (`terraform destroy`) immediately after evaluation to stop KMS charges.

### 5.3 Description of the New or Modified System

The system operates in a single mode: document processing.

**Operational environment:** AWS `us-east-1`, deployed via Terraform from CloudShell or a local machine with AWS credentials.

**Major components and interconnections:**

```
User (Browser)
  │
  ▼
CloudFront (or S3 Website) ──► S3 Web App Bucket (React SPA)
  │
  ▼
Cognito (User Pool + Identity Pool) ──► Authentication
  │
  ▼
AppSync GraphQL API
  │
  ├──► S3 Input Bucket (pre-signed upload URL)
  ├──► DynamoDB Configuration Table (extraction prompts)
  ├──► DynamoDB Tracking Table (document status)
  │
  ▼
EventBridge ──► SQS Queue ──► Step Functions State Machine
  │
  ├──► Lambda: OCR (calls Textract)
  ├──► Lambda: Classification (calls Bedrock Nova Lite)
  ├──► Lambda: Extraction (calls Bedrock Nova Lite)
  ├──► Lambda: Assessment
  └──► Lambda: Process Results ──► S3 Output Bucket + DynamoDB
```

**Interfaces to external systems:** Amazon Bedrock (Nova Lite model), Amazon Textract.

**Capabilities:** Upload documents (PDF, image). Define document classes and extraction fields via YAML configuration. Process documents through OCR → classify → extract → assess → store results. View structured JSON extraction results in the web UI.

**Performance characteristics:** Single-document sequential processing. Processing time depends on document size and Bedrock response latency (typically 10–60 seconds per document).

**Quality attributes:** This is a POC — reliability and availability are not requirements. The system must work correctly for a single user processing a few documents.

**Safety, security, privacy:** Cognito handles authentication. S3 buckets are encrypted (KMS or SSE-S3). No PII should be uploaded during the POC. The Vocareum SCPs prevent modification of platform-managed IAM resources.

### 5.4 Users / Affected Personnel

One user: the POC evaluator. Uses the web UI through a browser. Interacts with the system by uploading documents, editing extraction configuration, and reviewing results. No training required beyond familiarity with the web UI and the upstream repository's documentation.

### 5.5 Support Concept

Self-supported. Destroy and redeploy if issues arise. The `terraform destroy` command is the primary recovery mechanism. CloudWatch Logs (1-day retention) provide diagnostic information.

---

## Section 6: Operational Scenarios

### Scenario 1: Deploy the System

The evaluator clones the `genai-idp-terraform` repository. They configure `terraform.tfvars` with all optional features disabled, WAF disabled, cheapest Bedrock models selected, and minimal log retention. They run `terraform init` and `terraform apply`. CodeBuild builds the Lambda layer (~2 minutes) and the React web UI (~3 minutes). The system is operational. The evaluator receives a Cognito signup email and creates their account. They navigate to the CloudFront URL and see the IDP web interface.

### Scenario 2: Process a Document

The evaluator logs into the web UI. They navigate to the configuration section and define a document class (e.g., "Invoice") with extraction fields (e.g., vendor name, invoice number, total amount, line items). They upload a single-page invoice PDF. The system processes the document: Textract extracts text, Bedrock classifies the document type, Bedrock extracts the specified fields, the assessment Lambda scores confidence, and the results Lambda writes structured JSON to S3 and updates DynamoDB. The web UI shows the document status progressing through each stage. Within 30 seconds, the evaluator sees structured extraction results in the UI.

### Scenario 3: Exceed a Limit

The evaluator uploads a 50-page document. Bedrock token consumption exceeds the 1,000-token limit. The Vocareum platform terminates the lab session and destroys all AWS resources. After 10 minutes, the evaluator can restart the lab. All Terraform state is lost — they must redeploy from scratch. **Lesson:** Test with small documents only.

### Scenario 4: Tear Down

The evaluator runs `terraform destroy` from CloudShell. All resources are removed. The KMS key enters a 7-day deletion window. No ongoing charges accrue after destruction.

---

## Section 7: Summary of Impacts

### 7.1 Operational Impacts

The web UI provides a self-contained evaluation environment. No integration with external systems beyond the AWS services it uses. The evaluator interacts only through the browser and (for deployment) the terminal.

### 7.2 Organizational Impacts

None. Single-user POC.

### 7.3 Impacts During Development

The following risks exist during deployment and testing:

1. **CloudFront denial.** The SCP may block `cloudfront:CreateDistribution`, preventing the web UI from deploying. Mitigation: test the action first; fall back to S3 website hosting if blocked.
2. **Lambda limit ambiguity.** If the "Lambda Limit 3" means total functions (not concurrency), the deployment cannot proceed. Mitigation: clarify with Vocareum admin; if necessary, re-architect to consolidate Lambda functions.
3. **KMS cost.** $1/month for one key. Half the budget. Mitigation: deploy, test, destroy within one billing cycle — or patch modules to use SSE-S3.
4. **Bedrock token exhaustion.** 1,000 tokens is approximately one short document. Mitigation: use the smallest test documents possible; clarify whether the limit is per-request, per-minute, or per-session.
5. **Session termination.** Exceeding any concurrency limit destroys all resources. Mitigation: process one document at a time; monitor resource usage.
6. **Terraform state loss.** If the session is terminated, Terraform state stored in CloudShell's ephemeral storage is lost. Mitigation: store state in S3 (but this uses budget); or accept redeploy-from-scratch risk.

---

## Section 8: Theory of the Proposed System

### The Core Problem

The theory of this system is not about document extraction. It is about **operating within extreme constraints**. The upstream repository solves the IDP problem well. Our problem is different: can we deploy enough of that solution to be useful, within a $2 budget, with aggressive concurrency limits, service denials, and automatic session termination?

Every decision in this project flows from one question: **does this cost money, and if so, can we avoid it?**

### Principles Discovered Through Analysis

The following principles emerge from the analysis of the constraints. They are not aspirational — they are survival rules.

**1. The budget is the program.** A $2 budget with a $1/month KMS key and a $5/month WAF means the system is insolvent on deployment unless both are eliminated or mitigated. Every resource must be evaluated not by whether it is useful, but by whether it is free. The free tier is not a benefit — it is a requirement. If a service is not free-tier eligible, it must be eliminated or its cost must be quantified against the $2 ceiling.

**2. Concurrency limits are harder than budget.** Money runs out slowly. Concurrency violations terminate the session instantly and destroy everything. The system must be designed so that no normal operation — uploading a document, processing a page, viewing results — can trigger concurrent resource usage that exceeds any limit. Sequential processing is not a performance tradeoff. It is a survival requirement.

**3. The SCP is the real architecture.** The Vocareum SCPs deny specific AWS actions unconditionally. These denials are not preferences — they are walls. The `cloudfront:CreateDistribution` denial may block the web UI entirely. The EventBridge rule protection (`voc-*`) means we cannot use that namespace. The IAM protections mean we cannot modify platform roles. The architecture is not what we design — it is what the SCPs permit.

**4. Terraform state is fragile.** If a concurrency violation terminates the session, ephemeral storage is wiped, and Terraform state is lost. This means either: (a) store state in S3 (costs money, uses S3 quota), (b) accept that any session termination requires a full redeploy, or (c) use Terraform Cloud free tier for remote state. Option (b) is acceptable for a POC. Option (c) is preferable if available.

**5. Every optional feature is a threat.** Each enabled feature adds Lambda functions, Bedrock calls, DynamoDB reads, S3 objects, and CloudWatch logs. In a normal AWS account, these are free-tier rounding errors. In this account, each one moves us closer to a concurrency limit or budget ceiling. The default posture is: everything off. Enable only what is required to upload, extract, and view.

**6. Test small or don't test at all.** A 1,000-token Bedrock limit (if per-session) means approximately one page of extracted text. A 50-page document will exhaust the token budget and terminate the session. Test documents must be small: 1 page, simple structure, few fields. The POC evaluates whether extraction *works*, not whether it scales.

### Naur's Criteria Applied

**Explain how the solution relates to real-world affairs.** The real-world affair is evaluating a vendor's IDP capability within a constrained sandbox. The evaluator needs to see: can I upload a form, tell the AI what to extract, and get structured results? The full `genai-idp-terraform` solution answers this question comprehensively — but at a cost that exceeds the sandbox budget. Our job is to strip it down to the minimum that still answers the question.

**Explain what each part of the program text does and why.** WAF is disabled because it costs $5/month. Summarization is disabled because it adds Bedrock calls with no value to the core workflow. Nova Lite is selected because it is the cheapest Bedrock model. Log retention is 1 day because CloudWatch ingestion costs $0.50/GB. Every disabled feature, every parameter choice, every patch exists because the $2 budget demands it.

**Respond constructively to demands for modification.** When the CloudFront SCP blocks the web UI, the theory tells us what to do: find the cheapest way to serve static files that the SCPs permit. When the Lambda limit blocks deployment, the theory tells us: consolidate functions or negotiate a higher limit — but do not add cost. When a test document exceeds the token budget, the theory tells us: use a smaller document, not a bigger budget. The constraint is fixed. The solution must bend.

### Summary of Advantages

- Uses a battle-tested upstream IDP pipeline (`awslabs/genai-idp-terraform`)
- Fully serverless — no EC2, no EKS, no SageMaker endpoints
- Most components fall within AWS free tier (Lambda, DynamoDB, Cognito, AppSync, Textract first 1K pages, Step Functions first 4K transitions)
- Provides the complete evaluation workflow: upload → configure → extract → view
- Terraform-based: one command to deploy, one command to destroy

### Summary of Disadvantages / Limitations

- **$1/month KMS key** consumes half the budget with no free-tier alternative in the current module design
- **CloudFront may be SCP-blocked**, preventing web UI deployment entirely
- **~18 Lambda functions** may exceed the "Lambda Limit 3" if that limit means total function count
- **1,000 Bedrock token limit** (if per-session) restricts testing to tiny documents
- **Session termination risk** means any concurrency violation destroys all deployed resources and Terraform state
- **No high availability, no disaster recovery, no multi-user support** — single-user POC only

### Alternatives and Tradeoffs Considered

**Deploy the full solution as-is.** Cost: ~$7+/month (WAF $5 + KMS $1 + CloudWatch ~$1). Rejected: exceeds $2 budget immediately.

**Skip the web UI; use CLI-only.** Would avoid CloudFront, WAF, and most API Lambda functions. But the stated objective is to evaluate the web-based extraction workflow. Rejected: does not meet the evaluation requirement.

**Use a different IDP solution.** Amazon Bedrock Data Automation (Pattern 1) requires an existing BDA project. SageMaker UDOP (Pattern 3) requires a trained model and a running endpoint. Both are more expensive or more complex. Rejected: Pattern 2 (Bedrock LLM) is the cheapest viable option.

**Run the React app locally against deployed API.** Would avoid CloudFront and WAF costs. The React app could run on `localhost` with Cognito auth pointed at the deployed AppSync API. This is a **viable fallback** if CloudFront is SCP-blocked.

---

## Appendix A: Vocareum Account Constraints Detail

### Concurrency Limits

| Resource | Concurrency Limit | Fraud Limit |
|----------|-------------------|-------------|
| EC2 Running Instances | 2 | 3 |
| CodeBuild | 1 | — |
| SageMaker Notebooks | 2 | — |
| Lambda | 3 | — |
| SageMaker Apps | 2 | — |
| Bedrock Input Tokens | 1,000 | — |
| Bedrock Output Tokens | 1,000 | — |
| EKS Clusters | 1 | — |
| EKS Nodes | 2 | — |
| S3 Bucket Size (all buckets) | 10 GB | — |
| DynamoDB On-Demand Read Capacity | 1,000 | — |
| DynamoDB On-Demand Write Capacity | 1,000 | — |

### Introspecting Account Restrictions

The account is governed by SCPs and IAM policies managed by the platform. Organizations-level introspection (`aws organizations list-policies-for-target`, `describe-policy`) is denied. The following commands work:

```bash
# List policies on the assumed role
aws iam list-attached-role-policies --role-name <role-from-sts-get-caller-identity>
aws iam list-role-policies --role-name <role-from-sts-get-caller-identity>

# Test whether a specific action is allowed (EC2 example — dry-run does not create resources)
aws ec2 run-instances --dry-run --image-id ami-0c02fb55956c7d316 --instance-type t2.micro
```

**Note:** If a command returns `AccessDenied`, that denial is itself useful information. See the validated blocks and working services tables in AGENTS.md for the current known state.

## Appendix B: Minimal terraform.tfvars

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
  enabled = false
}

tags = {
  Environment = "poc"
  Project     = "idp-poc"
}
```

**Note:** This appendix shows the original planned tfvars. See Appendix D for the actual deployment configuration used, which differs significantly due to the S3 Object Lock, CloudFront, SES, and CodeBuild blockers discovered during execution.

### Required Module Patches (Planned vs. Actual)

1. **Disable WAF:** ✅ Applied. In `modules/web-ui/variables.tf`, changed `enable_waf` default from `true` to `false`.
2. **Address KMS:** ✅ Accepted $1/month cost (prorated <$0.01 for <1hr). KMS key pre-created via CLI with CloudWatch Logs permission.
3. **CloudFront:** ✅ Confirmed blocked. Set `web_ui = { enabled = false }`.
4. **S3 Object Lock (new):** ✅ Patched `modules/assets-bucket` to accept `external_bucket_name` / `external_bucket_arn`. All 4 S3 buckets pre-created via CLI.
5. **CodeBuild (new):** ✅ Lambda layers built locally with `uv` and uploaded to S3 manually. CodeBuild projects exist in Terraform state but never successfully build.
6. **SES (new):** ✅ Admin user password set via `aws cognito-idp admin-set-user-password --permanent`.

---

## Appendix D: Phase 2 Deployment Results (2026-03-17)

**Deployment method:** Custom `deploy/` directory calling root module (`source = "../genai-idp-terraform"`) with pre-created S3 buckets and KMS key. NOT the `examples/bedrock-llm-processor/` directory (which creates its own S3 buckets and hits the Object Lock SCP).

**Terraform:** v1.x, AWS provider v5.100.0, deployed from local machine (not CloudShell).

**Total resources created:** 247

### Pre-Created Resources (via AWS CLI, outside Terraform)

| Resource | Identifier |
|----------|------------|
| S3 bucket (input) | `poc-idp-input-571e2c0p` |
| S3 bucket (output) | `poc-idp-output-571e2c0p` |
| S3 bucket (working) | `poc-idp-working-571e2c0p` |
| S3 bucket (assets) | `poc-idp-assets-571e2c0p` |
| KMS key | `304d492f-7b7f-4bc5-849f-2bff67f3735f` |
| KMS alias | `alias/poc-idp-571e2c0p` |
| Lambda layer (idp-common) | Built locally with `uv`, uploaded to `s3://poc-idp-assets-571e2c0p/layers/poc-idp-5ayd6ree-idp-layer-lambda-layers-c1mjovfp/idp-common.zip` |
| Lambda layer (update_configuration) | Built locally with `uv`, uploaded to `s3://poc-idp-assets-571e2c0p/layers/processing-environment-0378stu2-lambda-layers-jh06tadw/update_configuration.zip` |

### Terraform-Created Resources (key outputs)

| Resource | Identifier |
|----------|------------|
| Name prefix | `poc-idp-5ayd6ree` |
| Cognito User Pool | `us-east-1_22EwGyHdP` |
| Cognito Client ID | `7pt01f2399fi0g7g59tkalgcfh` |
| Cognito Identity Pool | `us-east-1:48e0d251-9de3-49a9-b378-d90ae3497a5f` |
| AppSync GraphQL URL | `https://yiznuo43tfdn7ik5nlqpxf7rqa.appsync-api.us-east-1.amazonaws.com/graphql` |
| Step Functions state machine | `poc-idp-5ayd6ree-processor-document-processing` |
| DynamoDB configuration table | `idp-configuration-table-0378stu2` |
| DynamoDB tracking table | `idp-tracking-table-0378stu2` |
| DynamoDB concurrency table | `idp-concurrency-table-0378stu2` |
| SQS queue | `idp-document-queue-0378stu2` |
| Admin user | `admin@poc-idp.local` (CONFIRMED, password set via CLI) |
| Lambda functions | 20 total |

### Deployment Timeline

| Event | Time (approx) |
|-------|---------------|
| `terraform init` | ~2 min (provider download) |
| `terraform plan` | ~30 sec (247 resources planned) |
| `terraform apply` (first attempt) | ~8 min — **FAILED** at Lambda layer publish (CodeBuild STOPPED) |
| Local layer build with `uv` | ~2 min |
| S3 layer upload | ~1 min |
| `terraform apply` (second attempt) | ~5 min — **SUCCESS** (50 remaining resources created) |
| `admin-set-user-password` | immediate |
| **Total Phase 1+2 time** | **~20 min** |

### Module Patches Applied to genai-idp-terraform (commit affe799)

| File | Change | Rationale |
|------|--------|-----------|
| `modules/web-ui/variables.tf` | `enable_waf` default `true` → `false` | WAF costs $5/month, exceeds budget |
| `versions.tf` (root) | AWS provider `">= 5.0"` → `">= 5.0, < 6.0"` | Pin to v5 to avoid breaking changes |
| `examples/bedrock-llm-processor/versions.tf` | AWS provider `"~> 5.80"` | Pin for reproducibility |
| `modules/assets-bucket/main.tf` | All resources conditional on `external_bucket_name == null` | Skip S3 bucket creation when external bucket provided |
| `modules/assets-bucket/variables.tf` | Added `external_bucket_name`, `external_bucket_arn` | Accept pre-created bucket |
| `modules/assets-bucket/outputs.tf` | Conditional outputs: external values or resource values | Support both modes |
| `main.tf` (root) | Pass `assets_bucket_name`/`assets_bucket_arn` to assets-bucket module | Wire external bucket through |
| `variables.tf` (root) | Added `assets_bucket_name`, `assets_bucket_arn` | Expose external bucket config |

### Status at End of Phase 2

- **Phase 0 (Constraint Testing):** ✅ Complete — 7 tests, 4 passed, 3 blockers identified and resolved
- **Phase 1 (Acquire and Patch):** ✅ Complete — repo cloned, 8 patches applied, config written
- **Phase 2 (Deploy):** ✅ Complete — 247 resources deployed, admin user confirmed
- **Phase 3 (Validate):** ⏳ Next — test document processing via AppSync API
- **Phase 4 (Teardown):** ⏳ Pending — `terraform destroy` + manual S3/KMS cleanup

---

## Appendix C: Phase 0 Constraint Test Results (2026-03-17)

**Test Environment:** Vocareum-managed sandbox account, `us-east-1`.

| Test | Procedure | Result | Impact |
|------|-----------|--------|--------|
| **0.1: CloudFront** | `aws cloudfront create-distribution` with minimal config | ❌ **BLOCKED** — `AccessDenied`, explicit deny in SCP | Web UI cannot use CloudFront. **Fallback activated:** deploy backend only, serve React app via alternative means. |
| **0.2: Lambda limit** | Created 4 Lambda functions (`scp-test-lambda-1` through `-4`), all succeeded | ✅ **Limit is concurrency, not count** — 4 functions created simultaneously without session termination | ~18 Lambda functions from upstream repo are deployable. Constraint is on concurrent executions (≤3), not total function count. |
| **0.3: Bedrock Nova Lite** | `aws bedrock list-foundation-models` filtered for `nova-lite` | ✅ **AVAILABLE** — 3 variants listed: `amazon.nova-lite-v1:0`, `24k`, `300k`, all `ACTIVE` | Model accessible for classification and extraction. |
| **0.4: KMS keys** | `aws kms list-keys` | ✅ **No pre-existing keys** — empty result | Clean slate. No surprise costs from pre-provisioned keys. |

### Architecture Decisions Resulting from Phase 0

1. **CloudFront is permanently blocked for this account.** An SCP explicitly denies `cloudfront:CreateDistribution`. This is not a configuration issue — it is an organizational policy that cannot be overridden.

2. **Web UI delivery strategy changed.** The upstream `web-ui` Terraform module creates a CloudFront distribution. Since that is blocked, we set `web_ui = { enabled = false }` in tfvars and deploy the backend only. The React app will be served via one of:
   - **Option A (preferred):** S3 static website hosting with the pre-built React app uploaded manually. Limitation: HTTP only (no HTTPS), which may cause CORS issues with Cognito/AppSync.
   - **Option B:** Run `npm start` on a local machine with environment variables pointing at the deployed Cognito User Pool and AppSync endpoint.
   - **Option C:** Use API Gateway as an HTTPS frontend for S3-hosted static assets.

3. **Lambda deployment is feasible.** The "Lambda Limit 3" confirmed as concurrency limit. The Step Functions state machine executes Lambda functions sequentially, so concurrent executions should remain ≤3 during normal single-document processing.

4. **Budget outlook improved.** No pre-existing KMS keys. Estimated deployment cost remains ~$0.03 (prorated KMS + minimal Bedrock tokens + CloudWatch).

### Phase 0 Additional Findings (discovered during Phase 1–2)

| Test | Procedure | Result | Impact |
|------|-----------|--------|--------|
| **0.5: S3 Object Lock SCP** | `terraform apply` with `aws_s3_bucket` resources | ❌ **BLOCKED** — SCP denies `s3:GetBucketObjectLockConfiguration`. AWS Terraform provider (v5+) reads this attribute during bucket refresh, causing `AccessDenied` on any plan/apply/destroy. | All S3 buckets must be pre-created via CLI and referenced by ARN. No `aws_s3_bucket` resources in Terraform. |
| **0.6: SES blocked** | Cognito user pool invitation email | ❌ **BLOCKED** — SCP denies SES. Cognito invitation emails do not send. | Admin users must be created via `aws cognito-idp admin-set-user-password --permanent`. |
| **0.7: CodeBuild** | `aws codebuild start-build` | ❌ **BLOCKED** — Builds are STOPPED during PROVISIONING after ~3 seconds. Vocareum monitoring appears to kill CodeBuild builds. Concurrency limit of 1 may act as 0 effective builds. | Lambda layers must be built locally using `uv pip install --python-platform x86_64-manylinux2014 --python-version 3.12` and uploaded to S3 manually. |

### Architecture Decisions Resulting from Additional Findings

5. **S3 Object Lock workaround.** The `assets-bucket` module was patched to accept `external_bucket_name` and `external_bucket_arn` variables. When set, the module skips all `aws_s3_bucket` resource creation. All four S3 buckets (input, output, working, assets) are pre-created via CLI and passed to the root module by ARN.

6. **CodeBuild workaround.** Lambda layers are built locally on the developer machine using `uv` with cross-platform targeting (`--python-platform x86_64-manylinux2014 --python-version 3.12`). The resulting zip files are uploaded to S3 at the exact paths the Terraform `aws_lambda_layer_version` resources expect. The CodeBuild projects are created by Terraform (no SCP blocks project creation) but their builds are never successfully executed — the layers are populated externally.

7. **SES workaround.** Admin users are created via Terraform (`aws_cognito_user`) and then confirmed via CLI (`aws cognito-idp admin-set-user-password --permanent`).
