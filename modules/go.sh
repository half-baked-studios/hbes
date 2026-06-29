#!/usr/bin/env bash
# go.sh — the Go toolchain, from the platform package manager.

_go_pkgs() {
  case "$HBES_PM" in
    apt)     echo golang-go gopls ;;
    dnf|yum) echo golang ;;        # gopls via 'go install' on fedora
    pacman)  echo go gopls ;;
    brew)    echo go gopls ;;
  esac
}

hbes_go() {
  local pkgs
  # shellcheck disable=SC2046,SC2207  # package names never contain spaces or globs
  pkgs=( $(overrides go $(_go_pkgs)) )
  log "installing: ${pkgs[*]}"
  pkg_install "${pkgs[@]}" || warn "some go packages may not exist on this platform."
  [ "${DRY_RUN:-0}" -eq 1 ] && return 0

  command -v go >/dev/null 2>&1 && log "go: $(go version)"
  warn "package-manager go can lag; for the newest use https://go.dev/dl"
  return 0
}

hbes_go_down() {
  local pkgs
  # shellcheck disable=SC2046,SC2207
  pkgs=( $(overrides go $(_go_pkgs)) )
  log "removing: ${pkgs[*]}"
  pkg_remove "${pkgs[@]}" || warn "some go packages weren't installed."
  return 0
}
