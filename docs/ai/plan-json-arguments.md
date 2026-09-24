# Plan — json-arguments

**Repo**: command-line-api (System.CommandLine) · **Base branch**: main · **Date**: 2026-09-23 · **Status**: draft

## Feature

Add opt-in support for passing command-line arguments as a JSON object string. When `ParserConfiguration.EnableJsonArguments` is `true` and a single argument is detected that starts with `{`, the library deserializes it and synthesizes an equivalent token stream before the existing tokenization/parse pipeline runs — no downstream changes required.

## Out of scope

- Nested JSON objects mapping to subcommand trees
- JSON schema validation or schema generation
- Tab-completion for JSON-mode invocations
- Making JSON mode always-on (it is opt-in via `ParserConfiguration`)
- NativeAOT source-generated `JsonSerializerContext` (not needed — implementation uses `JsonDocument`, which is a DOM reader and AOT-safe without source generation)

## Current state

**Parse entry points** (`src/System.CommandLine/Parsing/CommandLineParser.cs`):
- Public `Parse(Command, IReadOnlyList<string>, ParserConfiguration?)` at line 21 → delegates to private `Parse` at line 138.
- Public `Parse(Command, string, ParserConfiguration?)` at line 32 → splits via `SplitCommandLine()`, then calls the same private overload.
- Private `Parse` (line 138): null-checks `arguments`, materialises `configuration`, calls `arguments.Tokenize(...)` at line 151 to produce `List<Token>`, then constructs `ParseOperation` at line 158 with the finished token list.

**Parser configuration** (`src/System.CommandLine/ParserConfiguration.cs`):
- `public class ParserConfiguration` (line 11) currently exposes `EnablePosixBundling` and `ResponseFileTokenReplacer`. Adding `EnableJsonArguments` here follows the existing opt-in pattern.

**Tokenization seam** (verified): there is a clean two-pass design — `Tokenize` runs first (line 151), `ParseOperation` receives the already-built `List<Token>` (line 158). Replacing `arguments` before `Tokenize` is the correct insertion point.

**JSON dependency**: `System.Text.Json` is not present anywhere in the core library. The project targets `$(NetMinimum);netstandard2.0`. On `$(NetMinimum)` (net10.0) it is inbox; for `netstandard2.0` a `PackageReference` is required. The repo uses central package management (`Directory.Packages.props:4` — `ManagePackageVersionsCentrally=true`), so the version must be declared there.

## Steps

| # | Files | Change | Verify by |
|---|-------|--------|-----------|
| 1 | `src/System.CommandLine/ParserConfiguration.cs` | Add `public bool EnableJsonArguments { get; set; } = false;` after the `ResponseFileTokenReplacer` property (line 42). Include XML doc comment following the existing style. | `dotnet build src/System.CommandLine` — no warnings or errors |
| 2 | `Directory.Packages.props` | Add `<PackageVersion Include="System.Text.Json" Version="9.0.0" />` [ASSUMPTION — confirm] to the `<ItemGroup>` at line 10. | `dotnet build src/System.CommandLine` — package restores on both TFMs |
| 3 | `src/System.CommandLine/System.CommandLine.csproj` | Add a new `<ItemGroup Condition="'$(TargetFramework)' == 'netstandard2.0'">` block containing `<PackageReference Include="System.Text.Json" />` (no version — sourced from central management). | `dotnet build src/System.CommandLine -f netstandard2.0` succeeds |
| 4 | `src/System.CommandLine/Parsing/JsonArgumentPreprocessor.cs` *(new file)* | Create `internal static class JsonArgumentPreprocessor` with a single method: `internal static bool TryExpand(string jsonString, [NotNullWhen(true)] out IReadOnlyList<string>? expanded, [NotNullWhen(false)] out string? error)`. Use `JsonDocument.Parse(jsonString)` inside a `try/catch (JsonException)`; verify `RootElement.ValueKind == JsonValueKind.Object`; iterate `RootElement.EnumerateObject()` and build a `List<string>` of tokens using the expansion rules below. Dispose `JsonDocument` via `using`. Token expansion rules: (a) key: if the JSON property name does not start with `-`, prepend `--`; otherwise use as-is; (b) string/number/other scalar → emit `[key, value.ToString()]`; (c) `JsonValueKind.True` → emit `[key]` only (boolean flag); (d) `JsonValueKind.False` or `Null` → skip; (e) `JsonValueKind.Array` → emit `[key, elem1, elem2, ...]` for each array element. | `dotnet build src/System.CommandLine` — no warnings or errors |
| 5 | `src/System.CommandLine/Parsing/CommandLineParser.cs` | In private `Parse` (line 138), after the null-check block (line 144–147) and before `arguments.Tokenize(...)` (line 151), add JSON pre-processing: declare `string? jsonExpandError = null;`; check `configuration.EnableJsonArguments && arguments.Count == 1 && arguments[0].TrimStart() is { Length: > 0 } t && t[0] == '{'`; if true, call `JsonArgumentPreprocessor.TryExpand(arguments[0], out var jsonArgs, out jsonExpandError)` and, on success, replace `arguments = jsonArgs`. After the `Tokenize` call (line 156), if `jsonExpandError is not null`, initialize or append to `tokenizationErrors`. | `dotnet test src/System.CommandLine.Tests` — all pre-existing tests pass |
| 6 | `src/System.CommandLine.ApiCompatibility.Tests/` *(approval snapshot)* | Re-run the API compatibility test after step 1 to regenerate the approved snapshot that now includes `bool EnableJsonArguments`. Run `dotnet test src/System.CommandLine.ApiCompatibility.Tests` once to observe the diff, then accept the new API surface using the ApprovalTests mechanism (rename `.received.txt` to `.approved.txt`, or use the configured reporter). | `dotnet test src/System.CommandLine.ApiCompatibility.Tests` — green |
| 7 | `src/System.CommandLine.Tests/ParserTests.JsonArguments.cs` *(new file)* | Add `public partial class ParserTests` (matching the existing partial class) with a nested class `JsonArguments` containing the tests described in the Test plan below. | `dotnet test src/System.CommandLine.Tests --filter "FullyQualifiedName~JsonArguments"` — all pass |

