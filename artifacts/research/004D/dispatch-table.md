# Dispatch Table — 004D: meta-production-upgrade

## Sub-Questions (validated, refined)

| # | Sub-Question | Evidence Type | Track A (Opus) | Track B (Sonnet/MCP) | Track C (Codex) | Track D (Gemini) |
|---|---|---|---|---|---|---|
| SQ1 | SLO/SLI frameworks: OpenSLO, Sloth, Google CUJ, enforcement patterns, PRR validation | Technical + Market | | Consensus, Context7, GitHub | Worker 1 | Primary |
| SQ2 | Chaos engineering state of art: Chaos Monkey, Litmus, Gremlin, Toxiproxy, maturity gates | Technical + Market | | Consensus, GitHub, Scholar | Worker 1 | Primary |
| SQ3 | DORA metrics: measurement, thresholds (Elite/High/Med/Low), instrumentation (Sleuth, LinearB, Faros) | Technical + Market | | Consensus, GitHub | Worker 2 | Primary |
| SQ4 | Deployment patterns: blue/green, canary, rolling, shadow, feature flags, progressive delivery (Argo, Flagger, LaunchDarkly) | Technical | | Context7, GitHub | Worker 2 | Primary |
| SQ5 | On-call readiness & incident response: runbooks, escalation, PagerDuty/OpsGenie, war rooms, blameless postmortems, severity classification | Technical + Market | | Consensus, WebSearch | Worker 3 | Primary |
| SQ6 | Observability gaps in current Dimension 8: OpenTelemetry best practices, SLI-based alerting, log aggregation, anomaly detection, cost-aware observability | Technical | Reasoning | Context7, GitHub | Worker 3 | |
| SQ7 | Security hardening for production: Falco, Seccomp, AppArmor, SLSA, Sigstore, network policies, pod security, secrets rotation | Technical | | GitHub, WebSearch | Worker 4 (devil) | Primary |
| SQ8 | Capacity planning & load testing: k6, Locust, Gatling, capacity thresholds, auto-scaling policies, PRR inclusion | Technical + Market | | Context7, Consensus | Worker 4 (devil) | Primary |
| SQ9 | Compliance & regulatory: SOC2, HIPAA, GDPR, PCI-DSS operational controls, audit logs, data retention, access reviews | Reasoning + Market | Reasoning | Consensus, Scholar, WebSearch | | Primary |
| SQ10 | PRR framework comparison: Google SRE vs Cortex vs OpsLevel vs Backstage vs Port.dev vs custom; dimension analysis, unique offerings, current model gaps | Market + Reasoning | Reasoning | Consensus, GitHub, WebSearch | Worker 4 (devil) | Primary |
| SQ11 | Dimension restructuring: Should the 10-dimension model be expanded/merged/restructured? What dimensions do other frameworks use? (Added by orchestrator) | Reasoning | Reasoning | Consensus | | Primary |

## Worker Allocation

### Track A — Opus Deep Reasoning (2 subagents)
- **Opus-1**: SQ6 (observability gap analysis — requires deep reasoning about current vs ideal state)
- **Opus-2**: SQ9 (compliance intersection) + SQ10 (framework comparison) + SQ11 (dimension restructuring)

### Track B — Sonnet Connector Sweep (5 connectors)
- **Consensus**: SQ1, SQ2, SQ3, SQ5, SQ8, SQ10, SQ11
- **Scholar Gateway**: SQ2, SQ9
- **Context7**: SQ1, SQ4, SQ6, SQ8
- **GitHub**: SQ1, SQ2, SQ3, SQ4, SQ6, SQ7, SQ10
- **WebSearch**: SQ5, SQ7, SQ9, SQ10

### Track C — Codex Technical Validation (4 workers)
- **Worker 1**: SQ1 (SLO/SLI tooling) + SQ2 (chaos engineering tooling)
- **Worker 2**: SQ3 (DORA measurement) + SQ4 (deployment patterns)
- **Worker 3**: SQ5 (on-call readiness) + SQ6 (observability gaps)
- **Worker 4 (devil's advocate)**: SQ7 (security), SQ8 (capacity planning), SQ10 (framework comparison)

### Track D — Gemini Web Grounding (2 instances)
- **Gemini-1 (primary + case studies)**: SQ1-5, SQ7-11 — broad research with real-world examples
- **Gemini-2 (contradiction hunter)**: All SQs — find dissent against Google SRE dogma, DORA thresholds
