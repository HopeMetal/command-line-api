# Plan quality checklist

Run every item before presenting a plan. A failed item is a defect in the plan, not a style preference.

| # | Check | Passes when | Fails when |
|---|-------|-------------|------------|
| 1 | **Grounded steps** | Every step names files that exist (verified by you or an investigator) | Any step says "the service layer", "relevant files", or names a path nobody checked |
| 2 | **Verifiable steps** | Every step has a verify-by: a command to run or an observable to check | A step's "done" is a feeling |
| 3 | **Out of scope is real** | The section lists at least one adjacent thing this plan deliberately won't do | Empty, or restates the feature negatively |
| 4 | **Test plan names behaviors** | Each row is a provable behavior ("rejects codes past expiry") | It says "write unit tests" |
| 5 | **Risks are honest** | The top risk is something that could actually derail this change | Boilerplate ("code may have bugs") |
| 6 | **Unknowns surfaced** | Every open question is either answered with evidence or tagged `[ASSUMPTION — confirm]` | An assumption is stated as fact |
| 7 | **Deviation log present and empty** | The section exists with its comment header, nothing else | Missing, or pre-filled |
| 8 | **Readable cold** | Someone who didn't watch you plan could execute it | Steps reference "the file mentioned above" or your conversation |

💡 Checks 1 and 2 catch most bad plans. If you only have time for two, run those.
