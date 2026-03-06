## 1. Objective

Assist in designing IAM policies and related Terraform configuration for a Dynatrace 3rd Gen (Grail) environment in a large enterprise.

Goals:
- Generate IAM using `dt.security_context` and Grail primary fields
- Avoid 2nd-gen constructs (no Management Zones, no `environment:roles:*`)
- Apply governance constraints defined by the central team
- Keep custom policy count minimal — maximise use of Dynatrace default policies

---

## 2. Customer Environment

- **10 Business Units (BUs)**
- **~2,000 applications** (also called deployments or landscapes)
- Previously used 1 Management Zone per deployment (2nd Gen) — migrating to Grail IAM
- Telemetry from: OneAgent, OpenTelemetry, Extensions, APIs

---

## 3. Group Model

Two levels of groups are created. Both levels have two roles. This is fixed — customers do not change the group structure, only the BU and application names they apply to.

### Levels

| Level | Scope | Example group names |
|---|---|---|
| **BU** | All data within a Business Unit (all applications, all stages) | `bu1-Admins`, `bu1-Users` |
| **Application** | Data within one application only (all stages within it) | `petclinic01-Admins`, `petclinic01-Users` |

### Roles

| Role | Base policy | Data access | Settings | SLO write |
|---|---|---|---|---|
| **Admins** (BU level) | Standard User + Admin Features (custom) | Scoped to BU | Write, scoped to BU | Yes (via Admin Features) |
| **Users** (BU level) | Standard User | Scoped to BU | Read only (global) | No |
| **Admins** (Application level) | Standard User + SLO Manager | Scoped to application | Write, scoped to application | Yes (via SLO Manager) |
| **Users** (Application level) | Standard User | Scoped to application | Read only (global) | No |

### Customer Input Required

> **⬇️ EDIT THIS SECTION with your BUs, applications, and stages, then ask Copilot to generate the Terraform configuration. ⬇️**

To generate the Terraform configuration, replace the example values below with your actual environment details:

```
<!-- ===================== CUSTOMER INPUT START ===================== -->

Business Units:
  - bu1 (applications: petclinic01)
  - bu2 (applications: petclinic02)

Stages active per application:
  - prod, dev

Application-to-BU mapping:
  - petclinic01 → bu1
  - petclinic02 → bu2

<!-- ===================== CUSTOMER INPUT END ======================= -->
```

> Each application belongs to exactly one BU. If two BUs have apps with the same name, use a unique identifier per application (e.g. `bu1-petclinic` and `bu2-petclinic`).

**Instructions:**
1. Replace the BU names (bu1, bu2, ...) with real business unit identifiers.
2. Replace the application names (petclinic01, ...) with real application/deployment names.
3. List all stages that apply (e.g. prod, dev, staging, test).
4. Ensure every application maps to exactly one BU.
5. Once updated, ask GitHub Copilot to generate the configuration (see the project README for suggested prompts).

---

## 4. Core IAM Principles

### 4.1 Primary Grail Fields

These fields exist across all signals and are usable in IAM policy conditions:

- `dt.security_context` — **primary enforcement field**
- `dt.cost.costcenter`
- `dt.cost.product`

### 4.2 Primary Grail Tags (Customer-defined)

Tags use the `primary_tags.<name>` prefix. Planned tags:
- `primary_tags.bu`
- `primary_tags.application`
- `primary_tags.stage`
- Possible future: tier, SOM, ownership team, criticality, component

> **IAM note**: Primary tags may not be directly usable in IAM policy conditions. `dt.security_context` remains the only reliable IAM enforcement field.

---

## 5. Security Context Strategy

### Format

```
dt.security_context = bu-stage-application-component
```

Examples:
- `bu1-prod-petclinic01-api`
- `bu2-dev-petclinic02-web`

### Rules

- Security context **must always be populated** at ingest time — data without it cannot be properly scoped
- Security context values **must be lowercase** — bucket names in Grail require lowercase
- It is **not multi-value**
- Use `startsWith()` for hierarchical scoping (e.g. all of bu1, or all of bu1-prod)
- Use exact match only when full precision is required

### Enrichment via OneAgent

Security context and primary tags are set directly on the host using `oneagentctl`. The OneAgent service must be stopped first (or use `--restart-service`).

```bash
sudo ./oneagentctl \
  --set-host-group=petclinic02 \
  --set-host-property="primary_tags.bu=bu2" \
  --set-host-property="primary_tags.stage=prod" \
  --set-host-property="primary_tags.application=petclinic02" \
  --set-host-property="dt.security_context=bu2-prod-petclinic02" \
  --restart-service
```

This sets:
- `host-group` — used for OneAgent configuration grouping (separate from IAM)
- `primary_tags.*` — custom tags for filtering, segments, and DQL (not directly usable in IAM policies)
- `dt.security_context` — the **IAM enforcement field**; must match the canonical format exactly

> **Note**: `dt.security_context` is set explicitly here rather than derived. This is the most reliable approach — derivation from tags requires OpenPipeline and introduces a dependency on the enrichment pipeline being in place.

---

## 6. Segments (Replaces Management Zones)

Segments are used for **filtering and visibility**, not security enforcement.

- Based on primary grail fields and primary grail tags
- Can combine conditions: `(segment1 OR segment2) AND stage == "prod"`
- Segments are read-only to end users; managed centrally

> **Critical**: IAM must NOT rely on segments for security enforcement. Security is enforced exclusively via `dt.security_context` in policy boundaries.
