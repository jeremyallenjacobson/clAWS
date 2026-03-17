# Software Product Specification (SPS)

**DID:** DI-IPSC-81441 (MIL-STD-498)
**System:** GenAI Intelligent Document Processing (IDP) POC
**Version:** 1.0 — 2026-03-17
**Status:** Draft — evolves with project execution

---

## 1. Scope

### 1.1 Identification

This document specifies the software product deliverables, version information, and required tools for the GenAI IDP POC deployed into AWS account `198082850288` (us-east-1).

### 1.2 System Overview

The IDP POC is not a custom software product — it is a configured deployment of the upstream `awslabs/genai-idp-terraform` repository with targeted patches and a custom `terraform.tfvars`. This document tracks what is delivered, what was modified, and what tools are required to reproduce the deployment.

---

## 2. Referenced Documents

| # | Document | Source |
|---|----------|--------|
| 1 | SDP v1.0 | `../SDP.md` |
| 2 | SSS v1.0 | `SSS.md` |
| 3 | genai-idp-terraform | https://github.com/awslabs/genai-idp-terraform.git |

---

## 3. Upstream Repository

| Property | Value |
|----------|-------|
| Repository | https://github.com/awslabs/genai-idp-terraform.git |
| Branch | main |
| Commit SHA | `affe799` |
| Clone date | 2026-03-17 |
| Pattern used | Pattern 2 — Bedrock LLM Processor |

---

## 4. Deliverables Checklist

### 4.1 Project Documentation

| # | Deliverable | File | Status |
|---|------------|------|--------|
| 1 | Pre-Requirements Operating Concept (PROCRV) | `../PROCRV.md` | Complete |
| 2 | Software Development Plan (SDP) | `../SDP.md` | Complete |
| 3 | System/Subsystem Specification (SSS) | `SSS.md` | Draft |
| 4 | Interface Requirements Specification (IRS) | `IRS.md` | Draft |
| 5 | Database Design Description (DBDD) | `DBDD.md` | Draft |
| 6 | Software Test Plan (STP) | `STP.md` | Draft |
| 7 | Software Test Description (STD) | `STD.md` | Draft |
| 8 | Software Center Operator Manual (SCOM) | `SCOM.md` | Draft |
| 9 | Software Product Specification (SPS) | `SPS.md` (this file) | Draft |
| 10 | Software User Manual (SUM) | `SUM.md` | Draft |
| 11 | Software Installation Plan (SIP) | `SIP.md` | Draft |

### 4.2 Configuration Artifacts

| # | Deliverable | File | Status |
|---|------------|------|--------|
| 1 | Terraform variables file | `terraform.tfvars` | Complete — deploy/terraform.tfvars |
| 2 | WAF disable patch | Diff to `modules/web-ui/variables.tf` | Complete — applied |
| 3 | KMS patch (if applied) | Diff to S3 encryption modules | Not applied (cost accepted) |

### 4.3 Deployment Artifacts

| # | Deliverable | Location | Status |
|---|------------|----------|--------|
| 1 | Terraform state | `terraform.tfstate` (ephemeral) | Complete — deploy/terraform.tfstate (247 resources) |
| 2 | Plan output log | `~/plan-output.txt` | Complete |
| 3 | Apply output log | `~/apply-output.txt` | Complete |
| 4 | Destroy output log | `~/destroy-output.txt` | Complete |
| 5 | Terraform outputs (JSON) | `~/terraform-outputs.json` | Complete |

### 4.4 Test Artifacts

| # | Deliverable | Location | Status |
|---|------------|----------|--------|
| 1 | Phase 0 constraint test results | `../PROCRV.md` Appendix C | Complete |
| 2 | Phase 3 validation test results | `STP.md` Section 7 | Complete — STD.md Section 4 |

---

## 5. Patches Applied to Upstream Repository

### 5.1 WAF Disable Patch

**File:** `modules/web-ui/variables.tf`
**Change:** Default value of `enable_waf` from `true` to `false`
**Rationale:** WAFv2 Web ACL costs $5/month — 2.5× the total budget.

```diff
 variable "enable_waf" {
   type    = bool
-  default = true
+  default = false
 }
```

### 5.2 Web UI Disable (tfvars)

**File:** `terraform.tfvars`
**Change:** `web_ui = { enabled = false }`
**Rationale:** CloudFront `CreateDistribution` is SCP-blocked (confirmed Phase 0 Test 0.1). Web UI served via alternative means.

### 5.3 Assets Bucket External Bucket Patch

**File:** `modules/assets-bucket/main.tf`, `modules/assets-bucket/variables.tf`, `modules/assets-bucket/outputs.tf`
**Change:** Added `external_bucket_name` and `external_bucket_arn` variables to accept pre-created S3 bucket instead of creating one. When set, module skips `aws_s3_bucket` creation and uses the provided ARN/name.
**Rationale:** S3 Object Lock SCP (`s3:GetBucketObjectLockConfiguration` denied) blocks Terraform's AWS provider v5+ from managing S3 buckets. All 4 S3 buckets pre-created via CLI.

### 5.4 CodeBuild Bypass — Local Lambda Layer Build

**Change:** Lambda layers built locally instead of via CodeBuild.
**Commands used:**
```bash
uv pip install --python-platform x86_64-manylinux2014 --python-version 3.12 --target /tmp/layer/python <requirements>
cd /tmp/layer && zip -r layer.zip python/
aws s3 cp layer.zip s3://poc-idp-assets-571e2c0p/<expected-path>
```
**Rationale:** Vocareum kills CodeBuild builds during PROVISIONING phase (~3 seconds).

### 5.5 S3 EventBridge Notification Fix

**Change:** Enabled EventBridge notifications on pre-created input bucket post-deployment.
```bash
aws s3api put-bucket-notification-configuration \
  --bucket poc-idp-input-571e2c0p \
  --notification-configuration '{"EventBridgeConfiguration": {}}'
```
**Rationale:** Pre-created S3 buckets did not have EventBridge notifications enabled (Terraform normally configures this on buckets it creates).

---

## 6. Required Tools

| Tool | Minimum Version | Purpose | Installation |
|------|----------------|---------|-------------|
| Terraform | ≥ 1.5 | Infrastructure deployment | Manual install in CloudShell (~80 MB) |
| AWS CLI | v2 | Constraint testing, diagnostics, teardown verification | Pre-installed in CloudShell |
| git | any | Repository cloning | Pre-installed in CloudShell |
| Node.js | ≥ 18 | Local React dev server (if used) | Pre-installed in CloudShell (verify version) |
| npm | any | React app dependency installation | Bundled with Node.js |
| Web browser | Modern (Chrome/Firefox/Edge) | Web UI validation | Evaluator's local machine |
| uv | any | Python package installer for Lambda layers (CodeBuild blocked) | `pip install uv` or `curl -LsSf https://astral.sh/uv/install.sh \| sh` |

### 6.1 Terraform Installation (CloudShell)

```bash
TERRAFORM_VERSION="1.7.5"
curl -fsSL "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip" -o /tmp/terraform.zip
unzip -o /tmp/terraform.zip -d ~/bin
export PATH="$HOME/bin:$PATH"
echo 'export PATH="$HOME/bin:$PATH"' >> ~/.bashrc
terraform version
```

---

## 7. Version History

| Version | Date | Change |
|---------|------|--------|
| 1.0 | 2026-03-17 | Initial draft with known deliverables and TBD markers |
