#!/usr/bin/env bash
# toolchain.sh — the extras you want once base is there
# clang, cmake, pkg-config, the build-system glue.

hbes_toolchain() {
  local pkgs
  case "$HBES_PM" in
    apt)     pkgs=(clang lld cmake ninja-build pkg-config gdb valgrind) ;;
    dnf|yum) pkgs=(clang lld cmake ninja-build pkgconf-pkg-config gdb valgrind) ;;
    pacman)  pkgs=(clang lld cmake ninja pkgconf gdb valgrind) ;;
    brew)    pkgs=(llvm cmake ninja pkg-config) ;;  # gdb/valgrind unsupported on macOS
  esac
  # shellcheck disable=SC2207  # package names never contain spaces or globs
  pkgs=( $(overrides toolchain "${pkgs[@]}") )
  log "installing: ${pkgs[*]}"
  pkg_install "${pkgs[@]}"
  [ "${DRY_RUN:-0}" -eq 1 ] && return 0

  [ "$HBES_PM" = brew ] && warn "brew's llvm is keg-only — add it to PATH if you want its clang."
  command -v clang >/dev/null 2>&1 && log "clang: $(clang --version | head -1)"
  command -v cmake >/dev/null 2>&1 && log "cmake: $(cmake --version | head -1)"
}
