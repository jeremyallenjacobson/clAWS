# Agent Instructions — GenAI IDP POC on Constrained AWS

## What This Project Is

Deploying a minimal subset of [awslabs/genai-idp-terraform](https://github.com/awslabs/genai-idp-terraform.git) (Pattern 2: Bedrock LLM Processor) into a Vocareum-managed AWS sandbox with a **$2 USD hard budget**. The goal is a working web UI for intelligent document processing: upload a document, provide extraction instructions, view structured results.

## Key Documents (Read These First)

1. **PROCRV.md** — The foundational constraint analysis. Contains the full operating concept, Vocareum account limits, SCP details, budget analysis, blockers, assumptions, and the theory of programming (Section 8 survival principles). **Read this before doing anything.**
2. **SDP.md** — The Software Development Plan. Contains the phased execution plan (Phase 0–4), go/no-go gates, work packages with exact commands, decision trees for each blocker, fallback plans, risk register, and an execution checklist at the bottom.

## Current Status

- **PROCRV:** Complete.
- **SDP:** Complete.
- **Deployment:** Not started. No repo cloned, no patches applied, no infrastructure deployed.
- **Next step:** Execute SDP Phase 0 (Constraint Testing) — install Terraform, test CloudFront SCP, test Lambda limits, test Bedrock model access.

## Critical Constraints (Memorize These)

| Constraint | Value | Consequence of Violation |
|------------|-------|--------------------------|
| Budget | $2.00 total | Account unusable |
| Lambda | 3 (concurrency or count — unknown) | Session terminated, all resources destroyed |
| Bedrock tokens | 1,000 input / 1,000 output | Session terminated |
| EC2 | 2 concurrent (3 = fraud lock) | Session terminated / account locked |
| S3 | 10 GB aggregate | Session terminated |
| Region | us-east-1 only | SCP denies actions elsewhere |
| CloudFront CreateDistribution | Possibly SCP-denied | Web UI cannot deploy (critical blocker) |
| WAF | $5/month default — must disable | Exceeds budget immediately |
| KMS | $1/month — accepted (prorated <$0.01 for <1hr) | Half the budget if left running |

## Six Survival Principles (PROCRV Section 8)

1. The budget is the program.
2. Concurrency limits are harder than budget.
3. The SCP is the real architecture.
4. Terraform state is fragile.
5. Every optional feature is a threat.
6. Test small or don't test at all.

## Environment

- **Platform:** AWS CloudShell, `us-east-1`
- **CloudShell home is NOT persistent across Vocareum session terminations** — if concurrency limits are exceeded, the session dies and storage is wiped.
- **This git repo (clAWS)** is the persistence mechanism. Commit important artifacts here.
- **Terraform** must be installed manually in CloudShell (~80MB binary).
- **IAM:** Allow All at assignment level; only SCPs restrict.

## Execution Quick Reference

The SDP Appendix has a full checklist. The short version:

```
Phase 0: Test constraints (CloudFront, Lambda, Bedrock, KMS) — 10 min
Phase 1: Clone genai-idp-terraform, patch WAF, write tfvars — 15 min
Phase 2: terraform init + apply — 15-25 min
Phase 3: Validate web UI end-to-end — 20-30 min
Phase 4: terraform destroy — 5-10 min
```

Total: ~90 min. Must fit in a 4-hour lab session.
