# Generation & Modeling Gotchas

Lessons that affect the overall generation workflow — input modeling, naming, scaling.

## #0 — Set dt.security_context directly via oneagentctl

Set `dt.security_context` explicitly on the host using `oneagentctl`, not derived from primary tags via OpenPipeline. Pipeline-based derivation requires the pipeline to exist before data is ingested — any gap means data arrives without a security context and cannot be retroactively scoped.

See [security-context-enrichment.md](./security-context-enrichment.md) for the command pattern.

## #1 — Application-to-BU mapping is 1:1

Each application belongs to **exactly one** BU. Do not model applications as shared across BUs.

If two BUs genuinely have apps with the same logical name (e.g. both have a "wallet" service), give them unique IDs in `inputs.yaml`:

```yaml
business_units:
  bu-payments:
    applications: [payments-wallet]
  bu-rewards:
    applications: [rewards-wallet]
```

The Terraform variables map requires unique keys, and the security context format depends on a single BU per app.

## #1b — Security context is the primary enforcement field

Use a consistent, hierarchical format: `{bu}-{stage}-{application}-{component}`, all lowercase. Use `startsWith()` for hierarchical scoping. Ensure security_context is **always populated** at ingest time (#0). Never rely on segments for security — segments provide filtering, not enforcement.

## #3 — Templated policies have constraints

`${bindParam:name}` parameters reduce overhead at scale, but:

- **Parameter names are immutable after binding** — you cannot rename a `bindParam` once any group is bound to the policy.
- **Parameter mismatch returns 400** — every binding must supply exactly the parameters the policy declares.
- **List values use comma-separated strings** for `IN`: `"stages" = "prod,dev,test"`.
- **In Terraform heredocs**, escape with double `$`: `$${bindParam:security_context_prefix}`. The doubled `$$` produces literal `${}` after Terraform's interpolation.

## #10 — Avoid 2nd-gen permission namespaces in Grail

| 2nd-gen (avoid) | 3rd-gen alternative |
|---|---|
| `environment:roles:viewer` | Use `Standard User` default policy |
| `environment:roles:operator` | Use specific 3rd-gen permissions |
| `environment:management-zone:*` | Use `storage:dt.security_context` |
| `tenant:*` | Use account-level policies |

These bypass Grail security_context and provide unscoped access. Mixing 2nd and 3rd gen creates inconsistent access patterns.

## #13 — Common mistakes to avoid

1. Creating custom policies without checking default policy contents (Standard User covers most needs).
2. Trying to scope `settings:read` (Standard User grants it unconditionally — see [policy-authoring gotchas #5](../../dt-iam-policy-authoring/references/gotchas.md#5--iam-is-additive-settingsread-cannot-be-scoped)).
3. Using Admin User for any scoped group (see [policy-authoring gotchas #16](../../dt-iam-policy-authoring/references/gotchas.md#16--admin-user-grants-unconditional-settingswrite--never-use-it)).
4. Splitting a group's bindings across multiple resources (see [bindings gotchas #21](../../dt-iam-bindings/references/gotchas.md#21--one-bindings_v2-resource-per-group-most-common-cause-of-403s)).
5. Forgetting to bind default `Read <table>` policies (see [bindings gotchas #19](../../dt-iam-bindings/references/gotchas.md#19--default-data-read-policies-required-for-grail-bucket-access)).
6. Mixed-case names anywhere (see [validation gotchas #18](../../dt-iam-validation/references/gotchas.md#18--all-iam-values-must-be-lowercase)).
7. Reintroducing product-specific names in the generic project — keep names abstract.

## Minimal custom policy set

For most deployments, exactly these custom/templated policies are needed:

| Policy | Type | Purpose |
|---|---|---|
| `Admin Features (No Settings Write)` | custom | BU Admin features without settings write — replaces Admin User |
| `OpenPipeline Management` | custom | Settings 2.0 schema-scoped pipeline write |
| `Anomaly Detection Write` | custom | All-user `schemaGroup`-scoped settings write |
| `SLO Manager` | custom | App-level SLO write |
| `Scoped Grail Data Read` | templated | Record-level Grail data filtering |
| `Scoped Settings Write` | templated | Only source of `settings:objects:write` |

All other capabilities come from default policies (Standard User + Read Logs/Metrics/Spans/Events/BizEvents/Entities + Read System Events).

## #24 — `inputs.yaml` policies/roles override defaults BY NAME

The generator merges `inputs.yaml.policies` and `inputs.yaml.roles` on top of `defaults.yaml`. The merge key is `policies[].name` for policies and `roles.<scope>.<role_name>` for roles. A customer entry with the same name **replaces** the default entirely (no field-level merge).

Implications:
- Renaming a default in `inputs.yaml` (e.g. `read_logs` → `read_log_records`) creates a new policy AND leaves the default in the catalog — likely not what you want. Stick to the default `name` when overriding.
- To remove a default role, set it to `null`: `roles.bu.users: null`.
- To tighten a default policy, repeat its `name` with the modified `statements`.

## #25 — Always merge defaults; never assume `inputs.yaml` is complete

The minimal valid `inputs.yaml` is `business_units` + `stages`. Both `policies:` and `roles:` are optional. The generator MUST always load `defaults.yaml` before validation — otherwise it will fail to resolve role policy references when the customer hasn't redefined them.

## #26 — Group naming: lowercase scope + Title-cased role

Group name pattern is `{scope_key}-{TitleCase(role_name)}`. Examples:
- `bu1` + `admins` → `bu1-Admins`
- `petclinic01` + `auditors` → `petclinic01-Auditors`

If a customer defines a role with a multi-word name (e.g. `on_call_engineers`), Title-case each word: `Bu1-OnCallEngineers`. Underscore-to-camel conversion is fine; do not introduce hyphens (they're already used as the BU/role separator).

Renaming a role after it's been bound recreates the group, dropping all memberships. Treat role keys as stable identifiers.
