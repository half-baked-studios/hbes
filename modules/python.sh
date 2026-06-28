#!/usr/bin/env bash
# python.sh — pip, venv, pipx
# enough to actually run python projects without fighting PEP 668.

hbes_python() {
  local pkgs=(
    python3
    python3-pip
    python3-venv
    python3-dev
    pipx
  )
  # shellcheck disable=SC2207  # package names never contain spaces or globs
  pkgs=( $(overrides python "${pkgs[@]}") )
  log "installing: ${pkgs[*]}"
  pkg_install "${pkgs[@]}"
  [ "${DRY_RUN:-0}" -eq 1 ] && return 0

  # pipx path setup (per-user, no sudo)
  if command -v pipx >/dev/null 2>&1; then
    pipx ensurepath >/dev/null 2>&1 || true
    log "pipx ready — install tools with: pipx install <tool>"
  fi

  log "python: $(python3 --version)"
  log "pip:    $(pip3 --version | cut -d' ' -f1-2)"
  warn "debian python is externally-managed (PEP 668)."
  warn "use 'python3 -m venv .venv' per project, or pipx for CLIs."
}
