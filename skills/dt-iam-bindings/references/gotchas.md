# Bindings, Groups & Boundaries Gotchas

Lessons specific to `dynatrace_iam_group`, `dynatrace_iam_policy_boundary`, and `dynatrace_iam_policy_bindings_v2` resources.

## #21 — One bindings_v2 resource per group (most common cause of 403s)

`dynatrace_iam_policy_bindings_v2` manages **all** bindings for a group as an atomic unit. Multiple resources targeting the same group → the last one **silently overwrites** the others. Users end up with only the policies from the last resource and get 403 Forbidden everywhere else.

```hcl
# ❌ WRONG — second resource overwrites first
resource "dynatrace_iam_policy_bindings_v2" "bu_admins_data"     { group = ...same... }
resource "dynatrace_iam_policy_bindings_v2" "bu_admins_settings" { group = ...same... }
```

```hcl
# ✅ CORRECT — single resource, mixed boundary types coexist
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

**Symptoms of this bug:**
- Users get 403 Forbidden across the platform
- Group shows only "Scoped Settings Write" when it should show 10+ policies
- `terraform apply` shows changes on every run
- Different `policy { ... }` blocks within the **same** resource CAN have different boundary types — that's fine. The constraint is one binding *resource* per group.

## #19 — Default data read policies REQUIRED for Grail bucket access

Grail has two permission layers:

1. **Bucket-level grant** — comes from `Read Logs`/`Read Metrics`/`Read Spans`/`Read Events`/`Read BizEvents`/`Read Entities` default policies. These say "you may access this table".
2. **Record-level filter** — comes from a `WHERE storage:dt.security_context startsWith ...` clause. Filters which records within the table the user sees.

The custom `Scoped Grail Data Read` templated policy provides only layer 2. Without the layer-1 default policies bound (with boundaries), users get:

```
No bucket permissions for table logs
```

**Bind both:**
- The default `Read <table>` policy with a boundary → grants bucket access, scoped
- The `Scoped Grail Data Read` policy (optional, defense-in-depth) → adds explicit WHERE filtering

## #2 — Boundary conditions only apply where namespaces match

Boundaries decouple "what" from "where", but a condition only takes effect on permissions whose namespace it applies to.

```
Policy:    ALLOW storage:logs:read, storage:entities:read;
Boundary:  storage:host.name = "myHost";
```

`storage:logs:read` gets the host.name filter. `storage:entities:read` does **not** support `host.name` → becomes **unconditional**. The user gets all entities across the environment.

**Fix:** group permissions whose conditions actually match the boundary into the same policy/binding block. Otherwise split into multiple `policy { ... boundaries = [...] }` blocks within the same resource.

## #7 — Storage condition availability by table

| Table | `dt.security_context` | `k8s.namespace.name` | `host.name` |
|---|---|---|---|
| logs | ✓ | ✓ | ✓ |
| metrics | ✓ | ✓ | ✓ |
| spans | ✓ | ✓ | ✓ |
| events | ✓ | ✓ | ✓ |
| bizevents | ✓ | ✓ | ✓ |
| entities | ✓ | ✗ | ✗ |

`storage:entities:read` only supports `entity.type` and `dt.security_context`. Applying `host.name` to an entities permission → unconditional access (#2).

## #8 — Storage and settings use different condition namespaces

| Domain | Condition prefix |
|---|---|
| Grail data (`storage:logs:read`, etc.) | `storage:dt.security_context` |
| Settings (`settings:objects:write`, etc.) | `settings:dt.security_context` |

Always create **separate boundaries** for each — never mix in one boundary:

```hcl
resource "dynatrace_iam_policy_boundary" "bu_data" {
  query = "storage:dt.security_context startsWith \"bu-platform-\";"
}

resource "dynatrace_iam_policy_boundary" "bu_settings" {
  query = "settings:dt.security_context startsWith \"bu-platform-\";"
}
```

## #9 — Recommended group hierarchy

```
Central Operations (NOT in this config)
└── Account Admins (full access, no boundaries)

Business Unit
├── {bu}-Admins      → all BU data + settings write within BU
└── {bu}-Users       → all BU data, read-only

Application (more restrictive)
├── {app}-Admins     → app data + scoped settings write
└── {app}-Users      → app data, read-only
```

- BU groups use `startsWith "{bu}-"` — captures all stages and applications.
- Application groups enumerate stages: one `startsWith "{bu}-{stage}-{app}"` line per active stage (multi-line boundary queries are OR'd; there is no AND).

## Boundary syntax notes

- Boundaries do **not** support an explicit `AND` operator. Each line in a multi-line query is a separate condition that produces a separate policy statement (effectively OR).
- Boundaries do **not** apply to `DENY` statements — for explicit denials, write them inside the policy itself.
- Each boundary should hold ≤ 10 conditions for performance.
