#!/usr/bin/env bash
# scan_repo.sh — read-only overview of the current repository.
# Part of the repo-map skill. Run from the repository root:
#   bash scan_repo.sh [depth]     (depth of the directory tree, default 3)
set -eu

DEPTH="${1:-3}"
case "$DEPTH" in
  ''|*[!0-9]*) echo "error: depth must be a number, got '$DEPTH'" >&2; exit 2 ;;
esac

if [ ! -e .git ]; then
  echo "⚠️  No .git found here — run this from the repository root." >&2
fi

# Dependency caches and build output are never architecture — prune them.
EXCL="-name .git -o -name node_modules -o -name vendor -o -name dist \
  -o -name build -o -name out -o -name bin -o -name obj -o -name target \
  -o -name __pycache__ -o -name .venv -o -name venv -o -name .next \
  -o -name .terraform -o -name coverage -o -name .idea -o -name .vs"

tree_dirs()  { eval "find . -maxdepth $DEPTH \( $EXCL \) -prune -o -type d -print" 2>/dev/null; }
list_files() { eval "find . \( $EXCL \) -prune -o -type f -print" 2>/dev/null; }

echo "== Repository =="
echo "root:        $(pwd)"
echo "base branch: $(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null \
  || echo 'unknown — no origin/HEAD; ask a human')"
echo

echo "== Directory tree (depth $DEPTH, junk pruned) =="
tree_dirs | sort | sed -e 's|^\./||' -e 's|^\.$|.|' -e 's|[^/]*/|  |g'
echo

echo "== Files =="
total=$(list_files | wc -l | tr -d ' ')
echo "total (excluding pruned dirs): $total"
echo
echo "by extension (top 15):"
list_files | sed 's|.*/||' | grep -F . | sed 's|.*\.||' \
  | tr '[:upper:]' '[:lower:]' | sort | uniq -c | sort -rn | head -15 || true
echo

echo "== 10 largest files (KB) =="
list_files | tr '\n' '\0' | xargs -0 du -k 2>/dev/null | sort -rn | head -10 || true
echo

echo "== Manifests & signals detected =="
found=0
for f in package.json pnpm-workspace.yaml lerna.json tsconfig.json \
         pyproject.toml setup.py requirements.txt go.mod Cargo.toml Gemfile \
         pom.xml build.gradle build.gradle.kts mix.exs Makefile Dockerfile \
         docker-compose.yml .github/workflows .gitlab-ci.yml Jenkinsfile; do
  if [ -e "$f" ]; then
    echo "  ✓ $f"
    found=1
  fi
done
for f in ./*.sln; do
  if [ -e "$f" ]; then
    echo "  ✓ ${f#./}"
    found=1
  fi
done
if [ "$found" -eq 0 ]; then
  echo "  (none of the usual suspects — see references/what-to-look-for.md)"
fi
