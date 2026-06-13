#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage: ./scripts/link-skills.sh --claude | --codex

  --claude  Link skills into ~/.claude/skills
  --codex   Link skills into ~/.agents/skills
EOF
}

if [ "$#" -ne 1 ]; then
  usage
  exit 2
fi

case "$1" in
  --claude)
    HARNESS="claude"
    DEST="$HOME/.claude/skills"
    ;;
  --codex)
    HARNESS="codex"
    DEST="$HOME/.agents/skills"
    ;;
  *)
    usage
    exit 2
    ;;
esac

REPO="$(cd "$(dirname "$0")/.." && pwd)"

# A destination symlink into this repo would write the per-skill links back
# into the working copy.
if [ -L "$DEST" ]; then
  resolved="$(readlink -m -- "$DEST" || true)"
  case "$resolved" in
    "$REPO"|"$REPO"/*)
      echo "[$HARNESS] error: $DEST is a symlink into this repo ($resolved)." >&2
      echo "[$HARNESS] remove it and re-run; the installer will recreate it as a real directory." >&2
      exit 1
      ;;
  esac
fi

mkdir -p "$DEST"

declare -a skill_names=()
declare -a skill_sources=()
declare -A expected_targets=()
declare -A skipped_targets=()
declare -a collisions=()

while IFS= read -r -d '' skill_md; do
  src="$(dirname "$skill_md")"
  name="$(basename "$src")"
  target="$DEST/$name"

  skill_names+=("$name")
  skill_sources+=("$src")
  expected_targets["$target"]="$src"

  if [ -e "$target" ] && [ ! -L "$target" ]; then
    collisions+=("$target")
  fi
done < <(find "$REPO/skills" -name SKILL.md \
  -not -path '*/node_modules/*' \
  -not -path '*/deprecated/*' \
  -print0 | sort -z)

if [ "${#collisions[@]}" -gt 0 ] && [ ! -t 0 ]; then
  for target in "${collisions[@]}"; do
    echo "[$HARNESS] collision: leaving $target" >&2
  done
  echo "[$HARNESS] error: resolve collisions interactively or remove them before retrying." >&2
  exit 1
fi

for target in "${collisions[@]}"; do
  reply=""
  read -r -p "[$HARNESS] collision: replace $target? [y/N] " reply || true
  case "$reply" in
    y|Y|yes|YES|Yes)
      rm -rf -- "$target"
      echo "[$HARNESS] replaced collision: $target"
      ;;
    *)
      skipped_targets["$target"]=1
      echo "[$HARNESS] left collision: $target"
      ;;
  esac
done

while IFS= read -r -d '' link; do
  resolved="$(readlink -m -- "$link" || true)"
  case "$resolved" in
    "$REPO"|"$REPO"/*)
      if [ "${expected_targets["$link"]-}" != "$resolved" ]; then
        rm -- "$link"
        echo "[$HARNESS] pruned stale link: $link -> $resolved"
      fi
      ;;
  esac
done < <(find "$DEST" -mindepth 1 -maxdepth 1 -type l -print0)

for index in "${!skill_names[@]}"; do
  name="${skill_names[$index]}"
  src="${skill_sources[$index]}"
  target="$DEST/$name"

  if [ -n "${skipped_targets["$target"]-}" ]; then
    continue
  fi

  ln -sfn -- "$src" "$target"
  echo "[$HARNESS] linked: $name -> $src"
done
