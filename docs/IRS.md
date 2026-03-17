# Interface Requirements Specification (IRS)

**DID:** DI-IPSC-81434 (MIL-STD-498)
**System:** GenAI Intelligent Document Processing (IDP) POC
**Version:** 1.0 — 2026-03-17
**Status:** Draft — evolves with project execution

---

## 1. Scope

### 1.1 Identification

This document specifies the external and internal interfaces for the GenAI IDP POC deployed into AWS account `198082850288` (us-east-1).

### 1.2 System Overview

The IDP POC interfaces with several AWS managed services for authentication, document processing, AI inference, and data storage. All interfaces are within the us-east-1 region.

---

## 2. Referenced Documents

| # | Document | Source |
|---|----------|--------|
| 1 | SSS v1.0 | `SSS.md` |
| 2 | PROCRV v1.0 | `../PROCRV.md` |

---

## 3. External Interfaces

### 3.1 Amazon Cognito (Authentication)

- **Type:** User authentication and authorization
- **Components:** User Pool, Identity Pool, App Client
- **Protocol:** OAuth 2.0 / OpenID Connect
- **User Pool ID:** `us-east-1_22EwGyHdP`
- **App Client ID:** `7pt01f2399fi0g7g59tkalgcfh`
- **Identity Pool ID:** `us-east-1:48e0d251-9de3-49a9-b378-d90ae3497a5f`
- **Auth flow:** User registers with email → receives verification code → confirms account → logs in → receives JWT tokens
- **Fallback:** If Cognito email delivery fails (SES may be SCP-restricted), confirm user manually via `aws cognito-idp admin-confirm-sign-up`.
- **Constraint:** Cognito free tier covers 50K MAU — well within POC needs.

### 3.2 AWS AppSync (GraphQL API)

- **Type:** GraphQL API for frontend-to-backend communication
- **Protocol:** HTTPS (GraphQL over WebSocket for subscriptions)
- **Endpoint URL:** [TBD — populated after deployment]
- **Authentication:** Cognito User Pool JWT
- **Operations:**
  - **Queries:** Get document status, list documents, get extraction results, get configuration
  - **Mutations:** Upload document (returns pre-signed S3 URL), save extraction configuration
  - **Subscriptions:** Document processing status updates
- **API schema:** [TBD — defined by upstream repository, captured after deployment]
- **CORS:** Must allow the web UI origin (S3 website URL or `http://localhost:3000`)

### 3.3 Amazon Bedrock (AI Inference)

- **Type:** Foundation model inference for classification and extraction
- **Model ID:** `us.amazon.nova-lite-v1:0` (Amazon Nova Lite)
- **Protocol:** AWS SDK (`bedrock-runtime:InvokeModel`)
- **Input format:** JSON with prompt text (document content + extraction instructions)
- **Output format:** JSON with model response (classification label or extracted fields)
- **Token limits (Vocareum):** 1,000 input tokens, 1,000 output tokens per invocation
- **Invocation pattern:** Called by Lambda functions within the Step Functions pipeline. Two calls per document: one for classification, one for extraction.
- **Cost:** Pay-per-token. Nova Lite pricing: ~$0.00006/1K input tokens, ~$0.00024/1K output tokens.

### 3.4 Amazon Textract (OCR)

- **Type:** Document text and layout extraction
- **Protocol:** AWS SDK (`textract:AnalyzeDocument` or `textract:DetectDocumentText`)
- **Input:** Document bytes (from S3 object reference)
- **Output:** JSON with extracted text blocks, bounding boxes, confidence scores
- **Free tier:** First 1,000 pages/month — sufficient for POC.
- **Invocation pattern:** Called by the OCR Lambda function at the start of the processing pipeline.

### 3.5 Amazon S3 (Document Upload)

- **Type:** Pre-signed URL for document upload from browser
- **Protocol:** HTTPS PUT via pre-signed URL
- **Flow:** Web UI requests upload URL via AppSync mutation → AppSync resolver generates pre-signed S3 PUT URL → browser uploads document directly to S3 input bucket
- **Input bucket:** `poc-idp-input-571e2c0p`
- **Output bucket:** `poc-idp-output-571e2c0p`
- **Supported formats:** PDF, PNG, JPEG, TIFF
- **Size limit:** Practical limit ~10 MB per document (Textract limits)

---

## 4. Internal Interfaces

### 4.1 EventBridge → SQS → Step Functions

- **Trigger:** S3 PutObject event on the input bucket → EventBridge rule → SQS queue → Step Functions execution
- **EventBridge rule name:** `poc-idp-5ayd6ree-processor-s3-event-rule-56eiivw4` (does not use `voc-*` prefix)
- **SQS queue:** `idp-document-queue-0378stu2`
- **State machine ARN:** `arn:aws:states:us-east-1:198082850288:stateMachine:poc-idp-5ayd6ree-processor-document-processing`

### 4.2 Step Functions → Lambda Functions

- **Interface type:** Synchronous invocation from Step Functions task states
- **Execution model:** Sequential — one Lambda at a time per document
- **Payload:** JSON containing document reference (S3 key), processing metadata, accumulated results from previous stages
- **Concurrency constraint:** ≤3 concurrent Lambda executions (Vocareum limit). Sequential pipeline design keeps this within bounds for single-document processing.

### 4.3 Lambda → DynamoDB

- **Interface type:** AWS SDK DynamoDB client
- **Operations:** PutItem (write results), UpdateItem (update status), GetItem (read configuration)
- **Tables:** Configuration table, Tracking table
- **Capacity mode:** On-demand (Vocareum limit: 1,000 RCU/WCU)

### 4.4 Lambda → S3

- **Interface type:** AWS SDK S3 client
- **Operations:** GetObject (read uploaded document), PutObject (write extraction results)
- **Encryption:** KMS customer-managed key (SSE-KMS)

---

## 5. Interface Constraints

| Interface | Constraint | Impact |
|-----------|-----------|--------|
| Cognito → SES | SES may be SCP-blocked | Email verification may fail; manual confirmation fallback |
| AppSync → Web UI | CORS must allow S3 website or localhost origin | Configuration needed post-deploy |
| Bedrock | 1,000 token input/output limit | Small documents only; 1–3 pages max |
| CloudFront | SCP-blocked (`CreateDistribution` denied) | Web UI cannot use CloudFront CDN |
| All services | us-east-1 only | SCP denies actions in other regions |
