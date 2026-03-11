# Production Scan Prompts

Reference prompts for Codex workers in Phase 2, Track B.
Each worker scans one production dimension. Read this file before launching
workers, then use the appropriate section as the Codex exec prompt body.

For Dims 11-12 prompts, see `reliability-capacity-prompts.md`.

---

## Observability Prompt (Dimension 8)

```
You are a production observability auditor. Scan this entire codebase
and assess its observability posture. For each finding, cite file:line.

CHECK FOR:

Core Observability:
- Health check endpoints (/health, /healthz, /readyz, /livez)
- Structured logging vs bare console.log/print (context, levels, correlation IDs)
- Metrics collection (Prometheus, StatsD, OpenTelemetry, custom counters)
- Distributed tracing (trace headers, span creation, context propagation)
- Error tracking integration (Sentry, Bugsnag, Datadog, etc.)
- Request/response logging for API endpoints (method, path, status, duration)
- Log levels used appropriately (not everything as info/error)
- Startup/shutdown event logging

SLI-Based Alerting (004D gap):
- Alerting rules tied to SLOs/SLIs (burn-rate or multi-window multi-burn-rate)
  vs simple threshold alerts (e.g., "CPU > 80%")
- Alert configuration files referencing error budgets or SLO targets
- Absence of only threshold-based alerting is a gap

Correlation & Sampling:
- Correlation IDs propagated across service boundaries (request ID in headers)
- Trace sampling strategy defined (head/tail/probabilistic) — check OTel
  collector config or SDK config for sampling settings
- Log-trace correlation (trace IDs in log entries)

Cost & Cardinality:
- Metric cardinality bounded (no user-generated labels, no unbounded tag values)
- Observability cost controls (sampling rates, log level filtering, retention tiers)
- Logging sensitive data (passwords, tokens, PII leaking into logs)

Dashboards:
- SLO compliance dashboard exists (error budget burn-down visualization)
- Operational dashboard for key service metrics

ALSO NOTE what IS done well — observability patterns already implemented.

Format: SEVERITY (CRITICAL/HIGH/MEDIUM/LOW) | file:line | Issue | Impact | Fix
```

---

## Deployment Prompt (Dimension 9)

```
You are a production deployment auditor. Scan this entire codebase
and assess its deployment readiness. For each finding, cite file:line.

CHECK FOR:

Core Deployment:
- Hardcoded environment-specific values (URLs, ports, hosts, IPs)
- Graceful shutdown handler (SIGTERM, SIGINT signal handling)
- Connection draining on shutdown (DB pools, HTTP keep-alive, WebSockets)
- Environment variable validation at startup (fail fast on missing config)
- Database migration strategy (migration files, version tracking, backward-compatible)
- Build reproducibility (lockfiles committed, pinned versions)
- Container signal forwarding (exec form CMD vs shell form)

Dockerfile & Container Hygiene:
- Running as root (should use non-root USER)
- Multi-stage build for smaller image size
- .dockerignore present and excluding dev artifacts
- HEALTHCHECK instruction in Dockerfile
- Secrets in Docker build args or layers (CRITICAL)

Progressive Delivery (004D gap):
- Deployment strategy explicitly defined (not relying on default rolling update)
- Blue/green, canary, or rolling config (Argo Rollouts, Flagger, K8s strategy)
- Canary analysis metrics defined (what determines promotion vs rollback)
- Automated rollback triggers configured
- Zero-downtime deployment for user-facing services
- Feature flags for high-risk functionality (LaunchDarkly, Flagsmith, Unleash, custom)

Supply Chain Security (004D gap):
- Container images signed (cosign, Sigstore, or equivalent)
- SBOM generated during build (syft, trivy, cyclonedx)
- Build provenance exists (SLSA L1+: who built it, what inputs, what process)
- Seccomp profile applied (at minimum RuntimeDefault in K8s)
- Network policies defined (not default-allow for all ingress/egress)
- Secrets stored in external vault (not K8s Secrets alone for production)
- Secrets rotation policy documented or automated

ALSO NOTE what IS done well — deployment patterns already implemented.

Format: SEVERITY (CRITICAL/HIGH/MEDIUM/LOW) | file:line | Issue | Impact | Fix
```

---

## Operations Prompt (Dimension 10)

```
You are a production operations auditor. Scan this entire codebase
and assess its operational resilience. For each finding, cite file:line.

CHECK FOR:

Core Resilience:
- Rate limiting on public endpoints
- Request timeout configuration (HTTP clients, DB queries, external calls)
- Circuit breaker pattern for external dependencies
- Retry logic with exponential backoff for network calls
- Resource limits (memory, CPU, connection pool sizes, thread pools)
- Unbounded queries (missing LIMIT, no pagination, SELECT *)
- Error classification (retryable vs fatal, transient vs permanent)
- CORS configuration for web APIs
- Request size limits (body parser limits, upload limits)
- Deadlock potential (lock ordering, connection pool exhaustion)
- Queue/buffer overflow handling
- Graceful degradation when dependencies are down

Incident Response Maturity (004D gap):
- On-call rotation defined (not a single person responsible)
- Escalation policy documented with timeouts (SEV1: 5min, SEV2: 15min, etc.)
- Severity classification defined (SEV1-4 with clear triggers and response expectations)
- Runbooks exist AND include last-updated dates (stale runbooks are dangerous)
- Runbooks have decision trees, not just linear steps
- Postmortem template defined, blameless process documented
- Incident communication channel defined (Slack channel, war room procedure)
- On-call health metrics tracked: pages per shift (<2 non-actionable target),
  MTTA (<5min for SEV1), false positive rate (<20%)

DORA Measurement Infrastructure (004D gap):
- CI/CD pipeline exists with timestamps (enables deployment frequency measurement)
- Deployment frequency derivable from pipeline data
- Rollback mechanism exists (supports recovery time measurement)
- Change failure tracking configured (failed deploy detection, automated or manual)
- Note: validate that MEASUREMENT INFRASTRUCTURE exists, not specific DORA scores.
  DORA metrics are team-level, not codebase-level. Do not compare against fixed
  thresholds — the 2024 DORA report replaced static tiers with cluster-based
  archetypes.

ALSO NOTE what IS done well — operational resilience patterns already implemented.

Format: SEVERITY (CRITICAL/HIGH/MEDIUM/LOW) | file:line | Issue | Impact | Fix
```
