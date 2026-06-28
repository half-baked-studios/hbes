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
  log "installing: ${pkgs[*]}"
  $SUDO apt-get install -y -qq "${pkgs[@]}"

  log "gcc:  $(gcc --version | head -1)"
  log "make: $(make --version | head -1)"
  log "git:  $(git --version)"
}
