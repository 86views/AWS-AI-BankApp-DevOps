# Troubleshooting Log — DevSecOps Pipeline Build-Out

This documents real issues hit while building and debugging the CI/CD pipeline for this project, along with root causes and fixes. Kept as a reference for future debugging, and as a record of what "keyless, security-gated CI/CD" actually looks like to build in practice — not just the finished YAML.

---

## 1. GitHub Actions OIDC: `Not authorized to perform sts:AssumeRoleWithWebIdentity`

**Symptom:** every `configure-aws-credentials` step failed immediately, before any AWS API call happened.

**Root cause:** the IAM role's trust policy `StringLike` condition on `token.actions.githubusercontent.com:sub` didn't match the actual claim GitHub was sending — an early version of the Terraform had the wrong branch hardcoded.

**Fix:** decoded the real OIDC token in a debug step to see the exact `sub` claim GitHub was issuing, then compared it character-for-character against the IAM trust policy's `StringLike` values:
```bash
curl -sSL -H "Authorization: bearer $ACTIONS_ID_TOKEN_REQUEST_TOKEN" \
  "$ACTIONS_ID_TOKEN_REQUEST_URL&audience=sts.amazonaws.com" \
  | jq -r '.value' | cut -d. -f2 | base64 -d | jq '{sub, aud, ref, event_name}'
```
**Lesson:** never guess at OIDC `sub` claim formats — decode the actual token. It's the fastest way to rule out a trust policy mismatch versus a workflow-side misconfiguration (missing `permissions: id-token: write`, wrong `role-to-assume`).

---

## 2. Trivy: `TOOMANYREQUESTS: Data limit exceeded`

**Symptom:** the Trivy container scan step failed instantly on `trivy image`, before scanning anything — it couldn't even download its vulnerability database.

**Root cause:** anonymous pulls from the AWS public ECR mirror (`public.ecr.aws`), which hosts Trivy's DB, are rate-limited. Enough public CI runners worldwide share that quota that unauthenticated pulls fail regularly.

**Fix:** authenticate to the mirror before scanning:
```bash
aws ecr-public get-login-password --region us-east-1 \
  | docker login --username AWS --password-stdin public.ecr.aws
```
This required adding `ecr-public:GetAuthorizationToken` and `sts:GetServiceBearerToken` to the GitHub Actions IAM role — an account-level permission, since `ecr-public` auth tokens can't be scoped to a specific resource ARN.

**Lesson:** "anonymous and public" doesn't mean "unlimited." Authenticated requests get a materially higher quota even against a public registry.

---

## 3. Dependency CVEs — multiple rounds

**Symptom:** Gate 7 (Trivy container scan) repeatedly failed on real HIGH/CRITICAL findings in application dependencies, across several rounds as fixes were applied.

**Root cause:** the project had drifted behind on patch versions for Spring Boot, Spring Security, Spring Data, Thymeleaf, Tomcat, and Jackson — each with known CVEs (SSTI in Thymeleaf, auth bypass in Spring Security, arbitrary code execution in Jackson-databind).

**Fix, in stages:**
1. Bumped the Spring Boot parent from `3.4.13` → `3.5.16`, which pulled in matching, patched versions of Spring Framework, Security, Data, and Tomcat together.
2. Jackson needed an explicit override — Spring Boot's own dependency management pinned an older Jackson version regardless of the parent bump:
   ```xml
   <jackson-bom.version>2.21.6</jackson-bom.version>
   ```
3. One CVE (`CVE-2026-68497`) was disclosed *after* `2.21.4` shipped, requiring a further bump to `2.21.6` once that fix was published.

**Lesson:** a major framework version bump doesn't always cascade to every transitive dependency — check what's still flagged after the "obvious" fix, and expect to iterate. Also: `mvn dependency:tree` (run inside the same JDK 21 container the Dockerfile uses, no local JDK required) is the fastest way to confirm a version override actually took effect, rather than trusting the `pom.xml` alone.

---

## 4. ECR push denied: doubled registry path

**Symptom:** `denied: ... not authorized to perform: ecr:InitiateLayerUpload ... because no identity-based policy allows the ecr:InitiateLayerUpload action` — despite the IAM policy clearly granting that action.

**Root cause:** the `ECR_REPOSITORY` GitHub secret was set to the *full registry URL* (`173331852212.dkr.ecr.us-east-1.amazonaws.com/devsecops-bankapp-bankapp`) instead of just the bare repository name. The workflow builds the image reference as `${{ steps.login-ecr.outputs.registry }}/${{ secrets.ECR_REPOSITORY }}`, and `login-ecr`'s `registry` output *already includes* the full registry hostname — so the final reference doubled the registry, producing a nonsense repository path that didn't match the ARN scoped in IAM.

**Fix:** set `ECR_REPOSITORY` to just `devsecops-bankapp-bankapp`.

**Lesson:** an `AccessDenied` error doesn't always mean the IAM policy is wrong — check that the resource being requested is actually the resource you *think* you're requesting. Always print the fully-resolved `IMAGE_REF` in the logs before trusting a permissions diagnosis.

---

## 5. SSM: `GetCommandInvocation` denied despite a scoped policy

**Symptom:** `ssm:SendCommand` succeeded (a Command ID was returned), but polling for its result with `ssm:GetCommandInvocation` was denied — even though both actions were in the same IAM statement.

**Root cause:** `ssm:GetCommandInvocation` and `ssm:ListCommandInvocations` do not support resource-level permissions in AWS IAM — they require `Resource: "*"`. Scoping them to specific instance/document ARNs (which works fine for `SendCommand`) causes AWS to silently deny them.

**Fix:** split the single IAM statement into two — `SendCommand` keeps scoped ARNs, `GetCommandInvocation`/`ListCommandInvocations` get their own statement with `Resource: "*"`.

**Lesson:** not every AWS action in a "related" group supports the same permission model. When IAM denies an action that's clearly listed in the policy, check the AWS documentation's "Actions, resources, and condition keys" table for that specific service — some actions are simply incompatible with resource-level scoping.

---

## 6. SSM deploy script corruption: `pipefailncd`

**Symptom:** the deploy script failed with a garbled error (`set: Illegal option -o pipefailncd`) and `docker login` parsed as an invalid flag (`unknown shorthand flag: 'i'`) — as if the entire multi-line script had been mashed onto one line.

**Root cause, two layered bugs:**
1. The script was sent to `aws ssm send-command` using CLI shorthand syntax (`--parameters "commands=$(...)"`), which does not correctly handle a JSON-escaped multi-line string — actual newlines were corrupted into literal `n` characters, merging separate lines together.
2. `AWS-RunShellScript` executes with `/bin/sh` (dash) by default on this AMI, which doesn't support `set -o pipefail` — a bash-only option.

**Fix:**
- Built the SSM parameters as a real JSON file using `jq`, passed via `--parameters file://params.json`, instead of CLI shorthand string interpolation.
- Added `#!/bin/bash` as the first line of the script — the SSM agent respects a shebang and switches interpreters accordingly.

**Lesson:** AWS CLI's shorthand parameter syntax (`key=value`) is fine for simple scalars, but breaks down for anything containing embedded newlines, quotes, or special characters. Build a real JSON payload instead of trying to escape your way through shorthand syntax.

---

## Summary

None of these were "one root cause" problems — OIDC trust, IAM resource-level permission quirks, dependency drift, and shell/CLI encoding edge cases are all genuinely different failure classes, and each needed a different debugging approach: decoding a token, reading AWS's IAM action reference, running `dependency:tree` inside a container, and printing the fully-resolved values before trusting an error message at face value.
