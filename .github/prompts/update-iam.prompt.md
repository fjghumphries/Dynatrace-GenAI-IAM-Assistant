---
mode: agent
description: Re-generate outputs/ after editing inputs.yaml.
---

The customer input in [`inputs.yaml`](../../inputs.yaml) has changed. Regenerate the Terraform IAM configuration in [`outputs/`](../../outputs/) so it matches the new spec exactly.

Steps:

1. Diff the current `outputs/variables.tf` against the new `inputs.yaml` to identify added/removed BUs, applications, or stages.
2. Load the [`dt-iam-generator`](../../skills/dt-iam-generator/SKILL.md) skill.
3. Update only the resources that need to change. Preserve unrelated content.
4. Update `outputs/docs/policies.txt`, `outputs/docs/groups.txt`, `outputs/docs/bindings.txt`, and `outputs/README.md` so all counts stay accurate.
5. Run `terraform fmt` (mentally) to keep style consistent.
6. Report the net change (e.g. "+1 BU, +2 applications → +6 boundaries, +6 groups, +6 bindings").

Then, in the **same turn**, ask via a single `vscode_askQuestions` call:

- header: `next_step`
- question: "What next?"
- options: `Validate (/validate-iam)`, `Apply to tenant (/apply-iam)`, `Edit inputs more (/add-bu, /add-app, /add-role, /add-policy)`, `Done`

If the user picks a wizard, follow that wizard's instructions in the same turn (no new prompt needed). If `Done`, end the turn.
