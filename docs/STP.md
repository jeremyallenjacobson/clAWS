# Software Test Plan (STP)

**DID:** DI-IPSC-81438 (MIL-STD-498)
**System:** GenAI Intelligent Document Processing (IDP) POC
**Version:** 1.0 — 2026-03-17
**Status:** Draft — evolves with project execution

---

## 1. Scope

### 1.1 Identification

This document describes the test plan for validating the GenAI IDP POC deployed into AWS account `198082850288` (us-east-1). Testing corresponds to SDP Phase 3 (Validate).

### 1.2 System Overview

The IDP POC is validated through 5 manual end-to-end tests that confirm the core workflow: web UI access, user authentication, extraction configuration, document processing, and budget compliance.

---

## 2. Referenced Documents

| # | Document | Source |
|---|----------|--------|
| 1 | SDP v1.0 | `../SDP.md` (Phase 3, Work Package 3) |
| 2 | STD v1.0 | `STD.md` (detailed test procedures) |
| 3 | SSS v1.0 | `SSS.md` |

---

## 3. Test Approach

### 3.1 General Approach

- **Method:** Manual end-to-end validation by the POC evaluator.
- **No automated tests.** The system either works or it doesn't. This is a POC — reliability testing is not a requirement.
- **Test environment:** The deployed AWS infrastructure itself. No separate test environment exists.
- **Test data:** A single-page invoice (PDF or image) with clearly formatted fields. Small document to minimize Bedrock token consumption.
- **Duration:** 20–30 minutes for all 5 tests.

### 3.2 Test Environment

| Component | Detail |
|-----------|--------|
| AWS Account | 198082850288 |
| Region | us-east-1 |
| Web UI Access | S3 website URL or `http://localhost:3000` |
| Browser | Chrome, Firefox, or Edge |
| Terminal | AWS CloudShell or local terminal with AWS credentials |

### 3.3 Constraints on Testing

- **Budget:** All testing must occur within the $2.00 total budget. Each Bedrock invocation costs tokens.
- **Token limits:** 1,000 input / 1,000 output tokens per Bedrock invocation. Use small documents only.
- **Concurrency:** Process one document at a time. Do not upload multiple documents simultaneously.
- **Time:** Testing must complete before teardown. System must be destroyed after validation.

---

## 4. Validation Tests

### Test 1: Web UI Access

- **Objective:** Verify the React SPA loads and is accessible in a browser.
- **Pre-condition:** `terraform apply` completed successfully (or local dev server is running).
- **Acceptance criteria:**
  - Web UI URL is reachable.
  - React application renders without errors.
  - Cognito login/registration screen is displayed.
- **Pass/Fail:** The page loads and shows a login form.

### Test 2: User Registration and Login

- **Objective:** Verify Cognito authentication flow works end-to-end.
- **Pre-condition:** Test 1 passed.
- **Acceptance criteria:**
  - User can register with an email address.
  - Verification code is received (via email or manual CLI confirmation).
  - User can log in and see the IDP dashboard.
- **Pass/Fail:** User is authenticated and the main application view is displayed.
- **Fallback:** If verification email is not received within 5 minutes, confirm user via `aws cognito-idp admin-confirm-sign-up`.

### Test 3: Extraction Configuration

- **Objective:** Verify the user can define document classes and extraction fields.
- **Pre-condition:** Test 2 passed (user is logged in).
- **Acceptance criteria:**
  - User can navigate to the configuration section.
  - User can create a document class (e.g., "Invoice").
  - User can define extraction fields (e.g., vendor_name, invoice_number, total_amount, invoice_date).
  - Configuration is saved and persists (stored in DynamoDB).
- **Pass/Fail:** Configuration is saved without error and is visible upon page refresh.

### Test 4: Document Processing

- **Objective:** Verify the full processing pipeline: upload → OCR → classify → extract → results.
- **Pre-condition:** Test 3 passed (extraction configuration exists).
- **Acceptance criteria:**
  - User can upload a single-page test document (invoice).
  - Document status progresses through pipeline stages (Uploaded → OCR → Classification → Extraction → Assessment → Complete).
  - Structured extraction results are displayed in the web UI.
  - Extracted field values are reasonable (correct vendor name, invoice number, etc.).
- **Pass/Fail:** Extraction results are displayed with recognizable field values.
- **Constraint:** Use a 1-page document with simple formatting. Processing should complete within 60 seconds.

### Test 5: Budget Check

- **Objective:** Verify total AWS spend remains ≤ $2.00.
- **Pre-condition:** Tests 1–4 completed.
- **Acceptance criteria:**
  - AWS Cost Explorer (or billing dashboard) shows total spend ≤ $2.00.
  - No unexpected charges from unintended resources.
- **Pass/Fail:** Total spend ≤ $2.00.
- **Note:** Cost Explorer data may lag by several hours. Estimated spend from `terraform apply` duration and known resource costs may be used as a proxy.

---

## 5. Test Schedule

| Test | Estimated Duration | Cumulative |
|------|-------------------|------------|
| Test 1: Web UI Access | 2 min | 2 min |
| Test 2: User Registration | 5 min | 7 min |
| Test 3: Extraction Config | 5 min | 12 min |
| Test 4: Document Processing | 10 min | 22 min |
| Test 5: Budget Check | 3 min | 25 min |

---

## 6. Overall Pass/Fail Criteria

- **PASS:** All 5 tests pass. The IDP POC is validated — the system successfully uploads, configures, processes, and displays extraction results within budget.
- **FAIL:** Any test fails. Record the failure, check CloudWatch Logs for diagnostics, and determine if a fix is feasible within remaining budget. Proceed to teardown regardless.

---

## 7. Test Results

| Test | Result | Notes |
|------|--------|-------|
| Test 1: Web UI Access | [TBD] | |
| Test 2: User Registration | [TBD] | |
| Test 3: Extraction Config | [TBD] | |
| Test 4: Document Processing | [TBD] | |
| Test 5: Budget Check | [TBD] | Spend: $[TBD] |
| **Overall** | **[TBD]** | |
