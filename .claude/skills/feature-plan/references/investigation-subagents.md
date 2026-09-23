# Investigation subagents

How to farm out unknowns during planning without losing rigor.

## The rules

- **One question per subagent.** A subagent with three questions answers one well and two by vibes.
- **Parallel only when independent.** If question B's meaning depends on question A's answer ("where is validation?" → "how is *that* validator tested?"), investigate sequentially yourself.
- **Fewer than three unknowns: no subagents.** Just look — delegation overhead would exceed the work.
- **Evidence or it didn't happen.** An investigator's claim without a file:line reference is a rumor. Spot-check at least one claim from every investigator before building on it.

## Investigator prompt

Use verbatim, filling the `<>` parts:

> You are investigating one question about this repository to support an implementation plan. Answer only this question; do not explore beyond what it needs.
>
> **Question**: <the single question>
> **Context**: <one line: the feature being planned>
>
> Return, in at most 15 lines:
> - **Answer**: direct answer to the question.
> - **Evidence**: file:line references for every claim.
> - **Confidence**: high / medium / low, one clause on why.
> - **Not checked**: what you deliberately did not look at.

The "Not checked" line matters most: it tells you where the answer's edges are, which is exactly what a plan's Risks section needs.

## What comes back badly, and what to do

| Symptom | Response |
|---------|----------|
| Answer with no evidence | Re-ask, or verify yourself — never paste it into the plan |
| "It depends" essays | Your question bundled two questions; split and re-run |
| Confident answer contradicting the repo map | Open the evidence file yourself; the code wins, then note the map is stale |
