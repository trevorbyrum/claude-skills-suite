# External Blast Radius Scan — Checklist

Reference for SKILL.md §6.

## Overview

External references are consumers of the project that live OUTSIDE the repo itself. A file may
have zero internal dependents (leaf) but still be required by a cron job, systemd service, or
another project. Always run this scan before marking any candidate safe to remove.

`PROJECT_DIR=$(pwd)` and `PROJECT_NAME=$(basename "$PROJECT_DIR")` are used throughout.

## Scan Checklist

### 1. Systemd Services (Linux)

```bash
# System-wide units
grep -rl "$PROJECT_DIR" /etc/systemd/ 2>/dev/null
# User units
grep -rl "$PROJECT_DIR" ~/.config/systemd/ 2>/dev/null
```

Capture: unit file path, matching line.
Platform: Linux only. On macOS, skip (check LaunchAgents instead).
Access denied: warn `[WARN] systemd scan skipped — permission denied`, continue.

### 2. LaunchAgents / LaunchDaemons (macOS)

```bash
grep -rl "$PROJECT_DIR" ~/Library/LaunchAgents/ 2>/dev/null
grep -rl "$PROJECT_DIR" /Library/LaunchAgents/ 2>/dev/null
grep -rl "$PROJECT_DIR" /Library/LaunchDaemons/ 2>/dev/null
```

Capture: plist file path, matching line.
Platform: macOS only. On Linux, skip.
Access denied: warn and continue.

### 3. Cron Jobs

```bash
crontab -l 2>/dev/null | grep -n "$PROJECT_NAME\|$PROJECT_DIR"
# System crontabs (Linux)
grep -rn "$PROJECT_DIR\|$PROJECT_NAME" /etc/cron* 2>/dev/null
```

Capture: cron schedule line, matched pattern.
Access denied: warn and continue. User crontab (`crontab -l`) should always be accessible.

### 4. Docker Containers and Compose Files

```bash
# Running containers with volume mounts referencing project dir
docker inspect $(docker ps -q) 2>/dev/null \
  | python3 -c "
import json,sys,os
data=json.load(sys.stdin)
proj=os.getcwd()
for c in data:
  mounts=c.get('Mounts',[])
  name=c['Name']
  for m in mounts:
    src=m.get('Source','')
    if proj in src:
      print(f'{name}: {src}')
" 2>/dev/null

# docker-compose files in parent dirs and common locations
find ~ /opt /srv -maxdepth 4 -name "docker-compose*.yml" 2>/dev/null \
  | xargs grep -l "$PROJECT_DIR\|$PROJECT_NAME" 2>/dev/null | head -20
```

Access denied: warn and continue. Docker may not be installed — check with `which docker` first.

### 5. Other Projects Importing This One

```bash
# Workspace symlinks
find ~ /opt /srv -maxdepth 5 -type l 2>/dev/null \
  | while read link; do
      target=$(readlink -f "$link" 2>/dev/null)
      [ "$target" = "$PROJECT_DIR" ] && echo "$link"
    done

# package.json workspace references or file: dependencies
find ~ -maxdepth 6 -name "package.json" 2>/dev/null \
  | xargs grep -l "\"file:.*$PROJECT_NAME\"\|\"workspace:.*$PROJECT_NAME\"" 2>/dev/null | head -10

# Python path or editable installs
grep -rn "$PROJECT_DIR" ~/.local/lib/ ~/.venv/ 2>/dev/null | head -10
```

Access denied: warn and continue.

### 6. CI/CD Configs Referencing Specific Files

Scan within the current repo only (no elevated access needed):

```bash
# GitHub Actions
grep -rn . .github/workflows/ 2>/dev/null | grep -v "^Binary"

# GitLab CI
grep -n . .gitlab-ci.yml 2>/dev/null

# Other CI configs
for f in Jenkinsfile .circleci/config.yml .travis.yml bitbucket-pipelines.yml azure-pipelines.yml; do
  [ -f "$f" ] && grep -n "$PROJECT_NAME" "$f" 2>/dev/null
done
```

For each CI file: extract job names and script lines that reference specific project files.
A CI reference to a specific source file (not just the project root) = high-priority external dep.

### 7. Git Hooks

```bash
ls .git/hooks/ 2>/dev/null | while read hook; do
  grep -n "." ".git/hooks/$hook" 2>/dev/null
done
# Husky
[ -d ".husky" ] && grep -rn "." .husky/ 2>/dev/null
# Lefthook / pre-commit
for f in lefthook.yml .pre-commit-config.yaml; do
  [ -f "$f" ] && cat "$f"
done
```

Capture: hook name, referenced script/file.

### 8. Shell Profiles

```bash
for profile in ~/.bashrc ~/.bash_profile ~/.zshrc ~/.zprofile ~/.profile; do
  [ -f "$profile" ] && grep -n "$PROJECT_DIR\|$PROJECT_NAME" "$profile" 2>/dev/null \
    && echo "[source: $profile]"
done
```

Access denied: N/A — these are always user-readable.

### 9. Reverse Proxy Configs

```bash
# Nginx (common locations)
grep -rn "$PROJECT_DIR\|$PROJECT_NAME" /etc/nginx/ 2>/dev/null | head -10
# Traefik labels in docker-compose (already covered by §4, reiterate for proxy rules)
# Caddy
grep -rn "$PROJECT_DIR\|$PROJECT_NAME" /etc/caddy/ ~/.config/caddy/ 2>/dev/null | head -10
```

Access denied: warn `[WARN] proxy config scan limited — /etc/nginx not readable`, continue.

### 10. Package Registries

Check if this project is published to a package registry (consumers exist outside the filesystem):

```bash
# npm
[ -f package.json ] && node -e "
  const p=require('./package.json');
  if (!p.private) console.log('npm:published name=' + p.name + ' version=' + p.version);
" 2>/dev/null

# PyPI (check if sdist/wheel exists or if published)
[ -f pyproject.toml ] && grep -n "^name\|^version\|^publish" pyproject.toml 2>/dev/null

# Cargo (crates.io)
[ -f Cargo.toml ] && grep -n "^publish\|^name\|^version" Cargo.toml 2>/dev/null
```

If published to a registry, mark ALL public exports as `external: registry` — never mark
published symbols as safe to remove without a major version bump.

## Access-Denied Handling

- Every scan command must have `2>/dev/null` or explicit error capture.
- If a scan returns a non-zero exit due to permission, emit: `[WARN] <location> scan skipped — access denied`
- Never abort the skill due to an access-denied scan. Log and continue.
- Collect all warnings in a separate `external_warnings` list in the output.

## Presenting External Dependencies in Candidate List

For each candidate with external references, add a populated `EXTERNAL-REFS` column:

```
src/cmd/server/main.go | orphan | leaf | 0 | systemd:myapp.service, cron:daily-backup | medium
```

Format: `type:identifier` — comma-separated if multiple. Types:
- `systemd:<unit-file-name>`
- `launchd:<plist-name>`
- `cron:<schedule-fragment>`
- `docker:<container-or-compose-file>`
- `ci:<workflow-file>:<job-name>`
- `hook:<hook-name>`
- `profile:<shell-profile>`
- `proxy:<config-file>`
- `registry:npm|pypi|crates.io`
- `project:<other-project-path>`

Any candidate with external references should have its blast class upgraded to **trunk** regardless
of internal dependent count, and its confidence treated as **high** (external consumers are
definitive, not statistical).
