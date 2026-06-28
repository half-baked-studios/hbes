#!/usr/bin/env bash
# node.sh — fnm (fast node manager) + the current LTS. per-user, no apt.
# debian's nodejs lags hard; a version manager is the sane default.

hbes_node() {
  if [ "${DRY_RUN:-0}" -eq 1 ]; then
    log "[dry-run] would install fnm via https://fnm.vercel.app/install + node LTS"
    return 0
  fi

  if ! command -v fnm >/dev/null 2>&1; then
    log "installing fnm, per-user — no sudo"
    curl -fsSL https://fnm.vercel.app/install | bash -s -- --skip-shell >/dev/null \
      || { warn "fnm install failed (offline?)."; return 0; }
  fi

  export PATH="${HOME}/.local/share/fnm:${HOME}/.fnm:${PATH}"
  command -v fnm >/dev/null 2>&1 || { warn "fnm not on PATH yet — open a new shell."; return 0; }

  eval "$(fnm env)" 2>/dev/null || true
  log "installing node LTS via fnm"
  fnm install --lts >/dev/null 2>&1 || warn "fnm install --lts failed (network?)"
  fnm default lts-latest >/dev/null 2>&1 || true
  command -v node >/dev/null 2>&1 && log "node: $(node --version)"
  warn "fnm is per-user; add its shell hook (see 'fnm env', or the dotfiles module)."
}
