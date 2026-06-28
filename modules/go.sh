#!/usr/bin/env bash
# go.sh — the Go toolchain, from the platform package manager.

hbes_go() {
  local pkgs
  case "$HBES_PM" in
    apt)     pkgs=(golang-go gopls) ;;
    dnf|yum) pkgs=(golang) ;;          # gopls via 'go install' on fedora
    pacman)  pkgs=(go gopls) ;;
    brew)    pkgs=(go gopls) ;;
  esac
  # shellcheck disable=SC2207  # package names never contain spaces or globs
  pkgs=( $(overrides go "${pkgs[@]}") )
  log "installing: ${pkgs[*]}"
  pkg_install "${pkgs[@]}" || warn "some go packages may not exist on this platform."
  [ "${DRY_RUN:-0}" -eq 1 ] && return 0

  command -v go >/dev/null 2>&1 && log "go: $(go version)"
  warn "package-manager go can lag; for the newest use https://go.dev/dl"
}
