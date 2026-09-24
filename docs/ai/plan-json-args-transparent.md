# Plan — json-args-transparent

**Repo**: command-line-api (System.CommandLine) · **Base branch**: main · **Date**: 2026-09-24 · **Status**: draft

## Feature

When a CLI application built on System.CommandLine is invoked with a single argument that is a valid JSON object string (e.g. `myapp '{"output":"./bin","verbose":true}'`), the library automatically deserializes that object and synthesizes the equivalent token stream before normal parsing runs. No configuration required; detection is transparent and falls back gracefully on invalid JSON.

## Out of scope

- Nested JSON objects as property values (no subcommand routing; nested objects are passed through as raw strings and will surface a parse error naturally)
- Tab-completion (`dotnet-suggest` / `StaticCompletions`) for JSON input mode
- Help output or documentation changes
- Positional `Argument<T>` values via JSON (only `Option<T>` and `Option<T[]>` are targeted)
- Response file (`@file`) integration with JSON
- Making JSON mode opt-in via `ParserConfiguration` (transparent always-on was confirmed)
- API surface change (no new public properties → no `ApiCompatibility.Tests` snapshot update needed)

## Current state

Raw CLI args arrive at `CommandLineParser.Parse(Command, IReadOnlyList<string>, ParserConfiguration?)` (`src/System.CommandLine/Parsing/CommandLineParser.cs:21`). The private overload at line 138 null-checks `arguments` (lines 144–147), materialises `configuration` (line 149), then calls `arguments.Tokenize(command, configuration, ...)` at line 151 — an extension in `src/System.CommandLine/Parsing/StringExtensions.cs`. The resulting `List<Token>` is passed to `new ParseOperation(...)` at line 158. There is no JSON-awareness anywhere in this path today.

`System.Text.Json` is not currently a dependency (`Directory.Packages.props` — no `System.Text.Json` entry; `src/System.CommandLine/System.CommandLine.csproj` — no reference). The project targets `$(NetMinimum);netstandard2.0` (line 4 of the `.csproj`). On `$(NetMinimum)` (net10.0) `System.Text.Json` is in-box; for `netstandard2.0` a NuGet `PackageReference` is required. A pattern for TFM-conditional package references already exists (lines 27–29 of the `.csproj`, where `System.Memory` is conditionally referenced for `netstandard2.0` only). Package versions are centralised in `Directory.Packages.props` at the repo root.

## Steps

| # | Files | Change | Verify by |
|---|-------|--------|-----------|
| 1 | `Directory.Packages.props` | Add `<PackageVersion Include="System.Text.Json" Version="9.0.0" />` [ASSUMPTION — confirm] to the `<ItemGroup>` at line 10, following the `System.Memory` entry style. | `dotnet restore src/System.CommandLine` — no NU1101/NU1107 errors |
| 2 | `src/System.CommandLine/System.CommandLine.csproj` | Add `<PackageReference Include="System.Text.Json" />` inside a new `<ItemGroup Condition="'$(TargetFramework)' == 'netstandard2.0'">` block, matching the existing pattern at lines 27–29. The modern TFM does not need a reference. | `dotnet build src/System.CommandLine -f netstandard2.0` succeeds; `dotnet build src/System.CommandLine -f net10.0` succeeds |
| 3 | `src/System.CommandLine/Parsing/JsonArgumentPreprocessor.cs` *(new file)* | Create `internal static class JsonArgumentPreprocessor` in namespace `System.CommandLine.Parsing` with one method: `internal static bool TryExpand(IReadOnlyList<string> args, [NotNullWhen(true)] out IReadOnlyList<string>? expanded)`. Implementation: (a) return `false` immediately if `args.Count != 1`; (b) check `args[0].TrimStart()` starts with `{` — if not, return `false`; (c) attempt `JsonDocument.Parse(args[0])` inside `try/catch (JsonException)` — on exception set `expanded = null; return false;`; (d) verify `RootElement.ValueKind == JsonValueKind.Object` — if not, return `false`; (e) iterate `RootElement.EnumerateObject()` and build a `List<string>` using these rules: key does not start with `-` → prepend `--`; `JsonValueKind.String/Number` → emit `[key, value.GetRawText().Trim('"')]`; `JsonValueKind.True` → emit `[key]` only (flag); `JsonValueKind.False` or `Null` → skip; `JsonValueKind.Array` → emit `[key, elem1ToString, elem2ToString, ...]`; (f) dispose `JsonDocument` via `using`; (g) set `expanded = result.AsReadOnly()` and return `true`. Use `System.Diagnostics.CodeAnalysis.NotNullWhenAttribute` (already available via the linked polyfill at `src/System.Diagnostics.CodeAnalysis.cs` compiled into the project). | `dotnet build src/System.CommandLine` — no warnings or errors on either TFM |
| 4 | `src/System.CommandLine/Parsing/CommandLineParser.cs` | In the private `Parse` method (line 138), add a single guard immediately after line 149 (`configuration ??= new ParserConfiguration();`) and before the `arguments.Tokenize(...)` call at line 151: `if (JsonArgumentPreprocessor.TryExpand(arguments, out var jsonExpanded)) arguments = jsonExpanded;`. No other changes to this file. | `dotnet build src/System.CommandLine` — no warnings or errors; `dotnet test src/System.CommandLine.Tests` — all pre-existing tests pass |
| 5 | `src/System.CommandLine.Tests/ParserTests.JsonInput.cs` *(new file)* | Add `public partial class ParserTests` following the pattern of `src/System.CommandLine.Tests/ParserTests.DoubleDash.cs` (partial class, same namespace). Create a nested class `JsonInput` with tests listed in the Test plan below. Use `command.Parse(new[] { jsonString })` and AwesomeAssertions (`using AwesomeAssertions;`). | `dotnet test src/System.CommandLine.Tests --filter "FullyQualifiedName~JsonInput"` — all pass |

