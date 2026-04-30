---
name: dt-iam-bindings
description: Design and modify Dynatrace IAM groups, policy boundaries, and policy bindings. Use when changing group membership, adding/removing policies from groups, restructuring boundaries, or troubleshooting effective permissions. Encodes the critical rule that one dynatrace_iam_policy_bindings_v2 resource manages all bindings for a group atomically.
license: Apache-2.0
---

# Dynatrace IAM Groups, Boundaries & Bindings

Use when working with `dynatrace_iam_group`, `dynatrace_iam_policy_boundary`, or `dynatrace_iam_policy_bindings_v2` resources.

## References (load on demand)

| Reference | When to load |
|---|---|
| [references/gotchas.md](references/gotchas.md) | Always — single-resource-per-group rule, bucket access, boundary applicability, condition namespaces |
| [../dt-iam-generator/references/group-model.md](../dt-iam-generator/references/group-model.md) | When defining or modifying the group hierarchy |

## Group model

Groups and bindings are **data-driven** from the merged `roles:` catalog (defaults + customer overrides — see [`../dt-iam-generator/references/defaults.yaml`](../dt-iam-generator/references/defaults.yaml) and [`../dt-iam-generator/references/group-model.md`](../dt-iam-generator/references/group-model.md)).

For each entry under `roles.bu.<role>`, the generator emits ONE `dynatrace_iam_group` resource and ONE `dynatrace_iam_policy_bindings_v2` resource, each with `for_each = var.business_units`. Same pattern for `roles.app.<role>` over `var.applications`.

The **default catalog** ships 4 roles — `bu.admins`, `bu.users`, `app.admins`, `app.users` — producing the standard 4-group model:

```
Central Operations (NOT managed by this config)
└── Account Admins (full access, unbounded)

Business Unit
├── {bu}-Admins      → Standard User + Admin Features + OpenPipeline Mgmt + Anomaly Detection Write
│                      + Scoped Data Read (bounded) + 6× Read <table> (bounded) + Scoped Settings Write (bounded)
└── {bu}-Users       → Standard User + Anomaly Detection Write
                       + Scoped Data Read (bounded) + 6× Read <table> (bounded)

Application
├── {app}-Admins     → Standard User + SLO Manager + Anomaly Detection Write
│                      + 6× Read <table> (bounded) + Scoped Settings Write (bounded)
└── {app}-Users      → Standard User + Anomaly Detection Write
                       + 6× Read <table> (bounded)
```

