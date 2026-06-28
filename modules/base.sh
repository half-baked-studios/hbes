#!/usr/bin/env bash
# base.sh — the stuff you install on every single new machine
# a compiler, make, git, curl, the non-negotiables. package names differ per
# platform (build-essential vs base-devel vs Xcode CLT), so we map them.

hbes_base() {
  local pkgs
  case "$HBES_PM" in
    apt)     pkgs=(build-essential git curl wget ca-certificates unzip file vim) ;;
    dnf|yum) pkgs=(gcc gcc-c++ make git curl wget ca-certificates unzip file vim) ;;
    pacman)  pkgs=(base-devel git curl wget unzip file vim) ;;
    brew)    pkgs=(git curl wget) ;;   # compiler + make come from Xcode CLT
  esac
  # shellcheck disable=SC2207  # package names never contain spaces or globs
  pkgs=( $(overrides base "${pkgs[@]}") )
  log "installing: ${pkgs[*]}"
  pkg_install "${pkgs[@]}"
  [ "${DRY_RUN:-0}" -eq 1 ] && return 0

  if [ "$HBES_PM" = brew ] && command -v xcode-select >/dev/null 2>&1 \
     && ! xcode-select -p >/dev/null 2>&1; then
    warn "run 'xcode-select --install' for the compiler toolchain (clang, make)."
  fi
  command -v cc   >/dev/null 2>&1 && log "cc:   $(cc --version | head -1)"
  command -v make >/dev/null 2>&1 && log "make: $(make --version | head -1)"
  command -v git  >/dev/null 2>&1 && log "git:  $(git --version)"
}