## Test plan

| Behavior to prove | Kind | Where it lives |
|-------------------|------|----------------|
| `{"output":"./bin"}` with `Option<string>("--output")` → `result.GetValue(output)` is `"./bin"` | unit | `ParserTests.JsonInput` |
| `{"verbose":true}` with `Option<bool>("--verbose")` → option is set (flag style, no value token needed) | unit | `ParserTests.JsonInput` |
| `{"verbose":false}` with `Option<bool>("--verbose")` → option is absent (retains default) | unit | `ParserTests.JsonInput` |
| `{"count":42}` with `Option<int>("--count")` → value is `42` | unit | `ParserTests.JsonInput` |
| `{"items":["a","b","c"]}` with `Option<string[]>("--items")` → all three values are bound | unit | `ParserTests.JsonInput` |
| JSON key already prefixed with `--` (e.g. `{"--output":"./bin"}`) → passed through without double-prepending | unit | `ParserTests.JsonInput` |
| `{"name":null}` → option is absent (same as not passing it) | unit | `ParserTests.JsonInput` |
| Empty object `{}` → no option tokens, `ParseResult.Errors` is empty | unit | `ParserTests.JsonInput` |
| Malformed JSON (single arg starting with `{` but not valid JSON) → `TryExpand` returns `false`; arg is passed to normal tokenization, resulting in an `UnrecognizedArgumentError` | unit | `ParserTests.JsonInput` |
| Non-JSON single arg (not starting with `{`) → JSON path not entered; parsed normally | unit | `ParserTests.JsonInput` |
| Multiple args where `args[0]` starts with `{` → JSON path not entered (`args.Count != 1`); normal parse proceeds | unit | `ParserTests.JsonInput` |
| Single JSON array arg `["a"]` → JSON path not entered (root is not an object); treated as a literal arg | unit | `ParserTests.JsonInput` |

## Risks & unknowns

- **AOT / trim safety**: `JsonDocument.Parse` is a DOM reader with no reflection and is explicitly trim-safe. This plan deliberately avoids `JsonSerializer.Deserialize<T>()` for that reason. After implementation, run `dotnet publish -c Release` against one of the existing AOT test apps (`src/System.CommandLine.Tests/TestApps/`) to confirm no trim warnings are introduced. `[ASSUMPTION — confirm]`
- **`System.Text.Json` version** [ASSUMPTION — confirm]: `9.0.0` supports `netstandard2.0` and aligns with recent .NET releases, but the repo does not currently declare this package. Verify the chosen version is compatible with the Arcade SDK's dependency graph before merging (check `eng/Versions.props` for any SDK-imposed constraints — the Arcade SDK may want a specific version).
- **Detection false positives**: The heuristic (`args.Count == 1 && args[0].TrimStart()` starts with `{`) will intercept any single positional argument that happens to begin with `{`. Malformed JSON falls back safely; valid JSON that is not an object also falls back. The only silent failure case is a valid JSON object string that was meant as a literal positional argument — this is the unavoidable cost of transparent auto-detection.
- **`GetRawText().Trim('"')` for string values**: using `GetRawText()` on a string `JsonElement` returns the JSON-encoded form (with quotes). `Trim('"')` removes surrounding quotes but will not handle escape sequences (e.g. `\"` inside the string). Use `GetString()` instead for `JsonValueKind.String`. This is a subtle correctness issue to catch in code review.

## Open questions

- Confirm the correct `System.Text.Json` NuGet version to add to `Directory.Packages.props`. Run `dotnet msbuild -getProperty:SystemTextJsonVersion` or check `eng/Versions.props` once the SDK pinning is clear.
- Should unmatched JSON keys (keys with no corresponding `Option` declared on the command) be surfaced as a dedicated error type rather than relying on the parser's generic `UnrecognizedArgumentError`? Depends on whether user-facing error messages matter for this feature.

## Rollback strategy

All changes are purely additive. No existing behaviour changes: the `TryExpand` guard only fires when `args.Count == 1` and the sole arg starts with `{`. To roll back: revert `CommandLineParser.cs` (one inserted `if` statement), delete `JsonArgumentPreprocessor.cs`, delete `ParserTests.JsonInput.cs`, revert the `PackageReference` line in `System.CommandLine.csproj`, and remove the `System.Text.Json` version entry from `Directory.Packages.props`. A partial rollback (reverting `CommandLineParser.cs` alone) is sufficient to fully disable the feature while leaving the other files in place.

## Deviation log

<!-- Written during implementation, never during planning. One entry per divergence:
- <date> · Step N — expected: X · found: Y · amendment: Z · approved by: <who> -->
