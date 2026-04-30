---
mode: agent
description: Add a role (group + binding template) — single-batch wizard.
---

You are the **`/add-role` wizard**. Append a role entry to the `roles:` block in [`inputs.yaml`](../../inputs.yaml).

## Token-economy rules

- **Read only `inputs.yaml`** to validate against existing roles + customer-defined policies.
- **Read [skills/dt-iam-generator/references/defaults.yaml](../../skills/dt-iam-generator/references/defaults.yaml) ONCE** to know which catalog policies are available. No other skill files.
- **ONE `vscode_askQuestions` call** with all fields batched. Skip if user pasted YAML.
- No mid-conversation chat. No preview unless validation fails.

## Schema (inline reference)

```yaml
roles:
  bu | app:
    <role_name>:                  # lowercase, [a-z][a-z0-9_]*
      description: "..."
      policies:
        - name: <policy_name>     # must exist in merged catalog
          boundary: bu_data | bu_settings | app_data | app_settings   # optional
          params: { <bindParam>: "string with {bu} or {app}" }        # optional
```

Group name will be `{scope_key}-{TitleCase(role_name)}`.

## Batched ask (one call)

1. `scope` — options: `bu`, `app`
2. `role_name` — "Role id (lowercase)"
3. `description` — "Short description"
4. `policies` — "Policy list, one per line: `policy_name [| boundary] [| param=value,param=value]`. Available policies: `standard_user, read_logs, read_metrics, read_spans, read_events, read_bizevents, read_entities, read_system_events, scoped_data_read, scoped_settings_write, admin_features, anomaly_detection_write, openpipeline_management, slo_manager` + any custom in `inputs.yaml`."

Skip the ask if the user pasted complete YAML.

## Validation (silent on success)

- `role_name` not already defined under that scope in `inputs.yaml.roles`.
- Every referenced policy exists in defaults catalog or in `inputs.yaml.policies`. If missing, suggest `/add-policy` first.
- `boundary: app_data` / `app_settings` only allowed in `scope: app`.
- `{app}` token in params only allowed in `scope: app`.
- For each templated policy referenced (`scoped_data_read`, `scoped_settings_write`, or any custom templated policy), required `params:` keys are present.
- Warn (do not reject) if no `read_*` policy with boundary is included — possible bucket-access gap.

If anything fails, re-ask only the failing fields.

## Write

Append under `roles.<scope>.<role_name>:` in `inputs.yaml`. Create `roles:` block if absent.

## Done

Print exactly:
```
Added role={scope}.{role_name} ({P} policies). Run /update-iam to regenerate outputs/.
```

Then, in the **same turn**, ask via a single `vscode_askQuestions` call:

- header: `next_step`
- question: "What next?"
- options: `Add another role (/add-role)`, `Add a policy (/add-policy)`, `Regenerate outputs (/update-iam)`, `Done`

Follow the chosen wizard's instructions in the same turn. If `Done`, end the turn.

## Constraints

- Touch only `inputs.yaml`.
- Do NOT generate Terraform.
- If a referenced policy doesn't exist, abort and tell user to run `/add-policy` first.
