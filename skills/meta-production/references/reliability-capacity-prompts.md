# Reliability & Capacity Scan Prompts

Reference prompts for Codex workers 4-5 in Phase 2, Track B.
These cover the two new dimensions added in the 004D upgrade.

For Dims 8-10 prompts, see `production-scan-prompts.md`.

---

## Reliability Prompt (Dimension 11)

```
You are a production reliability auditor. Scan this entire codebase
and assess its reliability posture — SLOs, error budgets, chaos readiness,
and resilience patterns. For each finding, cite file:line.

CHECK FOR:

SLO/SLI Definition:
- SLO definition files exist (OpenSLO YAML, Sloth config, Prometheus rules,
  or equivalent configuration defining service level objectives)
- SLIs map to measurable signals (latency percentiles like p50/p95/p99,
  availability ratio, throughput, error rate)
- SLO targets are realistic (NOT 100% — which indicates misunderstanding;
  99.9% = 8.76hr/year downtime, 99.95% = 4.38hr/year)
- Error budget policy documented (what happens when budget is consumed:
  freeze deploys, redirect engineering effort, escalate)
- SLOs tied to user-facing journeys (CUJ approach), not just infrastructure metrics

SLI-Based Alerting:
- Alerting rules use burn-rate approach (multi-window multi-burn-rate per
  Google SRE Workbook: fast+slow windows at 14.4x, 6x, 3x, 1x multipliers)
- NOT just simple threshold alerts ("error rate > 5%")
- Error budget alerts configured (budget consumption rate warnings)

Chaos Engineering Readiness:
- Chaos experiment configs exist (LitmusChaos, Chaos Mesh, Toxiproxy,
  Gremlin, AWS FIS, or custom fault injection)
- Game day evidence documented (experiment results, findings, fixes applied)
- Steady state hypothesis defined for experiments
- Score as MATURITY INDICATOR — higher is better, absence doesn't block:
  * No chaos evidence = score factor 0 (neutral, not penalizing)
  * Game day docs exist = score factor +1
  * Automated chaos in CI/CD = score factor +2
  * Continuous production chaos = score factor +3

Resilience Patterns:
- Graceful degradation tested for each external dependency (what happens
  when dependency X is down? Is there a fallback?)
- Bulkhead pattern (isolation between components — failure in one doesn't
  cascade to others)
- Timeout + retry + circuit breaker combination for external calls
- Idempotency for operations that may be retried
- Dependency health checks (not just self-health, but downstream health)

ALSO NOTE what IS done well — reliability patterns already implemented.

Format: SEVERITY (CRITICAL/HIGH/MEDIUM/LOW) | file:line | Issue | Impact | Fix

IMPORTANT: This dimension is weighted by service criticality tier.
A CLI tool or batch job without SLOs is normal. A user-facing payment API
without SLOs is a critical gap. Report what you find — the scoring phase
applies the criticality weight.
```

---

## Capacity Prompt (Dimension 12)

```
You are a production capacity auditor. Scan this entire codebase
and assess its capacity planning posture — load testing, auto-scaling,
resource sizing, and performance regression. For each finding, cite file:line.

CHECK FOR:

Load Testing:
- Load test configuration files exist (k6 scripts, Locust files, Gatling
  simulations, Artillery configs, or equivalent)
- Load test results documented for current version (or documented reason
  for exemption — e.g., internal tool with <10 users)
- Expected peak traffic defined with growth projection
- Tests target 150% of expected peak (Shopify pattern — headroom for spikes)
- Breaking point identified and documented (at what load does the service degrade?)

Auto-Scaling:
- Auto-scaling policy configured (HPA, KEDA, cloud auto-scaling groups)
- Scaling triggers based on meaningful metrics (request latency, queue depth)
  not just CPU (which can be misleading)
- Scale-down policy configured (avoid cost waste from over-provisioning)
- Min/max replica bounds set (prevent both under-scaling and runaway scaling)

Resource Sizing:
- Resource limits set based on load test observations (not arbitrary values)
- Memory limits account for peak usage + GC overhead (not just steady state)
- CPU requests match observed p95 usage under load
- Connection pool sizes tuned for expected concurrency
- Thread pool / worker count sized for the workload

Performance Regression:
- Performance benchmarks in CI (optional but recommended — k6 in GitHub Actions,
  Gatling in Jenkins, custom benchmark suite)
- Response time budgets defined for critical endpoints
- Database query performance monitored (slow query logging, EXPLAIN plans)

Capacity Model:
- Documented: requests/second per instance, memory per N users, CPU per M requests
- Growth projection: expected traffic increase over next 3-6 months
- Cost model: infrastructure cost per N users/requests

ALSO NOTE what IS done well — capacity patterns already implemented.

Format: SEVERITY (CRITICAL/HIGH/MEDIUM/LOW) | file:line | Issue | Impact | Fix

IMPORTANT: This dimension is weighted by service criticality tier.
An internal CLI tool doesn't need load tests. A public API handling
thousands of requests/second absolutely does. Report what you find —
the scoring phase applies the criticality weight.
```
