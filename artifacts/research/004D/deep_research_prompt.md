# Deep Research Prompt — 004D

## Research Question

What are the best practices, frameworks, and patterns for production readiness
assessment that the current meta-production skill is missing or underutilizing?
The goal is an exhaustive survey of industry-standard PRR approaches, then a
gap analysis against the skill's current 10-dimension scoring model, scan
prompts, and report template.

## Sub-Questions

1. **SLO/SLI frameworks**: How do mature organizations define, enforce, and
   monitor SLOs/SLIs? What tooling exists (OpenSLO, Sloth, Google CUJ)?
   How should a PRR validate that SLOs are defined and measurable?

2. **Chaos engineering**: What is the state of the art for resilience testing
   (Chaos Monkey, Litmus, Gremlin, Toxiproxy, Chaos Mesh)? At what maturity
   level should chaos experiments be a PRR gate? What minimal chaos checks
   are reasonable pre-launch vs. post-launch?

3. **DORA metrics integration**: Beyond referencing DORA, how should a PRR
   actually measure deployment frequency, lead time, change failure rate, and
   MTTR? What thresholds map to Elite/High/Medium/Low? How do teams instrument
   these in practice (DORA dashboards, Sleuth, LinearB, Faros)?

4. **Deployment patterns**: Blue/green, canary, rolling, shadow/dark launches,
   feature flags, progressive delivery (Argo Rollouts, Flagger, LaunchDarkly).
   What should a PRR check for each pattern? When is "just restart the container"
   acceptable vs. requiring zero-downtime deployment?

5. **On-call readiness & incident response**: Runbooks, escalation policies,
   PagerDuty/OpsGenie/Grafana OnCall integration, war room procedures, blameless
   postmortem templates, incident severity classification. What does a PRR
   validate about operational readiness beyond "does a runbook exist"?

6. **Observability gaps**: Is the current observability prompt (Dimension 8)
   missing anything? OpenTelemetry best practices, SLI-based alerting (vs.
   symptom-based vs. cause-based), log aggregation patterns, anomaly detection,
   cost-aware observability.

7. **Security hardening for production**: What production-specific security
   checks exist beyond OWASP? Runtime security (Falco, Seccomp, AppArmor),
   supply chain attestation (SLSA, Sigstore), network policies, pod security
   standards, secrets rotation.

8. **Capacity planning & load testing**: Should a PRR include load test results
   or capacity estimates? What frameworks exist (k6, Locust, Gatling)? How do
   orgs set capacity thresholds vs. auto-scaling policies?

9. **Compliance & regulatory**: SOC2, HIPAA, GDPR, PCI-DSS production
   requirements. What operational controls (audit logs, data retention, access
   reviews) does a PRR need to verify? How do compliance frameworks intersect
   with production readiness?

10. **PRR framework comparison**: Google SRE PRR vs. Cortex scorecards vs.
    OpsLevel service maturity vs. Backstage TechDocs + Scorecards vs.
    Port.dev vs. custom frameworks. What dimensions do they share? What does
    each uniquely offer? Where is the current 10-dimension model weak?

## Scope

- Breadth: exhaustive — survey all major frameworks, tools, and literature
- Time horizon: include historical foundations (Google SRE book, 2016) through
  latest (2025-2026 tooling, DORA 2025 State of DevOps)
- Domain constraints: stack-agnostic — patterns should apply to any tech stack
- Challenge baselines: Do NOT take Google SRE PRR, Cortex, or DORA as gospel.
  Find critiques, limitations, and alternatives.

## Project Context

This research upgrades the `meta-production` skill in a Claude Code skill suite.
The skill runs a scored production readiness assessment (10 dimensions, 0-100)
across a codebase using multi-model parallel scans (7 Sonnet review lenses +
3 Codex production scans + Gemini stack research). Current dimensions:

1. Code Completeness (completeness-review)
2. Code Quality (refactor-review)
3. Security (security-review)
4. Testing (test-review)
5. Documentation Sync (drift-review)
6. Compliance (compliance-review)
7. Architecture (counter-review)
8. Observability (Codex scan)
9. Deployment (Codex scan)
10. Operations (Codex scan)

Current production scan prompts check for: health endpoints, structured logging,
metrics, tracing, error tracking, graceful shutdown, signal handling, Dockerfile
quality, env validation, rate limiting, circuit breakers, retries, resource
limits, timeouts, CORS, request size limits, deadlock potential.

**Known gaps** (from prior audit): No SLO/SLI validation, no chaos engineering
checks, DORA metrics referenced but not measured, no blue/green/canary pattern
detection, on-call readiness is "runbooks exist" level only, no capacity
planning dimension.

## Known Prior Research

- 001D: agent-security-gaps (applied to security-review)
- 002D: meta-execute upgrade (applied)
- 003D: test-review upgrade (mutation testing, PBT, contract testing — applied)

## Output Configuration

- Research folder: artifacts/research/004D/
- Summary destination: artifacts/research/summary/004D-meta-production-upgrade.md
- Topic slug: meta-production-upgrade

## Special Instructions

- For each gap found, assess: (a) how hard it is to add to the skill,
  (b) whether it requires new tooling or just prompt changes, (c) what
  dimension it maps to (existing or new)
- Explicitly compare at least 5 PRR frameworks head-to-head
- Find real-world PRR checklists from companies (not just Google) — Uber,
  Netflix, Spotify, Airbnb, Shopify, etc.
- Challenge whether 10 dimensions is the right number — should we add, merge,
  or restructure?
- Prioritize findings by impact on the skill's ability to catch real production
  issues (not theoretical completeness)
