#!/usr/bin/env bash
# block-lockfile-edits.sh
# Blocks Claude from editing package manager lockfiles.
# These files are auto-generated and should only be modified by their respective package managers.

set -euo pipefail

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

if [[ -z "$FILE_PATH" ]]; then
  exit 0
fi

BASENAME=$(basename "$FILE_PATH")

LOCKFILES=(
  # JavaScript / Node
  "package-lock.json"
  "pnpm-lock.yaml"
  "yarn.lock"
  "bun.lockb"
  "bun.lock"
  "shrinkwrap.json"
  "npm-shrinkwrap.json"
  # Ruby
  "Gemfile.lock"
  # Rust
  "Cargo.lock"
  # Go
  "go.sum"
  # Python
  "Pipfile.lock"
  "poetry.lock"
  "uv.lock"
  "pdm.lock"
  # PHP
  "composer.lock"
  # Elixir
  "mix.lock"
  # Swift / iOS
  "Podfile.lock"
  "Package.resolved"
  # Dart / Flutter
  "pubspec.lock"
  # .NET
  "packages.lock.json"
  # Gradle (JVM)
  "gradle.lockfile"
  # Zig
  "build.zig.zon.lock"
)

for lockfile in "${LOCKFILES[@]}"; do
  if [[ "$BASENAME" == "$lockfile" ]]; then
    echo "Blocked: '$FILE_PATH' is a package manager lockfile. Lockfiles are auto-generated and must not be edited directly. Run the appropriate package manager command instead." >&2
    exit 2
  fi
done

GENERATED_FILES=(
  # Rails schema
  "schema.rb"
  "structure.sql"
)

for generated in "${GENERATED_FILES[@]}"; do
  if [[ "$BASENAME" == "$generated" ]]; then
    echo "Blocked: '$FILE_PATH' is an auto-generated file and must not be edited directly. Run the generator (e.g. a migration) instead." >&2
    exit 2
  fi
done

exit 0
