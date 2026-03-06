# Dynatrace IAM Configuration

This directory contains the generated Terraform configuration for Dynatrace IAM
resources, specifically designed for a Grail-based (3rd Gen) Dynatrace environment.

Generated from `instructions.md` on 2026-03-06.

## Customer Input Summary

| Item | Value |
|------|-------|
| Business Units | bu1, bu2 |
| Applications | petclinic01 (bu1), petclinic02 (bu2) |
| Stages | prod, dev |
| Security Context Format | `{bu}-{stage}-{application}-{component}` |

---

## Architecture Overview

### Security Context Strategy

All IAM enforcement uses the `dt.security_context` field with the format:

```
bu-stage-application-component
```

Examples:
- `bu1-prod-petclinic01-api`
- `bu2-dev-petclinic02-web`

> **Note**: Bucket names in Grail must be lowercase. The `lower()` function is
> used in Terraform boundaries/bindings as a safety net. All values are defined
> lowercase at source (see LESSONS_LEARNED.md #18).

### Access Control Hierarchy

```
Account Level
├── BU-Level Groups
│   ├── {bu}-Admins          → Full access to all BU data + scoped settings write
│   └── {bu}-Users           → Read access to all BU data
│
└── Application-Level Groups
    ├── {application}-Admins → Read data + write settings for application
    └── {application}-Users  → Read-only access to application data
```

### Group Summary

| Group | Base Policy | Data Scope | Settings Write | SLOs |
|-------|-------------|------------|----------------|------|
| bu1-Admins | Std User + Admin Features | Full bu1 | Scoped to bu1 | Write |
| bu1-Users | Standard User | Full bu1 | None (read ok) | Read |
| bu2-Admins | Std User + Admin Features | Full bu2 | Scoped to bu2 | Write |
| bu2-Users | Standard User | Full bu2 | None (read ok) | Read |
| petclinic01-Admins | Standard User | bu1-*-petclinic01 | Scoped to app | Write |
| petclinic01-Users | Standard User | bu1-*-petclinic01 | None (read ok) | Read |
| petclinic02-Admins | Standard User | bu2-*-petclinic02 | Scoped to app | Write |
| petclinic02-Users | Standard User | bu2-*-petclinic02 | None (read ok) | Read |

### Policy Summary

| Policy | Type | Used By |
|--------|------|---------|
| Standard User | Default | All groups |
| Admin User | Default | **NOT USED** (grants unconditional settings write) |
| Read Logs | Default | All groups (with boundary) |
| Read Metrics | Default | All groups (with boundary) |
| Read Spans | Default | All groups (with boundary) |
| Read Events | Default | All groups (with boundary) |
| Read BizEvents | Default | All groups (with boundary) |
| Read Entities | Default | All groups (with boundary) |
| Read System Events | Default | BU Admins, App Admins |
| Scoped Grail Data Read | Templated | All groups (record-level filtering) |
| Scoped Settings Read | Templated | User groups |
| Scoped Settings Write | Templated | Admin groups |
| Admin Features (No Settings Write) | Custom | BU Admins only (environment-wide!) |
| SLO Manager | Custom | Application Admins only |

---

## Files Structure

```
outputs/
├── versions.tf                        # Terraform + provider version requirements
├── provider.tf                        # Dynatrace provider configuration
├── variables.tf                       # BU, application, stage definitions
├── terraform.tfvars.example           # Example variable values
├── outputs.tf                         # Output definitions
├── main.tf                            # Configuration notes
├── boundaries_main.tf                 # Policy boundary definitions (dynamic)
├── policies_default_policies.tf       # References to Dynatrace default policies
├── policies_templated_policies.tf     # Parameterized custom policies
├── policies_custom_policies.tf        # Admin Features + SLO Manager policies
├── groups_main.tf                     # Group definitions
├── bindings_bu_bindings.tf            # BU-level policy bindings
├── bindings_application_bindings.tf   # Application-level policy bindings
└── docs/
    ├── policies.txt                   # Human-readable policy reference
    ├── groups.txt                     # Human-readable group reference
    └── bindings.txt                   # Human-readable bindings reference
```

---

## Resource Counts

| Resource Type | Count |
|---------------|------:|
| Custom policies | 5 (2 custom + 3 templated) |
| Default policy data sources | 10 |
| Groups | 8 (4 BU + 4 Application) |
| Boundaries | 8 (2 BU data + 2 BU settings + 2 App data + 2 App settings) |
| Binding resources | 12 |
| **Total Terraform resources** | **~43** |

At scale (10 BUs, 2000 Applications): ~14,000 resources — 8 policies shared across all.

---

## Key Design Decisions

### 1. Admin User Default Policy is NOT Used

The `Admin User` default policy grants unconditional `settings:objects:write`
which **cannot** be scoped via boundaries (IAM is additive — the most permissive
grant wins). Instead, we use:

- **Standard User** — base feature access
- **Admin Features (custom)** — admin capabilities without settings write
- **Scoped Settings Write (templated)** — settings write, bounded to BU/app scope

See LESSONS_LEARNED.md #16.

### 2. Application Boundaries are Stage-Aware

Application boundaries are dynamically generated from `each.value.stages` in
Terraform. Adding a new stage to an application in `variables.tf` automatically
updates the boundary — no manual boundary edits required.

### 3. Settings Read is Global

`Standard User` grants unconditional `settings:objects:read`. This cannot be
restricted via boundaries (IAM is additive). Only **settings write** is
meaningfully scoped. See LESSONS_LEARNED.md #5.

### 4. Default Data Read Policies Required for Bucket Access

The `Scoped Grail Data Read` templated policy (with WHERE clause) provides
**record-level filtering** but does NOT grant **bucket-level access**. Users
also need the Dynatrace default `Read Logs`, `Read Metrics`, `Read Spans`,
`Read Events`, and `Read BizEvents` policies bound with boundaries. Without
them, users get "No bucket permissions for table". See LESSONS_LEARNED.md #19.

### 5. Admin Features Are Environment-Wide (Not Scopeable)

Permissions in the `Admin Features` custom policy (`automation:*`, `slo:*`,
`extensions:*`, `openpipeline:*`, `app-engine:*`) do NOT support
`dt.security_context` conditions. Applying a boundary to them has no effect.
BU Admins have tenant-wide access to these features by design. Only `storage:*`
and `settings:*` permissions can be scoped. See LESSONS_LEARNED.md #20.

---

## Prerequisites

1. **Dynatrace Account** with appropriate permissions
2. **OAuth Client** configured with these scopes:
   - `account-idm-read` — View users and groups
   - `account-idm-write` — Manage users and groups
   - `iam-policies-management` — View and manage policies
   - `account-env-read` — View environments

3. **Environment Variables** set:
   ```bash
   export DT_CLIENT_ID="your-client-id"
   export DT_CLIENT_SECRET="your-client-secret"
   export DT_ACCOUNT_ID="your-account-uuid"
   ```

---

## Usage

### 1. Initialize Terraform

```bash
cd outputs
terraform init
```

### 2. Create Variable File

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your account_id and environment_id
```

### 3. Review Changes

```bash
terraform plan
```

### 4. Apply

```bash
terraform apply
```

---

## Customization

### Adding a New Business Unit

Add to `variables.tf` defaults or `terraform.tfvars`:

```hcl
business_units = {
  "bu3" = {
    name         = "bu3"
    description  = "Business Unit 3"
    applications = ["myapp"]
  }
  # ... existing BUs
}
```

### Adding a New Application

```hcl
applications = {
  "myapp" = {
    name        = "myapp"
    description = "My Application - belongs to bu3"
    bu          = "bu3"
    stages      = ["prod", "dev"]
  }
  # ... existing applications
}
```

> Application map keys must be globally unique. If two BUs have apps with the
> same name, prefix the key (e.g. `bu1_myapp`, `bu2_myapp`). The `name` field
> drives the security context.

### Adding a New Stage to an Application

Simply add the stage to `stages` in the application definition:

```hcl
"petclinic01" = {
  stages = ["prod", "dev", "staging"]  # boundary auto-updates
}
```

---

## Troubleshooting

**Boundary does not apply**: Ensure you're using the correct namespace:
- `storage:dt.security_context` for Grail storage permissions
- `settings:dt.security_context` for settings on entities

**Permission Denied**: Verify OAuth client scopes, environment variables,
and that `account_id` is the bare UUID (without `urn:dtaccount:` prefix).

**Invalid permission identifier**: Not all permission strings that look logical
are valid. Validate against the IAM API before adding to policies.
See LESSONS_LEARNED.md #17.

---

## References

- [Dynatrace IAM Documentation](https://docs.dynatrace.com/docs/manage/identity-access-management)
- [IAM Policy Reference](https://docs.dynatrace.com/docs/manage/identity-access-management/permission-management/iam-policy-reference)
- [Default Policies](https://docs.dynatrace.com/docs/manage/identity-access-management/permission-management/default-policies)
- [Policy Boundaries](https://docs.dynatrace.com/docs/manage/identity-access-management/permission-management/manage-user-permissions-policies/iam-policy-boundaries)
- [Terraform Provider](https://registry.terraform.io/providers/dynatrace-oss/dynatrace/latest/docs)