## Test plan

| Behavior to prove | Kind | Where it lives |
|-------------------|------|----------------|
| Valid JSON object with string value binds to the correct option | unit | `ParserTests.JsonArguments` |
| Valid JSON object with numeric value binds as a string token | unit | `ParserTests.JsonArguments` |
| JSON key without `--` prefix gets `--` added automatically | unit | `ParserTests.JsonArguments` |
| JSON key already starting with `--` is used as-is | unit | `ParserTests.JsonArguments` |
| `true` boolean value emits only the flag token (no value) | unit | `ParserTests.JsonArguments` |
| `false` boolean value causes the flag to be absent | unit | `ParserTests.JsonArguments` |
| `null` value causes the option to be absent | unit | `ParserTests.JsonArguments` |
| Array value emits the key followed by each element as separate tokens | unit | `ParserTests.JsonArguments` |
| Empty JSON object `{}` produces no option tokens and no errors | unit | `ParserTests.JsonArguments` |
| `EnableJsonArguments = false` (default) ignores a single arg that starts with `{` | unit | `ParserTests.JsonArguments` |
| Multiple args with `EnableJsonArguments = true` parse normally (no JSON mode fired) | unit | `ParserTests.JsonArguments` |
| Malformed JSON with `EnableJsonArguments = true` produces a `ParseError`, not an exception | unit | `ParserTests.JsonArguments` |
| A single valid JSON arg that is not an object (e.g. `[]`) produces a `ParseError` | unit | `ParserTests.JsonArguments` |

## Risks & unknowns

- **`System.Text.Json` version** [ASSUMPTION — confirm]: `9.0.0` was chosen because it supports `netstandard2.0` and aligns with recent .NET releases, but the repo does not currently declare this package anywhere. Confirm the correct version matches what the rest of the .NET 10 toolchain expects before merging.
- **Token expansion for non-flat JSON**: the plan expands only flat key-value pairs. A nested JSON object as a property value (e.g. `{"address": {"city": "NYC"}}`) will call `.ToString()` and produce a raw JSON string token — which the parser will almost certainly reject with an error. This is intentional given the out-of-scope decision above, but the error message may be confusing.
- **Single-arg detection heuristic**: the trigger (`args.Count == 1 && trimmed[0] == '{'`) combined with `EnableJsonArguments = true` is still a heuristic. If an application legitimately passes a single positional argument beginning with `{` and enables this flag, it will be misinterpreted. This is the trade-off of the opt-in design.

## Open questions

- Confirm the exact `System.Text.Json` version to add to `Directory.Packages.props`. Check against `global.json` / `eng/Versions.props` once SDK toolchain pins are settled.

## Rollback strategy

All changes are purely additive: one new property (default `false`), one new internal class, one new test file, and a new package dependency. No existing call sites are modified. To roll back: revert the 5 modified/created source files (`ParserConfiguration.cs`, `CommandLineParser.cs`, `JsonArgumentPreprocessor.cs`, `System.CommandLine.csproj`, `Directory.Packages.props`) and the 2 test files (`ParserTests.JsonArguments.cs`, API snapshot). Because the feature defaults to off, a partial rollback (removing only the test file and reverting `ParserConfiguration.cs` and `CommandLineParser.cs`) also leaves the codebase in a safe state.

## Deviation log

<!-- Written during implementation, never during planning. One entry per divergence:
- <date> · Step N — expected: X · found: Y · amendment: Z · approved by: <who> -->
