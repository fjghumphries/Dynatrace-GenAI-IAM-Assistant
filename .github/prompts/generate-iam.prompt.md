---
mode: agent
description: Generate the complete Terraform IAM configuration from inputs.yaml into outputs/.
---

Read [`inputs.yaml`](../../inputs.yaml) and extract:
- `business_units`, `applications` (derived from each BU's list), `stages`
- The **optional** `policies:` and `roles:` sections

Load the [`dt-iam-generator`](../../skills/dt-iam-generator/SKILL.md) skill (and its [`references/`](../../skills/dt-iam-generator/references/)). **Always** load [`references/defaults.yaml`](../../skills/dt-iam-generator/references/defaults.yaml) — the default policy + role catalog — and merge it with any customer overrides from `inputs.yaml` BY NAME (customer wins). Then:

1. Mirror the structure of [`sample-outputs/`](../../sample-outputs/).
2. Write a complete Terraform configuration into [`outputs/`](../../outputs/), including:
   - All `.tf` files. Emit ONE `dynatrace_iam_group` resource and ONE `dynatrace_iam_policy_bindings_v2` resource per role in the merged catalog.
   - `outputs/docs/policies.txt`, `outputs/docs/groups.txt`, `outputs/docs/bindings.txt` with accurate counts (one section per role)
   - `outputs/README.md` (role table reflects the merged catalog, including any custom roles)
   - `outputs/terraform.tfvars.example`
3. Apply the [`dt-iam-bindings`](../../skills/dt-iam-bindings/SKILL.md) rule: ONE `dynatrace_iam_policy_bindings_v2` resource per group.
4. Apply the [`dt-iam-policy-authoring`](../../skills/dt-iam-policy-authoring/SKILL.md) rules: never bind `Admin User`; reject any custom policy with unconditional `settings:objects:write`; templated policies must contain at least one `${bindParam:...}`.
5. Run all schema validation listed in the generator skill's Pre-flight checklist (boundary keys exist; `app_data`/`app_settings` only in app roles; `{app}` token only in app roles; `params:` keys match `${bindParam:...}` placeholders).
6. If you discover a new gotcha, append a section to the relevant `skills/<skill>/references/gotchas.md`.

Show a summary of resources generated:
- Policies: P (default + templated + custom)
- Boundaries: 2B + 2A
- Groups: B · R_bu + A · R_app (list each role name)
- Bindings: same as groups

Then, in the **same turn**, ask via a single `vscode_askQuestions` call:

- header: `next_step`
- question: "What next?"
- options: `Validate (/validate-iam)`, `Apply to tenant (/apply-iam)`, `Edit inputs more (/add-bu, /add-app, /add-role, /add-policy)`, `Done`

If the user picks a wizard, follow that wizard's instructions in the same turn. If `Done`, end the turn.
