# Policy Authoring Gotchas

Lessons specific to authoring policies (`dynatrace_iam_policy` resources, default policies, statement syntax).

## #4 — Always check default policies before creating custom ones

Dynatrace maintains default policies that stay up-to-date with platform changes. Standard User and Admin User cover most common needs.

**Standard User includes** (no need to recreate):
- `settings:objects:read`, `settings:schemas:read` (UNCONDITIONAL)
- `document:documents:*`, `document:*-shares:*`, `document:trash:*`
- `automation:workflows:read`, `run`; `write WHERE workflow-type = "SIMPLE"`; `automation:calendars:read`, `automation:rules:read`
- `davis:analyzers:read/execute`, `davis-copilot:*:execute`
- `slo:slos:read`, `slo:objective-templates:read`
- `notification:notifications:read/write`
- `hub:catalog:read`, `extensions:read`, `vulnerability:read`
- `storage:bucket-definitions:read`, `storage:fieldset-definitions:read`, `storage:filter-segments:*`

**Not in any default policy** — must be granted via custom/templated policies:
- `storage:logs:read` ❌
- `storage:metrics:read` ❌
- `storage:spans:read` ❌
- `storage:events:read` ❌
- `storage:bizevents:read` ❌

## #5 — IAM is additive: settings:read cannot be scoped

Standard User grants unconditional `settings:objects:read`. A custom "Scoped Settings Read" policy adds nothing — the broader grant always wins. Only `settings:write` can be meaningfully scoped via `Scoped Settings Write` + boundary.

**What you CAN scope:** Grail data (logs, metrics, spans, events), settings write, entities read.
**What you CANNOT scope:** settings read, automation, SLO, extensions, app-engine, document (see #20).

## #16 — Admin User grants unconditional settings:write — never use it

The Admin User default policy bundles feature-level permissions with `settings:objects:write` unconditionally. You cannot selectively boundary-scope individual permissions within a default policy — it's all or nothing.

Even if a *separate* binding attaches `Scoped Settings Write` with a boundary, the unbounded Admin User grant wins (IAM is additive).

**Correct approach:**
1. Do NOT bind `Admin User`.
2. Bind `Standard User` + a custom `Admin Features (No Settings Write)` policy that cherry-picks admin capabilities WITHOUT settings write.
3. Grant settings write only via the bounded `Scoped Settings Write` templated policy.

## #17 — Validate permission identifiers before committing

Not all identifiers that look logical are valid. Validate via:

```
POST /iam/v1/repo/account/{accountId}/policies/validation
{ "name": "test", "statementQuery": "ALLOW <namespace>:<resource>:<verb>;" }
```

**Confirmed invalid (do not use):**
| Identifier | Why |
|---|---|
| `hub:catalog-items:install` | Hub namespace only supports `catalog:read` |
| `activegate:activegates:read` | `activegate:*` namespace doesn't exist |
| `activegate:activegates:write` | Same |

## #20 — Feature permissions are tenant-wide — boundaries don't apply

Only two namespaces support `dt.security_context`-based scoping:

| Namespace | Scopable? |
|---|---|
| `storage:*` | ✅ via `storage:dt.security_context` |
| `settings:*` | ✅ via `settings:dt.security_context`, `schemaId`, `schemaGroup` |
| `automation:*` | ❌ tenant-wide |
| `slo:*` | ❌ tenant-wide |
| `extensions:*` | ❌ tenant-wide |
| `openpipeline:*` | ❌ tenant-wide |
| `app-engine:*` | ❌ tenant-wide |
| `document:*` | ❌ tenant-wide |

Applying a `storage:dt.security_context` boundary to an `automation:workflows:write` permission has **no effect** — the permission becomes unconditional.

**Implication for BU Admins:** they can manage automations, SLOs, extensions, OpenPipeline, and App Engine apps **across the entire environment**. Data and settings remain BU-scoped. If strict feature isolation is required, reserve those permissions for a central platform admin group instead.

## #22 — SchemaGroup-scoped settings write for cross-cutting features

Some settings features (anomaly detection) need write access for ALL users — not just admins. Use `settings:schemaGroup` to limit write scope:

```
ALLOW settings:objects:write
  WHERE settings:schemaGroup = "group:anomaly-detection";
```

Bound **without boundaries** — the schemaGroup condition is the scope control. Reuse this pattern for any other cross-cutting schema group.

## #23 — OpenPipeline: use Settings 2.0, not the legacy API

The old `openpipeline:configurations:read/write` belongs to the legacy IAM API. Use Settings 2.0 instead:

```
ALLOW settings:objects:write
  WHERE settings:schemaId = "builtin:openpipeline.<signal>.pipelines";
```

**Per-signal sub-schemas (Settings 2.0):**
| Sub-schema | Purpose | Granted? |
|---|---|---|
| `builtin:openpipeline.<signal>.pipelines` | Pipeline definitions | ✅ BU Admins |
| `builtin:openpipeline.<signal>.ingest-sources` | Ingest sources | ❌ |
| `builtin:openpipeline.<signal>.data-forwarding` | Data forwarding | ❌ |
| `builtin:openpipeline.<signal>.routing` | Routing rules | ❌ central platform only |
| `builtin:openpipeline.<signal>.pipeline-groups` | Pipeline groups | ❌ central platform only |

Signals (13): `bizevents`, `davis.events`, `davis.problems`, `events`, `events.sdlc`, `events.security`, `logs`, `metrics`, `security.events`, `spans`, `system.events`, `user.events`, `usersessions`.
