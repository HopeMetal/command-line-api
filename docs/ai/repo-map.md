# Repo Map — System.CommandLine

**Generated**: 2026-09-24 · **Base branch**: main · **By**: repo-map skill v1.0

## Overview

`dotnet/command-line-api` is a .NET class library (`System.CommandLine`) for building command-line applications — it handles argument parsing, model binding, help generation, shell completions, and action invocation. The library targets `netstandard2.0` and a modern .NET minimum (see Open questions), is trim-safe, and AOT-compatible on modern targets. The repo also ships `dotnet-suggest`, a companion global CLI tool that brokers real-time shell completion requests to any app built with the library, and `System.CommandLine.StaticCompletions`, a separate package for generating static shell completion scripts for Bash, Zsh, PowerShell, Fish, and Nushell.

## Build, run, test

| Action | Command | Source of truth |
|--------|---------|-----------------|
| Build (Windows) | `.\build.cmd` | `build.cmd` → `eng/common/build.sh` (Arcade SDK) |
| Build (macOS/Linux) | `./build.sh` | `build.sh` → `eng/common/build.sh` |
| Run locally | `dotnet run --project src/System.CommandLine.Suggest` | `src/System.CommandLine.Suggest/Program.cs` |
| Test (Windows) | `.\build.cmd -test` | `CONTRIBUTING.md` |
| Test (macOS/Linux) | `./build.sh --test` | `CONTRIBUTING.md` |

Tests use **xUnit** with **AwesomeAssertions** for assertions, **ApprovalTests** for API-surface snapshots, and **Verify.Xunit** for snapshot testing in `StaticCompletions.Tests`. All package versions are pinned in `Directory.Packages.props`.

## Directory guide

| Path | Purpose | Touch it when |
|------|---------|---------------|
| `src/System.CommandLine/` | Core library: parser, model, binding, invocation, help, completions | Adding a new symbol type, parser option, or built-in behavior |
| `src/System.CommandLine/Parsing/` | Tokenizer and parse-tree construction (`ParseOperation`, `SymbolResultTree`) | Changing how the CLI args string is tokenized or results are structured |
| `src/System.CommandLine/Binding/` | Type conversion from parsed tokens to typed values (`ArgumentConverter`) | Supporting a new argument value type |
| `src/System.CommandLine/Invocation/` | Action dispatch (`InvocationPipeline`, `CommandLineAction`) | Changing how commands are executed or cancellation behaves |
| `src/System.CommandLine/Help/` | Help text generation (`HelpBuilder`, `HelpAction`) | Changing help formatting or adding new help sections |
| `src/System.CommandLine/Completions/` | Runtime completion context and the `[suggest]` directive | Adding or changing live/dynamic completion behavior |
| `src/System.CommandLine.StaticCompletions/` | Generates static shell scripts from the command tree | Adding a new target shell or changing static completion script format |
| `src/System.CommandLine.StaticCompletions/shells/` | Per-shell script templates | Adding Nushell, Fish, etc. support |
| `src/System.CommandLine.Suggest/` | `dotnet-suggest` global tool entry point and suggestion registry | Changing how completions are brokered or registered per-app |
| `src/System.CommandLine.Tests/` | Unit and integration tests for the core library | Covering any change to `System.CommandLine` |
| `src/System.CommandLine.Tests/TestApps/` | NativeAOT, NativeLibrary, Trimming test harness apps | Verifying trim/AOT behavior |
| `src/System.CommandLine.ApiCompatibility.Tests/` | API surface snapshot tests (ApprovalTests) | Never touch manually — regenerate by running tests when public API changes |
| `src/System.CommandLine.Benchmarks/` | BenchmarkDotNet benchmarks | Adding or changing performance-sensitive code paths |
| `eng/` | Arcade SDK build infrastructure, signing, publishing config | Changing CI, signing, or NuGet publish settings |

Vendored/generated/build output: `artifacts/` (build outputs, NuGet cache), `eng/common/` (Arcade shared tooling — do not hand-edit).

## Architecture & layering

```
Consumer App
     │
     ▼
 [Model layer]
 Symbol / Command / Option / Argument / Directive / RootCommand
 (src/System.CommandLine/*.cs — no outward dependencies)
     │
     ▼
 [Configuration]
 ParserConfiguration · InvocationConfiguration
 (src/System.CommandLine/ParserConfiguration.cs, InvocationConfiguration.cs)
     │
     ▼
 [Parsing]
 CommandLineParser → ParseOperation → SymbolResultTree → ParseResult
 (src/System.CommandLine/Parsing/)
     │
     ├──► [Binding]
     │    ArgumentConverter (string tokens → typed values)
     │    (src/System.CommandLine/Binding/)
     │
     ├──► [Completions]
     │    CompletionContext / SuggestDirective
     │    (src/System.CommandLine/Completions/)
     │
     └──► [Invocation]
          InvocationPipeline → CommandLineAction (sync / async)
          (src/System.CommandLine/Invocation/)
               │
               └──► [Help]
                    HelpBuilder / HelpAction
                    (src/System.CommandLine/Help/)
```

