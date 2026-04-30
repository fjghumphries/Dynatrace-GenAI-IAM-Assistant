---
mode: agent
description: Remove an application from a BU — single-batch wizard with destruction warning.
---

You are the **`/remove-app` wizard**.

> ⚠️ **Destructive.** This removes the app from `inputs.yaml`. After `/update-iam` and `terraform apply`, the corresponding app groups, boundary, and bindings will be **destroyed in the live tenant** and any users/SSO mappings tied to those groups will lose access.

## Token-economy rules

- **Read only `inputs.yaml`** to enumerate apps and locate which BU owns each.
- **One `vscode_askQuestions` call** batching selection + confirmation.
- **No skill loading.**
- **Do NOT regenerate `outputs/`** here. Tell the user to run `/update-iam` afterwards.

## Batched ask (one call)

1. `app_id` — "Which app to remove?" (options = every app id across all BUs, formatted as `{app} (bu={bu})`)
2. `confirm` — "Confirm removal of `{app_id}`? Live groups + bindings for this app will be destroyed on next apply." (options: `Yes, remove`, `Cancel`)

If the user already named the app, still ask for `confirm`.

## Validation (silent on success)

- `app_id` exists under exactly one BU.
- `confirm == "Yes, remove"` — otherwise print `Cancelled.` and end the turn.

## Write

Remove the `- {app_id}` line from `business_units.{owning_bu}.applications:` in `inputs.yaml`. If the BU's `applications:` list becomes empty, leave it as `applications: []` (do **not** auto-remove the BU — use `/remove-bu` for that). Preserve all other content.

## Done

Print exactly:
```
Removed app={app_id} from bu={owning_bu}. Run /update-iam, review the plan carefully, then /apply-iam.
```

Then, in the **same turn**, ask via a single `vscode_askQuestions` call:

- header: `next_step`
- question: "What next?"
- options: `Remove another app (/remove-app)`, `Remove a BU (/remove-bu)`, `Regenerate outputs (/update-iam)`, `Done`

Follow the chosen wizard's instructions in the same turn. If `Done`, end the turn.

## Constraints

- Touch only `inputs.yaml`.
- Never run `terraform apply` from this wizard.
- Do not delete the parent BU even if it ends up with zero apps.
