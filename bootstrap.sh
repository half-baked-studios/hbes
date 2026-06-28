#!/usr/bin/env bash
#
# hbes bootstrap — the "curl one-liner". fetches the repo and runs install.sh.
#
#   interactive (like brew):
#     /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/half-baked-studios/hbes/main/bootstrap.sh)"
#
#   unattended — pass flags through a pipe:
#     curl -fsSL https://raw.githubusercontent.com/half-baked-studios/hbes/main/bootstrap.sh | bash -s -- --profile standard
#     curl -fsSL .../bootstrap.sh | bash -s -- --all --dry-run
#
# knobs (env):
#   HBES_REPO   git url to fetch        (default: github half-baked-studios/hbes)
#   HBES_DIR    where to put it         (default: ~/.hbes)
#   HBES_REF    branch/tag to fetch     (default: main)
#

set -euo pipefail

HBES_REPO="${HBES_REPO:-https://github.com/half-baked-studios/hbes}"
HBES_DIR="${HBES_DIR:-${HOME}/.hbes}"
HBES_REF="${HBES_REF:-main}"

c_reset=$'\033[0m'; c_grn=$'\033[32m'; c_red=$'\033[31m'
say() { printf '%s[hbes]%s %s\n' "$c_grn" "$c_reset" "$*"; }
die() { printf '%s[hbes]%s %s\n' "$c_red" "$c_reset" "$*" >&2; exit 1; }

# ---- fetch the repo (git if we have it, tarball if we don't) -----------------
fetch() {
  if command -v git >/dev/null 2>&1; then
    if [ -d "${HBES_DIR}/.git" ]; then
      say "updating ${HBES_DIR}"
      git -C "$HBES_DIR" fetch --depth 1 origin "$HBES_REF" --quiet
      git -C "$HBES_DIR" reset --hard "origin/${HBES_REF}" --quiet
    else
      say "cloning ${HBES_REPO} -> ${HBES_DIR}"
      rm -rf "$HBES_DIR"
      git clone --depth 1 --branch "$HBES_REF" --quiet "$HBES_REPO" "$HBES_DIR"
    fi
  elif command -v curl >/dev/null 2>&1; then
    say "no git — fetching tarball into ${HBES_DIR}"
    rm -rf "$HBES_DIR"; mkdir -p "$HBES_DIR"
    curl -fsSL "${HBES_REPO}/archive/refs/heads/${HBES_REF}.tar.gz" \
      | tar -xz -C "$HBES_DIR" --strip-components=1
  else
    die "need git or curl to fetch hbes."
  fi
}

main() {
  fetch
  cd "$HBES_DIR"
  chmod +x install.sh
  say "running installer from ${HBES_DIR}"

  # if stdin is a pipe (curl | bash), try to attach the real terminal so the
  # interactive picker still works. probe in a subshell so a missing tty can't
  # kill us; fall back to a plain run (which needs flags, or it bails cleanly).
  if [ ! -t 0 ] && ( : </dev/tty ) 2>/dev/null; then
    exec ./install.sh "$@" </dev/tty
  fi
  exec ./install.sh "$@"
}

main "$@"
