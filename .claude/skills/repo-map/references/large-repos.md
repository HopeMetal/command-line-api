# Large repos — the parallel explorer protocol

Use this when the scan reports more than roughly 2,000 source files, or the top level has more independent areas than you can explore without losing the thread. Below those thresholds, explore directly — subagents cost context and lose cross-cutting sight, so they must earn their place.

## Partition

- One explorer subagent per top-level source area (e.g. `src/api`, `src/domain`, `services/billing`).
- Group small or peripheral directories into a single "everything else" explorer.
- **Cap at 6 explorers.** If the repo has more areas than that, merge the least active ones (check `git log --stat` if unsure which matter).
- You (the main agent) explore nothing in parallel with them — your job is the merge.

## Explorer prompt

Give every explorer this prompt verbatim, filling the `<path>`:

> You are exploring one area of a larger repository: `<path>`. Do not read outside it. Report, in at most 25 lines:
>
> - **Purpose**: what this area does, one sentence.
> - **Key files**: up to 5, one line each on why they matter.
> - **Depends on**: which sibling areas/packages it imports from, with one file:line as evidence per claim.
> - **Depended on by**: who imports it, if visible from inside this area.
> - **Conventions**: naming, error-handling, and test patterns you observed.
> - **Surprises**: anything that contradicts what the directory name promises.

The fixed format is the point: explorers that report free-form prose cannot be merged.

## Merge rules

- You write the map; explorers never write files.
- Where two explorers make conflicting claims, open the evidence files yourself and decide — do not average.
- After merging, do a **cross-cutting pass** yourself: shared libraries, configuration layering, event/message flows, codegen pipelines. These span areas, so no single explorer saw them — this pass is what buys back the insight that partitioning lost.

## Costs — be honest about them

- Every explorer is a fresh context that must re-orient from zero; six explorers read the same manifests six times.
- Depth per area goes up; cross-cutting insight goes down. The merge pass compensates, but not fully.
- This is the **Parallel** pattern from Google's agentic design pattern catalog: independent sub-tasks, concurrent execution, synthesis at the end. Reach for it when the repo is too big for one context — not because parallelism feels fast.