Customers add roles by extending `roles:` in `inputs.yaml`. See ["Adding a custom role"](#adding-a-custom-role) below.

All groups carry `lifecycle { ignore_changes = [permissions] }` so binding edits never thrash the group resource.

## Boundaries

Two condition namespaces — **never mix in the same boundary**:

| Boundary type | Query template | Applies to |
|---|---|---|
| BU data | `storage:dt.security_context startsWith "{bu}-";` | `storage:*` permissions |
| BU settings | `settings:dt.security_context startsWith "{bu}-";` | `settings:*` permissions |
| App data | one `storage:...` line per stage: `storage:dt.security_context startsWith "{bu}-{stage}-{app}";` | `storage:*` |
| App settings | one `settings:...` line per stage | `settings:*` |

Multi-line boundary queries are **OR**'d — there is no `AND`. Each line produces an independent statement.

```hcl
resource "dynatrace_iam_policy_boundary" "app_data" {
  for_each = var.applications
  name     = "Boundary-${each.key}-Data"
  query = join("\n", [
    for stage in each.value.stages :
    "storage:dt.security_context startsWith \"${lower(each.value.bu)}-${lower(stage)}-${lower(each.key)}\";"
  ])
}
```

## The single-resource-per-group rule (gotchas #21)

`dynatrace_iam_policy_bindings_v2` manages **all** bindings for a group as an atomic unit. Two resources targeting the same group → the second silently overwrites the first → 403s.

```hcl
# ✅ CORRECT: one resource, mixed boundary types
resource "dynatrace_iam_policy_bindings_v2" "bu_admins" {
  for_each    = var.business_units
  group       = dynatrace_iam_group.bu_admins[each.key].id
  environment = var.environment_id

  policy { id = data.dynatrace_iam_policy.standard_user.id }
  policy { id = dynatrace_iam_policy.admin_features.id }

  policy {
    id         = data.dynatrace_iam_policy.read_logs.id
    boundaries = [dynatrace_iam_policy_boundary.bu_data[each.key].id]
  }

  policy {
    id         = dynatrace_iam_policy.scoped_settings_write.id
    boundaries = [dynatrace_iam_policy_boundary.bu_settings[each.key].id]
    parameters = { "security_context_prefix" = "${lower(each.key)}-" }
  }
}
```

```hcl
# ❌ WRONG: two resources for the same group → second overwrites first
resource "dynatrace_iam_policy_bindings_v2" "bu_admins_data"     { group = ...same... }
resource "dynatrace_iam_policy_bindings_v2" "bu_admins_settings" { group = ...same... }
```

## Bucket access requires default read policies (gotchas #19)

Custom WHERE-clause policies (`Scoped Grail Data Read`) only filter records — they do **not** grant bucket access. Always also bind:

- `Read Logs` + boundary
- `Read Metrics` + boundary
- `Read Spans` + boundary
- `Read Events` + boundary
- `Read BizEvents` + boundary
- `Read Entities` + boundary

…otherwise users get `No bucket permissions for table <X>`.

## Boundary applicability (gotchas #2 / #7)

A boundary condition only takes effect on permissions whose namespace matches. If a boundary applies `host.name` but the policy includes `storage:entities:read` (which doesn't support `host.name`), `entities:read` becomes **unconditional**.

→ Always group permissions whose conditions actually match the boundary into the same policy. Otherwise split into separate `policy { … boundaries = [...] }` blocks within the same binding resource.

## Effective-permissions troubleshooting

| Symptom | Likely cause |
|---|---|
| User has only `Scoped Settings Write` and 403s elsewhere | Two binding resources for the same group — see [gotchas #21](references/gotchas.md) |
| `No bucket permissions for table logs` | Missing `Read Logs` default policy + boundary — see [gotchas #19](references/gotchas.md) |
| User can write settings on entities outside their BU | `Admin User` was bound — see [policy-authoring gotchas #16](../dt-iam-policy-authoring/references/gotchas.md) |
| Boundary ignored on automation/SLO/extensions | Tenant-wide namespaces — see [policy-authoring gotchas #20](../dt-iam-policy-authoring/references/gotchas.md) |
| `terraform apply` keeps showing the same change | Multiple binding resources for the same group — see [gotchas #21](references/gotchas.md) |

## Anti-patterns

- ❌ Splitting bindings per boundary type into separate resources — [gotchas #21](references/gotchas.md)
- ❌ Binding `Admin User` to a scoped group — [policy-authoring gotchas #16](../dt-iam-policy-authoring/references/gotchas.md)
- ❌ Mixing storage and settings conditions in a single boundary — [gotchas #8](references/gotchas.md)
- ❌ Relying on `Scoped Grail Data Read` alone without `Read <table>` defaults — [gotchas #19](references/gotchas.md)
- ❌ Using `Management Zone` references or `environment:roles:*` — [generator gotchas #10](../dt-iam-generator/references/gotchas.md)

## Adding a custom role

Define the role in `inputs.yaml` under `roles.<scope>.<name>`. The generator merges it with the default catalog, then emits one new group resource and one new binding resource per scope instance.

**Example: a BU-level read-only auditor role with a new custom policy.**

```yaml
# inputs.yaml
policies:
  - name: security_auditor_read
    type: custom
    display_name: "Security Auditor Read"
    description: "Read-only access for compliance auditors."
    statements: |
      ALLOW storage:logs:read, storage:events:read, storage:bizevents:read;
      ALLOW iam:policies:read, iam:bindings:read;
      ALLOW settings:objects:read;

roles:
  bu:
    auditors:
      description: "Compliance auditors with read-only access"
      policies:
        - { name: standard_user }
        - { name: read_system_events }
        - { name: security_auditor_read, boundary: bu_data }
```

Generator output:

```hcl
# groups_main.tf (added)
resource "dynatrace_iam_group" "bu_auditors" {
  for_each    = var.business_units
  name        = "${each.key}-Auditors"
  description = "Compliance auditors with read-only access for ${each.value.description}."
  lifecycle { ignore_changes = [permissions] }
}

# bindings_bu_bindings.tf (added)
resource "dynatrace_iam_policy_bindings_v2" "bu_auditors" {
  for_each    = var.business_units
  group       = dynatrace_iam_group.bu_auditors[each.key].id
  environment = var.environment_id

  policy { id = data.dynatrace_iam_policy.standard_user.id }
  policy { id = data.dynatrace_iam_policy.read_system_events.id }
  policy {
    id         = dynatrace_iam_policy.security_auditor_read.id
    boundaries = [dynatrace_iam_policy_boundary.bu_data[each.key].id]
  }
}

# policies_custom_policies.tf (added)
resource "dynatrace_iam_policy" "security_auditor_read" {
  name        = "Security Auditor Read"
  description = "Read-only access for compliance auditors."
  account     = var.account_id
  tags        = var.tags
  statement_query = <<-EOT
    ALLOW storage:logs:read, storage:events:read, storage:bizevents:read;
    ALLOW iam:policies:read, iam:bindings:read;
    ALLOW settings:objects:read;
  EOT
}
```

Validation rules the generator MUST enforce on a new role (see [`../dt-iam-generator/references/group-model.md`](../dt-iam-generator/references/group-model.md)):

1. Every `policies[].name` exists in the merged catalog.
2. `boundary:` is one of `bu_data | bu_settings | app_data | app_settings`.
3. `app_data` / `app_settings` only used in `roles.app.*`.
4. `{app}` token in `params:` only used in `roles.app.*`.
5. `params:` keys match the `${bindParam:...}` placeholders in the referenced templated policy.
