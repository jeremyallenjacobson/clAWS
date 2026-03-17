# Software User Manual (SUM)

**DID:** DI-IPSC-81442 (MIL-STD-498)
**System:** GenAI Intelligent Document Processing (IDP) POC
**Version:** 1.0 — 2026-03-17
**Status:** Draft — evolves with project execution

---

## 1. Scope

### 1.1 Identification

This manual describes how to use the GenAI IDP POC CLI-based document processing pipeline to upload documents, configure extraction rules, and view structured extraction results. The system is deployed in AWS account `198082850288` (us-east-1). No web UI is deployed — CloudFront `CreateDistribution` is SCP-blocked.

### 1.2 System Overview

The IDP POC provides a CLI-based document processing pipeline for intelligent document processing. Users upload documents (PDFs, images) via AWS CLI to S3, define extraction fields via configuration files, and retrieve AI-extracted structured results from S3. CloudFront is SCP-blocked in this environment, so no web UI is deployed.

---

## 2. Referenced Documents

| # | Document | Source |
|---|----------|--------|
| 1 | STP v1.0 | `STP.md` |
| 2 | SCOM v1.0 | `SCOM.md` |

---

## 3. Accessing the System

### 3.1 CLI Access (Primary Method)

The web UI is not deployed (CloudFront is SCP-blocked). All interaction is via AWS CLI.

**Prerequisites:**
- AWS credentials configured (see SCOM Section 3)
- AWS CLI v2 installed

**Authentication:**
```bash
source ~/Projects/clAWS/.env

# Authenticate and get JWT tokens
aws cognito-idp initiate-auth \
  --auth-flow USER_PASSWORD_AUTH \
  --client-id 7pt01f2399fi0g7g59tkalgcfh \
  --auth-parameters USERNAME=admin@poc-idp.local,PASSWORD='P0c-Idp!2026#Eval' \
  --region us-east-1
```

---

## 4. Registration and Login

### 4.1 Admin User (Pre-Created)

The admin user is pre-configured during deployment:
- **Email:** `admin@poc-idp.local`
- **Password:** `P0c-Idp!2026#Eval`
- **Group:** Admin

SES is SCP-blocked, so email-based registration is not possible. The admin user's password was set via:
```bash
aws cognito-idp admin-set-user-password \
  --user-pool-id us-east-1_22EwGyHdP \
  --username admin@poc-idp.local \
  --password 'P0c-Idp!2026#Eval' \
  --permanent
```

### 4.2 Verify Authentication

```bash
aws cognito-idp initiate-auth \
  --auth-flow USER_PASSWORD_AUTH \
  --client-id 7pt01f2399fi0g7g59tkalgcfh \
  --auth-parameters USERNAME=admin@poc-idp.local,PASSWORD='P0c-Idp!2026#Eval' \
  --region us-east-1 \
  --query 'AuthenticationResult.AccessToken' --output text
```

A valid JWT token is returned on success.

---

## 5. Configuring Extraction Rules

Extraction rules are pre-configured in `deploy/config/config.yaml` and loaded into DynamoDB during `terraform apply`. No runtime configuration via a web UI is available.

### 5.1 Document Class: GenericDocument

The pre-configured document class is **GenericDocument** with the following extraction fields:

| Field Name | Description |
|------------|-------------|
| `DocumentTitle` | Title of the document |
| `DocumentDate` | Date found on the document |
| `DocumentType` | Type/category of the document |
| `KeyFields` | Key-value pairs extracted from the document |

### 5.2 Modifying Extraction Rules

To change extraction rules, edit `deploy/config/config.yaml` and re-run `terraform apply`. Changes are written to DynamoDB and take effect on the next document processed.

---

## 6. Uploading and Processing a Document

### 6.1 Prepare Your Test Document

- Use a **single-page** document (PDF, PNG, or JPEG).
- The document should be **small** (<1 MB) to minimize Bedrock token consumption.
- Fields on the document should be clearly formatted and readable.
- **Do not upload multi-page or complex documents** — the Bedrock token limit (1,000 tokens) restricts processing to short documents.

### 6.2 Upload a Document

```bash
# Upload a document to the input bucket
aws s3 cp /path/to/document.txt s3://poc-idp-input-571e2c0p/ --region us-east-1
```

### 6.3 Monitor Processing

After upload, the document is automatically processed through the pipeline (S3 → EventBridge → SQS → Step Functions):

| Stage | Description | Typical Duration |
|-------|-------------|-----------------|
| Uploaded | Document received in S3 | Immediate |
| OCR | Textract extracts text and layout | 5–10 seconds |
| Classification | Bedrock classifies document type | 5–15 seconds |
| Extraction | Bedrock extracts defined fields | 5–15 seconds |
| Assessment | Confidence scoring | 1–2 seconds |
| Complete | Results written to storage | 1–2 seconds |

Total processing time: **~15–45 seconds** for a single-page document.

```bash
# Monitor processing
aws stepfunctions list-executions \
  --state-machine-arn "arn:aws:states:us-east-1:198082850288:stateMachine:poc-idp-5ayd6ree-processor-document-processing" \
  --max-results 5 --region us-east-1

# Check results
aws s3 ls s3://poc-idp-output-571e2c0p/ --recursive --region us-east-1

# Download extraction results
aws s3 cp s3://poc-idp-output-571e2c0p/<document-name>/sections/1/result.json - --region us-east-1 | python3 -m json.tool
```

### 6.4 Important Constraints

- **Process one document at a time.** Do not upload additional documents while one is processing. Concurrent Lambda executions must stay ≤3.
- **Use small documents.** 1 page, simple format, few fields.
- **Monitor your budget.** Each document processed consumes Bedrock tokens and pipeline resources.

---

## 7. Viewing Results

### 7.1 View Extraction Results

After processing completes, download the result JSON from the output bucket (see Section 6.3). The extraction result format:

```json
{
  "document_class": {"type": "GenericDocument"},
  "inference_result": {
    "DocumentType": "invoice",
    "DocumentTitle": "INVOICE",
    "DocumentDate": "03/15/2026",
    "KeyFields": {
      "Field1Name": "Vendor",
      "Field1Value": "Acme Testing Corp",
      "Field2Name": "Invoice Number",
      "Field2Value": "INV-2026-001",
      "Field3Name": "Total Amount",
      "Field3Value": "$125.00"
    }
  },
  "explainability_info": [{"DocumentType": {"value": "invoice", "confidence": 1.0}}]
}
```

Review the extracted values against the original document. Confidence scores are included in the `explainability_info` array.

### 7.2 Understanding Results

- **Correct extractions:** Field values match the source document.
- **Partial extractions:** Some fields are correct, others are missing or incorrect. This is expected for a POC — Nova Lite is the cheapest model, not the most accurate.
- **Failed extractions:** No results or all fields empty. Check CloudWatch Logs for errors (see SCOM Section 6).

---

## 8. Limitations

| Limitation | Detail |
|------------|--------|
| Single user only | One user at a time; POC is not multi-user |
| Small documents only | 1–3 pages max due to Bedrock token limits |
| Sequential processing | One document at a time |
| No web UI deployed | CloudFront is SCP-blocked; all interaction via AWS CLI |
| Ephemeral system | System is destroyed after evaluation |
| No data persistence | All uploaded documents and results are deleted during teardown |
| Budget ceiling | $2.00 total — limited testing capacity |
