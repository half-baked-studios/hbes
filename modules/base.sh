#!/usr/bin/env bash
# base.sh — the stuff you install on every single new machine
# gcc, make, git, curl, the non-negotiables.

hbes_base() {
  local pkgs=(
    build-essential   # gcc, g++, make, libc-dev
    git
    curl
    wget
    ca-certificates
    unzip
    file
    vim
  )
  pkgs=( $(overrides base "${pkgs[@]}") )
  log "installing: ${pkgs[*]}"
  pkg_install "${pkgs[@]}"
  [ "${DRY_RUN:-0}" -eq 1 ] && return 0

  log "gcc:  $(gcc --version | head -1)"
  log "make: $(make --version | head -1)"
  log "git:  $(git --version)"
}
