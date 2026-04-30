---
mode: agent
description: Guided walkthrough — OAuth client setup, env vars, terraform init/plan/apply, and post-apply verification.
---

You are running the **`/apply-iam` wizard**. Walk the user through applying the generated [`outputs/`](../../outputs/) Terraform to their Dynatrace tenant.

## Steps

### 1. Pre-flight check (run `/validate-iam` checks inline)

- Confirm `outputs/` exists and contains `.tf` files.
- Confirm each group is referenced by exactly ONE `dynatrace_iam_policy_bindings_v2` resource (see [bindings gotchas #21](../../skills/dt-iam-bindings/references/gotchas.md)):
  ```bash
  grep -E "group += dynatrace_iam_group\." outputs/bindings_*.tf | sort | uniq -c | sort -rn
  ```
- Confirm `Admin User` is NOT referenced anywhere in `outputs/`.

### 2. Walk through OAuth client setup

Ask the user whether they already have an OAuth client. If not, give them the steps:

> In Dynatrace Account Management → Identity & access management → OAuth clients → Create. Required scopes:
> - `account-idm-read`
> - `account-idm-write`
> - `iam-policies-management`
> - `account-env-read`

Capture (do NOT log secrets to the chat — ask them to paste into a `.env` file):
- `DT_CLIENT_ID`
- `DT_CLIENT_SECRET`
- `DT_ACCOUNT_ID` (Account UUID, no `urn:dtaccount:` prefix)
- `DYNATRACE_ENV_URL` (e.g. `https://abc12345.live.dynatrace.com`)
- `environment_id` (e.g. `abc12345`)

### 3. Set up env vars

Suggest creating `outputs/.env` (already in `.gitignore`):

```bash
export DT_CLIENT_ID="dt0s02..."
export DT_CLIENT_SECRET="dt0s02..."
export DT_ACCOUNT_ID="00000000-0000-0000-0000-000000000000"
export DYNATRACE_ENV_URL="https://<env>.live.dynatrace.com"

# Map to Terraform input variables
export TF_VAR_account_id="$DT_ACCOUNT_ID"
export TF_VAR_environment_id="<env>"
```

Then `source outputs/.env`.

### 4. Init / plan / apply

```bash
cd outputs
terraform init
terraform plan -out=tfplan
```

**Pause.** Have the user review the plan. Confirm the resource counts match expectations:
- `2B + 2A` boundaries
- `2B + 2A` groups
- `2B + 2A` bindings
- 14 policies total

Once confirmed:
```bash
terraform apply tfplan
```

### 5. Post-apply verification

Walk through the checklist from [`dt-iam-validation/SKILL.md`](../../skills/dt-iam-validation/SKILL.md):

1. **Account Management → Identity & Access → Groups** — confirm each group exists with the expected policies.
2. Open a sample group → **Effective permissions** — confirm `storage:logs:read`, `storage:metrics:read`, etc. appear with the expected boundary.
3. Add a real test user to one BU and one App group.
4. Smoke test as that user (use the [`dt-for-ai`](../../skills/dt-for-ai/SKILL.md) skill bridge for DQL):
   ```dql
   fetch logs | limit 5
   ```
   Should return only records matching the boundary.
5. Try editing a setting outside the BU scope — must fail with 403.

### 6. Common failure modes

If the user reports a problem, branch to [`dt-iam-validation/SKILL.md`](../../skills/dt-iam-validation/SKILL.md) → "Common failure modes" — most issues map to:
- 403 everywhere → multiple binding resources for one group ([bindings gotchas #21](../../skills/dt-iam-bindings/references/gotchas.md))
- "No bucket permissions for table X" → missing default `Read <X>` policy ([bindings gotchas #19](../../skills/dt-iam-bindings/references/gotchas.md))
- Settings write outside BU → `Admin User` was bound somewhere ([policy-authoring gotchas #16](../../skills/dt-iam-policy-authoring/references/gotchas.md))

## Constraints

- NEVER print credentials to the chat — only to `outputs/.env`.
- NEVER run `terraform apply` without an explicit user confirmation after `terraform plan`.
- NEVER use `terraform apply -auto-approve`.
- Do NOT modify any `.tf` file in this wizard — it's apply-only. For changes, route to `/update-iam`, `/add-bu`, or `/add-app`.

## After apply

Once step 5 (verification) is complete, in the **same turn**, ask via a single `vscode_askQuestions` call:

- header: `next_step`
- question: "What next?"
- options: `Edit inputs and re-apply (/add-bu, /add-app, /add-role, /add-policy)`, `Re-validate (/validate-iam)`, `Done`

If the user picks a wizard, follow that wizard's instructions in the same turn. If `Done`, end the turn.
