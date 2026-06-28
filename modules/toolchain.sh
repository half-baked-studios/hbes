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
  log "installing: ${pkgs[*]}"
  $SUDO apt-get install -y -qq "${pkgs[@]}"

  log "clang: $(clang --version | head -1)"
  log "cmake: $(cmake --version | head -1)"
}
