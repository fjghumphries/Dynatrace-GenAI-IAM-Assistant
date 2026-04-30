# Validation & Operational Gotchas

Lessons specific to validating, applying, and verifying IAM configurations.

## #11 — `terraform apply` success ≠ correct effective permissions

`terraform apply` only confirms the API accepted the resources. It does NOT confirm the user can actually do what you intended. Always:

1. Add a real test user to the new group(s).
2. Open Account Management → Identity & Access → Groups → select group → **Effective permissions**. Confirm `storage:logs:read`, `storage:metrics:read`, etc. appear with the expected boundary.
3. Run a smoke-test DQL query as the user (e.g. `fetch logs | limit 1`) — should return only records matching the boundary.
4. Try to write a setting outside the BU scope — should fail with 403.
5. Inspect `dt.system.events` for `SETTINGS_CHANGE` events to confirm what the user actually attempted.

## #18 — All IAM values must be lowercase

Grail bucket names are case-sensitive and must be lowercase. Since `dt.security_context` maps to bucket names, every BU name, application name, stage, and security_context value must also be lowercase. A boundary referencing `bu-platform-` will NOT match an uppercase value like `BU-PLATFORM-prod-app-alpha`.

The `lower()` function is applied in Terraform boundary queries and binding parameters as a safeguard, but the source values in `inputs.yaml` should already be lowercase.

## #6 — Provider specifics

- **Account vs environment policies:** `dynatrace_iam_policy_bindings_v2` cannot mix account-level and environment-level policies in the same resource.
- **`lifecycle { ignore_changes = [permissions] }`** on every group resource — prevents `terraform plan` thrash when bindings are managed via `dynatrace_iam_policy_bindings_v2` (which sets group permissions out-of-band from the group resource).
- Use `policy_id.uuid` instead of `policy_id.id` when only the UUID is needed — the `id` is a composite string.

## #12 — Scaling considerations

| Limit | Value |
|---|---|
| Statements per policy | 100 |
| Conditions per boundary | 10 |
| Policies per binding | (no hard limit observed; ~13 used here) |

At 16K+ resources, `terraform plan` can take several minutes. Consider splitting into modules per BU when resource counts exceed ~5000.

**Resource counts at scale (10 BUs, 2000 apps):**
| Resource | Count |
|---|---|
| Policies | 14 (constant — templates reuse via parameters) |
| Boundaries | 4,020 |
| Groups | 4,020 |
| Bindings | 4,020 |

## Pre-apply checks

```bash
cd outputs
terraform fmt -check
terraform validate
terraform plan -out=tfplan

# Sanity: each group must be referenced by EXACTLY ONE binding resource (gotchas #21)
grep -E "group += dynatrace_iam_group\." bindings_*.tf | sort | uniq -c | sort -rn
```

Any group appearing more than once → split bindings — consolidate (see [bindings gotchas #21](../../dt-iam-bindings/references/gotchas.md#21--one-bindings_v2-resource-per-group-most-common-cause-of-403s)).
