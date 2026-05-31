# [Claude Code Expert](https://github.com/claude-code-expert) — Book Example Docs

> 📘 [github.com/claude-code-expert](https://github.com/claude-code-expert) — Claude Code Master (Hanbit Media Official Repository) <br>
> ☕ [www.brewnet.dev](https://www.brewnet.dev) — Self-hosted home server auto-provisioning open source
> Hanbit Media | Release: 2026.04.15

# Squad Subagent Commands Guide

https://github.com/claude-code-expert/subagents

A reference for all 9 slash commands with real-world usage examples.

---

## 📋 Command Summary

| Command | Role | Model | Pipeline Position |
|---------|------|-------|-------------------|
| `/squad` | Router (member dispatcher) | - | Entry point |
| `/squad-plan` | Planning / User stories / Wireframes | opus | START |
| `/squad-review` | Code review | - | After implementation |
| `/squad-refactor` | Refactoring | - | After review REQUEST_CHANGES |
| `/squad-qa` | Tests / QA | - | After review APPROVE |
| `/squad-debug` | Debugging / Root cause analysis | - | On bug reports |
| `/squad-docs` | Documentation generation | - | Any time |
| `/squad-gitops` | Commit / PR / Changelog | haiku | After qa PASS |
| `/squad-audit` | Security audit | - | Before deploy |

---

## 🔧 Command Reference

### 1. `/squad` — Router

Parses the first word as a keyword (`review`, `plan`, `refactor`, `qa`, `debug`, `docs`, `gitops`, `audit`) and dispatches to the matching subagent.

**Syntax**: `/squad <member> [task]`

```bash
/squad review
# → invokes squad-review (scope: latest commit)

/squad refactor src/utils/
# → invokes squad-refactor with src/utils/ scope

/squad debug "TypeError: undefined"
# → forwards error message to squad-debug

/squad plan checkout screen
# → forwards planning request to squad-plan
```

---

### 2. `/squad-plan <feature>` — Planning

**Deliverables**
- User stories (US-001, US-002 …)
- Wireframes (SVG/HTML, saved to `docs/wireframes/`)
- Implementation plan (ordered tasks + complexity S/M/L/XL)

**Prohibited**: source code edits, git commits

```bash
/squad-plan user login (OAuth + 2FA)
# → creates docs/wireframes/login.svg
# → 5 user stories + 10-step implementation plan

/squad-plan cart checkout screen
# → mobile 375x812 viewport wireframe
# → includes "empty cart" edge case

/squad-plan admin dashboard — realtime orders view
# → technical considerations: auth checks, WebSocket vs Polling
```

---

### 3. `/squad-review [scope]` — Code Review

**Inspects**: security, performance, maintainability, style
**Outcome**: `APPROVE` → `/squad-qa`, `REQUEST_CHANGES` → `/squad-refactor`

```bash
/squad-review
# Default: review the latest commit diff

/squad-review src/auth/
# Review a specific directory

/squad-review HEAD~3..HEAD
# Review the last 3 commits together

/squad-review PR #42
# Review a specific PR scope
```

---

### 4. `/squad-refactor [scope]` — Refactoring

**Scope**: up to file / directory / module level
**Note**: Does NOT run tests — delegate to `/squad-qa`

```bash
/squad-refactor
# Default: refactor latest commit diff

/squad-refactor src/utils/helpers.js
# Single-file refactor

/squad-refactor payments module — remove duplication
# Scope + goal specified in natural language

/squad-refactor src/api/ — focus on splitting long functions
# Directional hint for refactoring
```

---

### 5. `/squad-qa [scope]` — Test Execution

**Outcome**: `PASS` / `FAIL` report
**Next step on PASS**: `/squad-gitops`

```bash
/squad-qa
# Default: test all recent changes

/squad-qa tests/auth/
# Auth test directory only

/squad-qa "verify the payment E2E flow only"
# Natural-language scope

/squad-qa unit
# Unit tests only (skip integration)
```

---

### 6. `/squad-debug <error>` — Debugging

**Output**: root cause analysis + recommended fix (description only, no code changes)

```bash
/squad-debug "TypeError: Cannot read property 'id' of undefined at UserService.js:42"
# → stack trace walk-through, cause, proposed fix

/squad-debug
Error: EADDRINUSE: address already in use :::3000
    at Server.setupListenHandle [as _listen2]
# → instructions to identify the port-occupying process

/squad-debug "whitescreen after login, no console errors"
# → follow-up questions + suspect list

/squad-debug logs/app.log
# → log file analysis
```

---

### 7. `/squad-docs [type]` — Documentation

**Types**: `readme` / `api` / `architecture` / `jsdoc`

```bash
/squad-docs readme
# → generate or update README.md

/squad-docs api
# → API reference (endpoints, params, responses)

/squad-docs architecture
# → system architecture diagram + description

/squad-docs jsdoc src/services/
# → add JSDoc to files under services/
```

---

### 8. `/squad-gitops [type]` — Git Workflow

**Types**: `commit` / `pr` / `changelog` / `release-notes`
**Important**: Generates messages only — `git commit`/`push` is up to the user

```bash
/squad-gitops commit
# → Conventional Commit message
# e.g., "feat(auth): add OAuth2 login flow"

/squad-gitops pr
# → PR title + body (What / Changes / How to Test / Checklist)

/squad-gitops changelog
# → update CHANGELOG.md (Keep a Changelog format)

/squad-gitops release-notes v1.3.2
# → user-facing release notes
```

**Generated commit format**
```
type(scope): subject (under 50 chars)

body (wrap at 72 chars)

footer (BREAKING CHANGE, Closes #issue)
```

---

### 9. `/squad-audit [scope]` — Security Audit

**Checks**: secret exposure, OWASP Top 10, dependency CVEs, auth/permissions

```bash
/squad-audit
# Default: whole-project scan

/squad-audit src/api/
# Focused audit on a specific path

/squad-audit "focus on OWASP Top 10"
# Narrow the scope

/squad-audit .env, config/
# Prioritize secret-leak detection
```

---

## 🔄 Recommended Pipelines

### Standard Feature Development

```
/squad-plan new-feature
    ↓ (user stories + wireframes + plan)
[user implements]
    ↓
/squad-review
    ├─ APPROVE      → /squad-qa
    │                  ├─ PASS → /squad-gitops commit → /squad-gitops pr
    │                  └─ FAIL → /squad-debug → fix → /squad-qa
    └─ REQUEST_CHANGES → /squad-refactor → /squad-review (re-verify)
    ↓
[before deploy]
/squad-audit
```

### Bug Fix Flow

```
bug report
    ↓
/squad-debug "error message"
    ↓ (root cause + fix proposal)
[user fixes]
    ↓
/squad-qa
    ↓ PASS
/squad-gitops commit
```

### Documentation Flow

```
Any time:
/squad-docs readme
/squad-docs api
/squad-docs architecture
```

---

## 💡 Real-World Scenarios

### Scenario A: New Feature "Password Reset"

```bash
# Step 1: Plan
/squad-plan password reset (email-token based)
# → docs/wireframes/password-reset.svg
# → US-001 ~ US-004, 8-step implementation

# Step 2: Implement (user)

# Step 3: Review
/squad-review
# → REQUEST_CHANGES: hardcoded token expiry detected

# Step 4: Refactor
/squad-refactor src/auth/password-reset.js — externalize token config

# Step 5: Re-review
/squad-review
# → APPROVE

# Step 6: Test
/squad-qa tests/auth/password-reset.test.js
# → PASS

# Step 7: Commit + PR
/squad-gitops commit
/squad-gitops pr

# Step 8: Pre-deploy security audit
/squad-audit src/auth/
```

### Scenario B: Production Bug — Fast Response

```bash
# Step 1: Symptom analysis
/squad-debug "500 Internal Server Error on /api/orders after 5 min idle"
# → suspects DB connection pool timeout + verification steps

# Step 2: Re-diagnose with logs
/squad-debug logs/production-2026-04-17.log
# → root cause: missing keepalive, proposes fix

# Step 3: Test the fix
/squad-qa "DB connection reconnect scenario"

# Step 4: Hotfix commit
/squad-gitops commit
# → "fix(db): add connection keepalive to prevent idle timeout"
```

### Scenario C: Legacy Code Cleanup Sprint

```bash
# Step 1: Full audit
/squad-audit
# → 3 secret leaks, 5 outdated deps

# Step 2: Identify refactor targets
/squad-review src/legacy/
# → REQUEST_CHANGES: 7 long functions, 3 duplicated blocks

# Step 3: Module-level refactor
/squad-refactor src/legacy/order-processor.js
/squad-refactor src/legacy/inventory.js

# Step 4: Regression test
/squad-qa src/legacy/

# Step 5: Doc update
/squad-docs architecture

# Step 6: Record changes
/squad-gitops changelog
```

### Scenario D: Fast Dispatch via Router

```bash
# Use /squad instead of full command names
/squad plan notification center
/squad review
/squad qa tests/
/squad debug "NullPointerException at line 42"
/squad gitops commit
```

---

## 🚫 Agent Boundaries (Common Rules)

Every squad agent **never**:

- Executes `git commit` / `git push` directly (user decides)
- Runs destructive commands like `rm`, `mv`
- Performs work outside its role

Role delegation is explicit:

| Task | Owner |
|------|-------|
| Code modification | `/squad-refactor` |
| Test execution | `/squad-qa` |
| Commit / PR messages | `/squad-gitops` |
| Documentation | `/squad-docs` |
| Planning / Wireframes | `/squad-plan` |
| Security scan | `/squad-audit` |
| Root cause analysis | `/squad-debug` |
| Quality check | `/squad-review` |

---

## 📚 Related Docs

- [ARCHITECTURE.md](./ARCHITECTURE.md) — Full system structure
- [SQUAD-KEYWORD-MAP.md](./SQUAD-KEYWORD-MAP.md) — KO/EN trigger keyword map
- [SQUAD-ROUTER-KEYWORDS.md](./SQUAD-ROUTER-KEYWORDS.md) — Router keyword rules
- [pipeline-diagram.svg](./pipeline-diagram.svg) — Pipeline visualization
