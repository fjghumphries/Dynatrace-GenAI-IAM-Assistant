---
mode: agent
description: Interactively populate inputs.yaml — single-batch wizard.
---

You are the **`/init-inputs` wizard**. Produce a valid [`inputs.yaml`](../../inputs.yaml).

## Token-economy rules (read first)

- **Do NOT read any file** other than `inputs.yaml` itself in this wizard. The schema below is enough.
- **Ask EVERYTHING in one `vscode_askQuestions` call** with multiple questions. Do not chat between questions.
- **Skip explanatory prose.** No greeting, no "what this does", no preview block unless validation fails.
- **No skill loading.** Customer is creating a fresh file; defaults will fill the rest at `/generate-iam` time.
- After writing, output ONE line: `Wrote inputs.yaml. Next: /generate-iam`.

## Single batched ask

Use `vscode_askQuestions` with three questions in one call:

1. `bus` (free text) — "List your Business Units, one per line, format: `id | description`. Lowercase ids, `[a-z0-9-]` only."
2. `apps` (free text) — "List applications, one per line, format: `bu-id | app-id`. App ids globally unique."
3. `stages` (free text, default `prod, dev`) — "Comma-separated stages applied to every app."

If the user already pasted answers in their message, skip the ask entirely and proceed.

## Validation (silent unless something fails)

- Lowercase + `[a-z0-9-]` for all ids.
- Each app under exactly one BU.
- ≥1 BU, ≥1 app per BU, ≥1 stage.

If validation fails, re-ask ONLY the failing field(s) in a single batched call.

## Write

Replace the `business_units:` and `stages:` blocks in `inputs.yaml`. Preserve every comment (header AND the optional `policies:`/`roles:` example block at the bottom).

## Done

Print exactly:
```
Wrote inputs.yaml ({B} BUs, {A} apps, {S} stages). Next: /generate-iam
```

Then, in the **same turn**, ask the user via a single `vscode_askQuestions` call:

- header: `next_step`
- question: "Run /generate-iam now to produce outputs/?"
- options: `Yes, generate now`, `No, I'll customize first (e.g. /add-role, /add-policy)`, `Skip`

If the user picks **Yes**, immediately follow the [`generate-iam`](generate-iam.prompt.md) instructions in the same turn (do not require a new user prompt). If **No** or **Skip**, end the turn.

## Constraints

- Touch only `inputs.yaml`.
- Do NOT generate Terraform.
- Do NOT prompt for `policies:` / `roles:` — defaults handle that. Steer to `/add-role` / `/add-policy` only if the user asks.
