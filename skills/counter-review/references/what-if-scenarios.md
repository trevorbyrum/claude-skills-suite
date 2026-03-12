# "What If" Scenario Catalog

Reference for counter-review §7 (Stress Test Assumptions). Read on demand.

## Purpose

Every project makes assumptions — about uptime, trust, scale, and environment.
This section systematically challenges those assumptions with concrete failure
scenarios. The goal is not pessimism but preparedness: does the project handle
these scenarios gracefully, or does it silently fail?

## Infrastructure Failure Scenarios

### Database
- **What if the DB goes down mid-transaction?** Are writes atomic? Is there rollback?
- **What if the DB is slow (5s+ per query)?** Does the app timeout gracefully or hang?
- **What if the connection pool is exhausted?** Is there queuing, backpressure, or crash?
- **What if the DB returns stale data?** (Replication lag, cache invalidation failure)
- **What if the DB runs out of disk space?** Does the app surface the error or silently corrupt?

### Network
- **What if DNS resolution fails?** Does the app retry, cache, or crash?
- **What if an upstream API returns 500s for 30 minutes?** Circuit breaker? Retry storm?
- **What if network latency spikes to 2000ms?** Do timeouts fire? Does the UX degrade?
- **What if a webhook delivery fails?** Is there retry logic? Dead letter queue?
- **What if the CDN goes down?** Are assets self-hosted as fallback?

### Infrastructure
- **What if the container is OOM-killed?** Does it restart cleanly? Is state preserved?
- **What if the host disk fills up?** Log rotation? Temp file cleanup?
- **What if a scheduled job runs twice?** (Duplicate cron execution) Is it idempotent?
- **What if the load balancer routes to a stale instance?** Session affinity issues?

## Security Breach Scenarios

### Credential Compromise
- **What if an API key leaks to GitHub?** Can it be rotated without downtime? Is there an alert?
- **What if the DB password is compromised?** Can it be rotated? Are connections encrypted?
- **What if a JWT signing key leaks?** Can all sessions be invalidated? Is there key rotation?
- **What if an OAuth client secret leaks?** Can it be revoked without breaking all users?

### Data Breach
- **What if the DB is dumped?** Is PII encrypted at rest? Are passwords properly hashed?
- **What if logs are exfiltrated?** Do they contain tokens, PII, or request bodies?
- **What if backups are accessed?** Are they encrypted? Access-controlled?

### Supply Chain
- **What if a dependency publishes a malicious update?** Are versions pinned? Is there lockfile integrity?
- **What if npm/PyPI goes down during deploy?** Is there a local cache or vendor directory?
- **What if a CDN-hosted library is compromised?** SRI hashes? Self-hosting fallback?

## Scale Scenarios

### Traffic
- **What if traffic spikes 10x?** Auto-scaling? Queue depth? Connection limits?
- **What if traffic spikes 100x?** (HN front page, DDoS) Graceful degradation? Rate limiting?
- **What if a single user makes 10,000 requests/minute?** Per-user rate limiting?
- **What if bot traffic is 90% of requests?** Detection? Filtering? Impact on real users?

### Data Volume
- **What if the DB grows 10x?** Do queries still perform? Are there missing indexes?
- **What if a single table has 100M rows?** Pagination? Partitioning? Query planning?
- **What if file uploads total 1TB?** Storage limits? Cleanup policy? Cost?
- **What if search index grows past memory?** Disk-backed? Sharded?

### Concurrency
- **What if 1000 users hit the same endpoint simultaneously?** Thread pool? Connection pool?
- **What if two users edit the same resource at once?** Optimistic locking? Last-write-wins? Merge?
- **What if a long-running job blocks the event loop?** Worker queues? Async processing?

## Operational Scenarios

### Deployment
- **What if a deploy fails midway?** Rollback mechanism? Blue/green? Canary?
- **What if the new version has a DB migration bug?** Can the migration be reversed?
- **What if config changes are deployed without code changes?** Feature flags? Config validation?

### Monitoring & Recovery
- **What if alerting fails?** Is there a secondary alert channel?
- **What if the on-call engineer is unreachable?** Escalation path?
- **What if the incident happens at 3 AM on a holiday?** Automated recovery? Runbooks?
- **What if you need to restore from backup?** Has it been tested? What's the RTO?

## Scenario Documentation Format

For each relevant scenario, document:

```
## [SEVERITY] What if [scenario]?

**Assumption Challenged**: What the project currently assumes
**Current Behavior**: What actually happens (tested or inferred from code)
**Risk**: What goes wrong if this assumption fails
**Mitigation**: What should be in place (and whether it is)
**Verdict**: HANDLED | PARTIALLY HANDLED | UNHANDLED
```
