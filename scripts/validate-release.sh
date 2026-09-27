#!/usr/bin/env bash
set -euo pipefail
[[ "${GITHUB_REF:-}" =~ ^refs/tags/v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]] || {
  echo 'Release tags must have the form vMAJOR.MINOR.PATCH.' >&2
  exit 1
}
git fetch origin main:refs/remotes/origin/main
TAG_COMMIT=$(git rev-parse "${GITHUB_REF}^{commit}")
[[ "$(git rev-parse HEAD)" == "$TAG_COMMIT" ]] || exit 1
git merge-base --is-ancestor "$TAG_COMMIT" refs/remotes/origin/main || {
  echo 'Release tag must point to a commit on main.' >&2
  exit 1
}
printf 'VERSION=%s\n' "${GITHUB_REF#refs/tags/v}" >> "${GITHUB_ENV:?}"
