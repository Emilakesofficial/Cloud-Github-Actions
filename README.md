#  GitHub Actions CI/CD with Terraform on AWS

A complete Infrastructure as Code (IaC) pipeline using **Terraform** and 
**GitHub Actions** to automate the provisioning of AWS resources with 
remote state management, environment-based deployments, and safety controls.

---

##  Table of Contents

- [What This Project Does](#what-this-project-does)
- [Architecture Overview](#architecture-overview)
- [Repository Structure](#repository-structure)
- [Remote Backend](#remote-backend)
- [GitHub Actions Workflows](#github-actions-workflows)
  - [CI Workflow](#ci-workflow)
  - [CD Workflow](#cd-workflow)
  - [Manual Operations Workflow](#manual-operations-workflow)
- [GitHub Secrets](#github-secrets)
- [GitHub Environments](#github-environments)
- [How to Run Each Workflow](#how-to-run-each-workflow)
- [How to Destroy Infrastructure Safely](#how-to-destroy-infrastructure-safely)
- [Infrastructure Resources](#infrastructure-resources)

---

## What This Project Does

This project demonstrates a production-ready CI/CD pipeline for Terraform 
on AWS using GitHub Actions. It automates the full infrastructure lifecycle:

Developer pushes code
│
▼
┌───────────────────┐ Pull Request ┌─────────────────┐
│ Feature Branch │ ───────────────────▶ │ CI Workflow │
└───────────────────┘ │ (plan only) │
└────────┬────────┘
│ Review & Merge
▼
┌─────────────────┐
│ CD Workflow │
│ (plan + apply) │
└────────┬────────┘
│
▼
┌─────────────────┐
│ AWS Resources │
│ (S3 Bucket) │
└─────────────────┘

Manual destroy runs ONLY via workflow_dispatch with environment approval.


### Key Principles

| Principle | Implementation |
|-----------|----------------|
| **Never apply on PR** | CI workflow runs plan only — never apply |
| **Apply only on merge** | CD workflow triggers on push to main |
| **Destroy is manual only** | Manual workflow with environment approval |
| **No local state** | S3 remote backend for all state storage |
| **No hardcoded credentials** | All secrets via GitHub Secrets |
| **State locking** | S3 native lock file prevents concurrent runs |

---

## Architecture Overview
┌─────────────────────────────────────────────────────────────┐
│ GitHub Repository │
│ │
│ ┌──────────────┐ ┌──────────────┐ ┌──────────────────┐ │
│ │Pull Request │ │Push to main │ │  workflow_dispatch │ │
│ │ to main │ │ │ │(apply / destroy) │ │
│ └──────┬───────┘ └──────┬───────┘ └────────┬─────────┘ │
│ │ │ │ │
│ ▼ ▼ ▼ │
│ ┌──────────────┐ ┌──────────────┐ ┌──────────────────┐ │
│ │terraform- │ │    terraform- │ │  terraform-manual- │ │
│ │ci.yml │     │      cd.yml │   │     operations.yml │ │
│ │             │                 │ │                  │ │     
│ │fmt          │  │init          │ │     apply job OR │ │
│ │init         │   validate      │ │      destroy job │ │
│ │validate     │  │plan -out     │ │   (user selects) │ │
│ │plan         │  │apply  │ │    │ │
│ │NO apply    │  │                  │approval required │ │
│ └──────────────┘ └──────┬───────┘ └────────┬─────────┘ │
└─────────────────────────────────────────────────────────────┘
│ │
▼ ▼
┌──────────────────────────────────────────────┐
│ AWS Account │
│ │
│ ┌─────────────────────────────────────────┐ │
│ │ S3: tf-state-github-actions-demo │ │
│ │ (Remote Backend — State Storage) │ │
│ │ terraform/state/terraform.tfstate │ │
│ │ terraform/state/terraform.tfstate.lock │ │
│ └─────────────────────────────────────────┘ │
│ │
│ ┌─────────────────────────────────────────┐ │
│ │ S3: terraform-managed-demo-adekunle │ │
│ │ (Managed Infrastructure Resource) │ │
│ └─────────────────────────────────────────┘ │
└──────────────────────────────────────────────┘


---

## Repository Structure
.
├── .github/
│ └── workflows/
│ ├── terraform-ci.yml # CI — runs on Pull Request
│ ├── terraform-cd.yml # CD — runs on push to main
│ └── terraform-manual-operations.yml # Manual apply or destroy
│
├── terraform/
│ ├── backend.tf # S3 remote backend configuration
│ ├── providers.tf # AWS provider and Terraform version
│ ├── variables.tf # All input variables
│ ├── main.tf # AWS resources (S3 demo bucket)
│ └── outputs.tf # Output values after apply
│
└── README.md

---

## Remote Backend

### What Remote Backend Is Used

This project uses an **AWS S3 backend** for Terraform remote state storage.

Why Remote Backend Is Required in GitHub Actions
GitHub Actions runners are temporary, ephemeral virtual machines.

Without Remote Backend:           With S3 Remote Backend:
──────────────────────────────    ──────────────────────────────────
Run 1: Runner starts              Run 1: Runner starts
       Terraform creates           │      terraform init
       terraform.tfstate ──────  │      Downloads state from S3
       Runner is DESTROYED         │      Creates/updates resources
       State file is LOST          │      Uploads new state to S3
                                   │      Runner is destroyed 
Run 2: Runner starts               │
       No state file found         Run 2: Runner starts
       Terraform thinks            │      terraform init
       nothing exists ──────     │      Downloads state from S3 
       Tries to create             │      Knows what already exists
       duplicate resources         │      Only changes what changed 
        DISASTER                 │      Uploads new state to S3
                                    SAFE AND CONSISTENT
Benefits of This Backend Setup
- State persists between GitHub Actions runs
- State is consistent across all team members
- State locking prevents concurrent apply conflicts
- State encryption protects sensitive infrastructure data
- S3 versioning allows state recovery if corrupted
- No risk of losing state when runner terminates
  
GitHub Actions Workflows
CI Workflow
File: .github/workflows/terraform-ci.yml
Purpose: Validate Terraform code quality on every Pull Request.
This gives the team confidence that code is correct BEFORE it merges.

Triggers:
- pull_request → main     (automatic)
- workflow_dispatch        (manual)
What It Does:
Step 1: Checkout Repository
        └── Downloads code onto the runner

Step 2: Setup Terraform
        └── Installs Terraform 1.9.0 on the runner

Step 3: Terraform Format Check (terraform fmt -check)
        └── Fails if any .tf file is not properly formatted
        └── Enforces consistent code style

Step 4: Terraform Init (terraform init)
        └── Connects to S3 remote backend
        └── Downloads AWS provider plugin
        └── Uses AWS credentials from GitHub Secrets

Step 5: Terraform Validate (terraform validate)
        └── Checks syntax and internal consistency
        └── Catches errors before touching AWS

Step 6: Terraform Plan (terraform plan)
        └── Shows what WOULD be created/changed/destroyed
        └── NO -out flag — plan is NOT saved for apply
        └── CI NEVER applies infrastructure

Rule:  CI will never run terraform apply

CD Workflow
File: .github/workflows/terraform-cd.yml
Purpose: Automatically deploy infrastructure when code merges to main.
Triggers:
- push → main             (automatic on merge)
- workflow_dispatch        (manual) 
- GitHub Environment: dev
What It Does:
Step 1: Checkout Repository

Step 2: Setup Terraform

Step 3: Terraform Init
        └── Connects to S3 backend
        └── Downloads existing state

Step 4: Terraform Validate

Step 5: Terraform Plan -out=tfplan    ← SAVED PLAN
        └── Saves plan to file named "tfplan"
        └── Guarantees apply executes EXACTLY what was planned

Step 6: Terraform Apply tfplan        ← APPLIES SAVED PLAN ONLY
        └── Applies the saved plan — no surprises
        └── -auto-approve is safe because plan was already reviewed in CI

Step 7: Show Terraform Outputs
        └── Prints created resource details to logs


Without -out=tfplan:                With -out=tfplan:
────────────────────────────        ─────────────────────────────
plan runs → sees state A            plan runs → sees state A
                                    plan saved to file
time passes...                      
someone changes infra manually      apply reads the SAVED plan
                                    executes exactly what was planned
apply runs → sees state B           no drift possible 
applies unexpected changes 
Rule:  CD only applies after merge to main

Manual Operations Workflow
File: .github/workflows/terraform-manual-operations.yml

Purpose: Manually run Terraform apply or destroy on demand.
This is the ONLY workflow that can destroy infrastructure.

Triggers:

- workflow_dispatch ONLY
- Never on push
- Never on pull_request
User Input:
When triggering manually, user must choose:
┌─────────────────────────────────┐
│ Choose Terraform operation:     │
│                                 │
│ ○ apply    ← default            │
│ ○ destroy                       │
└─────────────────────────────────┘
Job Structure:
workflow_dispatch (action = apply OR destroy)
         │
         ├──── if action == "apply"  ──▶  terraform-apply job
         │                                 environment: dev
         │                                 ├── init
         │                                 ├── validate
         │                                 ├── plan -out=tfplan
         │                                 └── apply tfplan
         │
         └──── if action == "destroy" ──▶  terraform-destroy job
                                           environment: production
                                           ├── init              
                                           ├── plan -destroy     ← see blast radius
                                           └── destroy -auto-approve
Safety Controls:
Safety Layer - How It Works
- Manual trigger only	workflow_dispatch — never runs automatically
- User must choose - Must explicitly select "destroy" from dropdown
- Environment approval - production environment requires reviewer approval
- Destroy plan first shows exactly what will be deleted before destroy runs
- Separate jobs - Apply and destroy are completely separate jobs
Environments Used:

Job	Environment	Protection
Apply - dev	-> Optional reviewers
Destroy - production -> Required reviewer approval

GitHub Secrets
What Secrets Are Required
Navigate to: Repository → Settings → Secrets and Variables → Actions

Secret Name	Description	Example Value
AWS_ACCESS_KEY_ID - AWS IAM user access key ID	AKIAIOSFODNN7EXAMPLE
AWS_SECRET_ACCESS_KEY - AWS IAM user secret access key	wJalrXUtnFEMI/K7MDENG/...
AWS_REGION - AWS region for deployment	us-east-1

How Secrets Are Used
Secrets are injected as environment variables at the workflow level:
YAML
env:
  AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
  AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
  AWS_REGION: ${{ secrets.AWS_REGION }}
The AWS Terraform provider and AWS CLI automatically read these standard environment variable names for authentication.

Security Properties:
- Secrets are encrypted at rest in GitHub
- Secret values are NEVER printed in logs (masked as ***)
- Secrets are not accessible to forked repositories
- No credentials are hardcoded in any workflow or Terraform file
- Secrets are only available to workflows in this repository
GitHub Environments
Environment	Used By	Protection
dev	CD workflow, Manual apply	Optional reviewers,
production -> Manual destroy ONLY, Required reviewer approval.

Setting Up Environments
GitHub Repository
└── Settings
    └── Environments
        ├── dev
        │   └── (optional) Add required reviewers
        └── production
            └──  Required reviewers → add your GitHub username
            
How to Run Each Workflow
CI Workflow — Automatic
1. Create a feature branch
   git checkout -b feature/your-change

2. Make changes to terraform/ files

3. Push your branch
   git push origin feature/your-change

4. Open a Pull Request → main on GitHub
   → CI workflow triggers automatically
   → All steps must pass before merging
   
CI Workflow — Manual
GitHub Repository
└── Actions
    └── Terraform CI
        └── Run workflow
            └── Branch: main (or any branch)
                └── Run workflow 
                
CD Workflow — Automatic
1. Merge your Pull Request to main
   → CD workflow triggers automatically
   → Terraform plan runs
   → Terraform apply runs
   → Infrastructure is deployed to AWS

CD Workflow — Manual
GitHub Repository
└── Actions
    └── Terraform CD
        └── Run workflow
            └── Branch: main
                └── Run workflow 
Manual Apply
GitHub Repository
└── Actions
    └── Terraform Manual Operations
        └── Run workflow
            ├── Branch: main
            ├── Action: apply    # select from dropdown
            └── Run workflow 
            
Manual Destroy
GitHub Repository
└── Actions
    └── Terraform Manual Operations
        └── Run workflow
            ├── Branch: main
            ├── Action: destroy  # select from dropdown
            └── Run workflow 
            
  NOTE: Workflow waits for approval
    → GitHub sends notification to required reviewer
    → Reviewer goes to Actions → Reviews pending deployments
    → Reviewer approves or rejects
    → Only after approval does destroy execute

    
How to Destroy Infrastructure Safely
Destroying infrastructure is a serious operation.
This project has multiple safety layers to prevent accidental destruction.

Step-by-Step Safe Destroy Process
Step 1: Confirm what exists
────────────────────────────────────────────────────
Go to AWS Console → S3 → verify the demo bucket exists
OR
aws s3 ls | grep terraform-managed-demo

Step 2: Trigger Manual Destroy
────────────────────────────────────────────────────
GitHub Repository
└── Actions → Terraform Manual Operations
    └── Run workflow
        ├── action: destroy
        └── Run workflow

Step 3: Workflow pauses for approval
────────────────────────────────────────────────────
GitHub sends notification to required reviewer
Reviewer sees destroy plan (-destroy output)
Reviewer can see EXACTLY what will be deleted
Reviewer approves → destroy proceeds
Reviewer rejects → nothing is destroyed

Step 4: Destroy executes
────────────────────────────────────────────────────
terraform destroy -auto-approve runs
All managed resources are deleted
State file is updated in S3

Step 5: Verify destruction
────────────────────────────────────────────────────
aws s3 ls | grep terraform-managed-demo
→ Should return nothing (bucket deleted)

What Destroy Will Remove
Resources managed by Terraform (will be destroyed):
├── aws_s3_bucket.demo_bucket
├── aws_s3_bucket_versioning.demo_bucket_versioning
├── aws_s3_bucket_server_side_encryption_configuration.demo_bucket_encryption
└── aws_s3_bucket_public_access_block.demo_bucket_public_access_block

Resources NOT managed by Terraform (will NOT be destroyed):
├ It must be deleted manually if needed.
