#!/usr/bin/env bash
# dotfiles.sh — the shell + editor config you set up on every box.
# writes marker-bounded blocks into ~/.bashrc and ~/.vimrc so it's
# idempotent and trivially reversible (delete the block, you're back).
# installs a few quality-of-life CLIs while it's at it.

_dotfiles_bashrc() {
  cat <<'EOF'
# sane history
export HISTSIZE=100000 HISTFILESIZE=200000
export HISTCONTROL=ignoreboth
shopt -s histappend checkwinsize 2>/dev/null

# the aliases you retype on every machine
alias ll='ls -alh'
alias la='ls -A'
alias ..='cd ..'
alias ...='cd ../..'
alias gs='git status -sb'
alias gd='git diff'
alias gl='git log --oneline --graph --decorate -20'

# a prompt that tells you who and where you are
PS1='\[\e[32m\]\u@\h\[\e[0m\]:\[\e[34m\]\w\[\e[0m\]\$ '
EOF
}

_dotfiles_vimrc() {
  cat <<'EOF'
set nocompatible
syntax on
set number relativenumber
set expandtab shiftwidth=4 tabstop=4 softtabstop=4
set autoindent smartindent
set incsearch hlsearch ignorecase smartcase
set ruler showcmd wildmenu laststatus=2
set mouse=a
EOF
}

hbes_dotfiles() {
  local pkgs=(
    tmux
    fzf
    ripgrep    # rg
    bat        # 'batcat' on debian
  )
  # shellcheck disable=SC2207  # package names never contain spaces or globs
  pkgs=( $(overrides dotfiles "${pkgs[@]}") )
  log "installing: ${pkgs[*]}"
  pkg_install "${pkgs[@]}" || warn "some dotfiles CLIs may not be in apt on this release."

  # config blocks go in regardless of apt (they don't need the packages).
  write_block "${HOME}/.bashrc" "$(_dotfiles_bashrc)" '#'
  write_block "${HOME}/.vimrc"  "$(_dotfiles_vimrc)"  '"'

  [ "${DRY_RUN:-0}" -eq 1 ] && return 0

  log "shell + editor config applied (open a new shell or 'source ~/.bashrc')."
  log "to undo: delete the '${HBES_MARK_BEGIN}' block from the file."
}
