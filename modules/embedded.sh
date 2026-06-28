#!/usr/bin/env bash
# embedded.sh — bare-metal / cross-compile / flashing tools
# arm gcc, openocd, the stuff you only want on the dev box that
# actually talks to hardware.

hbes_embedded() {
  local pkgs=(
    gcc-arm-none-eabi       # bare-metal ARM (Cortex-M etc.)
    gcc-aarch64-linux-gnu   # aarch64 cross (RK3576 & friends)
    openocd
    minicom
    usbutils                # lsusb
    device-tree-compiler    # dtc
  )
  # shellcheck disable=SC2207  # package names never contain spaces or globs
  pkgs=( $(overrides embedded "${pkgs[@]}") )
  log "installing: ${pkgs[*]}"
  pkg_install "${pkgs[@]}" || {
    warn "some embedded packages may not exist on this Debian release."
    warn "check 'apt-cache search gcc-arm' if a package was skipped."
  }
  [ "${DRY_RUN:-0}" -eq 1 ] && return 0

  # rkdeveloptool isn't in apt — note it, don't auto-build
  if ! command -v rkdeveloptool >/dev/null 2>&1; then
    warn "rkdeveloptool not found — not in apt."
    warn "build from source: https://github.com/rockchip-linux/rkdeveloptool"
  fi

  command -v arm-none-eabi-gcc >/dev/null 2>&1 && \
    log "arm gcc: $(arm-none-eabi-gcc --version | head -1)"
  command -v dtc >/dev/null 2>&1 && \
    log "dtc: $(dtc --version)"
}
