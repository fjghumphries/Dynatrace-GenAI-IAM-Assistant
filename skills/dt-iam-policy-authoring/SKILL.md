---
name: dt-iam-policy-authoring
description: Author and review Dynatrace IAM policies — permission identifiers, statement syntax, conditions (storage:*, settings:*, schemaId, schemaGroup), and templated parameters. Load this skill before creating or editing any policy resource. Includes a permissions cheatsheet under references/.
license: Apache-2.0
---

# Dynatrace IAM Policy Authoring

Use when authoring or reviewing `dynatrace_iam_policy` resources or `data "dynatrace_iam_policy"` references.

## References (load on demand)

| Reference | When to load |
|---|---|
| [references/permissions-cheatsheet.md](references/permissions-cheatsheet.md) | When choosing or validating permission identifiers |
| [references/gotchas.md](references/gotchas.md) | Always — covers default-policy contents, additivity, Admin User trap, validation, schemaGroup, OpenPipeline migration |

## Statement syntax

```
ALLOW <namespace>:<resource>:<verb>[, <verb> ...]
  [WHERE <condition> [AND <condition>]];
```

- One statement per line, terminated with `;`.
- Multiple verbs on one line via comma.
- `WHERE` accepts `=`, `!=`, `startsWith`, `endsWith`, `contains`, `matches`, `IN`.
- `bindParam` placeholder: `$${bindParam:name}` inside a Terraform heredoc (single `$` is interpolated by Terraform; the doubled `$$` produces literal `${}`).

## Permission namespaces (cheatsheet)

| Namespace | Examples | Scopable by `dt.security_context`? |
|---|---|---|
| `storage:*` | `storage:logs:read`, `storage:metrics:read`, `storage:entities:read` | ✅ via `storage:dt.security_context` |
| `settings:*` | `settings:objects:read/write`, `settings:schemas:read` | ✅ via `settings:dt.security_context`, also `schemaId`, `schemaGroup` |
| `automation:*` | `workflows:read/write/run/admin`, `calendars:*`, `rules:*` | ❌ tenant-wide |
| `slo:*` | `slos:read/write`, `objective-templates:read` | ❌ tenant-wide |
| `extensions:*` | `definitions:read/write`, `configurations:read/write` | ❌ tenant-wide |
| `app-engine:*` | `apps:install/run/delete` | ❌ tenant-wide |
| `document:*` | `documents:read/write/delete`, `*-shares:*` | ❌ tenant-wide |
| `openpipeline:*` | **Legacy — do not use** | — |

See [references/permissions-cheatsheet.md](references/permissions-cheatsheet.md) for the full list of vetted identifiers, plus invalid ones that look plausible but fail validation.

## Default policies — what's already included

`Standard User` already grants (uncondionally):
- `settings:objects:read`, `settings:schemas:read`
- `document:documents:*`, `document:*-shares:*`, `document:trash:*`
- `automation:workflows:read`, `run`; `automation:workflows:write WHERE automation:workflow-type = "SIMPLE"`; `automation:calendars:read`, `automation:rules:read`
- `davis:analyzers:read/execute`, `davis-copilot:*:execute`
- `slo:slos:read`, `slo:objective-templates:read`
- `notification:notifications:read/write`
- `hub:catalog:read`, `extensions:read`, `vulnerability:read`

**Never assigned** in this project: `Admin User` — it grants unconditional `settings:objects:write` that bypasses boundaries (see [gotchas #16](references/gotchas.md)).

**Not in any default**: Grail data reads (`storage:logs:read`, etc.) — must come from `Read Logs`/`Read Metrics`/... default policies bound with boundaries (see [bindings gotchas #19](../dt-iam-bindings/references/gotchas.md)).

## Custom policies authored by this project

The **default catalog** ([`../dt-iam-generator/references/defaults.yaml`](../dt-iam-generator/references/defaults.yaml)) ships these custom policies. Customers may override them or add new ones via `policies:` in `inputs.yaml`.

| Policy | Statement(s) | Default role bindings |
|---|---|---|
| `Admin Features (No Settings Write)` | `automation:workflows:*`, `automation:calendars:*`, `automation:rules:*`, `slo:slos:*`, `slo:objective-templates:read`, `extensions:definitions:*`, `extensions:configurations:*`, `app-engine:apps:install/delete/run` | bu.admins |
| `Anomaly Detection Write` | `settings:objects:write WHERE settings:schemaGroup = "group:anomaly-detection"` | All roles (unbounded) |
| `OpenPipeline Management` | `settings:objects:write WHERE settings:schemaId = "builtin:openpipeline.<signal>.pipelines"` × 13 signals | bu.admins (unbounded) |
| `SLO Manager` | `slo:slos:read/write`, `slo:objective-templates:read` | app.admins |

## Authoring a NEW policy in `inputs.yaml`

Use the `policies:` block (see [group-model.md](../dt-iam-generator/references/group-model.md) for the full schema). Three types:

```yaml
policies:
  # type=default — reference an existing Dynatrace-maintained policy
  - name: read_security_events
    type: default
    dynatrace_name: "Read Security Events"

  # type=templated — a parameterised policy reused across groups with bindParam
  - name: scoped_logs_only
    type: templated
    display_name: "Scoped Logs Read"
    description: "Read logs filtered by security context."
    statements: |
      ALLOW storage:logs:read
        WHERE storage:dt.security_context startsWith "${bindParam:security_context_prefix}";

  # type=custom — literal statements, no parameters
  - name: security_auditor_read
    type: custom
    display_name: "Security Auditor Read"
    description: "Read-only access for compliance auditors."
    statements: |
      ALLOW storage:logs:read, storage:events:read, storage:bizevents:read;
      ALLOW iam:policies:read, iam:bindings:read;
      ALLOW settings:objects:read;
```

### Authoring rules

1. **Validate before committing.** Use `POST /iam/v1/repo/account/{accountId}/policies/validation` to confirm permission identifiers — see [gotchas #17](references/gotchas.md).
2. **Lowercase all values** — see [validation gotchas #18](../dt-iam-validation/references/gotchas.md).
3. **No `environment:roles:*`** — 2nd-gen, bypasses Grail security context. See [generator gotchas #10](../dt-iam-generator/references/gotchas.md).
4. **No `Management Zone` conditions** — replaced by `dt.security_context`.
5. **No legacy `openpipeline:configurations:*`** — superseded by Settings 2.0. See [gotchas #23](references/gotchas.md).
6. **One `bindParam` per parameter** — names cannot change after a policy is bound. See [generator gotchas #3](../dt-iam-generator/references/gotchas.md).
7. **Never grant unconditional `settings:objects:write`** in a `custom` policy — use `templated` with a boundary instead. The generator must reject this. See [gotchas #16](references/gotchas.md).
8. **`templated` policies must contain at least one `${bindParam:...}`** — otherwise downgrade to `custom`.
9. **`policies[].name`** must be unique across the merged catalog (defaults + customer entries). Customer entries with a duplicate `name` REPLACE the default — useful for tightening defaults; risky if you forget what you're overriding.
