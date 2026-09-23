# Repo Map — command-line-api (System.CommandLine)

**Generated**: 2026-09-22 · **Base branch**: main · **By**: repo-map skill v1.0 (3-explorer parallel run)
**Previous map**: 2026-09-21 — **What changed**: Added version number (3.0.0-preview.7); clarified C# 14 `extension` block in `DynamicSymbolExtensions.cs`; distinguished ApprovalTests (Help) vs. Verify.Xunit (StaticCompletions) snapshot frameworks; documented `CompilationTests.cs` process-spawning pattern; noted `AwesomeAssertions` vs. standard FluentAssertions; confirmed `NetFrameworkMinimum=net472` and `LangVersion=latest`; clarified that `.github/` is branch-management only (no CI builds there).

---

## Overview

This repository is the `System.CommandLine` library and its satellite tools — a .NET library (v3.0.0-preview.7) that provides command-line parsing, help generation, tab-completion, and invocation for .NET applications. Library consumers define a `RootCommand` tree of `Command`s, `Option<T>`s, and `Argument<T>`s, call `Parse()` to get a `ParseResult`, and call `Invoke()`/`InvokeAsync()` to execute the matched action. Two companion packages live in the same repo: `dotnet-suggest` (a .NET global tool that bridges the shell to an app's built-in completions at runtime) and `System.CommandLine.StaticCompletions` (generates static shell completion scripts from the command tree at publish time).

## Build, run, test

| Action | Command | Source of truth |
|--------|---------|-----------------|
| Build | `dotnet build` | `Directory.Build.props` imports Arcade SDK; versions in `eng/Versions.props` |
| Test | `dotnet test src/System.CommandLine.Tests` | `src/System.CommandLine.Tests/System.CommandLine.Tests.csproj` |
| AOT/Trim compile tests | Run in Release only (`[ReleaseBuildOnly]` attribute) | `src/System.CommandLine.Tests/CompilationTests.cs` |
| Benchmarks | `dotnet run -p src/System.CommandLine.Benchmarks` | `src/System.CommandLine.Benchmarks/System.CommandLine.Benchmarks.csproj` |
| CI / official build | Azure DevOps only — `.azuredevops/` | `eng/common/core-templates/`; `.github/` contains branch-management scripts only |

> No `.sln` file — projects are discovered by `dotnet` tooling via `Directory.Build.props`. Build infrastructure uses the Microsoft [Arcade](https://github.com/dotnet/arcade) SDK (`eng/common/`, version 11.0.0-beta at time of map). `LangVersion=latest` is set globally, enabling C# 14 features. `TreatWarningsAsErrors=true` everywhere.

## Directory guide

| Path | Purpose | Touch it when |
|------|---------|---------------|
| `src/System.CommandLine/` | Core library: parsing, binding, invocation, help, completions | Adding a new symbol type, parser option, invocation behavior, or help feature |
| `src/System.CommandLine/Parsing/` | Tokenization → `ParseOperation` → `ParseResult` | Changing how raw tokens are lexed or parsed into the result tree |
| `src/System.CommandLine/Invocation/` | `InvocationPipeline`, `CommandLineAction` base and anonymous variants | Changing how matched actions are executed, pre/post action hooks, cancellation |
| `src/System.CommandLine/Binding/` | `ArgumentConverter` — token strings → typed CLR values | Adding support for a new argument type conversion |
| `src/System.CommandLine/Help/` | `HelpBuilder` (internal) and `HelpOption`, `HelpAction`, `HelpBuilderExtensions` (public) | Changing help formatting or adding help sections |
| `src/System.CommandLine/Completions/` | `CompletionContext`, `CompletionItem`, `SuggestDirective` | Changing runtime tab-completion behavior |
| `src/System.CommandLine.Suggest/` | `dotnet-suggest` global tool — shell shims (bash/zsh/pwsh) + dispatcher that routes completion requests to the target app | Changing the shell-to-app completion bridge or registration mechanisms |
| `src/System.CommandLine.StaticCompletions/` | Library that adds a `completions` subcommand and generates static shell scripts (bash/zsh/fish/pwsh/nushell) | Adding a new shell provider or changing generated script format |
| `src/System.CommandLine.StaticCompletions/shells/` | One `IShellProvider` implementation per shell | Adding a new shell backend |
| `src/System.CommandLine.Tests/` | Main test suite (xUnit, ApprovalTests for Help, AwesomeAssertions) | Adding tests for any core library change |
| `src/System.CommandLine.Tests/TestApps/` | NativeAOT, NativeLibrary, Trimming test apps (spawned as child processes by `CompilationTests.cs`) | Testing AOT/trim publish correctness |
| `src/System.CommandLine.StaticCompletions.Tests/` | Snapshot tests using Verify.Xunit for each shell provider's generated output | Adding/changing a shell provider or its output format |
| `src/System.CommandLine.ApiCompatibility.Tests/` | API surface regression tests (single approval snapshot of the full public API) | Verifying no public API was accidentally broken |
| `src/System.CommandLine.Benchmarks/` | BenchmarkDotNet micro-benchmarks | Measuring performance impact of a change |
| `eng/` | Arcade build infrastructure — versions, signing, publishing, cross-platform native | Bumping dependencies or changing build/publish configuration |
| `docs/` | Human-written docs (history, goals, dotnet-suggest guide) | Writing documentation for users |

Vendored/generated: `eng/common/` is Arcade shared tooling, not hand-maintained; `src/System.CommandLine/System.Diagnostics.CodeAnalysis/` and `src/System.CommandLine/System.Runtime.CompilerServices/` are polyfill shims for downlevel targets.

## Architecture & layering

```
┌────────────────────────────────────────────────────────┐
│  Consumer app: defines RootCommand tree, calls Invoke  │
└──────────────────────┬─────────────────────────────────┘
                       │
          ┌────────────▼────────────┐
          │   System.CommandLine    │  (core library; only external dep: System.Memory on netstandard2.0)
          │  ┌──────────────────┐   │
          │  │  Symbol model    │   │  Symbol ← Command / Option<T> / Argument<T> / Directive
          │  │  (Command.cs,    │   │
          │  │   Symbol.cs)     │   │
          │  └────────┬─────────┘   │
          │           │             │
          │  ┌────────▼─────────┐   │
          │  │  Parsing layer   │   │  CommandLineParser → tokens → ParseOperation → ParseResult
          │  │  (Parsing/*.cs)  │   │
          │  └────────┬─────────┘   │
          │           │             │
          │  ┌────────▼─────────┐   │
          │  │ Invocation layer │   │  ParseResult.Invoke() → InvocationPipeline → CommandLineAction
          │  │(Invocation/*.cs) │   │
          │  └──────────────────┘   │
          └───────────┬─────────────┘
                      │ ProjectReference
       ┌──────────────┴──────────────────────┐
       │                                     │
 ┌─────▼───────────────────────┐   ┌─────────▼──────────────────────┐
 │ System.CommandLine          │   │ System.CommandLine             │
 │ .StaticCompletions          │   │ .Suggest  (dotnet-suggest)     │
 │                             │   │                                │
 │ BUILD-TIME approach:        │   │ RUNTIME approach:              │
 │ Adds `completions`          │   │ Global tool; shell shims ask   │
 │ subcommand; generates       │   │ dotnet-suggest → it calls back │
 │ static bash/zsh/fish/       │   │ the target app with [suggest]  │
 │ pwsh/nushell scripts        │   │ directive to get completions   │
 │ (IShellProvider per shell)  │   │ (3 shims: bash, zsh, ps1)      │
 └─────────────────────────────┘   └────────────────────────────────┘
          ↑ no shared code between the two completion approaches ↑
```

**Dependency direction** (verified via `ProjectReference` entries in `.csproj` files):
- `System.CommandLine` has **zero** project references — it is the leaf dependency.
- `System.CommandLine.StaticCompletions` and `dotnet-suggest` each reference `System.CommandLine` only.
- `StaticCompletions` and `Suggest` are parallel, independent approaches sharing no code.
- No circular dependencies.

**Parse → Invoke data flow** (verified in `CommandLineParser.cs`, `InvocationPipeline.cs`, `ParseResult.cs`):
1. `CommandLineParser.Parse(command, args)` tokenizes input and runs `ParseOperation`.
2. `ParseOperation` walks the symbol tree and builds a `ParseResult` containing a `CommandResult` tree, matched `Action`, optional `PreActions`, errors, and unmatched tokens.
3. `parseResult.Invoke()` / `InvokeAsync()` calls `InvocationPipeline`, which runs pre-actions then the main action.

**AOT / Trim** (verified in `System.CommandLine.csproj` and `System.CommandLine.StaticCompletions.csproj`): Both the core library and `StaticCompletions` are `IsAotCompatible=true` and `IsTrimmable=true` for the `$(NetMinimum)` target. Trim-safety is a non-obvious constraint in `Binding/ArgumentConverter.cs` which converts string tokens to arbitrary .NET types.

**C# 14 extension blocks** (verified in `src/System.CommandLine.StaticCompletions/DynamicSymbolExtensions.cs`): `StaticCompletions` uses the C# 14 `extension(T)` block syntax (not traditional `static class TExtensions`) to tag options/arguments as requiring dynamic runtime completions. Enabled by `LangVersion=latest` in `Directory.Build.props`.

## Where things go

| Task | Where | Example to imitate |
|------|-------|--------------------|
| Add a new built-in option (e.g. `--version`) | `src/System.CommandLine/` as a standalone file | `src/System.CommandLine/VersionOption.cs` |
| Add a new directive (e.g. `[debug]`) | `src/System.CommandLine/` + register in `ParseOperation` | `src/System.CommandLine/ParseDiagramDirective.cs` |
| Add a new argument type converter | `src/System.CommandLine/Binding/ArgumentConverter.StringConverters.cs` | Existing converters in same file |
| Add a new shell provider for static completions | `src/System.CommandLine.StaticCompletions/shells/` implementing `IShellProvider` | `src/System.CommandLine.StaticCompletions/shells/BashShellProvider.cs` |
| Add a test for parsing behavior | `src/System.CommandLine.Tests/Parsing/` | `src/System.CommandLine.Tests/ParserTests.cs` |
| Add a test for help output | `src/System.CommandLine.Tests/Help/HelpBuilderTests.cs` | Same file (ApprovalTests pattern — `Approvals.Verify`) |
| Add a test for static completion output | `src/System.CommandLine.StaticCompletions.Tests/` | Existing provider test (Verify.Xunit snapshot pattern — `.verified.{ext}`) |
| Add a test for invocation | `src/System.CommandLine.Tests/Invocation/` | `src/System.CommandLine.Tests/TestActions.cs` for stubs |
| Change a public API (check backward compat) | Modify core, then update API snapshot | `src/System.CommandLine.ApiCompatibility.Tests/ApiCompatibilityApprovalTests.cs` |
| Bump a NuGet dependency version | `eng/Versions.props` + `eng/Version.Details.xml` | Existing entries in those files |

## Conventions observed

- **Symbol naming**: option names use kebab-case (e.g. `--output-path`); class names follow standard .NET PascalCase. Source: `src/System.CommandLine/Option.cs`.
- **Nullable reference types**: `#nullable enable` / `<Nullable>enable</Nullable>` throughout all library code. Source: `src/System.CommandLine/System.CommandLine.csproj:6`.
- **Warnings as errors**: `<TreatWarningsAsErrors>true</TreatWarningsAsErrors>` globally. Source: `Directory.Build.props:9`.
- **C# 14 enabled**: `<LangVersion>latest</LangVersion>` globally — `extension` blocks and other preview features are in use. Source: `Directory.Build.props:8`.
- **No DI container**: configuration is passed explicitly via `ParserConfiguration` and `InvocationConfiguration`; no service locator. Source: `src/System.CommandLine/InvocationConfiguration.cs`.
- **Sync/async action pairs**: every public API that invokes an action has both `Invoke()` and `InvokeAsync()` overloads. Source: `src/System.CommandLine/Invocation/InvocationPipeline.cs`.
- **Internal partial classes for large types**: `HelpBuilder`, `ArgumentConverter`, and `ParserTests` are all split across multiple `partial` files by concern. Source: `src/System.CommandLine/Help/HelpBuilder.Default.cs`.
- **`internal sealed` for parsing internals**: `ParseOperation`, `InvocationPipeline`, `SymbolResultTree` are all `internal sealed`. Source: `src/System.CommandLine/Parsing/ParseOperation.cs`.
- **Error accumulation, not exceptions**: parse errors go into `List<ParseError>` on the `ParseResult`; invocation returns `int` exit codes.
- **Two snapshot frameworks in use**: `ApprovalTests` (with `.approved.txt` files) for Help output tests; `Verify.Xunit` + `Verify.DiffPlex` (with `.verified.{ext}` files) for StaticCompletions shell output tests. Do not mix them.
- **`AwesomeAssertions`**: the NuGet package is `AwesomeAssertions` (a FluentAssertions fork), but the `using FluentAssertions` namespace is identical — standard FluentAssertions is NOT the package in use. Source: `src/System.CommandLine.Tests/System.CommandLine.Tests.csproj`.
- **Release-only expensive tests**: `[ReleaseBuildOnlyFact/Theory]` gates NativeAOT/trim `dotnet publish` tests. Source: `src/System.CommandLine.Tests/CompilationTests.cs`.
- **Localization**: user-facing strings go through `LocalizationResources` (backed by `.resx`), not raw string literals. Source: `src/System.CommandLine/LocalizationResources.cs`.
- **Polyfill shims inline**: downlevel BCL types (`IsExternalInit`, `Range`, `DynamicallyAccessedMembersAttribute`) are included as source files under their original namespaces rather than taking a package dependency. Source: `src/System.CommandLine/System.Runtime.CompilerServices/`.

## Open questions

- `$(NetMinimum)` is injected by the Arcade SDK, not defined in any local `.props` file. Confirmed: `$(NetFrameworkMinimum)=net472`. `$(NetMinimum)` is likely `net10.0` based on Arcade SDK version 11.0.0-beta, but verify before relying on it.
- CI pipeline YAML was not found under `.azuredevops/` (only `dependabot.yml` is there); the actual build pipeline likely lives in the Azure DevOps project configuration or `eng/common/core-templates/`. Confirm the pipeline name before adding new CI steps.
- `src/System.CommandLine.Benchmarks/` uses `Microsoft.CodeAnalysis.CSharp.Scripting` to compile `Sample1.Main.cs` at benchmark runtime — the purpose and design of this benchmark were not verified in detail. Check before adding new benchmarks.
- `DynamicSymbolExtensions.cs` uses C# 14 `extension` block syntax — confirm this compiles on the minimum CI SDK version if the project needs to build on SDK versions older than the one that stabilized this feature.
