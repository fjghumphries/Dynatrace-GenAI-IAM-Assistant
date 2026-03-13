# Dynatrace IAM Generator

> [!WARNING]
> **This project is experimental.** Generated Terraform configurations are a starting point, not a production-ready solution. Real-world deployments require manual review, iterative adjustments, and thorough testing before applying to a live Dynatrace account. Always validate with `terraform plan` and verify effective permissions in a non-production environment first.

> [!IMPORTANT]
> **LLM Model Matters.** This project was developed and tested with **Claude Sonnet 4.6** via GitHub Copilot. The quality of generated IAM configurations depends on the model — different models may misunderstand IAM scoping rules, generate invalid permission identifiers, or fail to follow the design constraints in `instructions.md`. If you switch models, verify outputs carefully.

Generate Terraform-managed IAM configurations for Dynatrace Grail (3rd Gen) environments using GitHub Copilot.

You fill in your Business Units, applications, and stages in [`instructions.md`](instructions.md) — GitHub Copilot reads the spec and generates a complete, ready-to-apply Terraform configuration.

---

## Getting Started

### Prerequisites

- [Visual Studio Code](https://code.visualstudio.com/) with the [GitHub Copilot](https://marketplace.visualstudio.com/items?itemName=GitHub.copilot) and [GitHub Copilot Chat](https://marketplace.visualstudio.com/items?itemName=GitHub.copilot-chat) extensions installed
- A Dynatrace Grail (3rd Gen) account
- [Terraform](https://developer.hashicorp.com/terraform/install) v1.0+

### Setup

1. **Open the repository** in VS Code:
   ```bash
   code "/path/to/GenAI IAM Generation"
   ```

2. **Select Claude Sonnet 4.6** in Copilot Chat — click the model selector and choose `Claude Sonnet 4.6`.

3. **Copilot reads its instructions automatically** — [`.github/copilot-instructions.md`](.github/copilot-instructions.md) is loaded on every interaction. It contains critical IAM gotchas, generation rules, and documentation update requirements. You do not need to paste it manually.

4. **Read before generating:**
   - [`instructions.md`](instructions.md) — IAM specification with a clearly marked **Customer Input** section
   - [`LESSONS_LEARNED.md`](LESSONS_LEARNED.md) — Accumulated gotchas and design decisions (23 entries as of March 2026)
   - [`sample-outputs/`](sample-outputs/) — Complete working reference (3 BUs × 3 applications × 2 stages)

---

## Project Structure

```
.
├── instructions.md                  # IAM specification — edit the Customer Input section
├── LESSONS_LEARNED.md               # Design decisions, gotchas, Dynatrace IAM findings
├── README.md                        # This file
├── .github/
│   └── copilot-instructions.md      # Rules Copilot follows during every generation
│
├── sample-outputs/                  # Complete reference example
│   ├── *.tf                         # Terraform configuration files
│   ├── docs/                        # Human-readable IAM documentation
│   └── README.md                    # Architecture overview for the sample config
│
└── outputs/                         # ← YOUR generated Terraform files go here
    ├── *.tf
    ├── docs/
    └── README.md
```

### Key Files

| File | Purpose |
|------|---------|
| [`instructions.md`](instructions.md) | IAM specification file. Contains the group model, policy design rules, security context strategy, and a **Customer Input** section where you define your BUs, applications, and stages. |
| [`LESSONS_LEARNED.md`](LESSONS_LEARNED.md) | Living knowledge base of Dynatrace IAM gotchas, design decisions, and findings. Explains *why* the configuration is structured as it is. Read this before making manual changes. |
| [`sample-outputs/`](sample-outputs/) | A complete, working Terraform configuration for 3 BUs × 3 applications × 2 stages. Use as a reference for expected structure and patterns. |
| [`outputs/`](outputs/) | Where Copilot writes your generated Terraform files. Mirrors the structure of `sample-outputs/`. |

### The `docs/` Folder

Every configuration (sample and generated) includes a `docs/` subfolder with three human-readable reference files:

| File | Contents |
|------|----------|
| `docs/policies.txt` | All IAM policies (default, templated, custom) with descriptions and permissions. |
| `docs/groups.txt` | Group hierarchy, capabilities, and policy assignments at a glance. |
| `docs/bindings.txt` | Mapping of policies to groups, with boundaries and parameters. |

These are **not consumed by Terraform** — they exist for review and sharing without reading HCL. Copilot keeps them in sync with the `.tf` files automatically.

---

## IAM Model Overview

The generated configuration implements a two-level, two-role group model:

| Level | Groups | Scope |
|-------|--------|-------|
| **BU** | `{BU}-Admins`, `{BU}-Users` | All applications and stages within the BU |
| **Application** | `{App}-Admins`, `{App}-Users` | One application, all its stages |

| Role | Data Access | Settings | SLO Write | OpenPipeline | Anomaly Detectors |
|------|-------------|----------|-----------|--------------|-------------------|
| BU Admins | Scoped to BU | Write (scoped) | Yes | Pipeline write (no routing/groups) | Yes |
| BU Users | Scoped to BU | Read only | No | Read only | Yes |
| App Admins | Scoped to app | Write (scoped) | Yes | Read only | Yes |
| App Users | Scoped to app | Read only | No | Read only | Yes |

**Security context format:** `bu-stage-application-component` (lowercase, e.g. `bu1-prod-petclinic01-api`)

**Access is enforced via `dt.security_context`** — the primary IAM enforcement field in Grail. Primary tags (`primary_tags.application`, `primary_tags.bu`, `primary_tags.stage`) are used for filtering and DQL but cannot be used directly in IAM policy conditions.

### Critical Design Rules (summary — read `LESSONS_LEARNED.md` for full details)

| Rule | Reason |
|------|--------|
| Admin User default policy is **never used** | Grants unconditional `settings:objects:write` which cannot be scoped by boundaries |
| One `dynatrace_iam_policy_bindings_v2` resource per group | Multiple resources targeting the same group overwrite each other |
| Default data read policies required alongside custom WHERE-clause policies | Custom policies filter records but don't grant bucket access |
| Feature permissions (`automation:*`, `slo:*`, `app-engine:*`, etc.) are tenant-wide | Boundaries have no effect on these namespaces |
| OpenPipeline managed via `settings:schemaId = "builtin:openpipeline.*.pipelines"` | The old `openpipeline:configurations:*` API is deprecated; `.routing` and `.pipeline-groups` write never granted |

---

## How to Generate

### Step 1 — Edit `instructions.md`

Open [`instructions.md`](instructions.md) and edit **Section 1 — Customer Configuration**. Update the YAML blocks with your actual values:

```yaml
business_units:
  finance:
    applications: [sap01, sap02]
  retail:
    applications: [ecommerce01, pos01]

stages: [prod, staging, dev]
```

> Each application belongs to exactly one BU. Application and BU names must be lowercase. If two BUs share an app name, use a unique identifier (e.g. `finance-sap` and `retail-sap`).

### Step 2 — Ask Copilot to Generate

Open Copilot Chat and use one of:

**Basic generation:**
```
Generate the Terraform IAM configuration from instructions.md
```

**Full generation with explanation:**
```
Read instructions.md, extract the customer input, and generate the complete
Terraform IAM configuration into outputs/. Include all .tf files, docs, and README.
```

**After updating input:**
```
I've updated the customer input in instructions.md. Regenerate the Terraform
configuration in outputs/ to match.
```

**Add a new BU:**
```
Add a new BU called LOGISTICS with applications WAREHOUSE01 and FLEET01.
Update all Terraform files and docs in outputs/.
```

### Step 3 — Review the Output

Copilot generates these files in `outputs/`:

| File | Purpose |
|------|---------|
| `variables.tf` | BU, application, and stage definitions |
| `boundaries_main.tf` | Policy boundary resources |
| `policies_default_policies.tf` | References to Dynatrace default policies |
| `policies_templated_policies.tf` | Parameterised custom policies |
| `policies_custom_policies.tf` | Fully custom policies |
| `groups_main.tf` | Group definitions |
| `bindings_bu_bindings.tf` | BU-level policy bindings |
| `bindings_application_bindings.tf` | Application-level policy bindings |
| `docs/policies.txt` | Human-readable policy reference |
| `docs/groups.txt` | Human-readable group reference |
| `docs/bindings.txt` | Human-readable bindings reference |
| `README.md` | Architecture overview for the generated config |

---

## How to Apply with Terraform

### Step 1 — Create an OAuth Client

In Dynatrace Account Management, create an OAuth client with these scopes:

| Scope | Description |
|-------|-------------|
| `account-idm-read` | View users and groups |
| `account-idm-write` | Manage users and groups |
| `iam-policies-management` | View and manage policies |
| `account-env-read` | View environments |

### Step 2 — Set Environment Variables

Create a `.env` file in `outputs/` (add it to `.gitignore`):

```bash
# Terraform OAuth client
export DT_CLIENT_ID="dt0s02.XXXX"
export DT_CLIENT_SECRET="dt0s02.XXXX...."
export DT_ACCOUNT_ID="your-account-uuid"
export DYNATRACE_ENV_URL="https://your-env-id.live.dynatrace.com"

# These map directly to Terraform variables — no terraform.tfvars needed
export TF_VAR_account_id="your-account-uuid"
export TF_VAR_environment_id="your-env-id"
```

Then source it:
```bash
source outputs/.env
```

> **Why both `DT_ACCOUNT_ID` and `TF_VAR_account_id`?** The provider uses `DT_*` variables for API authentication. The Terraform input variables (`var.account_id`, `var.environment_id`) are used inside resource definitions and need a separate mechanism — `TF_VAR_*` maps directly to `var.*`.

### Step 3 — Initialize and Apply

```bash
cd outputs
terraform init
terraform plan    # Review all changes before applying
terraform apply
```

### Step 4 — Verify

1. Log into **Dynatrace Account Management**
2. Navigate to **Identity & Access Management → Groups** to verify groups
3. Check **Policies** to confirm policy content
4. Use **Effective Permissions** on a test group to validate scoping
5. Test with a real user account — `terraform apply` success does not guarantee effective permissions are correct

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| `terraform init` fails | Ensure internet access and Terraform v1.0+ |
| Authentication errors | Verify `DT_CLIENT_ID`, `DT_CLIENT_SECRET`, `DT_ACCOUNT_ID` are exported |
| Variable not set | Ensure `TF_VAR_account_id` and `TF_VAR_environment_id` are exported (see `.env` setup above) |
| Boundary does not apply | Check namespace — storage conditions use `storage:dt.security_context`, settings use `settings:dt.security_context` |
| No bucket permissions for table | Default data read policies (`Read Logs`, etc.) must also be bound with boundaries — the WHERE-clause policy alone is insufficient |
| Policy write permission denied | Verify OAuth client has `iam-policies-management` scope |
| Group shows only one policy set | You have multiple binding resources for the same group — consolidate into one (Lesson #21) |

---

## References

- [Dynatrace IAM Documentation](https://docs.dynatrace.com/docs/manage/identity-access-management)
- [Default Policies](https://docs.dynatrace.com/docs/manage/identity-access-management/permission-management/default-policies) — review before creating custom policies
- [IAM Policy Reference](https://docs.dynatrace.com/docs/manage/identity-access-management/permission-management/iam-policy-reference) — valid permissions and conditions
- [Policy Statement Syntax](https://docs.dynatrace.com/docs/manage/identity-access-management/permission-management/manage-user-permissions-policies/iam-policystatement-syntax)
- [Policy Boundaries](https://docs.dynatrace.com/docs/manage/identity-access-management/permission-management/manage-user-permissions-policies/iam-policy-boundaries)
- [Settings 2.0 — Available Schemas](https://docs.dynatrace.com/docs/dynatrace-api/environment-api/settings/schemas) — for `settings:schemaId` conditions
- [Dynatrace Terraform Provider](https://registry.terraform.io/providers/dynatrace-oss/dynatrace/latest/docs)

