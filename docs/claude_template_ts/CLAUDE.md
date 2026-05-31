# CLAUDE.md — Universal Project Guidelines

> Baseline working instructions applied across all projects.
> Project-specific details live in `@.claude/rules/*.md` and are referenced, not duplicated.
> Tradeoff: these guidelines bias toward caution over speed. For trivial tasks, use judgment.

---

## ⚠️ MANDATORY — Every Session, Every Response

1. **Source first**: Never answer questions about paths, config values, or runtime behavior by guessing. Read the actual source code first.
2. **Session restore**: After `/compact` or a new session, re-read this file before resuming work.
3. **No partial completion**: If a task cannot be finished, report what is blocking. Never commit or leave half-finished code.
4. **New bug pattern**: When discovered, record it in `.claude/rules/gotchas.md` immediately — do not rely on memory.

---

## 1. Think Before Coding (Karpathy)

- State assumptions explicitly. If uncertain, stop and ask.
- If multiple interpretations exist, present them — do not silently pick one.
- If a simpler approach exists, say so. Push back when warranted.

## 2. Simplicity First (Karpathy)

- Implement only what was asked. No speculative features, abstractions, or "flexibility."
- No error handling for impossible scenarios.
- "Would a senior engineer call this overcomplicated?" If yes, simplify.

## 3. Surgical Changes (Karpathy)

- Touch only what you must. Don't "improve" adjacent code, comments, or formatting.
- Don't refactor what isn't broken. Match the existing style.
- Remove only the imports/variables your change orphaned. Mention pre-existing dead code; don't delete it.
- Test: every changed line must trace directly to the user's request.

## 4. TDD & Tidy First (Kent Beck)

- **TDD cycle**: Red (failing test) → Green (minimum code to pass) → Refactor.
- Write the simplest failing test first. Implement just enough to pass.
- Bug fix: first write a test that reproduces the defect, then make it pass.
- **Tidy First**: separate changes into two kinds —
  - Structural (rename / extract / move — behavior unchanged)
  - Behavioral (add / modify functionality)
- Never mix the two in one commit. Make structural changes first; run tests before and after to confirm behavior is unchanged.

## 5. Goal-Driven Execution (Karpathy)

- Turn tasks into verifiable goals: "add validation" → "write tests for invalid input, then make them pass."
- For multi-step work, state a brief plan first: `1. [step] → verify: [check]`.

---

## Commit Discipline (Kent Beck)

- Commit only when: ① all tests pass, ② zero compiler/linter warnings, ③ a single logical unit of work.
- State in the message whether the commit is structural or behavioral.
- Prefer small, frequent commits over large, infrequent ones.

## Git Workflow

- **Commit/push only on explicit user request.** Without a direct command ("commit", "push", "create a PR"), never run `git commit` / `git push` / `gh pr create`. After finishing, report a change summary and wait for instruction.
- Conventional Commits: `feat:`, `fix:`, `refactor:`, `docs:`, with a scope prefix.
- Always run tests before committing. PR descriptions include what / why / how.

---

## Response Control (CRITICAL)

> This section overrides all other response-format guidance. It exists to prevent duplicate/verbose output bugs.

- **R1 Single output**: One final response per request. No "summary + detail" or "plan + result" double repetition.
- **R2 Summary once**: The completion summary appears exactly once. Don't narrate in the body then re-list as bullets.
- **R3 Code output dedup**: Output only ONE of ① full file, ② diff, ③ text summary. Default is changed-section + a short note. For files over 200 lines, show changed lines ± context only.
- **R4 Tool-call boundary**: Don't repeat the same intent before and after a tool call ("I'll do X" → run → "I did X"). Report only the result.
- **R5 One task, one turn**: Don't auto-run follow-up work that wasn't requested. Offer next steps as a question only.
- **R6 Length budget**: Simple Q&A within 3 paragraphs; code edits within changed-section + ~10 lines of explanation.

## Hallucination Guard

Before sending, self-verify:
- Do the referenced file paths / class names / method names actually exist?
- Are external links the correct domain/path? Is sample code syntactically valid?
- If unsure, mark it "needs verification" / "unverified" — do not guess.

---

## Language & Response Policy

| Target | Language |
|--------|----------|
| Internal reasoning & planning | English |
| Code, variable names, comments, logs, error messages | English |
| Git commit messages | English (Conventional Commits) |
| User-facing response (explanation · summary · question) | English summary → Korean conclusion (see format below) |

**Response format (always):**
- Write the working summary / explanation in **English first**.
- Then state the **final conclusion in Korean** (한글로 최종 결론).
- Order is fixed: **English summary → Korean conclusion**, each exactly once (see R2).
- When error output or quoted English text appears, add a brief Korean note for that part only.

**On task completion**, the Korean conclusion covers, in one block, once:
1. What changed (무엇을 변경했는지)
2. Why (왜 그렇게 했는지)
3. Caveats (주의할 점)

---

## Safety Guardrails

### Absolute Prohibitions
- **Data destruction**: `DELETE`/`TRUNCATE` without `WHERE`, `DROP TABLE`/`DROP DATABASE`, volume removal (`docker compose down -v`), `rm -rf` on project root, editing/deleting existing migration files.
- **Git**: `git push --force`, `git reset --hard`, `git commit --no-verify`. Committing/pushing without an explicit request.
- **Secrets**: creating/editing `.env*` directly; exposing API keys, tokens, or secrets in code or logs.
- **Production**: auto-modifying a production DB; changing production Docker/Compose configs without approval; exposing internal ports (e.g. `5432`/`6379`) to a public network.

### Require Explicit User Approval
- DB schema / entity changes; new migration file creation.
- Dependency additions or version changes (`package.json` / `build.gradle`, etc.); build, security, or config file changes.
- Docker config changes; documentation file deletions.
- Core infrastructure files (compose, routing/SSL, shared types & schemas) require approval before any change.

### Best Practices
- Confirm a backup exists before any destructive operation. Prefer an SQL fix over a DB reset.
- Introduce libraries outside the core stack only with a stated rationale and approval. Never run `npm audit fix --force`.
- No workarounds — for production/open-source quality, find the structural root cause and apply a complete fix so the issue never recurs.

> See `@.claude/rules/safety.md` for project-specific safety rules.

---

## Project-Specific References (extension slots)

Each project defines these in its own `.claude/rules/` and references them here:
@.claude/rules/techstack.md
@.claude/rules/project-structure.md
@.claude/rules/commands.md
@.claude/rules/code-style.md
@.claude/rules/safety.md
@.claude/rules/gotchas.md
