# GitHub Copilot Instructions — Dynatrace IAM Generator

This workspace generates Terraform-managed Dynatrace IAM configurations for Grail (3rd Gen) environments from an `instructions.md` specification file. Follow these rules on every interaction.

---

## Project Structure

- **`instructions.md`** — IAM specification and design rules. Contains a **Customer Input** section where users define their BUs, landscapes, and stages.
- **`sample-outputs/`** — A complete sample Terraform output for reference (2 BUs, 2 landscapes, 2 stages).
- **`outputs/`** — The target directory for newly generated Terraform configurations. All generated files go here.
- **`LESSONS_LEARNED.md`** — Gotchas, design decisions, and findings.

---

## Generation Rules

When asked to generate a Terraform IAM configuration:

1. **Read `instructions.md`** to understand the IAM model, group structure, policies, and constraints.
2. **Extract customer input** from the `Customer Input Required` section in `instructions.md`.
3. **Use `sample-outputs/`** as a reference for file structure, naming conventions, and Terraform patterns.
4. **Write all generated files to `outputs/`** — mirror the same file structure as `sample-outputs/`.

---

## Project Context

- **Provider**: dynatrace-oss/dynatrace ~> 1.91
- **IAM model**: Grail 3rd Gen only — no Management Zones, no `environment:roles:*`
- **Security context format**: `BU-STAGE-LANDSCAPE-COMPONENT` (e.g. `BU1-PROD-PETCLINIC01-API`)
- **IAM is additive**: permissions compound across bindings. Standard User grants unconditional `settings:objects:read` — settings read cannot be scoped via boundaries, only write can.
- **Generated files** (inside `outputs/`):
  - `variables.tf` — BUs, landscapes, stages definitions
  - `boundaries_main.tf` — boundary resources
  - `policies_*.tf` — default, templated, and custom policies
  - `groups_main.tf` — group resources
  - `bindings_*.tf` — policy binding resources
  - `docs/policies.txt` — human-readable policy reference
  - `docs/groups.txt` — human-readable group reference
  - `docs/bindings.txt` — human-readable bindings reference
  - `README.md` — architecture overview

---

## Mandatory Update Rules

### Rule 1 — Terraform changes → update docs

Whenever any Terraform file is changed (variables, policies, boundaries, groups, bindings), always update ALL of the following to stay in sync:

| File | What to update |
|---|---|
| `outputs/docs/policies.txt` | Policy list, counts, descriptions |
| `outputs/docs/groups.txt` | Group hierarchy, capabilities, counts |
| `outputs/docs/bindings.txt` | Binding tables, boundary references, counts |
| `outputs/README.md` | Architecture overview, group/policy tables, file structure |

Do not wait to be asked — update them as part of the same response that makes the Terraform change.

### Rule 2 — Lessons learned: always update proactively

Update `LESSONS_LEARNED.md` in ANY of these situations:

1. **A Terraform change reveals a design decision** — document why the change was made and what alternative was rejected.
2. **A user question reveals a misconception, gap, or gotcha** — document the finding even if no code changes are applied. The question itself is evidence of something worth capturing.
3. **An error or unexpected behaviour occurs** — document the root cause and fix.
4. **A new insight about Dynatrace IAM behaviour is discovered** — add it immediately.

`LESSONS_LEARNED.md` is a living document. Err on the side of adding entries, not skipping them.

---

## Doc Update Style Guidelines

- Keep all counts accurate (sample config numbers and at-scale projections)
- In `docs/*.txt` files, preserve the existing plain-text section format with `===` and `---` dividers
- In `README.md`, keep tables and code block formatting
- When updating `LESSONS_LEARNED.md`, add a new `##` section or append to an existing relevant section — never delete existing entries
- Never leave stale examples (e.g. old landscape names like `LANDSCAPE_A`) after a rename

---

## What NOT to do

- Do not create additional markdown summary files after changes — update the existing docs instead
- Do not leave `outputs/docs/*.txt` files out of sync with the Terraform configuration
- Do not skip a LESSONS_LEARNED update just because the user didn't explicitly ask for one
- Do not write generated files outside of `outputs/` — the root-level files (`instructions.md`, `LESSONS_LEARNED.md`) are project-level, not per-generation
