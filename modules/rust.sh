#!/usr/bin/env bash
# rust.sh — rustup + the stable toolchain. per-user, no sudo, no apt.
# rustup is the one everyone agrees on; it owns ~/.cargo and ~/.rustup.

hbes_rust() {
  if [ "${DRY_RUN:-0}" -eq 1 ]; then
    log "[dry-run] would install rustup + stable via https://sh.rustup.rs"
    return 0
  fi

  if command -v rustup >/dev/null 2>&1; then
    log "rustup present — updating stable"
    rustup update stable >/dev/null 2>&1 || warn "rustup update failed (offline?)"
  else
    log "installing rustup (stable toolchain), per-user — no sudo"
    curl --proto '=https' --tlsv1.2 -fsSL https://sh.rustup.rs \
      | sh -s -- -y --no-modify-path --default-toolchain stable >/dev/null \
      || { warn "rustup install failed."; return 0; }
  fi

  # shellcheck disable=SC1091  # this file only exists after rustup runs
  [ -f "${HOME}/.cargo/env" ] && . "${HOME}/.cargo/env"
  command -v rustc >/dev/null 2>&1 && log "rust:  $(rustc --version)"
  command -v cargo >/dev/null 2>&1 && log "cargo: $(cargo --version)"
  warn "cargo lives in ~/.cargo/bin — open a new shell, or: . ~/.cargo/env"
}
