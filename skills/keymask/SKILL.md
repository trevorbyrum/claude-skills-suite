---
name: keymask
description: Decision tree for calling the keymask MCP server. Triggers when the user mentions needing an API key, secret, token, OAuth credentials, or a service that needs configuration (Stripe, OpenAI, GitHub PAT, Linear, etc) AND there's a keymask MCP server registered in the user's setup. Tells you which destination to pick, when to omit the path, and what questions to ask if the situation is ambiguous.
---

# keymask

The `keymask` MCP server brokers credentials between you and the user without exposing values to your transcript. When the user mentions needing a secret for the project you're working on, the right move is almost never "paste it in chat" — it's `request_secret`.

This skill is your decision tree for HOW to call it.

## When this skill applies

Trigger words from the user: "API key", "secret", "token", "credentials", "PAT", "OAuth", "client ID", "client secret", "set up Linear/Stripe/OpenAI/Schwab/etc", "the script needs a key", ".env", "configure the integration".

## What keymask does (one-line model)

`request_secret` opens a browser form on the user's machine where they type the value. You get back `{ name, destination, fields[] }` — never the value itself. Subsequent `run_with_secrets` / `pipe_secret_to` / `write_secret_to_file` calls inject the value into a subprocess and scrub it from output before returning to you.

## Decision tree

Before calling `request_secret`, walk this:

### 1. What's the destination?

In priority order:

- **The user's current project's `.env`** → omit `destination` (or pass `"local"`). This is the right answer when:
  - The user says "set up X in this project", "add Linear to this app", "the script needs a key"
  - There's a `package.json` / `Cargo.toml` / `go.mod` / etc. in `cwd` indicating you're inside a project
  - The integration is for code Claude is editing right now
- **A remote server** → use `"ssh:<host>"` where `<host>` is the alias from `~/.ssh/config`. Right when:
  - User says "put this on tower", "this is for the homelab", "the server needs the key"
  - The credential is for code that runs on a different machine
  - First call `list_destinations` to confirm `ssh:<host>` is in the list (it's auto-discovered from `~/.ssh/config`)
- **macOS Keychain** → use `"keychain"`. Right when:
  - User explicitly says "keychain", or
  - The credential is cross-project on a Mac (e.g., AWS profile, GitHub PAT used by `gh` everywhere)
- **A user-declared destination** (Vault, custom) → use the name from `list_destinations` where `builtin: false`. Right when:
  - User has explicitly configured a custom store and references it by name
  - You see a `[destinations.<name>]` block in their config.toml

If you can't tell which from the user's request, **ask before calling** (see §3).

### 2. Construct the call

Minimum viable shape for a project `.env`:

```json
{
  "name": "linear",
  "fields": [{ "name": "LINEAR_API_KEY" }]
}
```

That's it — `destination` defaults to `"local"`, `path` defaults to `<cwd>/.env`.

For an SSH host:

```json
{
  "name": "tradetally",
  "destination": "ssh:tower",
  "fields": [
    { "name": "SCHWAB_CLIENT_ID" },
    { "name": "SCHWAB_CLIENT_SECRET" }
  ]
}
```

For Keychain on Mac (cross-project credential):

```json
{
  "name": "aws-prod",
  "destination": "keychain",
  "fields": [
    { "name": "AWS_ACCESS_KEY_ID" },
    { "name": "AWS_SECRET_ACCESS_KEY" }
  ]
}
```

### 3. When to ask before calling

Ask the user ONE clarifying question (max two) if any of these are true:

| Ambiguity | Question to ask |
|---|---|
| You're not in a project directory (cwd is `~` or something generic) AND user didn't name a destination | "Where should this live — this machine's keychain, or a remote server like `tower`?" |
| User said "production" or "prod" without naming a host | "Which destination — local `.env`, or one of the SSH hosts (`ssh:tower`, etc)?" |
| Credential serves multiple projects | "Should this go in this project's `.env`, or in keychain so other projects can use it too?" |
| 3+ fields requested | "I can only request 2 fields at a time — should we split this into two requests, or use a Vault destination?" |

If the answer is obvious from context (you're in a clear project directory, user said "set up X here"), DON'T ask — call with the default.

### 4. Field-name rules

- Must be UPPER_SNAKE_CASE: `[A-Z][A-Z0-9_]*`
- These names become the env-var names in `run_with_secrets`
- Choose canonical names per the vendor: `OPENAI_API_KEY`, `STRIPE_KEY`, `LINEAR_API_KEY`, `GITHUB_TOKEN`, `SCHWAB_CLIENT_ID` / `SCHWAB_CLIENT_SECRET`
- Max 2 fields per `request_secret` call. For OAuth (client_id + client_secret), that fits.

### 5. After submission

`request_secret` returns `{ name, destination, fields[] }`. To USE the value:

```json
{
  "command": "node scripts/sync.js",
  "refs": ["linear"]
}
```

`run_with_secrets` injects each field as an env var (`LINEAR_API_KEY` in this case), runs the command, scrubs literal occurrences of the value from output, returns scrubbed stdout/stderr to you.

For piping to a CLI that reads from stdin:

```json
{
  "ref": "github",
  "field": "GITHUB_TOKEN",
  "command": "gh auth login --with-token"
}
```

## Common pitfalls

- **DON'T paste the value into chat.** That's literally what keymask exists to prevent. Always use the tool.
- **DON'T put `path` inside `fields[]`.** Path is a top-level argument, sibling of `name` / `destination` / `fields`.
- **DON'T set `destination` to a name you haven't seen in `list_destinations`** — call `list_destinations` first if you're not sure.
- **DON'T use `suggested_destination`** — that was an older schema. The field is `destination`.
- **DON'T forget the env-var-style field name** — `linear_key` (lowercase) is rejected. `LINEAR_API_KEY` works.

## Threat-model reminder

You never see the value. But the scrubber only catches LITERAL occurrences in output. So:

- `echo $LINEAR_API_KEY` — fine, scrubbed
- `echo $LINEAR_API_KEY | base64` — base64-encoded form is NOT scrubbed (known gap)
- `echo ${LINEAR_API_KEY:0:5}` — partial isn't scrubbed
- Side channels (timing, DNS) are not defended

If the user is in a sensitive context, don't print env vars in `run_with_secrets` at all. The value lives in the subprocess env and reaches the consuming code without ever touching your transcript.

## Quick reference

| Tool | Purpose | Returns |
|---|---|---|
| `request_secret` | Open form, get user to type value, store at destination | `{ name, destination, fields[] }` |
| `list_destinations` | See what's available (includes `builtin: true/false` flag) | `{ destinations[] }` |
| `list_secrets` | Names + destinations + timestamps; NEVER values | `{ secrets[] }` |
| `run_with_secrets` | Run a command with secret(s) in env, scrub output | `{ stdout, stderr, exit }` |
| `pipe_secret_to` | Pipe a single field's value to a command's stdin | `{ stdout, stderr, exit }` |
| `write_secret_to_file` | Write a single field to a local file (path-allowlisted) | `{ path }` |
| `delete_secret` | Remove from index (and optionally purge at destination) | `{ name, destination, purged }` |
| `rotate_secret` | Re-open the form for the same schema; user types new value | `{ name, destination, fields[], rotated_at }` |
