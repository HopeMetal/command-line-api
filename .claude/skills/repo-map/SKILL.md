---
name: repo-map
description: Explain the structure of any code repository and produce a durable repo map. Use when onboarding to a codebase, when asked to explain repository structure, architecture, or layout, or before planning changes in an unfamiliar repo. Runs a read-only scan, spawns parallel explorer subagents on large repos, and writes the result to docs/ai/repo-map.md.
compatibility: Designed for Claude Code; requires git and a POSIX shell
metadata:
  author: ai-assisted-engineering-labs
  version: "1.0"
allowed-tools: Read Grep Glob Bash Write
---

# Repo Map

Produce a repository map that explains **architecture, not directory names**: what this system is, how its parts depend on each other, and where a change of a given kind belongs. The output is a single file, `docs/ai/repo-map.md`, durable enough that the next agent (or human) can plan work from it without re-exploring the repo.

⚠️ **Write access is scoped**: `allowed-tools` grants `Write` for exactly one purpose — creating or updating `docs/ai/repo-map.md`. Do not write or modify any other file.

## Procedure

1. **Scan.** From the repository root, run the bundled script:

   ```
   bash scripts/scan_repo.sh
   ```

   It prints the directory tree (junk dirs pruned), file counts by extension, the largest files, detected manifests, and the base branch. It is read-only.

2. **Note the base branch** from the scan output. If it prints `unknown`, ask the human — never assume `main`.

3. **Choose your route.**
   - Under roughly 2,000 source files with a comprehensible top level: explore directly yourself.
   - Larger, or a monorepo with many independent top-level areas: follow the parallel explorer protocol in [references/large-repos.md](references/large-repos.md).

4. **Read the signals, not everything.** [references/what-to-look-for.md](references/what-to-look-for.md) lists the files that reveal structure — manifests, entry points, layering evidence, DI/config wiring, test layout, CI pipelines, codegen — with per-ecosystem hints. Every architectural claim you make must cite at least one file you actually read.

5. **Fill the template.** Copy the structure of [assets/repo-map-template.md](assets/repo-map-template.md) exactly and write `docs/ai/repo-map.md` (create `docs/ai/` if it does not exist). Rules:
   - The Directory guide covers only directories a developer touches. Vendored, generated, and build-output directories get one collective line, not rows.
   - Every "Where things go" row names a concrete **example file to imitate**, not just a directory.
   - Anything you inferred but did not verify goes under **Open questions**, never into the map as fact.

6. **Self-test.** Invent a plausible small feature for this repo and check that the map answers: *where would I add it, and which existing file would I imitate?* If it can't, the map is a directory listing wearing a trench coat — go back to step 4.

## Edge cases

- **No recognizable manifests / unfamiliar stack**: say so explicitly, map from directory content and file headers, and add "confirm build/run/test commands" to Open questions.
- **Monorepo**: one shared Overview, then a short per-package section reusing the same template headings.
- **Generated or vendored code** (`generated/`, `vendor/`, `*.g.cs`, lockfile churn): identify the generator and its source of truth; never describe generated code as hand-maintained architecture.
- **`docs/ai/repo-map.md` already exists**: read it first, update it, and note at the top what changed and when — do not silently overwrite.
