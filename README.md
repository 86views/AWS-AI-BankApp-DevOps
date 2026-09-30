# DevSecOps Banking Application

A Spring Boot 3 / Java 21 banking application deployed through a fully automated, security-gated CI/CD pipeline on AWS — built to demonstrate production-grade DevSecOps practices: keyless authentication, immutable artifacts, layered security scanning, and zero long-lived credentials anywhere in the stack.

**Live health check:**
```bash
curl http://<ec2-public-ip>:8080/actuator/health
# {"status":"UP"}
```

## Architecture

```
GitHub Actions (OIDC) ──assume role──▶ AWS IAM Role
        │
        ├─▶ Amazon ECR (immutable, tag = git SHA)
        │
        └─▶ AWS SSM Send-Command ──▶ EC2 Instance
                                        ├── bankapp (Spring Boot, Docker)
                                        ├── MySQL 8.0
                                        └── Ollama (local LLM integration)
```

- **No long-lived AWS credentials anywhere.** GitHub Actions authenticates via OpenID Connect (OIDC), assuming a narrowly-scoped IAM role per workflow run.
- **No SSH.** Deployment to EC2 happens via AWS Systems Manager `Send-Command` — no open port 22, no key pairs to manage or leak.
- **No Secrets Manager.** Application configuration (DB credentials, service URLs) is stored in SSM Parameter Store as `SecureString`, decrypted with the AWS-managed KMS key.
- **Immutable image tags.** Every image is tagged with its git SHA and pushed to an immutable ECR repository — `:latest` is never used, and a tag can never be silently overwritten.

## The 9 Security Gates

Every push to `main` runs through nine sequential gates before the app reaches production. A failure at any gate stops the pipeline — nothing insecure ships.

| # | Gate | Tool | Purpose |
|---|------|------|---------|
| 1 | Secret Scan | Gitleaks | Blocks commits containing credentials, keys, or tokens |
| 2 | Lint | Checkstyle | Enforces code style consistency |
| 3 | SAST | Semgrep | Static analysis for Java, secrets, and Dockerfile misconfigurations |
| 4 | SCA | OWASP Dependency-Check | Flags known-vulnerable dependencies against the NVD database |
| 5 | Build | Maven | Compiles and packages the application |
| 6 | Container Build | Docker | Builds the runtime image on a multi-stage `eclipse-temurin:21-jre-alpine` base |
| 7 | Container Scan | Trivy | Fails the build on any HIGH/CRITICAL vulnerability, OS or application-level |
| 8 | Deploy | AWS SSM Send-Command | Keyless, SSH-free deployment to the EC2 host |
| 9 | DAST | OWASP ZAP Baseline | Live, black-box scan of the running application |

## Tech Stack

- **Application:** Spring Boot 3.5, Java 21, Thymeleaf, Spring Data, Spring Security
- **Database:** MySQL 8.0
- **AI integration:** Ollama (local LLM), Spring AI
- **Infrastructure:** Terraform (modular: IAM, networking, EC2, ECR)
- **CI/CD:** GitHub Actions, OIDC federation
- **Container:** Docker, Docker Compose, Amazon ECR (immutable)
- **Security tooling:** Gitleaks, Checkstyle, Semgrep, OWASP Dependency-Check, Trivy, OWASP ZAP
- **Runtime:** AWS EC2, AWS Systems Manager (Parameter Store + Session Manager + Send-Command)

## Repository

[`86views/AWS-AI-BankApp-DevOps`](https://github.com/86views/AWS-AI-BankApp-DevOps)

## Running Locally

```bash
git clone https://github.com/86views/AWS-AI-BankApp-DevOps.git
cd AWS-AI-BankApp-DevOps
docker compose up -d --build
curl http://localhost:8080/actuator/health
```

## Infrastructure

All infrastructure is provisioned via Terraform, split into modules:

- **`modules/iam`** — GitHub OIDC provider trust, the CI/CD role (scoped to this repo and branch), and the EC2 instance role
- **`modules/network`** — VPC, subnet, security groups
- **`modules/ec2`** — the application host, with an SSM-managed instance profile (no SSH)
- **`modules/ecr`** — the immutable container registry

```bash
cd terraform/environments/dev
terraform init
terraform plan
terraform apply
```

## Notable Engineering Decisions

- **OIDC trust policy** scopes `sts:AssumeRoleWithWebIdentity` to the exact repository and branch via the token's `sub` claim, rather than trusting the whole GitHub organization.
- **SSM IAM permissions are split by action**, since `ssm:GetCommandInvocation` and `ssm:ListCommandInvocations` do not support resource-level scoping in AWS IAM and must be granted on `"*"`, while `ssm:SendCommand` is scoped to specific instance and document ARNs.
- **Trivy authenticates to the public ECR mirror** (`public.ecr.aws`) before pulling its vulnerability database, avoiding the anonymous pull rate limit that public CI runners frequently hit.
- **The NVD dependency-check cache is restored and saved independently of job success**, so a slow first-time NVD database download isn't lost if a later gate fails.

## Security Posture

As of the latest pipeline run: **0 CRITICAL, 0 HIGH** vulnerabilities across the base OS image and application dependencies (Trivy), all managed via pinned dependency versions in `pom.xml` (Spring Boot 3.5.16, Jackson 2.21.6).

---

*Built as a portfolio project to demonstrate keyless cloud authentication, immutable artifact pipelines, and defense-in-depth security scanning in a real, deployed application — not a toy example.*
