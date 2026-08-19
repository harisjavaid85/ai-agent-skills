#!/usr/bin/env bash
set -euo pipefail

# NOTE: This is a dev-only script, intended for use by maintainers of this repo.
# It is not a supported installer.
#
# Links all skills in the repository into the local skill directories used by
# each agent harness:
#   - ~/.claude/skills: Claude Code
#   - ~/.agents/skills: Codex and other Agent Skills-compatible harnesses
# Each entry is a symlink into this repo, so a `git pull` is all that's needed
# to keep installed skills up to date.

REPO="$(cd "$(dirname "$0")/.." && pwd)"
DESTS=("$HOME/.claude/skills" "$HOME/.agents/skills")

if [ "$#" -ne 0 ]; then
  echo "Usage: ./scripts/link-skills.sh" >&2
  echo "Links every skill into both ~/.claude/skills and ~/.agents/skills (takes no arguments)." >&2
  exit 2
fi

# Collect the repo's skills once, link into every destination.
names=()
srcs=()
while IFS= read -r -d '' skill_md; do
  src="$(dirname "$skill_md")"
  names+=("$(basename "$src")")
  srcs+=("$src")
done < <(find "$REPO/skills" -name SKILL.md \
  -not -path '*/node_modules/*' \
  -not -path '*/deprecated/*' \
  -print0 | sort -z)

for DEST in "${DESTS[@]}"; do
  # If $DEST is a symlink that resolves into this repo, we'd end up writing the
  # per-skill symlinks back into the repo's own skills/ tree. Detect and bail
  # out instead of polluting the working copy.
  if [ -L "$DEST" ]; then
    resolved="$(readlink -f "$DEST")"
    case "$resolved" in
      "$REPO"|"$REPO"/*)
        echo "error: $DEST is a symlink into this repo ($resolved)." >&2
        echo "Remove it (rm \"$DEST\") and re-run; the script will recreate it as a real dir." >&2
        exit 1
        ;;
    esac
  fi

  mkdir -p "$DEST"

  # A real (non-symlink) entry at a target is a collision: never delete it
  # silently. Prompt interactively; bail out when non-interactive.
  collisions=()
  for i in "${!names[@]}"; do
    target="$DEST/${names[$i]}"
    if [ -e "$target" ] && [ ! -L "$target" ]; then
      collisions+=("$target")
    fi
  done

  if [ "${#collisions[@]}" -gt 0 ] && [ ! -t 0 ]; then
    for target in "${collisions[@]}"; do
      echo "[$DEST] collision: leaving $target" >&2
    done
    echo "[$DEST] error: resolve collisions interactively or remove them before retrying." >&2
    exit 1
  fi

  declare -a skipped=()
  for target in "${collisions[@]}"; do
    reply=""
    read -r -p "[$DEST] collision: replace $target? [y/N] " reply || true
    case "$reply" in
      y|Y|yes|YES|Yes)
        rm -rf -- "$target"
        echo "[$DEST] replaced collision: $target"
        ;;
      *)
        skipped+=("$target")
        echo "[$DEST] left collision: $target"
        ;;
    esac
  done

  # Prune stale links: symlinks in $DEST that point into this repo but no
  # longer correspond to a collected skill (deleted, renamed, or deprecated).
  while IFS= read -r -d '' link; do
    resolved="$(readlink -m -- "$link" || true)"
    case "$resolved" in
      "$REPO"|"$REPO"/*)
        known=0
        for s in "${srcs[@]}"; do
          [ "$s" = "$resolved" ] && known=1 && break
        done
        if [ "$known" -eq 0 ]; then
          rm -- "$link"
          echo "[$DEST] pruned stale link: $link -> $resolved"
        fi
        ;;
    esac
  done < <(find "$DEST" -mindepth 1 -maxdepth 1 -type l -print0)

  for i in "${!names[@]}"; do
    name="${names[$i]}"
    src="${srcs[$i]}"
    target="$DEST/$name"

    skip=0
    for s in ${skipped[@]+"${skipped[@]}"}; do
      [ "$s" = "$target" ] && skip=1 && break
    done
    [ "$skip" -eq 1 ] && continue

    ln -sfn -- "$src" "$target"
    echo "[$DEST] linked: $name -> $src"
  done
done
