# Permissions Cheatsheet

Vetted permission identifiers for Dynatrace Grail (3rd Gen) IAM. Always validate via the IAM policy validation endpoint before committing — this list is curated but not exhaustive.

## Storage (Grail data) — supports `storage:dt.security_context`

| Identifier | Notes |
|---|---|
| `storage:logs:read` | Bucket access via `Read Logs` default policy |
| `storage:metrics:read` | `Read Metrics` |
| `storage:spans:read` | `Read Spans` |
| `storage:events:read` | `Read Events` |
| `storage:bizevents:read` | `Read BizEvents` |
| `storage:entities:read` | `Read Entities` — only `entity.type` and `dt.security_context` conditions valid |
| `storage:system:read` | `Read System Events` — no security_context support |
| `storage:bucket-definitions:read` | In Standard User |
| `storage:fieldset-definitions:read` | In Standard User |
| `storage:filter-segments:read/write/delete` | In Standard User |

## Settings — supports `settings:dt.security_context`, `settings:schemaId`, `settings:schemaGroup`

| Identifier | Notes |
|---|---|
| `settings:objects:read` | Unconditional in Standard User |
| `settings:objects:write` | **Only via bounded Scoped Settings Write or schemaId/schemaGroup conditions** |
| `settings:objects:admin` | In Admin User (not used here) |
| `settings:schemas:read` | In Standard User |

## Automation — tenant-wide

| Identifier | Notes |
|---|---|
| `automation:workflows:read` | In Standard User |
| `automation:workflows:run` | In Standard User |
| `automation:workflows:write` | Standard User has it conditionally (`workflow-type = "SIMPLE"`); full write in Admin Features |
| `automation:workflows:admin` | Admin Features |
| `automation:calendars:read/write` | read in Standard User; write in Admin Features |
| `automation:rules:read/write` | read in Standard User; write in Admin Features |

## SLOs

| Identifier | Notes |
|---|---|
| `slo:slos:read` | Standard User |
| `slo:slos:write` | Admin Features (BU) or SLO Manager (App) |
| `slo:objective-templates:read` | Standard User |

## Extensions

| Identifier | Notes |
|---|---|
| `extensions:read` | Standard User |
| `extensions:definitions:read/write` | write in Admin Features |
| `extensions:configurations:read/write` | write in Admin Features |

## App Engine

| Identifier | Notes |
|---|---|
| `app-engine:apps:install` | Admin Features |
| `app-engine:apps:run` | Admin Features |
| `app-engine:apps:delete` | Admin Features |

## Documents

| Identifier | Notes |
|---|---|
| `document:documents:read/write/delete` | Standard User |
| `document:environment-shares:*` | Standard User |
| `document:direct-shares:*` | Standard User |
| `document:trash.*` | Standard User |

## Davis

| Identifier | Notes |
|---|---|
| `davis:analyzers:read/execute` | Standard User |
| `davis-copilot:conversations:execute` | Standard User |
| `davis-copilot:nl2dql:execute` | Standard User |
| `davis-copilot:dql2nl:execute` | Standard User |

## Hub & misc

| Identifier | Notes |
|---|---|
| `hub:catalog:read` | Standard User |
| `notification:notifications:read/write` | Standard User |
| `vulnerability:read` | Standard User |
| `oauth2:clients:manage` | Admin User only — not used here |

## Invalid / commonly-mistaken identifiers

These look plausible but fail validation. **Do not use.**

| Invalid | Why |
|---|---|
| `hub:catalog-items:install` | Hub namespace only supports `catalog:read` |
| `activegate:activegates:read` | `activegate:*` namespace does not exist |
| `activegate:activegates:write` | Same |
| `openpipeline:configurations:read/write` | Legacy IAM API — superseded by `settings:objects:write WHERE schemaId = "builtin:openpipeline.*"` (see [gotchas #23](gotchas.md)) |
| `environment:roles:viewer` | 2nd-gen — bypasses Grail security context (see [generator gotchas #10](../../dt-iam-generator/references/gotchas.md)) |
| `environment:roles:operator` | Same |
| `environment:management-zone:*` | 2nd-gen — replaced by `dt.security_context` |

## OpenPipeline schemas (Settings 2.0)

Per signal, 5 sub-schemas exist. Only `.pipelines` is granted to BU Admins.

| Sub-schema | Purpose | Granted? |
|---|---|---|
| `builtin:openpipeline.<signal>.pipelines` | Pipeline definitions | ✅ BU Admins |
| `builtin:openpipeline.<signal>.ingest-sources` | Ingest sources | ❌ |
| `builtin:openpipeline.<signal>.data-forwarding` | Data forwarding | ❌ |
| `builtin:openpipeline.<signal>.routing` | Routing rules | ❌ central platform only |
| `builtin:openpipeline.<signal>.pipeline-groups` | Pipeline groups | ❌ central platform only |

Signals (13): `bizevents`, `davis.events`, `davis.problems`, `events`, `events.sdlc`, `events.security`, `logs`, `metrics`, `security.events`, `spans`, `system.events`, `user.events`, `usersessions`.

## Anomaly detection schema group

```
ALLOW settings:objects:write WHERE settings:schemaGroup = "group:anomaly-detection";
```

Granted to **all four** group types (Admins and Users at BU and App level), unbounded — `schemaGroup` is itself the scope control.

## References

- [Default Policies](https://docs.dynatrace.com/docs/manage/identity-access-management/permission-management/default-policies)
- [IAM Policy Reference](https://docs.dynatrace.com/docs/manage/identity-access-management/permission-management/iam-policy-reference)
- [Settings 2.0 Schemas](https://docs.dynatrace.com/docs/dynatrace-api/environment-api/settings/schemas)
