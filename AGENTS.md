# Agent Instructions — GenAI IDP Testbed on Constrained AWS

## What This Project Is

A testbed for deploying and developing the [awslabs/genai-idp-terraform](https://github.com/awslabs/genai-idp-terraform.git) (Pattern 2: Bedrock LLM Processor) into Vocareum-managed AWS sandbox accounts. These accounts have restrictive SCPs and hard concurrency limits. Violating a concurrency limit terminates the session and destroys all resources.

## Key Documents (Read These First)

1. **PROCRV.md** — Operating concept, Vocareum constraints, blockers, and survival principles.
2. **SDP.md** — Phased execution plan (Phase 0–4) with go/no-go gates.
3. **docs/SIP.md** — Software Installation Plan: step-by-step deployment into a fresh account.
4. **docs/SCOM.md** — Operator manual: monitoring, teardown, recovery procedures.

## Before Attempting Any New AWS Action

**This account has invisible restrictions.** SCPs and Vocareum concurrency limits cannot be queried from within the account. If the user asks you to do something new (a service, resource type, or action not already validated), **stop and verify first:**

1. Check the task against the known constraints table below.
2. If the action involves a service or API call not listed as validated, tell the user:
   *"This action hasn't been tested in this account. The Vocareum SCPs may block it, and hitting a concurrency limit could terminate the session and destroy all resources. I recommend we probe this with a dry-run or small test first."*
3. For EC2 actions, use `--dry-run` to test without creating resources.
4. For other services, use the smallest possible test (e.g., describe/list calls before create calls).
5. Never assume an AWS service works just because it's generally available — the SCPs deny specific actions silently.

## Critical Constraints (Memorize These)

| Constraint | Value | Consequence of Violation |
|------------|-------|--------------------------|
| Budget | $2.00 total | Account unusable |
| Lambda concurrent executions | 3 | Session terminated, all resources destroyed |
| Bedrock tokens | 1,000 input / 1,000 output | Session terminated |
| EC2 concurrent instances | 2 (3 = fraud lock) | Session terminated / account locked |
| CodeBuild | 1 (killed during PROVISIONING) | Builds never complete |
| S3 aggregate size | 10 GB | Session terminated |
| DynamoDB R/W capacity | 1,000 each | Session terminated |
| Region | us-east-1 only | SCP denies actions elsewhere |

### Validated SCP Blocks (Confirmed Denied)

| Action | SCP |
|--------|-----|
| `cloudfront:CreateDistribution` (and all cloudfront:Create*) | VocUnconditionalDeny |
| `ses:*` | VocUnconditionalDeny |
| `s3:GetBucketObjectLockConfiguration` | VocUnconditionalDeny |
| `s3:PutBucketObjectLockConfiguration` | VocUnconditionalDeny |
| `s3:PutObjectRetention`, `s3:GetObjectRetention` | VocUnconditionalDeny |
| `lightsail:*`, `comprehendmedical:*`, `clouddirectory:*` | VocUnconditionalDeny |
| EC2 instance types larger than `*.large` | VocConditionalDeny |

### Validated Working Services

| Service | Notes |
|---------|-------|
| Lambda | Works (20 functions deployed). Concurrency limit is 3 simultaneous executions. |
| S3 | Works if buckets created via CLI (not Terraform). Object Lock APIs denied. |
| DynamoDB | Works. On-demand capacity. |
| Cognito | Works (User Pool, Identity Pool, App Client). |
| AppSync | Works (GraphQL API). |
| Step Functions | Works (state machine orchestration). |
| EventBridge | Works. Do NOT create rules with `voc-*` prefix. |
| SQS | Works. |
| KMS | Works ($1/month — prorated <$0.01 for short sessions). |
| Bedrock | Works (Nova Lite). Token limits enforced by Vocareum. |
| Textract | Works (OCR). Free tier covers POC. |
| IAM | Works for creating roles/policies. Cannot modify `vocareum`/`voclabs`/`vocuser` resources. |

## Six Survival Principles

1. The budget is the program.
2. Concurrency limits are harder than budget.
3. The SCP is the real architecture.
4. Terraform state is fragile.
5. Every optional feature is a threat.
6. Test small or don't test at all.

## Environment

- **Credentials:** `source .env` before any AWS command. Credentials are session-scoped — no system changes.
- **Terraform:** `bin/terraform` (installed by `bin/voc-setup`).
- **Deploy directory:** `deploy/` contains the Terraform wrapper, state, and tfvars.
- **Upstream repo:** `genai-idp-terraform/` (cloned from awslabs, commit `affe799`).
- **Region:** `us-east-1` only. All resources must be in this region.
- **IAM:** "Allow All" at the assignment level. Only SCPs and Vocareum concurrency limits restrict.
- **All work stays inside `clAWS/`.** Do NOT write to `~/.aws/` or anywhere outside this directory.
