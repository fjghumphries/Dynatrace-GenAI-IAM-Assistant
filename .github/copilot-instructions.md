# GitHub Copilot Instructions — Dynatrace GenAI IAM Assistant

This workspace generates Terraform-managed Dynatrace IAM configurations for Grail (3rd Gen) from [`inputs.yaml`](../inputs.yaml). All knowledge — group model, policy rules, gotchas — lives in [`skills/`](../skills/) under each skill's `SKILL.md` and `references/`. Load the relevant skill before acting.

## Skill routing

| User intent | Skill to load |
|---|---|
| Generate / regenerate Terraform IAM configuration | [`skills/dt-iam-generator/SKILL.md`](../skills/dt-iam-generator/SKILL.md) |
| Author or review a policy (permissions, conditions, syntax) | [`skills/dt-iam-policy-authoring/SKILL.md`](../skills/dt-iam-policy-authoring/SKILL.md) |
| Define groups, boundaries, or bindings | [`skills/dt-iam-bindings/SKILL.md`](../skills/dt-iam-bindings/SKILL.md) |
| Validate, plan, or test the generated config | [`skills/dt-iam-validation/SKILL.md`](../skills/dt-iam-validation/SKILL.md) |
| Work with Dynatrace AI observability or DQL | [`skills/dt-for-ai/SKILL.md`](../skills/dt-for-ai/SKILL.md) |

## Non-negotiables

1. Always read [`inputs.yaml`](../inputs.yaml) first — it is the only customer input.
2. Generated files **must** go into [`outputs/`](../outputs/), mirroring the structure of [`sample-outputs/`](../sample-outputs/).
3. After any Terraform change, sync `outputs/docs/{policies,groups,bindings}.txt` and `outputs/README.md` in the same response.
4. New findings → append a section to the relevant `skills/<skill>/references/gotchas.md`. Do **not** create a top-level summary file.
5. Do **not** create extra summary markdown files — update existing skill references and `outputs/docs/`.

## Generic naming

The repo ships with generic example names (`bu-platform`, `bu-payments`, `app-alpha`, `app-beta`). Customers replace these in `inputs.yaml`. Never reintroduce product-specific names.
