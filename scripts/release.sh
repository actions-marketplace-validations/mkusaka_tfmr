#!/usr/bin/env bash
set -euo pipefail

# Usage: ./scripts/release.sh patch|minor|major

arg="${1:-}"

if [ -z "${arg}" ]; then
  echo "Usage: $0 <patch|minor|major|vX.Y.Z>"
  echo ""
  echo "Recent tags:"
  git tag --sort=-version:refname | head -5 || echo "  (none)"
  exit 1
fi

if echo "${arg}" | grep -qE '^v[0-9]+\.[0-9]+\.[0-9]+$'; then
  # Explicit tag: ./scripts/release.sh v1.2.3
  tag="${arg}"
else
  # Bump: ./scripts/release.sh patch|minor|major
  case "${arg}" in
    patch|minor|major) ;;
    *) echo "Error: argument must be 'patch', 'minor', 'major', or 'vX.Y.Z', got '${arg}'"; exit 1 ;;
  esac

  latest=$(git tag --sort=-version:refname | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | head -1 || true)
  if [ -z "${latest}" ]; then
    latest="v0.0.0"
  fi

  version="${latest#v}"
  IFS='.' read -r major minor patch <<< "${version}"

  case "${arg}" in
    patch) patch=$((patch + 1)) ;;
    minor) minor=$((minor + 1)); patch=0 ;;
    major) major=$((major + 1)); minor=0; patch=0 ;;
  esac

  tag="v${major}.${minor}.${patch}"
fi

# Check for uncommitted changes
if [ -n "$(git status --porcelain)" ]; then
  echo "Error: working tree is not clean"
  git status --short
  exit 1
fi

# Check release tag doesn't already exist locally or remotely
if git rev-parse --verify --quiet "refs/tags/${tag}" >/dev/null; then
  echo "Error: tag '${tag}' already exists"
  exit 1
fi
remote_tag="$(git ls-remote --tags origin "refs/tags/${tag}")"
if [ -n "${remote_tag}" ]; then
  echo "Error: remote tag '${tag}' already exists"
  exit 1
fi
if command -v gh >/dev/null 2>&1; then
  release_draft="$(gh release view "${tag}" --json isDraft --jq '.isDraft' 2>/dev/null || true)"
  if [ "${release_draft}" = "false" ]; then
    echo "Error: GitHub Release '${tag}' already exists"
    exit 1
  fi
fi

release_version="${tag#v}"
IFS='.' read -r release_major _release_minor _release_patch <<< "${release_version}"
major_tag="v${release_major}"

if command -v gh >/dev/null 2>&1; then
  major_release_draft="$(gh release view "${major_tag}" --json isDraft --jq '.isDraft' 2>/dev/null || true)"
  if [ -n "${major_release_draft}" ]; then
    echo "Error: GitHub Release '${major_tag}' exists"
    echo "Moving action tags such as '${major_tag}' must not have GitHub Releases when release immutability is enabled."
    exit 1
  fi
fi

# Show what will be released
if [ -n "${latest:-}" ]; then
  echo "${latest} -> ${tag} (${arg})"
else
  echo "Release: ${tag}"
fi
echo "Commit: $(git log --oneline -1)"
echo "Branch: $(git branch --show-current)"
echo "Moving action tag: ${major_tag} -> ${tag}"
echo ""
read -rp "Proceed? [y/N] " confirm
if [ "${confirm}" != "y" ] && [ "${confirm}" != "Y" ]; then
  echo "Aborted."
  exit 0
fi

git tag "${tag}"
git push origin "${tag}"

release_commit="$(git rev-parse "${tag}^{commit}")"
git tag -f "${major_tag}" "${release_commit}"
git push --force origin "refs/tags/${major_tag}"

echo ""
echo "Tag '${tag}' pushed. GitHub Actions will:"
echo "  1. Build binaries for 5 platforms via goreleaser"
echo "  2. Create GitHub Release with assets"
echo "  3. Leave the moving major tag (${major_tag}) as a tag-only action ref"
echo ""
echo "Monitor: https://github.com/mkusaka/tfmr/actions"
