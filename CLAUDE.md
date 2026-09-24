# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Test

```bash
# Build (Windows)
.\build.cmd

# Build (macOS/Linux)
./build.sh

# Build and run all tests (Windows)
.\build.cmd -test

# Build and run all tests (macOS/Linux)
./build.sh --test

# Run a single test project directly
dotnet test src/System.CommandLine.Tests/

# Run a specific test by name
dotnet test src/System.CommandLine.Tests/ --filter "FullyQualifiedName~<TestName>"

# Run dotnet-suggest locally
dotnet run --project src/System.CommandLine.Suggest
```

Build uses the [Arcade SDK](https://github.com/dotnet/arcade) — `build.cmd`/`build.sh` delegate to `eng/common/build.sh`. Tests use **xUnit**, **AwesomeAssertions**, and **ApprovalTests** (API surface snapshots).

## Architecture

The library follows a strict layered model. Dependencies only flow downward:

```
[Model layer]  Symbol / Command / Option / Argument / Directive / RootCommand
     ↓
[Configuration]  ParserConfiguration · InvocationConfiguration
     ↓
[Parsing]  CommandLineParser → ParseOperation → SymbolResultTree → ParseResult
     ↓
[Binding]  ArgumentConverter (tokens → typed values)
[Completions]  CompletionContext / SuggestDirective
[Invocation]  InvocationPipeline → CommandLineAction (sync/async)
     ↓
[Help]  HelpBuilder / HelpAction
```

`ParseResult` is the hand-off between parsing and all downstream subsystems (binding, invocation, help).

`dotnet-suggest` (`src/System.CommandLine.Suggest/`) is a separate global tool executable that brokers shell completions to registered apps at runtime — not a layer inside the library.

`System.CommandLine.StaticCompletions` is a separate package that adds a `completions` subcommand to the user's `RootCommand` for generating static shell scripts (Bash, Zsh, PowerShell, Fish, Nushell).

## Key Conventions

- **Nullable enabled** everywhere; `TreatWarningsAsErrors` is set — all nullable warnings must be resolved.
- **Central package management** — all dependency versions go in `Directory.Packages.props`. Never add `Version="..."` to a `<PackageReference>` in a `.csproj`.
- **Localized strings** go in `src/System.CommandLine/Properties/Resources.resx`. The class `LocalizationResources.cs` is auto-generated — never hand-edit it.
- **AOT/trim annotations** must be preserved for any code path reachable from the public API; `EnableTrimAnalyzer` and `EnableSingleFileAnalyzer` enforce this on modern targets.
- **API surface snapshots** in `src/System.CommandLine.ApiCompatibility.Tests/` are managed by ApprovalTests — regenerate by running the tests after any public API change. Never edit them manually.
- `eng/common/` is vendored Arcade SDK tooling — do not edit files there.

## Repo map

- Only use repo-map skill if there are changes to the code. Use git to find out.
- If there are no changes and a `repo-map.md` does not exist, run repo-map
- If a `repo-map.md` exists in `docs/ai` use it when asked anything about the repository