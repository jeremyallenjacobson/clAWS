# System/Subsystem Specification (SSS)

**DID:** DI-IPSC-81431 (MIL-STD-498)
**System:** GenAI Intelligent Document Processing (IDP) POC
**Version:** 1.0 — 2026-03-17
**Status:** Draft — evolves with project execution

---

## 1. Scope

### 1.1 Identification

- **System Title:** GenAI IDP POC
- **Account:** 198082850288
- **Region:** us-east-1
- **Source Repository:** `https://github.com/awslabs/genai-idp-terraform.git`
- **Pattern:** Pattern 2 — Bedrock LLM Processor
- **Budget:** $2.00 USD

### 1.2 System Overview

A minimal Intelligent Document Processing platform deployed from the `awslabs/genai-idp-terraform` repository into a Vocareum-managed AWS sandbox. The system allows a single user to upload documents via a web interface, configure extraction instructions, and view structured results. All optional features are disabled; only the core pipeline is deployed.

---

## 2. Referenced Documents

| # | Document | Source |
|---|----------|--------|
| 1 | PROCRV v1.0 | `../PROCRV.md` |
| 2 | SDP v1.0 | `../SDP.md` |
| 3 | genai-idp-terraform | https://github.com/awslabs/genai-idp-terraform.git |

---

## 3. System-Wide Design Decisions

- **CloudFront is SCP-blocked.** Web UI disabled (`web_ui.enabled = false`). API-only deployment; test via CLI or local React dev server.
- **WAF disabled** ($5/month exceeds budget).
- **S3 Object Lock SCP blocks Terraform.** AWS provider v5+ reads `s3:GetBucketObjectLockConfiguration` during refresh — denied by SCP. All S3 buckets pre-created via CLI; no `aws_s3_bucket` resources in Terraform.
- **CodeBuild blocked.** Vocareum stops builds during PROVISIONING (~3s). Lambda layers built locally with `uv` and uploaded to S3.
- **SES blocked.** Cognito invitation emails don't send. Admin users confirmed via `admin-set-user-password --permanent`.
- **KMS customer-managed key accepted** (prorated <$0.01 for <1hr operation).
- **All optional features disabled:** summarization, evaluation, reporting, human review, knowledge base, discovery, chat-with-document, process-changes, agent-analytics, test studio, FCC dataset, error analyzer, MCP, agent companion chat.
- **Bedrock model:** Amazon Nova Lite (`us.amazon.nova-lite-v1:0`) for classification and extraction.
- **Log retention:** 1 day. Data tracking retention: 7 days.
- **Sequential document processing only** — Lambda concurrency limit of 3.

---

## 4. System Architecture

```
User (Browser)
  │
  ▼
S3 Website / localhost:3000 ──► S3 Web App Bucket (React SPA)
  │
  ▼
Cognito (User Pool + Identity Pool) ──► Authentication
  │
  ▼
AppSync GraphQL API
  │
  ├──► S3 Input Bucket (pre-signed upload URL)
  ├──► DynamoDB Configuration Table (extraction prompts/rules)
  ├──► DynamoDB Tracking Table (document processing status)
  │
  ▼
EventBridge ──► SQS Queue ──► Step Functions State Machine
  │
  ├──► Lambda: OCR (calls Amazon Textract)
  ├──► Lambda: Classification (calls Bedrock Nova Lite)
  ├──► Lambda: Extraction (calls Bedrock Nova Lite)
  ├──► Lambda: Assessment
  └──► Lambda: Process Results ──► S3 Output Bucket + DynamoDB
```

---

## 5. Subsystems

### 5.1 Web UI Subsystem

- **Technology:** React Single Page Application
- **Delivery:** S3 static website hosting (Option A) or local dev server at `localhost:3000` (Option B). CloudFront is SCP-blocked.
- **Functions:** Login, extraction configuration, document upload, results display.
- **Build:** CodeBuild (if deploying via Terraform) or `npm start` locally.

### 5.2 API Subsystem (AppSync)

- **Technology:** AWS AppSync (GraphQL)
- **Authentication:** Amazon Cognito User Pool
- **Data sources:** DynamoDB (configuration, tracking), Lambda resolvers, S3 (pre-signed URLs)
- **Endpoint URL:** [TBD — populated after `terraform apply`]

### 5.3 Processing Pipeline Subsystem

- **Orchestration:** AWS Step Functions state machine
- **Trigger:** EventBridge → SQS → Step Functions
- **Pipeline stages:**

| Stage | Lambda Function | External Service | Purpose |
|-------|----------------|------------------|---------|
| OCR | [TBD] | Amazon Textract | Extract text/layout from document |
| Classification | [TBD] | Bedrock Nova Lite | Classify document type |
| Extraction | [TBD] | Bedrock Nova Lite | Extract structured fields |
| Assessment | [TBD] | — | Score extraction confidence |
| Results | [TBD] | — | Write results to S3/DynamoDB |

- **Lambda function list:** ~18 functions total. Exact names [TBD — populated after `terraform plan`].
- **Concurrency:** Lambda concurrency limit is 3 (confirmed). Step Functions executes stages sequentially, keeping concurrent executions within limit.

### 5.4 Storage Subsystem

- **S3 Buckets:**

| Bucket | Purpose | Encryption |
|--------|---------|------------|
| Input bucket | Uploaded documents | KMS (customer-managed) |
| Output bucket | Extraction results (JSON) | KMS (customer-managed) |
| Web app bucket | React SPA assets (if S3 hosting) | KMS (customer-managed) |

- Bucket names: [TBD — `poc-idp-*` prefix, populated after deployment]

- **DynamoDB Tables:**

| Table | Purpose |
|-------|---------|
| Configuration table | Extraction prompts, document class definitions, field rules |
| Tracking table | Document processing status, timestamps, results references |

- Table names and schemas: [TBD — populated after deployment]

---

## 6. Constraints and Limitations

| Constraint | Value | Source |
|------------|-------|--------|
| Total budget | $2.00 | Vocareum account |
| Lambda concurrency | 3 | Vocareum concurrency limit |
| Bedrock input tokens | 1,000 | Vocareum concurrency limit |
| Bedrock output tokens | 1,000 | Vocareum concurrency limit |
| S3 total size | 10 GB | Vocareum concurrency limit |
| DynamoDB R/W capacity | 1,000 each | Vocareum concurrency limit |
| Region | us-east-1 only | SCP VocRestrictRegions |
| CloudFront | Blocked | SCP VocUnconditionalDeny (confirmed) |
| WAF | Disabled (cost) | $5/month exceeds budget |
| EC2 | Not used (serverless) | Fraud limit: 3 instances |

---

## 7. Resource ARNs and Identifiers

All values populated after `terraform apply`:

| Resource | ARN / Identifier |
|----------|-----------------|
| Cognito User Pool | [TBD] |
| Cognito Identity Pool | [TBD] |
| AppSync API | [TBD] |
| Step Functions State Machine | [TBD] |
| S3 Input Bucket | [TBD] |
| S3 Output Bucket | [TBD] |
| S3 Web App Bucket | [TBD] |
| KMS Key | [TBD] |
| DynamoDB Config Table | [TBD] |
| DynamoDB Tracking Table | [TBD] |
