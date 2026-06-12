# **Exercise 8.2 — OIDC Federation** **\+ Secrets Manager**

**Course:** Optimizaciones y Desempeño — Cloud Deployment Automation  
**Session:** 8 — June 11, 2026  
**Time allowed:** 30 minutes  
**Submission:** Initialize a new repository called oyd-exercise-8-2 and commit/push everything into it. Submit the repository URL only.

# Context

Your CI pipeline currently authenticates to AWS using a long-lived access key stored as a GitHub Secret. You will replace that with keyless authentication via GitHub's OIDC provider — GitHub Actions proves its identity using a short-lived token, and AWS grants access only if the token comes from your specific repository and branch. You will also store a database connection string in AWS Secrets Manager so the application can retrieve it at startup instead of reading it from environment variables.

The following starter code gives you a minimal Terraform configuration and a GitHub Actions workflow that uses stored keys. Your task is to wire in OIDC authentication and Secrets Manager, then verify the CI workflow authenticates without any stored AWS credentials.

### main.tf

terraform {  
  required\_providers {  
    aws \= {  
      source  \= "hashicorp/aws"  
      version \= "\~\> 5.0"  
    }  
  }  
  required\_version \= "\>= 1.6"  
}

provider "aws" {  
  region \= "us-east-1"  
}

### .github/workflows/ci.yml (starter — uses stored keys)

name: CI

on:  
  push:  
    branches: \[main\]

permissions:  
  contents: read

jobs:  
  validate:  
    runs-on: ubuntu-latest  
    steps:  
      \- uses: actions/checkout@v4

      \- name: Configure AWS credentials  
        uses: aws-actions/configure-aws-credentials@v4  
        with:  
          aws-access-key-id: ${{ secrets.AWS\_ACCESS\_KEY\_ID }}  
          aws-secret-access-key: ${{ secrets.AWS\_SECRET\_ACCESS\_KEY }}  
          aws-region: us-east-1

      \- uses: hashicorp/setup-terraform@v3

      \- run: terraform init  
      \- run: terraform validate

# Setup

## Prerequisites

* Terraform \>= 1.6 installed  
* AWS credentials configured locally (for terraform apply)  
* A GitHub account and a new public repository called oyd-exercise-8-2  
* Your GitHub organization/username handy — you will embed it in the OIDC trust policy

## Repository structure

oyd-exercise-8-2/  
├── main.tf            (add OIDC provider, IAM role, Secrets Manager here)  
├── outputs.tf  
├── .github/  
│   └── workflows/  
│       └── ci.yml     (update to use role-to-assume)  
└── evidence/  
    └── ci-run.png     (screenshot of successful Actions run)

# Tasks

## Task 1 — Register the GitHub OIDC provider

Add an aws\_iam\_openid\_connect\_provider resource to main.tf:

* url \= "https://token.actions.githubusercontent.com"  
* client\_id\_list \= \["sts.amazonaws.com"\]  
* thumbprint\_list \= \["6938fd4d98bab03faadb97b34396831e3780aea1"\]

## Task 2 — Create the CI runner role with OIDC trust

Add an aws\_iam\_role.ci\_runner with an assume\_role\_policy that:

* Uses Principal \= { Federated \= aws\_iam\_openid\_connect\_provider.github.arn }  
* Sets Action \= "sts:AssumeRoleWithWebIdentity"  
* Adds a Condition using StringEquals on token.actions.githubusercontent.com:sub equal to repo:\<your-org\>/\<your-repo\>:ref:refs/heads/main  
* Adds a second Condition using StringEquals on token.actions.githubusercontent.com:aud equal to sts.amazonaws.com

Attach a policy that grants the role terraform validate access at minimum (read access to the resources it manages). A minimal set: sts:GetCallerIdentity plus any IAM read action needed for plan.

Important: use StringEquals, not StringLike. A wildcard in the sub claim would allow any repository to assume the role.

## Task 3 — Store a secret in Secrets Manager

Add an aws\_secretsmanager\_secret and an aws\_secretsmanager\_secret\_version to main.tf:

* Secret name: \<project\>-db-password (use a variable or local for the prefix)  
* Secret value: any placeholder string, e.g. "changeme-in-rotation"  
* Add ignore\_changes \= \[secret\_string\] in a lifecycle block so future rotations do not cause Terraform drift

Expose the secret ARN as an output in outputs.tf.

## Task 4 — Apply and update the CI workflow

Run:

terraform init  
terraform apply \-auto-approve

Then update .github/workflows/ci.yml to replace the stored-key step with keyless auth:

* Remove aws-access-key-id and aws-secret-access-key inputs from the configure-aws-credentials step  
* Add role-to-assume: \<ci\_runner\_role\_arn\> (use the Terraform output value)  
* Set the top-level permissions block to include id-token: write so the workflow can request an OIDC token

Commit all Terraform files and the updated workflow, then push to the main branch to trigger CI.

## Task 5 — Capture evidence

After the GitHub Actions run completes successfully:

1. Open the workflow run in the GitHub Actions UI  
2. Click the Configure AWS Credentials step and confirm it shows the OIDC token exchange (no access key input)  
3. Take a screenshot of the passing run and save it as evidence/ci-run.png  
4. Commit the screenshot to the repository

# Acceptance Criteria

* aws\_iam\_openid\_connect\_provider exists with url \= https://token.actions.githubusercontent.com  
* Trust policy uses StringEquals (not StringLike) on the sub claim  
* sub condition value matches repo:\<org\>/\<repo\>:ref:refs/heads/main exactly — no wildcards  
* aud condition value is sts.amazonaws.com  
* aws\_secretsmanager\_secret exists; secret version has a non-empty value; lifecycle ignore\_changes includes secret\_string  
* Secret ARN is exposed as a Terraform output  
* ci.yml contains role-to-assume and does not contain aws-access-key-id or aws-secret-access-key  
* ci.yml top-level permissions block includes id-token: write  
* evidence/ci-run.png shows a green (passing) GitHub Actions run with the OIDC configure-credentials step visible

