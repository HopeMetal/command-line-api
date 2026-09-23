---
name: feature-plan
description: Produce a grounded implementation plan before writing any code. Use when asked to plan a feature, prepare an implementation plan, or before any non-trivial change. Reads docs/ai/repo-map.md if present, resolves unknowns with parallel investigation subagents, confirms scope and open questions with the human, and writes docs/ai/plan-<slug>.md. Never writes source code.
compatibility: Designed for Claude Code; requires git
metadata:
  author: ai-assisted-engineering-labs
  version: "1.0"
---

# Feature Plan

Turn a feature request into a plan grounded in **this** repository: real file paths, verifiable steps, explicit unknowns. A plan that says "update the service layer" is a horoscope; a plan that says "add the rule to `src/checkout/validate.ts` and prove it via `npm test -- validate`" is a contract. This skill produces contracts.

🚫 **This skill never writes source code.** Its only output is one plan file under `docs/ai/`.

## Procedure

1. **Orient.** Read `docs/ai/repo-map.md` if it exists. If it doesn't, suggest running the `repo-map` skill first; if the human declines, do a quick orientation pass yourself before planning. Detect the base branch (`git symbolic-ref --short refs/remotes/origin/HEAD`); if unknown, ask.

2. **Restate and confirm** *(human checkpoint 1)*. Restate the feature in at most two sentences, plus a first guess at what is **out of scope**. Wait for confirmation before investigating — a plan for the wrong feature is worse than no plan.

3. **List the unknowns.** Everything the plan depends on that you have not verified in the code: where the relevant logic lives, what patterns neighboring code uses, what would break, how this area is tested. Write them down as questions.

4. **Investigate.** For **independent** unknowns, spawn one investigation subagent per question, in parallel, following [references/investigation-subagents.md](references/investigation-subagents.md). For unknowns that depend on each other's answers, investigate sequentially yourself. Fewer than three unknowns: skip subagents and just look.

5. **Draft the plan** using the exact structure of [assets/plan-template.md](assets/plan-template.md). Every step names real files (paths you or an investigator verified exist) and a **verify-by**: the command or observable that proves the step worked. Leave the **Deviation log** section empty — it belongs to implementation, not planning.

6. **Self-check** against [references/plan-quality-checklist.md](references/plan-quality-checklist.md). Fix every failure before showing the plan to anyone.

7. **Present and decide** *(human checkpoint 2)*. Show the human the open questions and the risky decisions — not the whole plan, just the decisions. Whatever stays unresolved goes into the plan tagged `[ASSUMPTION — confirm]`, never silently absorbed.

8. **Write the file**: `docs/ai/plan-<slug>.md`, where `<slug>` is a short kebab-case name for the feature. Create `docs/ai/` if missing. Announce the path.

## Edge cases

- **The feature is too big** (more than ~5 files or multiple independent behaviors): say so and propose a split into separately plannable slices. Do not produce a 30-step plan.
- **The repo map is stale** (it names files that no longer exist): trust the code, note the staleness, and suggest re-running `repo-map`.
- **The human wants to skip checkpoints**: comply, but tag every decision you made alone with `[ASSUMPTION — confirm]` so the review trail survives.
