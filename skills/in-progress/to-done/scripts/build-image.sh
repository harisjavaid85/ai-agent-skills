#!/usr/bin/env bash
# Builds the image the loop runs its phases in: to-done:base from this repo,
# then the target repo's .to-done/Dockerfile on top. A repo without one is
# tagged straight from the base.
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

base_image="to-done:base"
image_name=""
skills_ref=""
build_flags=()

usage() {
  cat <<'EOF'
Usage: build-image.sh [--image-name <name>] [--skills-ref <branch|tag>] [--no-cache]

Run from the root of the repo you want an image for.

  --image-name  Final image tag (default: $TO_DONE_IMAGE, else to-done:<repo>).
  --skills-ref  Branch or tag of the skills repo to bake in (default: its current
                branch). Must be pushed. A raw commit sha is not accepted — the
                skills installer resolves refs only.
  --no-cache    Rebuild every layer from scratch.
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --image-name) image_name="${2:?--image-name needs a value}"; shift 2 ;;
    --skills-ref) skills_ref="${2:?--skills-ref needs a value}"; shift 2 ;;
    --no-cache) build_flags+=(--no-cache); shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

command -v docker >/dev/null 2>&1 || {
  echo "docker is not installed." >&2
  exit 2
}
docker info >/dev/null 2>&1 || {
  echo "The Docker daemon is not reachable. Start it and re-run." >&2
  exit 2
}

# The target repo is where this was invoked; the skills repo is where the script
# lives. Usually different, so each is derived from its own anchor.
target_dir="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
repo_tag="$(basename "$target_dir" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9._-' '-')"
repo_tag="${repo_tag%-}"
[ -n "$image_name" ] || image_name="${TO_DONE_IMAGE:-to-done:${repo_tag}}"

remote_url="$(git -C "$script_dir" remote get-url origin)"
skills_repo="$(printf '%s' "$remote_url" | sed -E 's#^(git@github\.com:|https://github\.com/)##; s#\.git$##')"
# A branch or tag, because the installer rejects a raw sha — see the Dockerfile.
# Defaults to the checked-out branch, so a feature-branch build tests that
# branch's skills rather than silently testing the default one.
[ -n "$skills_ref" ] || skills_ref="$(git -C "$script_dir" rev-parse --abbrev-ref HEAD)"
skills_sha="$(git -C "$script_dir" rev-parse "$skills_ref")"

if ! git -C "$script_dir" ls-remote --exit-code --heads --tags origin "$skills_ref" >/dev/null 2>&1; then
  echo "\"$skills_ref\" is not on origin. The build resolves the ref remotely, so push it first." >&2
  exit 2
fi

if [ -n "$(git -C "$script_dir" status --porcelain -- "$script_dir/../../..")" ]; then
  echo "Warning: the skills repo has uncommitted changes. The image bakes ${skills_ref} at ${skills_sha:0:7}, so those edits will not be in it." >&2
fi

echo "Building ${base_image} from ${skills_repo}#${skills_ref} (${skills_sha:0:7}) as uid $(id -u):$(id -g)"

docker build "${build_flags[@]}" \
  --build-arg "AGENT_UID=$(id -u)" \
  --build-arg "AGENT_GID=$(id -g)" \
  --build-arg "SKILLS_REPO=${skills_repo}" \
  --build-arg "SKILLS_REF=${skills_ref}" \
  --build-arg "SKILLS_SHA=${skills_sha}" \
  --tag "$base_image" \
  --file "$script_dir/Dockerfile" \
  "$script_dir"

overlay="${target_dir}/.to-done/Dockerfile"
if [ -f "$overlay" ]; then
  echo "Building ${image_name} from ${overlay#"${target_dir}"/}"
  # Context is the repo root, so an overlay can COPY the lockfiles it warms
  # caches from.
  docker build "${build_flags[@]}" \
    --build-arg "BASE_IMAGE=${base_image}" \
    --tag "$image_name" \
    --file "$overlay" \
    "$target_dir"
else
  echo "No .to-done/Dockerfile in ${target_dir} — tagging the base as ${image_name}"
  docker tag "$base_image" "$image_name"
fi

echo "Built ${image_name}."
