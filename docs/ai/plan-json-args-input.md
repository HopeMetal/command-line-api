# Plan — json-args-input

**Repo**: command-line-api · **Base branch**: main · **Date**: 2026-09-23 · **Status**: draft

## Feature

Users can pass a single JSON object string as the sole argument to a CLI application (e.g. `myapp '{"output":"./bin","verbose":true}'`). The parser deserializes that object and populates the command's declared options and arguments from the JSON properties, as if the equivalent flags had been passed on the command line.

## Out of scope

- Subcommand routing via JSON (e.g. `{"subcommand": {...}}` does not dispatch to a subcommand)
- Tab-completion (`dotnet-suggest` / `StaticCompletions`) for JSON input mode
- Help output changes
- Response file (`@file`) integration
- JSON arrays as positional `Argument<T>` values (only `Option<T[]>` with repeated tokens is supported)

## Current state

Raw CLI args arrive at `CommandLineParser.Parse(Command, IReadOnlyList<string>, ParserConfiguration?)` (`src/System.CommandLine/Parsing/CommandLineParser.cs:21`). The private overload at line 138 calls `arguments.Tokenize(command, configuration, ...)` at line 151 (an internal extension in `src/System.CommandLine/Parsing/StringExtensions.cs`), then hands the resulting `List<Token>` to `new ParseOperation(...)`. There is no JSON-awareness anywhere in this path. `System.Text.Json` is not currently a dependency; the only third-party dependency on `netstandard2.0` is `System.Memory` (`src/System.CommandLine/System.CommandLine.csproj:27-29`).

## Steps

| # | Files | Change | Verify by |
|---|-------|--------|-----------|
| 1 | `src/System.CommandLine/Parsing/JsonArgsPreprocessor.cs` (new) | Add `internal static class JsonArgsPreprocessor` with one method: `TryExpand(IReadOnlyList<string> args, Command command, [NotNullWhen(true)] out string[]? expanded)`. **Detection**: return `false` if `args.Count != 1` or `args[0].TrimStart()` does not start with `{`. **Deserialization**: use `System.Text.Json` with a `[JsonSerializable(typeof(Dictionary<string, JsonElement>))]` source-gen context (required for AOT/trim safety; declare `internal partial class JsonArgsSerializerContext : JsonSerializerContext` in the same file). **Mapping**: for each JSON property key, search `command.Options` — strip leading `-` and `/` chars from `option.Name` and each string in `option.Aliases` (`Option.Aliases`, public at `src/System.CommandLine/Option.cs:125`) and compare case-insensitively; fall back to matching `command.Arguments` by `argument.Name`. Emit the matched symbol's own `.Name` as the first synthetic token (preserving its declared prefix). Emit value tokens by JSON type: string/number → single value token; boolean `true` → no value token (flag-style); boolean `false` → omit the token entirely; array → repeat `[symbolName, element.ToString()]` per element. If any key is unmatched, return `false` so the caller falls through to normal tokenization and the parser surfaces the error naturally. | `dotnet build src/System.CommandLine` — zero warnings, zero errors |
| 2 | `src/System.CommandLine/System.CommandLine.csproj` | Add `<PackageReference Include="System.Text.Json" />` inside the existing `Condition="'$(TargetFramework)' == 'netstandard2.0'"` `<ItemGroup>` (line 27). Add the version entry to `eng/Versions.props` following the existing `<PackageVersion>` pattern used for `System.Memory`. The modern TFM (`$(NetMinimum)`) already has `System.Text.Json` in-box; no reference needed there. | `dotnet build src/System.CommandLine` targeting both TFMs (`-f net10.0` and `-f netstandard2.0`) — zero warnings, zero errors |
| 3 | `src/System.CommandLine/Parsing/CommandLineParser.cs` | In the private `Parse` method (line 138), immediately before `arguments.Tokenize(...)` at line 151, add: `if (JsonArgsPreprocessor.TryExpand(arguments, command, out var expanded)) arguments = expanded;` No other changes to this file. | `dotnet build src/System.CommandLine` — zero warnings, zero errors |
| 4 | `src/System.CommandLine.Tests/ParserTests.JsonInput.cs` (new) | Add `public partial class ParserTests` following the pattern of `src/System.CommandLine.Tests/ParserTests.DoubleDash.cs`. Use `command.Parse(new[] { jsonString })` and FluentAssertions (AwesomeAssertions — package name differs from namespace; `using FluentAssertions;` is correct). Cover the behaviors listed in the Test plan below. | `dotnet test src/System.CommandLine.Tests --filter "FullyQualifiedName~ParserTests"` — all new tests pass, no regressions in existing tests |

## Test plan

| Behavior to prove | Kind | Where it lives |
|---|---|---|
| `{"--output":"./bin"}` with `Option<string>("--output")` → option value is `"./bin"` | unit | `ParserTests.JsonInput.cs` |
| JSON key matching an alias (not primary name) of an option resolves to that option's value | unit | `ParserTests.JsonInput.cs` |
| `{"verbose":true}` with `Option<bool>("--verbose")` → flag is set, no extra value token required | unit | `ParserTests.JsonInput.cs` |
| `{"verbose":false}` with `Option<bool>("--verbose")` → option remains at its default value | unit | `ParserTests.JsonInput.cs` |
| `{"items":["a","b"]}` with `Option<string[]>("--items")` → both values are bound | unit | `ParserTests.JsonInput.cs` |
| Malformed JSON as sole arg → `TryExpand` returns `false`; parse result contains an `UnrecognizedArgumentError` | unit | `ParserTests.JsonInput.cs` |
| Non-JSON single arg (not starting with `{`) → parsed normally, JSON path not entered | unit | `ParserTests.JsonInput.cs` |
| Multiple args where `args[0]` starts with `{` → JSON path not entered; normal parse proceeds | unit | `ParserTests.JsonInput.cs` |

## Risks & unknowns

- **AOT correctness**: The library is `IsAotCompatible=true` on the modern TFM (`System.CommandLine.csproj:17`). Reflection-based `JsonSerializer.Deserialize<T>()` is not trim-safe; the `[JsonSerializable]` source-gen context in Step 1 is mandatory. After implementation, verify with `dotnet publish -c Release` on one of the existing TestApps in `src/System.CommandLine.Tests/TestApps/` that the AOT/trim build still succeeds. `[ASSUMPTION — confirm]`: `[JsonSerializable]` source generation on `netstandard2.0` via the NuGet package behaves identically to the in-box version on the modern TFM.
- **`System.Text.Json` version compatibility**: All NuGet versions are governed by `eng/Versions.props`. The minimum version that supports source generation is 6.0. Confirm the chosen version is compatible with the Arcade SDK dependency graph before pinning. `[ASSUMPTION — confirm]`
- **JSON detection false positives**: The heuristic `args.Count == 1 && args[0].TrimStart().StartsWith('{')` will intercept any single positional argument that begins with `{`. If any existing command in the consuming application legitimately accepts such a positional argument today, this change silently redirects it. Audit known consumers before shipping. `[ASSUMPTION — confirm]`

## Open questions

- Is adding `System.Text.Json` as a NuGet dependency to the core library acceptable? It would be the only new external dependency beyond `System.Memory`.
- Should unmatched JSON keys produce explicit entries in `ParseResult.Errors` rather than silently falling through to normal parse?

## Deviation log

<!-- Written during implementation, never during planning. One entry per divergence:
- <date> · Step N — expected: X · found: Y · amendment: Z · approved by: <who> -->
