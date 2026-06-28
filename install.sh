#!/usr/bin/env bash
#
# hbes — Half Baked Env
# works on my machine. ship it.
#
# Bootstrap a Debian dev box. Pick what you want, or let it recommend.
#
# usage:
#   ./install.sh                  interactive (recommendation-driven defaults)
#   ./install.sh --recommend      probe the box, print suggestions, install nothing
#   ./install.sh --all            every module, no prompts
#   ./install.sh --base --python  pick modules by name
#   ./install.sh --profile std    install a named bundle
#   ./install.sh --list           list available modules and profiles
#
# modules:   base  toolchain  python  embedded
# profiles:  minimal  standard  full  embedded
#

set -euo pipefail

HBES_VERSION="0.2.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULES_DIR="${SCRIPT_DIR}/modules"
LOCKFILE="${SCRIPT_DIR}/hbes.lock"

# ---- pretty output ----------------------------------------------------------
c_reset=$'\033[0m'; c_dim=$'\033[2m'; c_grn=$'\033[32m'
c_ylw=$'\033[33m'; c_red=$'\033[31m'; c_bold=$'\033[1m'

log()  { printf '%s[hbes]%s %s\n' "$c_grn" "$c_reset" "$*"; }
warn() { printf '%s[hbes]%s %s\n' "$c_ylw" "$c_reset" "$*"; }
err()  { printf '%s[hbes]%s %s\n' "$c_red" "$c_reset" "$*" >&2; }
step() { printf '\n%s==>%s %s%s%s\n' "$c_grn" "$c_reset" "$c_bold" "$*" "$c_reset"; }

# ---- guards -----------------------------------------------------------------
require_debian() {
  if ! command -v apt-get >/dev/null 2>&1; then
    err "this is built for Debian/Ubuntu (apt). aborting."
    exit 1
  fi
}

need_sudo() {
  if [ "$(id -u)" -ne 0 ]; then
    SUDO="sudo"
  else
    SUDO=""
  fi
}

# ---- module runner ----------------------------------------------------------
run_module() {
  local name="$1"
  local file="${MODULES_DIR}/${name}.sh"
  if [ ! -f "$file" ]; then
    warn "module '${name}' not found, skipping"
    return
  fi
  step "module: ${name}"
  # shellcheck source=/dev/null
  source "$file"
  "hbes_${name}"
  echo "${name}" >> "$LOCKFILE"
}

# ---- prompt -----------------------------------------------------------------
ask() {
  # ask "question" default(y/n) -> returns 0 for yes
  local q="$1" default="${2:-y}" ans
  if [ "${HBES_ALL:-0}" -eq 1 ]; then return 0; fi
  read -r -p "$(printf '%s ? %s[%s]%s ' "$q" "$c_dim" "$default" "$c_reset")" ans || true
  ans="${ans:-$default}"
  [[ "$ans" =~ ^[Yy] ]]
}

# ---- module metadata --------------------------------------------------------
MODULES=(base toolchain python embedded)

module_blurb() {
  case "$1" in
    base)      echo "gcc, make, git, curl — the non-negotiables" ;;
    toolchain) echo "clang, cmake, ninja, gdb — build-system glue" ;;
    python)    echo "pip, venv, pipx — PEP 668 aware" ;;
    embedded)  echo "arm gcc, openocd, dtc — talks to hardware" ;;
    *)         echo "" ;;
  esac
}

# profiles: named bundles so you can declare a setup instead of clicking.
profile_modules() {
  case "$1" in
    minimal)  echo "base" ;;
    standard) echo "base toolchain python" ;;
    full)     echo "base toolchain python embedded" ;;
    embedded) echo "base toolchain embedded" ;;
    *)        return 1 ;;
  esac
}

# ---- recommendation engine --------------------------------------------------
# probe the box and decide what's actually worth installing here. each
# recommend_<module> echoes a one-line reason and returns 0 (recommend) or
# 1 (skip). detection is best-effort and never installs anything.
has() { command -v "$1" >/dev/null 2>&1; }

recommend_base() {
  if ! has gcc || ! has git; then
    echo "no compiler/git yet — you want these"
  else
    echo "gcc+git present, but rounds out the set"
  fi
  return 0
}

recommend_toolchain() {
  if ! has cmake || ! has clang; then
    echo "no cmake/clang — standard C/C++ build tools"; return 0
  fi
  echo "cmake+clang already installed"; return 1
}

