# SLO, Chaos, and DORA Validation Checks

Detailed scoring criteria for Dimensions 11 (Reliability) and 12 (Capacity),
with service criticality tier weighting. Referenced from SKILL.md Phase 3.

---

## Dimension 11: Reliability — Scoring by Tier

### Critical Tier (Full Weight)

| Score | Evidence Required |
|---|---|
| 9-10 | SLOs defined (OpenSLO/equivalent), SLIs measurable, error budget policy documented, burn-rate alerting configured, game day evidence within last quarter, resilience tested for all external deps |
| 7-8 | SLOs defined, SLIs measurable, error budget policy exists, threshold-based alerting (not burn-rate), some chaos/resilience testing documented |
| 5-6 | SLOs partially defined (some services missing), no error budget policy, basic alerting, no chaos testing but graceful degradation implemented |
| 3-4 | No formal SLOs, availability targets mentioned informally, minimal resilience patterns, no chaos evidence |
| 1-2 | No SLOs, no error budgets, no resilience patterns, no degradation handling |
| 0 | Reliability not considered at all |

### Standard Tier (70% Weight)

Apply Critical tier rubric, then multiply gap from 10 by 0.7.
Example: Critical tier would score 4 → gap = 6 → weighted gap = 4.2 → score = 5.8 → round to 6.

Practically:
- Missing SLOs: score 5-6 (not 3-4)
- Missing chaos: no penalty (chaos is a maturity indicator, not a requirement for Standard)
- Missing error budgets: score 6-7 (not 5-6)

### Low Tier (40% Weight)

Apply Critical tier rubric, then multiply gap from 10 by 0.4.

Practically:
- No SLOs, no chaos, no error budgets: score 7 (expected for batch jobs/internal tools)
- Basic health checks + graceful shutdown: score 8
- Any SLOs or resilience patterns: score 9-10 (exceeds expectations)

---

## Dimension 12: Capacity — Scoring by Tier

### Critical Tier (Full Weight)

| Score | Evidence Required |
|---|---|
| 9-10 | Load tests at 150% peak, breaking point documented, auto-scaling configured + tested, resource limits from load test data, capacity model documented, performance regression in CI |
| 7-8 | Load tests exist for current version, auto-scaling configured, resource limits set based on testing, capacity model informal |
| 5-6 | Some load testing (not current version), auto-scaling configured but not tested, resource limits set but not validated |
| 3-4 | No load tests, resource limits are arbitrary defaults, no auto-scaling for traffic-dependent service |
| 1-2 | No capacity consideration, default resource limits, no scaling strategy |
| 0 | Capacity not considered at all |

### Standard Tier (70% Weight)

- Missing load tests: score 5-6 (not 3-4)
- No auto-scaling for an internal API: score 6-7 (acceptable if fixed capacity has headroom)
- Arbitrary resource limits: score 5 (still worth flagging)

### Low Tier (40% Weight)

- No load tests, no scaling: score 7-8 (expected for CLI tools, batch jobs)
- Resource limits set at all: score 8-9
- Any load testing for a batch job: score 9-10 (exceeds expectations)

---

## SLO Validation Checklist

When scanning for SLO/SLI evidence, check for these specific patterns:

1. **SLO definition files**: `*.slo.yaml`, `*.slo.json`, `sloth.yaml`, OpenSLO
   resources, Prometheus recording rules with `slo` in the name, any file
   containing `error_budget` or `burn_rate`
2. **SLI signals**: latency percentiles (p50, p95, p99), availability ratio
   (successful/total), throughput (requests/second), saturation metrics
3. **Error budget policy**: look in docs/, runbooks/, or README for phrases
   like "error budget", "budget consumed", "freeze deploys"
4. **Burn-rate alerting**: Prometheus rules or alerting configs with
   `burn_rate`, `multi_window`, or references to Google SRE Workbook patterns
5. **Anti-pattern**: SLO target of 100% (indicates misunderstanding — nothing
   is 100% available). Flag but don't score as critical.

## Chaos Readiness Checklist

Score as maturity indicator (higher = better, absence = neutral for non-Critical):

| Level | Evidence | Score Bonus |
|---|---|---|
| **None** | No chaos experiments, no game day docs | +0 (neutral) |
| **Basic** | Graceful degradation tested manually for each dep | +1 |
| **Game Days** | Documented game day within last quarter, findings applied | +2 |
| **CI/CD Chaos** | Automated fault injection in staging pipeline | +3 |
| **Continuous** | Production chaos experiments (Litmus, Chaos Mesh, FIS) | +4 |

Look for: `chaos*.yaml`, `litmus*.yaml`, `chaosexperiment`, `toxiproxy`,
game day docs in `docs/`, `runbooks/`, or `incidents/`.

## DORA Infrastructure Checklist

Validate that MEASUREMENT INFRASTRUCTURE exists, not scores. DORA metrics
are team-level. The 2024 report replaced fixed tiers with cluster-based
archetypes — do NOT use Elite/High/Medium/Low thresholds as gates.

| Check | What to Look For |
|---|---|
| Deployment frequency measurable | CI/CD pipeline with timestamps, deployment logs |
| Lead time measurable | PR merge → deploy timestamps derivable from pipeline |
| Change failure rate trackable | Failed deploy detection (rollback triggers, health check failures) |
| Recovery time measurable | Rollback mechanism exists, recovery timestamps logged |
| Dashboard exists | Grafana/DataDog/custom board showing deployment metrics |

If all 5 checks pass: DORA infrastructure is adequate.
If 3-4 pass: partially adequate, note gaps.
If <3 pass: significant gap in deployment observability.
