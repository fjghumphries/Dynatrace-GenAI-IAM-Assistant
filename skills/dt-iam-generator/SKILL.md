---
name: dt-iam-generator
description: End-to-end workflow for generating Terraform-managed Dynatrace IAM configurations for Grail (3rd Gen) environments from a customer specification in inputs.yaml. Use when the user asks to generate, regenerate, scaffold, or extend the IAM Terraform output. Coordinates the policy-authoring, bindings, and validation skills.
license: Apache-2.0
---

# Dynatrace GenAI IAM Assistant

End-to-end workflow for turning the customer spec in `inputs.yaml` into a complete Terraform IAM configuration under `outputs/`.

## When to load

Load when the user asks to:
- "Generate the Terraform IAM config"
- "Regenerate `outputs/` from `inputs.yaml`"
- "Add a new BU / application / stage"
- "Scaffold a fresh IAM project"

For deep policy syntax, branch to [dt-iam-policy-authoring](../dt-iam-policy-authoring/SKILL.md). For binding/group/boundary edits, branch to [dt-iam-bindings](../dt-iam-bindings/SKILL.md). For verification, branch to [dt-iam-validation](../dt-iam-validation/SKILL.md).

## References (load on demand)

| Reference | When to load |
|---|---|
| [references/defaults.yaml](references/defaults.yaml) | **Always** — the default policy + role catalog. Merge with customer overrides from `inputs.yaml`. |
| [references/group-model.md](references/group-model.md) | Always — schema for `policies:` and `roles:`, role capability matrix, security context format |
| [references/security-context-enrichment.md](references/security-context-enrichment.md) | When the user asks about `oneagentctl`, host setup, or how `dt.security_context` gets populated |
| [references/gotchas.md](references/gotchas.md) | Generation/modeling lessons (#0, #1, #1b, #3, #10, #13, #24 schema, #25 merge order) |

## Pre-flight checklist

Before writing any file:

1. Read [`inputs.yaml`](../../inputs.yaml) — extract `business_units`, `applications` (derived from each BU's list), `stages`, and the **optional** `policies:` / `roles:` sections.
2. Read [`references/defaults.yaml`](references/defaults.yaml) — the default policy + role catalog.
3. **Merge by name** (customer wins): for each policy in `inputs.yaml.policies`, replace any default with the same `name`; otherwise append. Same rule for `roles.<scope>.<role_name>`.
4. Inspect [`sample-outputs/`](../../sample-outputs/) for current file structure and naming conventions.
5. Validate input:
   - All names lowercase (see [validation gotchas](../dt-iam-validation/references/gotchas.md))
   - Each application appears under exactly one BU (see [gotchas #1](references/gotchas.md))
   - Stages list non-empty
   - Every `roles[].policies[].name` exists in the merged policy catalog
   - Every `boundary:` is one of `bu_data`, `bu_settings`, `app_data`, `app_settings`
   - `app_data` / `app_settings` boundaries appear ONLY in `roles.app.*` (apps don't index by BU at the boundary layer)
   - For every templated policy, every binding that uses it provides all required `params:` keys
   - No custom policy grants unconditional `settings:objects:write` (gotcha #16)

## Output file map (mirrors `sample-outputs/`)

| File | Purpose |
|---|---|
| `variables.tf` | `business_units`, `applications`, `stages`, account/env vars |
| `provider.tf` + `versions.tf` | Provider config + version pin (`dynatrace-oss/dynatrace ~> 1.91`) |
| `boundaries_main.tf` | 4 boundary types: `bu_data`, `bu_settings`, `app_data`, `app_settings` (static — unchanged across customers) |
| `policies_default_policies.tf` | One `data "dynatrace_iam_policy"` per `policies[].type == default` entry. **Never** include Admin User. |
| `policies_templated_policies.tf` | One `resource "dynatrace_iam_policy"` per `policies[].type == templated` entry (uses `${bindParam:...}`) |
| `policies_custom_policies.tf` | One `resource "dynatrace_iam_policy"` per `policies[].type == custom` entry |
| `groups_main.tf` | One `dynatrace_iam_group` `for_each` resource per **role** under each scope (e.g. `bu_admins`, `bu_users`, plus any extra roles like `bu_auditors`). Always include `lifecycle { ignore_changes = [permissions] }`. |
| `bindings_bu_bindings.tf` | One `dynatrace_iam_policy_bindings_v2` resource per BU role, with `for_each = var.business_units`. |
| `bindings_application_bindings.tf` | One `dynatrace_iam_policy_bindings_v2` resource per app role, with `for_each = var.applications`. |
| `outputs.tf` | Outputs for every group resource generated, plus policy + boundary IDs and a summary |
| `main.tf` | Header comment block (BUs, apps, stages, role list summary) |
| `docs/policies.txt` | Plain-text policy reference — list every policy from the merged catalog |
| `docs/groups.txt` | Plain-text group hierarchy + capabilities — list every role from the merged catalog |
| `docs/bindings.txt` | Plain-text binding tables — one section per role, listing each policy block with boundary + params |
| `README.md` | Architecture overview, role-capabilities table (rendered from merged `roles:`), file structure |
| `terraform.tfvars.example` | Empty-value template (account_id, environment_id) |

## Generation algorithm

```
1. Parse inputs.yaml → {bus, apps_by_bu, stages, customer_policies?, customer_roles?}.
2. Load defaults.yaml → {default_policies, default_roles}.
3. Merge by name (customer wins):
     policies = upsert(default_policies, customer_policies, key=name)
     roles    = deep-merge(default_roles, customer_roles, key=scope.role_name)
4. Lowercase all dimension names; assert no duplicate app names across BUs.
5. Validate (see Pre-flight checklist).
6. Render boundaries_main.tf (static — 4 boundary types, only the for_each
   sources change).
7. Render policies_default_policies.tf:
     for each policies[].type == default:
       data "dynatrace_iam_policy" "<name>" { name = "<dynatrace_name>" }
8. Render policies_templated_policies.tf:
     for each policies[].type == templated:
       resource "dynatrace_iam_policy" "<name>" {
         name            = "<display_name>"
         description     = "<description>"
         account         = var.account_id
         tags            = var.tags
         statement_query = <<-EOT
           ...statements with $${bindParam:...} (escape $ as $$)...
         EOT
       }
9. Render policies_custom_policies.tf: same as templated but no bindParam.
10. Render groups_main.tf:
      for each role in roles.bu:
        resource "dynatrace_iam_group" "bu_<role>" {
          for_each    = var.business_units
          name        = "${each.key}-<Role>"          # Title-cased
          description = "<role.description> for ${each.value.description}."
          lifecycle { ignore_changes = [permissions] }
        }
      for each role in roles.app: same pattern with var.applications.
11. Render bindings_bu_bindings.tf and bindings_application_bindings.tf:
      for each role:
        resource "dynatrace_iam_policy_bindings_v2" "<scope>_<role>" {
          for_each    = var.<scope_var>
          group       = dynatrace_iam_group.<scope>_<role>[each.key].id
          environment = var.environment_id
          # one policy { } block per role.policies[] entry, in order:
          policy {
            id         = <ref to data/resource based on policy.type>
            boundaries = [<ref to dynatrace_iam_policy_boundary.<boundary>[scope_key].id>]   # if boundary set
            parameters = { ... interpolated {bu}/{app} ... }                                  # if params set
          }
        }
      Boundary scope_key:
        bu_data, bu_settings -> indexed by BU key
          (for app roles: each.value.bu; for bu roles: each.key)
        app_data, app_settings -> indexed by app key (each.key)
          (only valid in roles.app.*)
      Param interpolation:
        "{bu}"  -> for bu roles: each.key; for app roles: each.value.bu
        "{app}" -> for app roles: each.key (forbidden in bu roles)
12. Render docs/*.txt with accurate counts and per-role sections.
13. Render outputs/README.md (architecture diagram + role table).
14. Render outputs/outputs.tf with one output per group resource generated.
15. If a new finding emerged, append a section to the relevant references/gotchas.md.
```

## Counts (for `docs/*.txt` and `README.md`)

Let `B` = number of BUs, `A` = number of applications, `R_bu` = number of roles under `roles.bu`, `R_app` = number under `roles.app`, `P` = total policies in the merged catalog.

| Resource | Formula |
|---|---|
| Boundaries | `2B + 2A` (always) |
| Groups | `B · R_bu + A · R_app` |
| Bindings | `B · R_bu + A · R_app` |
| Policies | `P` (default catalog ships 14: 8 default + 2 templated + 4 custom) |

## Mandatory post-generation steps

After writing or modifying any `.tf` file in `outputs/`, in the **same response**:

1. Update `outputs/docs/policies.txt`, `outputs/docs/groups.txt`, `outputs/docs/bindings.txt`.
2. Update `outputs/README.md`.
3. If a new gotcha was discovered, append a section to the relevant `skills/<skill>/references/gotchas.md`.

Do **not** create new top-level summary `.md` files — update the existing skill references instead.

## Anti-patterns

- ❌ Using `Admin User` on scoped groups — see [policy-authoring gotchas #16](../dt-iam-policy-authoring/references/gotchas.md)
- ❌ Splitting a group's policies across multiple `dynatrace_iam_policy_bindings_v2` resources — see [bindings gotchas #21](../dt-iam-bindings/references/gotchas.md)
- ❌ Omitting default `Read <table>` policies — see [bindings gotchas #19](../dt-iam-bindings/references/gotchas.md)
- ❌ Mixed-case BU/app/stage names — see [validation gotchas #18](../dt-iam-validation/references/gotchas.md)
- ❌ Reintroducing product-specific names — keep examples generic
