# What to look for

Signals that reveal structure, in priority order. Read these first; skip bulk source code until the shape is clear.

## 1. Manifests and lockfiles

`package.json`, `pyproject.toml`, `go.mod`, `*.sln`/`*.csproj`, `pom.xml`, `build.gradle`, `Cargo.toml`, `Gemfile`. They give you the project's name, its dependencies (what kind of system this is), and its scripts — the executable truth about how it builds and tests.

## 2. Entry points

Where execution starts tells you what the system *is*: a service, a CLI, a library, several of these. One repo can have many entry points — find them all before characterizing the repo.

## 3. Layering and boundaries

- Folder names that hint at layers: `api`/`web`, `domain`/`core`, `infra`/`adapters`, `shared`.
- Hard evidence beats names: project references (`.csproj` `ProjectReference`, `tsconfig` paths, Go import paths), and the **direction of imports** — layering is whatever direction the imports actually flow, not what the README claims.

## 4. Configuration and wiring

DI registration (`Program.cs`/`Startup`, module definitions, providers), environment/config files, feature flags. The wiring file is often the single best map of what talks to what.

## 5. Test layout

Where tests live, their naming pattern, shared fixtures/helpers, and which config file runs them. This feeds the map's Build/run/test table and later labs depend on it being right.

## 6. CI pipelines

`.github/workflows/`, `.gitlab-ci.yml`, `Jenkinsfile`. The commands CI runs are the repo's *real* build and test commands — prefer them over guesses and over the README.

## 7. Codegen and migrations

`.proto`, OpenAPI/schema files, `migrations/`, files with "generated" headers. Find the generator and the source of truth; the generated output is not architecture.

## Per-ecosystem hints

| Ecosystem | Entry points | Tests | Real commands live in |
|-----------|--------------|-------|-----------------------|
| JS/TS | `package.json` `main`/`bin`, `src/index.*`, framework dirs (`app/`, `pages/`) | `*.test.*`, `*.spec.*`, `__tests__/` | `package.json` scripts |
| Python | `__main__.py`, `manage.py`, `[project.scripts]` in pyproject, `app.py` | `tests/test_*.py`, `conftest.py` | pyproject / `tox.ini` / Makefile |
| .NET | `Program.cs`, the `.sln` project graph | `*Tests` projects | `.sln` + CI yaml |
| JVM | classes with `main()`, `application.yml` | `src/test/java` | `pom.xml` / `build.gradle` |
| Go | `cmd/<name>/main.go` | `*_test.go` beside the code | Makefile / CI yaml |
| Rust | `src/main.rs`, `src/lib.rs`, `[[bin]]` entries | `#[cfg(test)]` + `tests/` | `Cargo.toml` |

## Anti-signals

- **README claims** — verify against manifests and CI before repeating them; READMEs rot.
- **Directory names alone** (`utils`, `core`, `common`) — open two or three files before characterizing what a directory is for.
- **File counts** — the biggest directory is often generated code or tests, not the heart of the system.