recommend_python() {
  if ! has python3; then
    echo "no python3 — most projects expect it"; return 0
  fi
  if ! has pipx || ! python3 -m venv --help >/dev/null 2>&1; then
    echo "python3 here but pip/venv/pipx tooling is thin"; return 0
  fi
  echo "python tooling looks complete"; return 1
}

recommend_embedded() {
  # only worth it if this box actually talks to hardware
  if ls /dev/ttyUSB* /dev/ttyACM* >/dev/null 2>&1; then
    echo "serial device on /dev/tty* — hardware attached"; return 0
  fi
  if has lsusb && lsusb 2>/dev/null | grep -qiE 'stmicro|segger|j-?link|ft232|ftdi|dfu'; then
    echo "debug probe / serial bridge seen on usb"; return 0
  fi
  if has arm-none-eabi-gcc; then
    echo "arm-none-eabi already partially set up"; return 0
  fi
  echo "no serial/usb probes detected"; return 1
}

# print the recommendation table; install nothing.
print_recommendations() {
  step "what hbes recommends for this box"
  local m reason
  for m in "${MODULES[@]}"; do
    if reason="$(recommend_"$m")"; then
      printf '  %s✓ %-10s%s %s%s%s\n' "$c_grn" "$m" "$c_reset" "$c_dim" "$reason" "$c_reset"
    else
      printf '  %s· %-10s%s %s%s%s\n' "$c_dim" "$m" "$c_reset" "$c_dim" "$reason" "$c_reset"
    fi
  done
}

# print modules and profiles, then exit.
list_modules() {
  step "modules"
  local m
  for m in "${MODULES[@]}"; do
    printf '  %s%-10s%s %s\n' "$c_bold" "$m" "$c_reset" "$(module_blurb "$m")"
  done
  step "profiles"
  printf '  %-10s %s\n' "minimal"  "base"
  printf '  %-10s %s\n' "standard" "base toolchain python"
  printf '  %-10s %s\n' "full"     "base toolchain python embedded"
  printf '  %-10s %s\n' "embedded" "base toolchain embedded"
}

# ---- main -------------------------------------------------------------------
main() {
  require_debian
  need_sudo

  printf '%s\n' "${c_bold}half baked env${c_reset} ${c_dim}v${HBES_VERSION}${c_reset}"
  printf '%sworks on my machine. ship it.%s\n' "$c_dim" "$c_reset"

  local selected=() m reason def
  HBES_ALL=0

  # parse args
  if [ "$#" -eq 0 ]; then
    # interactive: recommendation drives the per-module default
    print_recommendations
    echo
    for m in "${MODULES[@]}"; do
      if reason="$(recommend_"$m")"; then def=y; else def=n; fi
      ask "install ${m} ($(module_blurb "$m"))" "$def" && selected+=("$m")
    done
  else
    while [ "$#" -gt 0 ]; do
      case "$1" in
        --all) HBES_ALL=1; selected=("${MODULES[@]}") ;;
        --base|--toolchain|--python|--embedded) selected+=("${1#--}") ;;
        --recommend) print_recommendations; echo; log "run again with --profile / module flags to install."; exit 0 ;;
        --list) list_modules; exit 0 ;;
        --profile)
          shift; [ "$#" -gt 0 ] || { err "--profile needs a name (see --list)"; exit 1; }
          read -r -a selected <<< "$(profile_modules "$1")" || { err "unknown profile: $1"; exit 1; } ;;
        --profile=*)
          read -r -a selected <<< "$(profile_modules "${1#--profile=}")" || { err "unknown profile: ${1#--profile=}"; exit 1; } ;;
        -h|--help) grep '^#' "$0" | sed 's/^#//'; exit 0 ;;
        *) warn "unknown arg: $1" ;;
      esac
      shift
    done
  fi

  if [ "${#selected[@]}" -eq 0 ]; then
    warn "nothing selected. exiting."
    exit 0
  fi

  : > "$LOCKFILE"
  echo "# hbes.lock — generated $(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$LOCKFILE"

  step "updating apt index"
  $SUDO apt-get update -qq

  for m in "${selected[@]}"; do
    run_module "$m"
  done

  step "done"
  log "installed modules: ${selected[*]}"
  log "lockfile written to: ${LOCKFILE}"
  log "if it works, we're still going to figure out why."
}

main "$@"
