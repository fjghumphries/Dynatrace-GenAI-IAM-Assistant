---
mode: agent
description: Validate the generated Terraform IAM configuration before applying.
---

Load the [`dt-iam-validation`](../../skills/dt-iam-validation/SKILL.md) skill (and its [`references/gotchas.md`](../../skills/dt-iam-validation/references/gotchas.md)) and validate [`outputs/`](../../outputs/):

1. Suggest the `terraform fmt -check`, `terraform validate`, and `terraform plan` commands.
2. Verify resource counts match the formulas in `dt-iam-generator` (boundaries/groups/bindings = `2B + 2A`).
3. Grep that each group is referenced by **exactly one** `dynatrace_iam_policy_bindings_v2` resource (see [bindings gotchas #21](../../skills/dt-iam-bindings/references/gotchas.md)).
4. Confirm `Admin User` is **not** referenced anywhere (see [policy-authoring gotchas #16](../../skills/dt-iam-policy-authoring/references/gotchas.md)).
5. Confirm every `Read Logs/Metrics/Spans/Events/BizEvents/Entities` policy is bound with a boundary (see [bindings gotchas #19](../../skills/dt-iam-bindings/references/gotchas.md)).
6. Confirm all BU/app/stage values are lowercase (see [validation gotchas #18](../../skills/dt-iam-validation/references/gotchas.md)).
7. Print a checklist of the post-apply verification steps from the skill (Effective Permissions, smoke test DQL queries).

Then, in the **same turn**, ask via a single `vscode_askQuestions` call:

- header: `next_step`
- question: "What next?"
- options: `Apply to tenant (/apply-iam)`, `Edit inputs (/add-bu, /add-app, /add-role, /add-policy)`, `Regenerate (/update-iam)`, `Done`

If the user picks a wizard, follow that wizard's instructions in the same turn. If `Done`, end the turn.
