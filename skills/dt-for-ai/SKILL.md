---
name: dt-for-ai
description: Bridge to the official Dynatrace for AI skills (https://github.com/Dynatrace/dynatrace-for-ai) — DQL essentials, observability skills (services, hosts, kubernetes, logs, problems, tracing, AWS, frontends), dashboards, notebooks, and migration. Load when the user asks DQL/observability questions, wants to query Dynatrace data, or wants AI-agent guidance for live Dynatrace environments. This skill explains how to install the upstream skills and which one to load for a given task.
license: Apache-2.0
---

# Dynatrace for AI — Bridge Skill

This repo focuses on **IAM generation**. For runtime operations against a live Dynatrace tenant — DQL queries, observability investigations, dashboards, notebooks, AI-assisted troubleshooting — load the official **Dynatrace for AI** skills from [github.com/Dynatrace/dynatrace-for-ai](https://github.com/Dynatrace/dynatrace-for-ai).

## Install the upstream skills

```bash
# Skills package (works with Claude Code, Cursor, Cline, GitHub Copilot, OpenCode, …)
npx skills add dynatrace/dynatrace-for-ai

# OR Claude Code plugin
claude plugin marketplace add dynatrace/dynatrace-for-ai
claude plugin install dynatrace@dynatrace-for-ai

# OR manual: copy skill directories into your agent's skills path
#   .agents/skills/  |  .claude/skills/  |  .cursor/skills/
```

## Pair with a Dynatrace tool

Skills provide **knowledge only**. To execute live queries, pair with one of:

| Tool | Use when |
|---|---|
| [`dtctl`](https://github.com/dynatrace-oss/dtctl) (kubectl-style CLI) | Running shell commands; CI; agent has shell access |
| [Dynatrace MCP server](https://docs.dynatrace.com/docs/shortlink/dynatrace-mcp-server) | Agent supports MCP natively |

## Skill catalog (upstream)

### DQL & Query Language

| Skill | Use for |
|---|---|
| `dt-dql-essentials` | **Required before writing any DQL.** Syntax rules, common pitfalls, query patterns. |

### Observability

| Skill | Use for |
|---|---|
| `dt-obs-services` | Service RED metrics, runtime telemetry (.NET/Java/Node.js/Python/PHP/Go) |
| `dt-obs-frontends` | RUM, Web Vitals, user sessions, mobile crashes |
| `dt-obs-tracing` | Distributed traces, spans, dependencies, failure detection |
| `dt-obs-hosts` | Host/process metrics: CPU, memory, disk, network, containers |
| `dt-obs-kubernetes` | Clusters, pods, nodes, workloads, labels, relationships |
| `dt-obs-aws` | EC2, RDS, Lambda, ECS/EKS, VPC, LBs, cost optimization |
| `dt-obs-logs` | Log queries, filtering, pattern analysis, correlation |
| `dt-obs-problems` | Davis problems, RCA, impact assessment |

### Platform

| Skill | Use for |
|---|---|
| `dt-app-dashboards` | Create/modify dashboard JSON: tiles, layouts, variables |
| `dt-app-notebooks` | Create/modify notebook JSON: sections, DQL, analytics workflows |

### Migration

| Skill | Use for |
|---|---|
| `dt-migration` | Convert classic entity-based DQL/topology to Smartscape |

## Reusable prompts

Upstream `prompts/` directory provides templates (copy into `.github/prompts/` for VS Code slash commands):

- `daily-standup` — health summary across services
- `health-check` — single-service production health
- `incident-response` — triage + RCA for an active incident
- `investigate-error` — Davis problem → logs → traces walk-through
- `performance-regression` — deployment regression analysis
- `troubleshoot-problem` — structured Davis problem investigation

## How this skill is used here

1. The IAM generator (this repo) **does not** query a live tenant — it produces Terraform.
2. After applying the generated config, switch to the `dt-for-ai` skills + a Dynatrace tool to:
   - Verify a test user's effective permissions via DQL (`fetch dt.system.events`)
   - Build a dashboard showing `dt.security_context` distribution per BU
   - Investigate access-denial events surfaced as Davis problems
3. Reference these skills from generated `outputs/README.md` for downstream operability.

## Why use Agent Skills format

This repo packages its own knowledge under `skills/` using the same [Agent Skills](https://agentskills.io/) specification, so any agent that supports Dynatrace for AI can also load this repo's skills with no extra wiring.
