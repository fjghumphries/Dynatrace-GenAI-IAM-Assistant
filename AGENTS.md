# AGENTS.md

Guidance for any AI coding agent (Claude Code, Cursor, OpenCode, GitHub Copilot, Gemini CLI, …) operating in this workspace.

## Purpose (read this first)

**The user edits one file (`inputs.yaml`) and gets a complete Terraform IAM configuration in `outputs/`.** Nothing else.

| Who | What | How |
|---|---|---|
| **User** | Provides Business Units, applications, and stages in [`inputs.yaml`](inputs.yaml). Runs `terraform apply` from `outputs/`. | One YAML file edit + one wizard prompt + standard Terraform CLI |
| **Agent (you)** | Translates `inputs.yaml` → complete Terraform under `outputs/` (boundaries, policies, groups, bindings, docs, README) | Load `dt-iam-generator`, mirror `sample-outputs/`, follow each skill's `gotchas.md` |
| **Success** | A Dynatrace Grail tenant with the 4-group model (BU Admins/Users + App Admins/Users) scoped by `dt.security_context`, applied via Terraform | `terraform apply` succeeds **and** Effective Permissions in Account Management match the spec |

**Wizards available** (slash commands in Copilot Chat — see [.github/prompts/](.github/prompts/)):
- `/init-inputs` — interactively populate `inputs.yaml` for a new project
- `/generate-iam` — produce all `.tf` files + docs in `outputs/`
- `/update-iam` — regenerate after `inputs.yaml` changes
- `/add-bu` and `/add-app` — one-shot edits without re-explaining context
- `/validate-iam` — pre-apply sanity checks
- `/apply-iam` — guided OAuth setup, env vars, init/plan/apply, post-apply verification

**Non-goals.** This repo does NOT query a live Dynatrace tenant, manage state outside Terraform, or generate runtime/observability assets (use the [`dt-for-ai`](skills/dt-for-ai/SKILL.md) skill bridge for that).

## What this repo does

Generates Terraform-managed IAM for Dynatrace Grail (3rd Gen) from [`inputs.yaml`](inputs.yaml). Output is written to [`outputs/`](outputs/).

## Skills (Agent Skills format)

Knowledge lives in [`skills/`](skills/) following the [Agent Skills](https://agentskills.io/) spec. Each `SKILL.md` carries its own `references/` (including `gotchas.md`). Load the skill matching the user's intent:

| Skill | When to load |
|---|---|
| `dt-iam-generator` | End-to-end generation; reading `inputs.yaml`; writing `outputs/` |
| `dt-iam-policy-authoring` | Authoring/reviewing `dynatrace_iam_policy` resources |
| `dt-iam-bindings` | Groups, boundaries, `dynatrace_iam_policy_bindings_v2` |
| `dt-iam-validation` | Plan/apply/troubleshoot/verify |
| `dt-for-ai` | Live tenant queries (DQL, dashboards, notebooks) — bridges to upstream [Dynatrace for AI](https://github.com/Dynatrace/dynatrace-for-ai) |

Catalog (name + description) is loaded automatically; full `SKILL.md` is loaded on demand; `references/*` files are loaded only when needed.

## Hard rules

1. Read [`inputs.yaml`](inputs.yaml) before generating or modifying IAM resources.
2. Mirror [`sample-outputs/`](sample-outputs/) file structure when writing to [`outputs/`](outputs/).
3. After every Terraform change, update `outputs/docs/{policies,groups,bindings}.txt` and `outputs/README.md`.
4. New gotchas → append to the relevant `skills/<skill>/references/gotchas.md`. Do **not** create a top-level lessons file.
5. All IAM identifiers (BU, app, stage, security_context) must be **lowercase**.
6. Never use the **Admin User** default policy on scoped groups — use `Standard User` + `Admin Features` (custom) + `Scoped Settings Write` (templated).
7. **One** `dynatrace_iam_policy_bindings_v2` resource per group — never split.
8. Default data read policies (`Read Logs`, `Read Metrics`, …) must be bound with boundaries; WHERE-clause policies alone do not grant bucket access.

## Project context

- Provider: `dynatrace-oss/dynatrace ~> 1.91`
- IAM model: Grail 3rd Gen (no Management Zones, no `environment:roles:*`)
- Security context format: `{bu}-{stage}-{application}-{component}`
- Generic example names: `bu-platform`, `bu-payments`, `app-alpha`, `app-beta`, stages `prod` / `dev`

## Reference docs

- [Default Policies](https://docs.dynatrace.com/docs/manage/identity-access-management/permission-management/default-policies)
- [IAM Policy Reference](https://docs.dynatrace.com/docs/manage/identity-access-management/permission-management/iam-policy-reference)
- [Settings 2.0 Schemas](https://docs.dynatrace.com/docs/dynatrace-api/environment-api/settings/schemas)
- [Dynatrace Terraform Provider](https://registry.terraform.io/providers/dynatrace-oss/dynatrace/latest/docs)