**Dependency rules:**
- Model layer imports nothing from Parsing, Binding, or Invocation (`src/System.CommandLine/Symbol.cs` only imports `Completions` for completion source hooks).
- `ParseResult` is the hand-off point: created by Parsing, consumed by Binding/Invocation/Help.
- `dotnet-suggest` (`src/System.CommandLine.Suggest/`) references `System.CommandLine` as a `ProjectReference` but is a separate executable that dispatches to registered apps at runtime — not a layer inside the library.
- `System.CommandLine.StaticCompletions` references `System.CommandLine` as a `ProjectReference` and adds the `completions` subcommand on top of the user's `RootCommand`. Evidence: `src/System.CommandLine.StaticCompletions/System.CommandLine.StaticCompletions.csproj`.

## Where things go

| Task | Where | Example to imitate |
|------|-------|--------------------|
| Add a new built-in option (e.g. `--verbose`) | `src/System.CommandLine/` — create an `Option<T>` subclass | `src/System.CommandLine/VersionOption.cs` |
| Add a new directive (e.g. `[debug]`) | `src/System.CommandLine/` — implement `Directive` | `src/System.CommandLine/ParseDiagramDirective.cs` |
| Change how arguments are tokenized | `src/System.CommandLine/Parsing/ParseOperation.cs` | `src/System.CommandLine/Parsing/CommandLineParser.cs` |
| Add a new argument value converter | `src/System.CommandLine/Binding/ArgumentConverter.cs` | `src/System.CommandLine/Binding/ArgumentConverter.StringConverters.cs` |
| Add a test for parsing behavior | `src/System.CommandLine.Tests/` | `src/System.CommandLine.Tests/ParserTests.cs` |
| Add a test for completions | `src/System.CommandLine.Tests/CompletionTests.cs` | `src/System.CommandLine.Tests/CompletionTests.cs` |
| Add a static completion shell | `src/System.CommandLine.StaticCompletions/shells/` | Existing shell implementations in that directory |
| Add a dependency | `Directory.Packages.props` (version) + the relevant `.csproj` (`PackageReference` without version) | `Directory.Packages.props` |

## Conventions observed

- **Nullable enabled** everywhere; `TreatWarningsAsErrors` is set in `Directory.Build.props` — all nullable warnings must be resolved.
- **LangVersion latest** (`Directory.Build.props:9`) — use current C# features freely.
- **Central package management** (`Directory.Packages.props`) — versions are pinned in one place; `.csproj` files use `<PackageReference Include="..." />` without a `Version` attribute.
- **Localized strings** go in `src/System.CommandLine/Properties/Resources.resx`; the source is auto-generated into `LocalizationResources.cs` — never hand-edit the generated class.
- **Async actions** follow `SynchronousCommandLineAction` / `AsynchronousCommandLineAction` pattern (`src/System.CommandLine/Invocation/CommandLineAction.cs`); anonymous lambdas wrap them via `AnonymousAsynchronousCommandLineAction.cs`.
- **AOT/trim annotations** must be preserved for any code path reachable from the library's public API; the `EnableTrimAnalyzer` and `EnableSingleFileAnalyzer` flags enforce this on modern targets.

## Open questions

- **`$(NetMinimum)` value**: not resolved from the files read — `global.json` pins .NET SDK 11.0-preview and runtime 10.0.2, suggesting `NetMinimum` is `net10.0`, but this is defined inside the imported Arcade SDK props and was not confirmed from a file in this repo. Run `dotnet msbuild -getProperty:NetMinimum` to verify.
- **CI build definition**: only two workflow files exist in `.github/workflows/` (`backport.yml`, `inter-branch-merge-flow.yml`) and both delegate to external reusable workflows. The primary CI (Azure DevOps) is referenced in the README badge but its pipeline YAML is not in this repo. Test and publish commands from `CONTRIBUTING.md` were used as the source of truth.
- **`NetFrameworkMinimum`**: confirmed as `net472` in `Directory.Build.props`, but only the tests project uses it — the main library does not target .NET Framework directly (only `netstandard2.0`).
