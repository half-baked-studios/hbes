#!/usr/bin/env bash
# toolchain.sh — the extras you want once base is there
# clang, cmake, pkg-config, the build-system glue.

hbes_toolchain() {
  local pkgs=(
    clang
    lld
    cmake
    ninja-build
    pkg-config
    gdb
    valgrind
  )
  # shellcheck disable=SC2207  # package names never contain spaces or globs
  pkgs=( $(overrides toolchain "${pkgs[@]}") )
  log "installing: ${pkgs[*]}"
  pkg_install "${pkgs[@]}"
  [ "${DRY_RUN:-0}" -eq 1 ] && return 0

  log "clang: $(clang --version | head -1)"
  log "cmake: $(cmake --version | head -1)"
}
