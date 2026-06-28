#!/usr/bin/env bash
# go.sh — the Go toolchain, straight from apt. simple and good enough.

hbes_go() {
  local pkgs=(
    golang-go
    gopls       # language server (may be absent on older releases)
  )
  # shellcheck disable=SC2207  # package names never contain spaces or globs
  pkgs=( $(overrides go "${pkgs[@]}") )
  log "installing: ${pkgs[*]}"
  pkg_install "${pkgs[@]}" || warn "some go packages may not exist on this release."
  [ "${DRY_RUN:-0}" -eq 1 ] && return 0

  command -v go >/dev/null 2>&1 && log "go: $(go version)"
  warn "apt's go can lag; for the newest use https://go.dev/dl or a manager like 'g'."
}
