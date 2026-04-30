# Dynatrace IAM Configuration — Grail 3rd Gen

Generated: 2026-04-30

## Overview

This Terraform configuration manages IAM for a Dynatrace Grail (3rd Gen) environment using `dt.security_context` as the primary enforcement field.

| Dimension | Value |
|---|---|
| Business Units | bu1, bu2, bu3 |
| Applications | petclinic01 (bu1), petclinic02 (bu2), petclinic03 (bu3) |
| Stages | prod, dev |
| Security context format | `bu-stage-application-component` (lowercase) |

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│ Policies (14)                                               │
│  8 Default │ 2 Templated │ 4 Custom  │
├─────────────────────────────────────────────────────────────┤
│ Boundaries (8)                                             │
│  2 BU Data │ 2 BU Settings │ 2 App Data │ 2 App Settings   │
├─────────────────────────────────────────────────────────────┤
│ Groups (8)                                                 │
│  2 BU Admins │ 2 BU Users │ 2 App Admins │ 2 App Users     │
├─────────────────────────────────────────────────────────────┤
│ Bindings (8) — ONE per group                               │
│  2 BU Admin │ 2 BU User │ 2 App Admin │ 2 App User         │
└─────────────────────────────────────────────────────────────┘
```

## Group Capabilities

| Group | Base Policy | Data Access | Settings | SLO Write | OpenPipeline | Anomaly Detectors |
|---|---|---|---|---|---|---|
| BU Admins | Standard User + Admin Features | Scoped to BU | Write (scoped) | Yes | Pipeline write (no routing/groups) | Yes |
| BU Users | Standard User | Scoped to BU | Read only (global) | No | Read only | Yes |
| App Admins | Standard User + SLO Manager | Scoped to app | Write (scoped) | Yes | Read only | Yes |
| App Users | Standard User | Scoped to app | Read only (global) | No | Read only | Yes |

## Key Design Decisions

1. **Admin User NOT used** — grants unconditional `settings:objects:write` (gotcha #16)
2. **ONE binding resource per group** — multiple resources overwrite each other (gotcha #21)
3. **Default data read policies + boundaries** — required for Grail bucket access (gotcha #19)
4. **Feature permissions are tenant-wide** — `automation:*`, `slo:*`, etc. cannot be scoped by `dt.security_context` (gotcha #20)
5. **Scoped Data Read at BU level only** — at app level, no single `startsWith` prefix covers one app across stages; boundaries on default read policies handle scoping
6. **All values lowercase** — Grail bucket names require lowercase (gotcha #18)
7. **Anomaly Detection Write for all users** — schemaGroup-scoped settings write so all groups can create anomaly detectors
8. **OpenPipeline via Settings 2.0** — `openpipeline:configurations:*` (old API) removed; pipeline write granted via `settings:objects:write WHERE settings:schemaId = "builtin:openpipeline.<signal>.pipelines"`. Routing and pipeline-group write never granted (gotcha #23)

## File Structure

| File | Description |
|---|---|
| `variables.tf` | BUs, applications, stages, account config |
| `boundaries_main.tf` | 8 boundary resources (4 types × 2) |
| `policies_default_policies.tf` | 8 default policy data sources |
| `policies_templated_policies.tf` | 2 parameterised policies |
| `policies_custom_policies.tf` | 4 custom policies (Admin Features, OpenPipeline Mgmt, Anomaly Detection Write, SLO Manager) |
| `groups_main.tf` | 8 group resources (4 types × 2) |
| `bindings_bu_bindings.tf` | 4 BU binding resources (2 BUs × 2 roles) |
| `bindings_application_bindings.tf` | 4 application binding resources (2 apps × 2 roles) |
| `outputs.tf` | Group IDs, policy IDs, boundary IDs, summary |
| `main.tf` | Configuration header |
| `provider.tf` | Dynatrace provider config |
| `versions.tf` | Required providers |

## Resource Counts

| Resource Type | Count |
|---|---|
| Policies (data sources) | 8 |
| Policies (created) | 6 |
| Boundaries | 8 |
| Groups | 8 |
| Bindings | 8 |
| **Total** | **38** |

## Usage

```bash
# Set environment variables (includes TF_VAR_* so no -var flags needed)
source .env

# Initialise and apply
terraform init
terraform plan
terraform apply
```
