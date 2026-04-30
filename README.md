# Dynatrace GenAI IAM Assistant

[![Terraform](https://img.shields.io/badge/Terraform-1.0%2B-7B42BC?logo=terraform)](https://developer.hashicorp.com/terraform/install)
[![Dynatrace Provider](https://img.shields.io/badge/dynatrace--oss%2Fdynatrace-~%3E%201.91-1496FF?logo=dynatrace)](https://registry.terraform.io/providers/dynatrace-oss/dynatrace/latest)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

> [!WARNING]
> **Experimental.** Generated Terraform is a starting point, not production-ready output. Always run `terraform plan` and verify effective permissions in a non-production tenant before applying.

Generate Terraform-managed IAM configurations for **Dynatrace Grail (3rd Gen)** using any AI coding agent (GitHub Copilot, Claude Code, Cursor, OpenCode, Gemini CLI, …). Knowledge is packaged as portable [Agent Skills](https://agentskills.io/) under [`skills/`](skills/), so the same workflow runs across editors.

You fill in your Business Units, applications, and stages in [`inputs.yaml`](inputs.yaml) — the agent loads the relevant skills and writes a complete Terraform configuration into [`outputs/`](outputs/).

## Quick start

```bash
git clone https://github.com/fjghumphries/Dynatrace-GenAI-IAM-Assistant.git
cd Dynatrace-GenAI-IAM-Assistant
code .                       # open in VS Code (with GitHub Copilot)
```

Then, in Copilot Chat (or any agent that supports slash prompts):

```
/init-inputs       # interactive interview → fills inputs.yaml
/generate-iam      # writes complete Terraform to outputs/
/apply-iam         # guided OAuth + terraform init/plan/apply + verify
```

Each wizard suggests the next logical step when it finishes.

## Prerequisites

- An AI coding agent (e.g. VS Code + [GitHub Copilot](https://marketplace.visualstudio.com/items?itemName=GitHub.copilot) + [Copilot Chat](https://marketplace.visualstudio.com/items?itemName=GitHub.copilot-chat))
- A Dynatrace Grail (3rd Gen) account with permission to create OAuth clients
- [Terraform](https://developer.hashicorp.com/terraform/install) v1.0+

Optional — install the bridged Dynatrace observability skills (DQL, dashboards, notebooks):

```bash
npx skills add dynatrace/dynatrace-for-ai
```

## Wizards

| Wizard | Use it to |
|---|---|
| `/init-inputs` | Populate `inputs.yaml` from scratch |
| `/generate-iam` | Produce all Terraform under `outputs/` |
| `/update-iam` | Re-generate after editing `inputs.yaml` directly |
| `/add-bu` | Add a new Business Unit (and its apps) |
| `/add-app` | Add a new application to an existing BU |
| `/add-policy` | Add a custom, templated, or default policy |
| `/add-role` | Add a new role (group + binding) at BU or app level |
| `/validate-iam` | Pre-apply sanity checks |
| `/apply-iam` | Guided OAuth setup → init/plan/apply → verification |

Wizard sources live in [`.github/prompts/`](.github/prompts/).

## Manual flow (no wizards)

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

```
Generate the Terraform IAM configuration from inputs.yaml into outputs/.
```

The agent loads `dt-iam-generator`, parses `inputs.yaml`, mirrors the structure of [`sample-outputs/`](sample-outputs/), and writes complete `.tf` files plus `docs/*.txt` and `README.md` into `outputs/`.

### 3. Apply

```bash
cd outputs

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

Full env-var reference and OAuth scope list: [`skills/dt-iam-validation/SKILL.md`](skills/dt-iam-validation/SKILL.md).

### 4. Verify

Inspect Effective Permissions in Account Management, then run a real-user smoke test via DQL. See [`skills/dt-iam-validation/SKILL.md`](skills/dt-iam-validation/SKILL.md).

## IAM model

Two levels × two roles → 4 group types per Business Unit / application. Full details in [`skills/dt-iam-generator/references/group-model.md`](skills/dt-iam-generator/references/group-model.md).

| Group | Data access | Settings | SLO | OpenPipeline | Anomaly detection |
|---|---|---|---|---|---|
| `{bu}-Admins` | scoped to BU | write (scoped) | yes | pipeline write | yes |
| `{bu}-Users` | scoped to BU | read only | no | read only | yes |
| `{app}-Admins` | scoped to app | write (scoped) | yes (via SLO Manager) | read only | yes |
| `{app}-Users` | scoped to app | read only | no | read only | yes |

Enforcement field: `dt.security_context = {bu}-{stage}-{application}-{component}` (lowercase).

## Repository layout

```
.
├── inputs.yaml                          # ← the only file you edit
├── README.md, AGENTS.md, .gitignore, LICENSE
│
├── .github/
│   ├── copilot-instructions.md          # GitHub Copilot routing
│   └── prompts/                         # Slash-command wizards
│
├── skills/                              # Agent Skills (portable knowledge)
│   ├── dt-iam-generator/                #   end-to-end generation
│   ├── dt-iam-policy-authoring/         #   policy syntax & permissions
│   ├── dt-iam-bindings/                 #   groups, boundaries, bindings
│   ├── dt-iam-validation/               #   plan / apply / troubleshoot
│   └── dt-for-ai/                       #   DQL & observability bridge
│
├── sample-outputs/                      # Reference: 2 BUs × 2 apps × 2 stages
└── outputs/                             # ← generated Terraform goes here
```

## Extending

The generator ships a default catalog (14 policies, 4 roles) in [`skills/dt-iam-generator/references/defaults.yaml`](skills/dt-iam-generator/references/defaults.yaml). To add or override, drop optional `policies:` and `roles:` blocks into `inputs.yaml` — entries merge with the defaults **by name** (customer wins).

See the commented examples at the bottom of [`inputs.yaml`](inputs.yaml), or run `/add-policy` / `/add-role` for guided edits.

## License

[MIT](LICENSE)

## References

- [Dynatrace for AI](https://github.com/Dynatrace/dynatrace-for-ai) — official skills, prompts, MCP server
- [Default Policies](https://docs.dynatrace.com/docs/manage/identity-access-management/permission-management/default-policies)
- [IAM Policy Reference](https://docs.dynatrace.com/docs/manage/identity-access-management/permission-management/iam-policy-reference)
- [Settings 2.0 Schemas](https://docs.dynatrace.com/docs/dynatrace-api/environment-api/settings/schemas)
- [Dynatrace Terraform Provider](https://registry.terraform.io/providers/dynatrace-oss/dynatrace/latest/docs)
- [Agent Skills specification](https://agentskills.io/specification)
