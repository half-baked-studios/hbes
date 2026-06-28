#!/usr/bin/env bash
# embedded.sh — bare-metal / cross-compile / flashing tools
# arm gcc, openocd, the stuff you only want on the dev box that
# actually talks to hardware. toolchain package names vary a lot.

hbes_embedded() {
  local pkgs
  case "$HBES_PM" in
    apt)     pkgs=(gcc-arm-none-eabi gcc-aarch64-linux-gnu openocd minicom usbutils device-tree-compiler) ;;
    dnf|yum) pkgs=(arm-none-eabi-gcc-cs arm-none-eabi-newlib openocd minicom usbutils dtc) ;;
    pacman)  pkgs=(arm-none-eabi-gcc arm-none-eabi-newlib openocd minicom usbutils dtc) ;;
    brew)    pkgs=(open-ocd minicom dtc) ;;   # bare-metal arm gcc needs a tap (below)
  esac
  # shellcheck disable=SC2207  # package names never contain spaces or globs
  pkgs=( $(overrides embedded "${pkgs[@]}") )
  log "installing: ${pkgs[*]}"
  pkg_install "${pkgs[@]}" || {
    warn "some embedded packages may not exist on this platform."
    warn "arm toolchain naming varies — check your package manager if one was skipped."
  }
  [ "${DRY_RUN:-0}" -eq 1 ] && return 0

  if [ "$HBES_PM" = brew ]; then
    warn "bare-metal ARM gcc isn't in core brew — tap one:"
    warn "  brew install --cask gcc-arm-embedded"
  fi

  command -v arm-none-eabi-gcc >/dev/null 2>&1 && \
    log "arm gcc: $(arm-none-eabi-gcc --version | head -1)"
  command -v dtc >/dev/null 2>&1 && log "dtc: $(dtc --version 2>&1 | head -1)"

  # rkdeveloptool isn't packaged most places — note it, don't auto-build
  if ! command -v rkdeveloptool >/dev/null 2>&1; then
    warn "rkdeveloptool not found — not in most repos."
    warn "build from source: https://github.com/rockchip-linux/rkdeveloptool"
  fi
}
