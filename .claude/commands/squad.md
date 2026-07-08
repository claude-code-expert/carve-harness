---
description: "Invoke a Squad Agent. Usage: /squad <member> [task]"
allowed-tools: Agent
---

Parse the user's input:
- First word = member keyword (review, plan, refactor, qa, debug, docs, gitops, audit)
- Remaining text = task description

The actual agent name is `squad-{keyword}`. For example:
- "/squad review" → invoke squad-review
- "/squad refactor src/utils/" → invoke squad-refactor with scope

Available Squad Agents:
- squad-review: Code review (security, performance, style)
- squad-plan: Feature planning, user stories, wireframes
- squad-refactor: Code refactoring (extract, simplify, rename, remove)
- squad-qa: Run tests and generate QA report
- squad-debug: Error analysis and root cause identification
- squad-docs: Documentation generation and updates
- squad-gitops: Commit messages, PR descriptions, changelogs
- squad-audit: Security audit and vulnerability scanning

If no match, list all members and ask to choose.

$ARGUMENTS
