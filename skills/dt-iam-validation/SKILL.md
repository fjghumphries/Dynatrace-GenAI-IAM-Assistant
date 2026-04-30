---
name: dt-iam-validation
description: Validate generated Dynatrace IAM Terraform configurations before and after apply. Covers terraform fmt/validate/plan, the IAM policy validation API, OAuth client setup, and effective-permissions verification for real users. Load when the user wants to verify, plan, apply, or troubleshoot a generated configuration.
license: Apache-2.0
---

# Dynatrace IAM Validation

Use to plan, apply, validate, and verify a generated IAM configuration.

## References (load on demand)

| Reference | When to load |
|---|---|
| [references/gotchas.md](references/gotchas.md) | Always — `terraform apply` ≠ effective permissions, lowercase rule, scaling limits, pre-apply checks |

## Pre-apply checks (run from `outputs/`)

```bash
terraform fmt -check
terraform validate
terraform plan -out=tfplan
```

Then review:
- Number of `dynatrace_iam_policy_boundary` resources = `2 × BUs + 2 × Apps`
- Number of `dynatrace_iam_group` resources = `2 × BUs + 2 × Apps`
- Number of `dynatrace_iam_policy_bindings_v2` resources = `2 × BUs + 2 × Apps`
- **Each group is referenced by exactly ONE binding resource** — see [bindings gotchas #21](../dt-iam-bindings/references/gotchas.md)

Quick sanity grep:

```bash
grep -E "group += dynatrace_iam_group\." bindings_*.tf | sort | uniq -c | sort -rn
```

Any group appearing more than once is a bug — consolidate into a single resource.

## OAuth client (one-time setup)

Required scopes:

| Scope | Why |
|---|---|
| `account-idm-read` | View users/groups |
| `account-idm-write` | Manage groups |
| `iam-policies-management` | Manage policies/boundaries/bindings |
| `account-env-read` | Read environments |

## Environment variables

Provider authentication uses `DT_*`. Terraform inputs use `TF_VAR_*`.

```bash
export DT_CLIENT_ID="dt0s02.XXXX"
export DT_CLIENT_SECRET="dt0s02.XXXX...."
export DT_ACCOUNT_ID="00000000-0000-0000-0000-000000000000"
export DYNATRACE_ENV_URL="https://<env>.live.dynatrace.com"

export TF_VAR_account_id="$DT_ACCOUNT_ID"
export TF_VAR_environment_id="<env>"
```

## Permission identifier validation (before authoring)

```
POST {baseUrl}/iam/v1/repo/account/{accountId}/policies/validation
{
  "name": "test",
  "statementQuery": "ALLOW <namespace>:<resource>:<verb>;"
}
```

400 → invalid identifier. Always run for any new permission you haven't used before — see [policy-authoring gotchas #17](../dt-iam-policy-authoring/references/gotchas.md).

## Effective-permissions verification (post-apply)

`terraform apply` success ≠ correct effective permissions. After apply:

1. **Account Management → Identity & Access → Groups** — confirm each group has the expected policies.
2. Open a group → **Effective permissions** — confirm `storage:logs:read`, `storage:metrics:read`, etc. appear with the expected boundary.
3. Add a real test user to one BU and one App group.
4. In Notebooks, run `fetch logs` — should return only records matching the boundary.
5. Try editing a setting outside the boundary scope — must fail with 403.

## Smoke test queries

```dql
fetch logs
| filter dt.security_context == "<wrong-bu>-prod-app-x"
| limit 1
```

Should return zero results for users scoped to a different BU.

```dql
fetch dt.system.events
| filter event.kind == "SETTINGS_CHANGE"
| filter user.email == "<test-user>"
```

Confirms whether settings writes the user attempted were accepted.

## Common failure modes

| Symptom | Diagnosis |
|---|---|
| `403 Forbidden` for a known-permitted action | Multiple binding resources for one group — see [bindings gotchas #21](../dt-iam-bindings/references/gotchas.md) |
| `No bucket permissions for table <X>` | Missing default `Read <X>` policy with boundary — see [bindings gotchas #19](../dt-iam-bindings/references/gotchas.md) |
| Boundary shows but doesn't restrict | Wrong namespace (`storage:` vs `settings:`) — see [bindings gotchas #2/#8](../dt-iam-bindings/references/gotchas.md) |
| Settings write works outside BU scope | `Admin User` is bound — see [policy-authoring gotchas #16](../dt-iam-policy-authoring/references/gotchas.md) |
| `terraform plan` keeps drifting | Group has policies set out-of-band; ensure `lifecycle { ignore_changes = [permissions] }` is on every group — see [gotchas #6](references/gotchas.md) |

## Rollback

Bindings are managed atomically per group. If a binding resource is misconfigured, removing the resource entirely (and re-applying) clears all policies for that group — users will lose all access until re-bound. Prefer in-place edits over delete/re-create.
