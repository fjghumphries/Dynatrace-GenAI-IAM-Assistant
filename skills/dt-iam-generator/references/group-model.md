# Group Model & Schema

This file is loaded by [dt-iam-generator](../SKILL.md) when generating or editing Terraform output. It documents the **schema** for `policies:` and `roles:` in `inputs.yaml`, the **default catalog** that ships in [`defaults.yaml`](defaults.yaml), and the **merge rules** the generator follows.

## Two-layer model

```
┌─────────────────────────────────────────────────────────────┐
│ Layer 1: POLICIES — what permissions exist                  │
│  default  → data "dynatrace_iam_policy" (DT-maintained)     │
│  templated → resource with ${bindParam:...}                 │
│  custom   → resource with literal statements                │
├─────────────────────────────────────────────────────────────┤
│ Layer 2: ROLES — which policies bundle for a group          │
│  roles.bu.<name>   → 1 group + 1 binding per BU             │
│  roles.app.<name>  → 1 group + 1 binding per application    │
│  Each role.policies[] entry: name (required), boundary?,    │
│    params? — interpolation tokens {bu}, {app}               │
├─────────────────────────────────────────────────────────────┤
│ Layer 3: DIMENSIONS — business_units, applications, stages  │
│  Drives the for_each iteration count                        │
└─────────────────────────────────────────────────────────────┘
```

## `policies:` schema

```yaml
policies:
  - name: <unique_lowercase_id>      # required — used as TF resource address
    type: default | templated | custom
    # type=default fields:
    dynatrace_name: "Standard User"  # required for default — the DT policy name
    # type=templated | custom fields:
    display_name: "Scoped Settings Write"   # required — shown in DT UI
    description: "..."                       # required
    statements: |                            # required — multiline DT policy DSL
      ALLOW ...;
      ALLOW ... WHERE ${bindParam:foo};      # only templated may use ${bindParam:...}
```

Validation:
- `name` must be unique across the merged catalog.
- `name` must match `[a-z][a-z0-9_]*`.
- `statements` for `custom` policies must NOT contain unconditional `settings:objects:write` (gotcha #16).
- `statements` for `templated` must contain at least one `${bindParam:...}`.

## `roles:` schema

```yaml
roles:
  bu:                                 # scope: one group per BU
    <role_name>:                      # lowercase id; group name will be {bu}-{Title}
      description: "..."              # used in TF group description
      policies:
        - name: <policy_name>         # must exist in policies[]
          boundary: bu_data |
                    bu_settings |
                    app_data |        # only valid in roles.app.*
                    app_settings      # only valid in roles.app.*
          params:                     # optional, only for templated policies
            <bindParam_name>: "string with {bu} or {app} tokens"
  app:                                # scope: one group per application
    <role_name>:
      description: "..."
      policies: [...]
```

Group name pattern: `{bu_or_app}-{Title(role_name)}` — e.g. role key `admins` under `bu1` → group `bu1-Admins`.

## Boundary keys

The four boundary types are defined statically in `outputs/boundaries_main.tf` (rarely changed). Roles reference them by key:

| Boundary key | Indexed by | Use for |
|---|---|---|
| `bu_data` | BU key (`each.value.bu` for app roles, `each.key` for bu roles) | `storage:*` permissions scoped to the whole BU |
| `bu_settings` | BU key | `settings:*` permissions scoped to the whole BU |
| `app_data` | App key (`each.key`) | `storage:*` permissions scoped to one app across its stages |
| `app_settings` | App key | `settings:*` permissions scoped to one app across its stages |

Storage and settings boundaries can coexist on different `policy {}` blocks within the same binding resource (gotcha #21).

## Param interpolation

`params:` values are strings passed to the policy at binding time. The generator substitutes:

| Token | Becomes (bu role) | Becomes (app role) |
|---|---|---|
| `{bu}` | `each.key` | `each.value.bu` |
| `{app}` | (forbidden — fail validation) | `each.key` |

Example for `scoped_settings_write` bound to a BU admin role:

```yaml
- name: scoped_settings_write
  boundary: bu_settings
  params: { security_context_prefix: "{bu}-" }
```

renders to:

```hcl
parameters = { "security_context_prefix" = "${each.key}-" }
```

## Merge order (customer overrides defaults)

The generator loads `defaults.yaml`, then applies the customer's `inputs.yaml`:

1. **Policies** — keyed by `name`. A customer entry with the same `name` as a default replaces the default entirely. New names append.
2. **Roles** — keyed by `<scope>.<role_name>`. Same replacement-by-key rule. To remove a default role, set it to `null`:
   ```yaml
   roles:
     bu:
       users: null   # remove the default bu users role
   ```
3. **Dimensions** — `business_units`, `applications` (derived), `stages` are taken verbatim from `inputs.yaml`; defaults provide nothing here.

## Default role capability matrix (shipped in `defaults.yaml`)

| Capability | bu.admins | bu.users | app.admins | app.users |
|---|---|---|---|---|
| Base policy | Standard User | Standard User | Standard User | Standard User |
| Data access | Scoped to BU | Scoped to BU | Scoped to app | Scoped to app |
| Settings write | Yes (BU-scoped) | No | Yes (app-scoped) | No |
| Settings read | Global (Std User) | Global | Global | Global |
| SLO write | Yes (Admin Features) | No | Yes (SLO Manager) | No |
| Automation admin | Yes | No | No | No |
| Extensions write | Yes | No | No | No |
| OpenPipeline write | Yes | No | No | No |
| Anomaly detection write | Yes | Yes | Yes | Yes |

## Security context

```
dt.security_context = {bu}-{stage}-{application}-{component}
```

All values **lowercase**. Use `startsWith()` for hierarchical scoping.

| Boundary use case | Pattern |
|---|---|
| Whole BU | `startsWith "{bu}-"` |
| One stage of a BU | `startsWith "{bu}-{stage}-"` |
| One app across all stages | one `startsWith "{bu}-{stage}-{app}"` line per active stage (OR'd) |
| One component | `startsWith "{bu}-{stage}-{app}-{component}"` |

## Additional Grail fields (no IAM enforcement)

- `dt.cost.costcenter`, `dt.cost.product` — usable in policy WHERE clauses
- Customer-defined `primary_tags.*` — for filtering/segments/DQL only; **cannot** be used in IAM conditions

## Anti-patterns

- ❌ Adding a custom policy with unconditional `settings:objects:write` (gotcha #16)
- ❌ Referencing a non-existent boundary key (only the 4 listed above are valid)
- ❌ Using `app_data`/`app_settings` in a `roles.bu.*` role
- ❌ Using `{app}` token in a `roles.bu.*` param value
- ❌ Renaming a role after it has been bound — the group is recreated, losing memberships
