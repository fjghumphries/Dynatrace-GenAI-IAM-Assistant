# Dynatrace GenAI IAM Assistant

[![Terraform](https://img.shields.io/badge/Terraform-1.0%2B-7B42BC?logo=terraform)](https://developer.hashicorp.com/terraform/install)
[![Dynatrace Provider](https://img.shields.io/badge/dynatrace--oss%2Fdynatrace-~%3E%201.91-1496FF?logo=dynatrace)](https://registry.terraform.io/providers/dynatrace-oss/dynatrace/latest)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

> [!WARNING]
> **Experimental.** Generated Terraform is a starting point, not production-ready output. Always run `terraform plan` and verify effective permissions in a non-production tenant before applying.

Generate Terraform-managed IAM configurations for **Dynatrace Grail (3rd Gen)** using any AI coding agent (GitHub Copilot, Claude Code, Cursor, OpenCode, Gemini CLI, …). Knowledge is packaged as portable [Agent Skills](https://agentskills.io/) under [`skills/`](skills/), so the same workflow runs across editors.

You fill in your Business Units, applications, and stages in [`inputs.yaml`](inputs.yaml) — the agent loads the relevant skills and writes a complete Terraform configuration into [`outputs/`](outputs/).

## TL;DR

```bash
git clone https://github.com/fjghumphries/GenAI-IAM-Generation.git
cd GenAI-IAM-Generation
code .                       # open in VS Code (with GitHub Copilot)
```

Then, in Copilot Chat (or any agent that supports slash prompts):

```
/init-inputs       # interactive interview → fills inputs.yaml
/generate-iam      # writes complete Terraform to outputs/
/apply-iam         # guided OAuth + terraform init/plan/apply + verify
```

That's the entire workflow. The wizard chains automatically suggest the next step.

---

## Why skills (not a single instructions file)?

Knowledge is split into focused [Agent Skills](https://agentskills.io/) so agents only load what they need. Each skill carries its own gotchas under `references/`.

| Skill | Loaded when |
|---|---|
| [`dt-iam-generator`](skills/dt-iam-generator/SKILL.md) | Generating or regenerating the Terraform output |
| [`dt-iam-policy-authoring`](skills/dt-iam-policy-authoring/SKILL.md) | Writing or reviewing a `dynatrace_iam_policy` |
| [`dt-iam-bindings`](skills/dt-iam-bindings/SKILL.md) | Editing groups, boundaries, or bindings |
| [`dt-iam-validation`](skills/dt-iam-validation/SKILL.md) | Planning, applying, or troubleshooting |
| [`dt-for-ai`](skills/dt-for-ai/SKILL.md) | DQL, observability, dashboards, notebooks (bridges to the official [Dynatrace for AI](https://github.com/Dynatrace/dynatrace-for-ai) skills) |

GitHub Copilot picks them up via [`.github/copilot-instructions.md`](.github/copilot-instructions.md). Other agents read [`AGENTS.md`](AGENTS.md). Both are short routing files — the substance lives in `skills/`.

There is **no** top-level `instructions.md` or `LESSONS_LEARNED.md`. The customer input is `inputs.yaml`. Knowledge and gotchas live inside each skill's `references/` folder.

---

## Getting started

### Prerequisites

- An AI coding agent (e.g. VS Code + [GitHub Copilot](https://marketplace.visualstudio.com/items?itemName=GitHub.copilot) + [Copilot Chat](https://marketplace.visualstudio.com/items?itemName=GitHub.copilot-chat))
- A Dynatrace Grail (3rd Gen) account
- [Terraform](https://developer.hashicorp.com/terraform/install) v1.0+

### Install the bridged Dynatrace for AI skills (optional, recommended)

```bash
# Skills package — works with Claude Code, Cursor, Cline, GitHub Copilot, OpenCode, …
npx skills add dynatrace/dynatrace-for-ai
```

This adds DQL, observability, dashboard, and notebook skills used by the `dt-for-ai` bridge skill.

### Repository layout

```
.
├── README.md, AGENTS.md, inputs.yaml, .gitignore
│
├── .github/
│   ├── copilot-instructions.md          # GitHub Copilot routing
│   └── prompts/                         # Reusable VS Code slash commands
│
├── skills/                              # Agent Skills (portable knowledge)
│   ├── dt-iam-generator/
│   │   ├── SKILL.md
│   │   └── references/
│   │       ├── group-model.md
│   │       ├── security-context-enrichment.md
│   │       └── gotchas.md
│   ├── dt-iam-policy-authoring/
│   │   ├── SKILL.md
│   │   └── references/
│   │       ├── permissions-cheatsheet.md
│   │       └── gotchas.md
│   ├── dt-iam-bindings/
│   │   ├── SKILL.md
│   │   └── references/gotchas.md
│   ├── dt-iam-validation/
│   │   ├── SKILL.md
│   │   └── references/gotchas.md
│   └── dt-for-ai/SKILL.md
│
├── sample-outputs/                      # Reference: 2 BUs × 2 apps × 2 stages
└── outputs/                             # ← generated Terraform goes here
```

---

## How to use

The whole workflow is driven by **slash-command wizards** in your AI chat (Copilot Chat, Claude Code, etc.). Type `/` to see them.

| Wizard | Use it to |
|---|---|
| `/init-inputs` | Populate `inputs.yaml` from scratch — interactive interview |
| `/generate-iam` | Produce all Terraform under `outputs/` from the current `inputs.yaml` |
| `/update-iam` | Re-generate after editing `inputs.yaml` directly |
| `/add-bu` | Add a new Business Unit (and its apps) in one shot |
| `/add-app` | Add a new application to an existing BU |
| `/add-policy` | Add a new custom, templated, or default policy |
| `/add-role` | Add a new role (group + binding) at BU or app level |
| `/validate-iam` | Pre-apply sanity checks |
| `/apply-iam` | Guided OAuth client setup → env vars → init/plan/apply → verification |

Wizards are token-economical: they batch all questions into a single prompt and chain into the next logical step automatically. Sources live in [`.github/prompts/`](.github/prompts/).

### Manual flow (no wizards)

### 1. Edit `inputs.yaml`

```yaml
business_units:
  bu-platform:
    description: "Platform Engineering"
    applications: [app-alpha]
  bu-payments:
    description: "Payments"
    applications: [app-beta]

stages: [prod, dev]
```

All names lowercase. Each application maps to exactly one BU.

### 2. Ask your agent to generate

In your AI agent:

```
Generate the Terraform IAM configuration from inputs.yaml into outputs/.
```

Or use a slash command (Copilot Chat, after copying prompts):

```
/generate-iam
```

The agent loads `dt-iam-generator`, parses `inputs.yaml`, mirrors the structure of `sample-outputs/`, and writes complete `.tf` files plus `docs/*.txt` and `README.md` into `outputs/`.

### 3. Apply

```bash
cd outputs

# See skills/dt-iam-validation/SKILL.md for full env var reference
export DT_CLIENT_ID="..."
export DT_CLIENT_SECRET="..."
export DT_ACCOUNT_ID="..."
export DYNATRACE_ENV_URL="https://<env>.live.dynatrace.com"
export TF_VAR_account_id="$DT_ACCOUNT_ID"
export TF_VAR_environment_id="<env>"

terraform init
terraform plan
terraform apply
```

### 4. Verify

Follow the post-apply checks in [`skills/dt-iam-validation/SKILL.md`](skills/dt-iam-validation/SKILL.md): inspect Effective Permissions in Account Management, then run a real-user smoke test via DQL.

---

## IAM model (summary)

Two levels × two roles → 4 group types. Full details in [skills/dt-iam-generator/references/group-model.md](skills/dt-iam-generator/references/group-model.md).

| Group | Data access | Settings | SLO | OpenPipeline | Anomaly detection |
|---|---|---|---|---|---|
| `{bu}-Admins` | scoped to BU | write (scoped) | yes | pipeline write | yes |
| `{bu}-Users` | scoped to BU | read only | no | read only | yes |
| `{app}-Admins` | scoped to app | write (scoped) | yes (via SLO Manager) | read only | yes |
| `{app}-Users` | scoped to app | read only | no | read only | yes |

Enforcement field: `dt.security_context = {bu}-{stage}-{application}-{component}` (lowercase).

---

## Critical rules (don't skip)

Each rule links to the relevant skill reference:

1. Never bind **Admin User** on scoped groups — see [policy-authoring gotchas #16](skills/dt-iam-policy-authoring/references/gotchas.md).
2. **One** `dynatrace_iam_policy_bindings_v2` resource per group — see [bindings gotchas #21](skills/dt-iam-bindings/references/gotchas.md).
3. Default data read policies must be bound with boundaries — see [bindings gotchas #19](skills/dt-iam-bindings/references/gotchas.md).
4. Feature permissions are tenant-wide — see [policy-authoring gotchas #20](skills/dt-iam-policy-authoring/references/gotchas.md).
5. All identifiers lowercase — see [validation gotchas #18](skills/dt-iam-validation/references/gotchas.md).

---

## Extending — adding your own policies and roles

The generator ships a default catalog (14 policies, 4 roles) in [`skills/dt-iam-generator/references/defaults.yaml`](skills/dt-iam-generator/references/defaults.yaml). Customers add or override entries directly in `inputs.yaml` under optional `policies:` and `roles:` blocks — entries merge with defaults **by name** (customer wins).

See the commented examples at the bottom of [`inputs.yaml`](inputs.yaml), or run `/add-policy` / `/add-role` for guided edits. Schema details: [skills/dt-iam-generator/references/group-model.md](skills/dt-iam-generator/references/group-model.md).

---

## Contributing

Issues and pull requests are welcome. When adding a new lesson learned, append it to the relevant `skills/<skill>/references/gotchas.md` rather than creating a top-level summary file — that keeps knowledge close to the skill that needs it.

## License

[MIT](LICENSE)

## References

- [Dynatrace for AI](https://github.com/Dynatrace/dynatrace-for-ai) — official skills, prompts, MCP server
- [Default Policies](https://docs.dynatrace.com/docs/manage/identity-access-management/permission-management/default-policies)
- [IAM Policy Reference](https://docs.dynatrace.com/docs/manage/identity-access-management/permission-management/iam-policy-reference)
- [Settings 2.0 Schemas](https://docs.dynatrace.com/docs/dynatrace-api/environment-api/settings/schemas)
- [Dynatrace Terraform Provider](https://registry.terraform.io/providers/dynatrace-oss/dynatrace/latest/docs)
- [Agent Skills specification](https://agentskills.io/specification)
