# Security Context Enrichment

`dt.security_context` is the primary IAM enforcement field for Grail. Set it **directly on the host via `oneagentctl`** — never derive it from tags through OpenPipeline, because any pipeline gap means data arrives without a security context and cannot be retroactively scoped.

## Command pattern

```bash
sudo /opt/dynatrace/oneagent/agent/tools/oneagentctl \
  --restart-service \
  --set-host-group=bu-platform-app-alpha \
  --set-host-property="primary_tags.bu=bu-platform" \
  --set-host-property="primary_tags.stage=prod" \
  --set-host-property="primary_tags.application=app-alpha" \
  --set-host-property="dt.security_context=bu-platform-prod-app-alpha" \
  --set-host-property="dt.cost.costcenter=bu-platform" \
  --set-host-property="dt.cost.product=app-alpha"
```

## Critical notes

- **`--restart-service` is required.** Without it the change is silently ignored — the command warns and exits.
- **`host-group` and `dt.security_context` are independent.** `host-group` controls OneAgent configuration grouping. `dt.security_context` controls IAM scoping.
- **`primary_tags.*` are NOT usable in IAM policies.** They are filter/segment/DQL fields only.
- **All values lowercase** to match Grail bucket naming.
- The `dt.security_context` value must follow the format `{bu}-{stage}-{application}` (component suffix optional).

## Verifying enrichment

```dql
fetch dt.entity.host
| filter primary_tags.application == "app-alpha"
| fields entity.name, dt.security_context, primary_tags.bu, primary_tags.stage
| limit 20
```

Every host in scope must show a non-null `dt.security_context`. Any null value means OneAgent was not properly configured and that host's data cannot be scoped by IAM.
