# Attack Chain Construction Guide

Reference for counter-review §6 (Attack Chain Construction). Read on demand.

## What Is an Attack Chain?

An attack chain combines multiple low/medium-severity findings into a high-severity
exploit path. Individual findings may seem acceptable in isolation, but chained together
they create critical vulnerabilities. Counter-review's unique value is constructing
these chains — security-review finds the individual links, counter-review connects them.

## Trust Boundary Mapping

Before building chains, map where trust transitions occur:

### Common Trust Boundaries
1. **User → Application**: Browser/client to server (authentication boundary)
2. **Application → Database**: App code to data store (authorization boundary)
3. **Application → External API**: Outbound calls to third-party services
4. **Agent → Tools**: AI agent to tool execution (agency boundary)
5. **Internal → Internal**: Service-to-service calls (network boundary)
6. **Config → Runtime**: Environment variables / config files to running code

### Mapping Process
For each boundary, identify:
- What data crosses it?
- What validation occurs at the crossing?
- What credentials/tokens are used?
- What happens if the boundary is bypassed?

## Escalation Path Templates

### Template 1: Info Disclosure → Account Takeover
```
[LOW] Error messages leak user email format
  → [MEDIUM] Enumerate valid accounts via timing difference on login
    → [HIGH] Password reset flow uses predictable tokens
      → [CRITICAL] Full account takeover
```

### Template 2: SSRF → Internal Access
```
[MEDIUM] User-controlled URL in webhook/callback config
  → [HIGH] SSRF to internal metadata service (169.254.169.254)
    → [CRITICAL] Cloud credentials exfiltrated → full infrastructure access
```

### Template 3: Injection → Data Exfil
```
[LOW] Verbose error messages reveal DB schema
  → [MEDIUM] Blind SQL injection in search parameter
    → [HIGH] Extract user table with hashed passwords
      → [CRITICAL] Offline password cracking → credential stuffing
```

### Template 4: Agent Prompt Injection → System Compromise
```
[LOW] Agent reads user-supplied document content
  → [MEDIUM] Indirect prompt injection in document metadata
    → [HIGH] Agent executes tool with attacker-controlled parameters
      → [CRITICAL] File write/read to sensitive system paths
```

### Template 5: Weak Auth → Privilege Escalation
```
[LOW] No rate limiting on API endpoints
  → [MEDIUM] Brute-force API key enumeration
    → [HIGH] Discover admin API key with elevated permissions
      → [CRITICAL] Full admin access, data manipulation
```

### Template 6: Supply Chain → Backdoor
```
[LOW] Unpinned dependency versions
  → [MEDIUM] Dependency with low download count / recent publish
    → [HIGH] Typosquatted package with install script
      → [CRITICAL] Arbitrary code execution in CI/CD or production
```

## How to Build Chains From Findings

1. **List all findings** from all review lenses (security, counter, completeness, etc.)
2. **Classify each by what it enables**: info disclosure, access, execution, persistence
3. **Draw edges**: finding A enables finding B if A's output is B's prerequisite
4. **Find paths**: trace from low-privilege entry to high-impact outcome
5. **Score the chain**: severity = highest-impact node; likelihood = weakest link

## Chain Severity Scoring

| Chain Length | Entry Severity | Exit Impact | Chain Severity |
|---|---|---|---|
| 2 steps | LOW | HIGH | **HIGH** |
| 2 steps | MEDIUM | CRITICAL | **CRITICAL** |
| 3+ steps | LOW | CRITICAL | **HIGH** (longer = less likely) |
| 3+ steps | LOW | HIGH | **MEDIUM** |
| Any | Any | Data breach / RCE | **CRITICAL** regardless |

## Data Exfiltration Routes

For each type of sensitive data in the project, trace how an attacker could reach it:

### Questions to Ask
- Where is PII stored? Can it be queried without per-record authorization?
- Are API responses filtered, or do they return full database records?
- Can logs be accessed? Do they contain sensitive data?
- Are backups accessible? Are they encrypted?
- Can debug/monitoring endpoints leak internal state?
- Does the error handling reveal data structure or values?

## Chain Documentation Format

Each chain should be documented as:

```
## [SEVERITY] Chain Title

**Entry Point**: How the attacker gets in (the first link)
**Path**:
  1. [LOW] First finding (file:line) — what it enables
  2. [MEDIUM] Second finding (file:line) — what it enables
  3. [HIGH/CRITICAL] Final impact — what the attacker achieves

**Prerequisites**: What the attacker needs (network access, account, specific timing)
**Likelihood**: HIGH (automated) | MEDIUM (targeted) | LOW (requires insider/luck)
**Impact**: What data/systems are compromised

**Mitigation**: Breaking the weakest link in the chain (usually cheapest fix)
```
