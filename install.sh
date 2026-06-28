#!/usr/bin/env bash
#
# hbes — Half Baked Env
# works on my machine. ship it.
#
# Bootstrap a dev box on Debian/Ubuntu, RHEL/Fedora, Arch, or macOS.
# Detects the package manager (apt/dnf/pacman/brew). Pick modules, or recommend.
#
# usage:
#   ./install.sh                  interactive — checkbox TUI if available, else y/n
#   ./install.sh --tui            force the checkbox selector (python+questionary)
#   ./install.sh --recommend      probe the box, print suggestions, install nothing
#   ./install.sh --all            every module, no prompts
#   ./install.sh --base --python  pick modules by name
#   ./install.sh --profile std    install a named bundle
#   ./install.sh --config FILE    drive the run from an hbes.toml
#   ./install.sh --dry-run        show what would happen, change nothing
#   ./install.sh --skip-installed skip modules already in the lockfile
#   ./install.sh --status         show what the lockfile recorded
#   ./install.sh --uninstall [m]  revert modules (dotfiles fully; apt left alone)
#   ./install.sh --list           list available modules and profiles
#
# modules:   base  toolchain  python  rust  go  node  embedded  dotfiles
# profiles:  minimal  standard  workstation  full  embedded
#

set -euo pipefail

HBES_VERSION="0.3.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULES_DIR="${SCRIPT_DIR}/modules"
LOCKFILE="${SCRIPT_DIR}/hbes.lock"
DRY_RUN=0

# markers that bound an hbes-managed block inside a config file
HBES_MARK_BEGIN=">>> hbes >>>"
HBES_MARK_END="<<< hbes <<<"

# ---- pretty output ----------------------------------------------------------
c_reset=$'\033[0m'; c_dim=$'\033[2m'; c_grn=$'\033[32m'
c_ylw=$'\033[33m'; c_red=$'\033[31m'; c_bold=$'\033[1m'

log()  { printf '%s[hbes]%s %s\n' "$c_grn" "$c_reset" "$*"; }
warn() { printf '%s[hbes]%s %s\n' "$c_ylw" "$c_reset" "$*"; }
err()  { printf '%s[hbes]%s %s\n' "$c_red" "$c_reset" "$*" >&2; }
step() { printf '\n%s==>%s %s%s%s\n' "$c_grn" "$c_reset" "$c_bold" "$*" "$c_reset"; }

# ---- platform detection -----------------------------------------------------
# sets HBES_OS (linux/macos), HBES_DISTRO (debian/rhel/arch/macos),
# HBES_PM (apt/dnf/yum/pacman/brew), HBES_SELINUX (1 if enforcing/permissive).
detect_platform() {
  HBES_SELINUX=0
  case "$(uname -s)" in
    Darwin)
      HBES_DISTRO=macos; HBES_PM=brew
      ;;
    Linux)
      local id="" like=""
      if [ -r /etc/os-release ]; then
        id="$(awk -F= '$1=="ID"{gsub(/"/,"",$2); print $2}' /etc/os-release 2>/dev/null)"
        like="$(awk -F= '$1=="ID_LIKE"{gsub(/"/,"",$2); print $2}' /etc/os-release 2>/dev/null)"
      fi
      case " $id $like " in
        *" debian "*|*" ubuntu "*)            HBES_DISTRO=debian; HBES_PM=apt ;;
        *" rhel "*|*" fedora "*|*" centos "*) HBES_DISTRO=rhel;   HBES_PM=dnf ;;
        *" arch "*)                           HBES_DISTRO=arch;   HBES_PM=pacman ;;
        *)
          # unknown distro — guess from whatever package manager is present
          if   command -v apt-get >/dev/null 2>&1; then HBES_DISTRO=debian; HBES_PM=apt
          elif command -v dnf     >/dev/null 2>&1; then HBES_DISTRO=rhel;   HBES_PM=dnf
          elif command -v yum     >/dev/null 2>&1; then HBES_DISTRO=rhel;   HBES_PM=yum
          elif command -v pacman  >/dev/null 2>&1; then HBES_DISTRO=arch;   HBES_PM=pacman
          else err "no supported package manager found (apt/dnf/pacman)."; exit 1
          fi
          ;;
      esac
      # rhel without dnf (older centos) -> yum
      [ "$HBES_PM" = dnf ] && ! command -v dnf >/dev/null 2>&1 && HBES_PM=yum
      # selinux awareness — we only write to $HOME, but mode informs the user
      if command -v getenforce >/dev/null 2>&1; then
        case "$(getenforce 2>/dev/null)" in Enforcing|Permissive) HBES_SELINUX=1 ;; esac
      fi
      ;;
    *) err "unsupported OS: $(uname -s)"; exit 1 ;;
  esac

  command -v "$HBES_PM" >/dev/null 2>&1 || { err "package manager '${HBES_PM}' not found."; exit 1; }
}

# ensure_brew — macOS leans on Homebrew; bail with instructions if it's missing.
ensure_brew() {
  command -v brew >/dev/null 2>&1 && return 0
  err "Homebrew not found — hbes uses it on macOS. install it, then re-run:"
  # shellcheck disable=SC2016  # literal command to show the user, not for us to expand
  err '  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
  exit 1
}

need_sudo() {
  # brew refuses to run as root and needs no sudo; package managers do
  if [ "${HBES_PM:-}" = brew ] || [ "$(id -u)" -eq 0 ]; then
    SUDO=""
  else
    SUDO="sudo"
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
  record_lock "$name"
}

# the lockfile is a cumulative record of what hbes installed: one
# "<module>\t<timestamp>" line each, newest write wins (no duplicates).
record_lock() {
  [ "${DRY_RUN:-0}" -eq 1 ] && return 0
  local name="$1" tmp; tmp="$(mktemp)"
  [ -f "$LOCKFILE" ] && awk -F'\t' -v n="$name" '$1!=n' "$LOCKFILE" > "$tmp"
  printf '%s\t%s\n' "$name" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$tmp"
  mv "$tmp" "$LOCKFILE"
}

unrecord_lock() {
  [ "${DRY_RUN:-0}" -eq 1 ] && return 0
  [ -f "$LOCKFILE" ] || return 0
  local tmp; tmp="$(mktemp)"
  awk -F'\t' -v n="$1" '$1!=n' "$LOCKFILE" > "$tmp"
  mv "$tmp" "$LOCKFILE"
}

# lockfile_modules — echo the space-separated modules recorded in the lockfile.
lockfile_modules() {
  [ -f "$LOCKFILE" ] || return 0
  awk -F'\t' '$1!="" && $1!~/^#/ {print $1}' "$LOCKFILE" | tr '\n' ' '
}

# run_uninstall <module> — revert a module if it knows how (defines a *_down
# function). apt packages are left alone on purpose; we only auto-undo the
# things we wrote (e.g. dotfiles blocks).
run_uninstall() {
  local name="$1"
  local file="${MODULES_DIR}/${name}.sh"
  if [ ! -f "$file" ]; then
    warn "module '${name}' not found, skipping"
    return
  fi
  # shellcheck source=/dev/null
  source "$file"
  if declare -F "hbes_${name}_down" >/dev/null; then
    step "uninstall: ${name}"
    "hbes_${name}_down"
  else
    warn "${name}: no automatic uninstall — apt packages stay (remove with apt yourself)."
  fi
}

# show_status — print what the last run recorded in the lockfile.
show_status() {
  if [ ! -f "$LOCKFILE" ]; then
    warn "no hbes.lock yet — nothing installed by hbes here."
    return 0
  fi
  step "hbes.lock"
  local name ts
  while IFS=$'\t' read -r name ts; do
    case "$name" in ''|\#*) continue ;; esac
    printf '  %s%-10s%s %s%s%s\n' "$c_bold" "$name" "$c_reset" "$c_dim" "${ts:-?}" "$c_reset"
  done < "$LOCKFILE"
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

# ---- helpers modules use ----------------------------------------------------
# pkg_install <pkgs...> — install via the platform's package manager, or just
# report it under --dry-run.
pkg_install() {
  if [ "${DRY_RUN:-0}" -eq 1 ]; then
    log "[dry-run] install: $*"
    return 0
  fi
  case "$HBES_PM" in
    apt)    $SUDO apt-get install -y -qq "$@" ;;
    dnf)    $SUDO dnf install -y "$@" ;;
    yum)    $SUDO yum install -y "$@" ;;
    pacman) $SUDO pacman -S --needed --noconfirm "$@" ;;
    brew)   brew install "$@" ;;
    *)      err "no package manager set"; return 1 ;;
  esac
}

# pm_update — refresh the package index (best-effort; never fatal).
pm_update() {
  if [ "${DRY_RUN:-0}" -eq 1 ]; then log "[dry-run] refresh ${HBES_PM:-pkg} index"; return 0; fi
  case "$HBES_PM" in
    apt)    $SUDO apt-get update -qq ;;
    dnf)    $SUDO dnf -q makecache 2>/dev/null || true ;;
    yum)    $SUDO yum -q makecache 2>/dev/null || true ;;
    pacman) $SUDO pacman -Sy --noconfirm ;;
    brew)   brew update >/dev/null 2>&1 || true ;;
  esac
}

# selinux_restore <file> — fix a file's SELinux context after we replace it
# (mktemp + mv can leave a tmp_t label that surprises tools). no-op elsewhere.
selinux_restore() {
  [ "${HBES_SELINUX:-0}" -eq 1 ] || return 0
  command -v restorecon >/dev/null 2>&1 && restorecon "$1" 2>/dev/null || true
}

# ensure_yay — Arch only: install the yay AUR helper (built as a normal user).
ensure_yay() {
  command -v yay >/dev/null 2>&1 && { log "yay already installed"; return 0; }
  if [ "${DRY_RUN:-0}" -eq 1 ]; then log "[dry-run] would build yay from the AUR"; return 0; fi
  if [ "$(id -u)" -eq 0 ]; then
    warn "yay needs a non-root user to build (makepkg refuses root) — skipping."
    return 0
  fi
  log "installing yay (AUR helper) from the AUR"
  pkg_install base-devel git
  local tmp; tmp="$(mktemp -d)"
  if git clone --depth 1 https://aur.archlinux.org/yay-bin.git "${tmp}/yay-bin" >/dev/null 2>&1 \
     && ( cd "${tmp}/yay-bin" && makepkg -si --noconfirm >/dev/null 2>&1 ); then
    log "yay: $(yay --version 2>/dev/null | head -1)"
  else
    warn "yay build failed — install it by hand: https://github.com/Jguer/yay"
  fi
  rm -rf "$tmp"
}

# platform_setup — distro-specific bootstrap run once before modules.
platform_setup() {
  case "$HBES_DISTRO" in
    arch) ensure_yay ;;
    rhel)
      [ "${HBES_SELINUX:-0}" -eq 1 ] && \
        warn "SELinux is active — hbes only writes to \$HOME and restores file contexts."
      ;;
  esac
}

# overrides <module> <pkgs...> — echo the package list with per-module add/
# remove applied. driven by HBES_ADD_<m> / HBES_REMOVE_<m> (set from hbes.toml).
# package names never contain spaces, so word-splitting the result is safe.
overrides() {
  local mod="$1"; shift
  local add_var="HBES_ADD_${mod}" rm_var="HBES_REMOVE_${mod}"
  local add="${!add_var:-}" remove="${!rm_var:-}"
  local p out=()
  for p in "$@"; do
    case " $remove " in *" $p "*) continue ;; esac
    out+=("$p")
  done
  for p in $add; do out+=("$p"); done
  printf '%s\n' "${out[@]}"
}

# write_block <file> <content> [comment_leader] — insert or replace an
# hbes-managed, marker-bounded block in <file>, leaving everything else alone.
# idempotent: re-running replaces our block, never duplicates it.
write_block() {
  local file="$1" content="$2" cl="${3:-#}"
  local begin="${cl} ${HBES_MARK_BEGIN}" end="${cl} ${HBES_MARK_END}"
  if [ "${DRY_RUN:-0}" -eq 1 ]; then
    log "[dry-run] would write hbes block to ${file}"
    return 0
  fi
  local tmp; tmp="$(mktemp)"
  if [ -f "$file" ]; then
    awk -v b="$begin" -v e="$end" '
      $0==b {skip=1} !skip {print} $0==e {skip=0}' "$file" > "$tmp"
  fi
  {
    printf '%s\n' "$begin"
    printf '%s\n' "$content"
    printf '%s\n' "$end"
  } >> "$tmp"
  mkdir -p "$(dirname "$file")"
  mv "$tmp" "$file"
  selinux_restore "$file"
  log "wrote hbes block to ${file}"
}

# remove_block <file> [comment_leader] — strip the hbes-managed block, leaving
# the rest of the file untouched. the reverse of write_block.
remove_block() {
  local file="$1" cl="${2:-#}"
  local begin="${cl} ${HBES_MARK_BEGIN}" end="${cl} ${HBES_MARK_END}"
  [ -f "$file" ] || return 0
  if [ "${DRY_RUN:-0}" -eq 1 ]; then
    log "[dry-run] would remove hbes block from ${file}"
    return 0
  fi
  local tmp; tmp="$(mktemp)"
  awk -v b="$begin" -v e="$end" '
    $0==b {skip=1} !skip {print} $0==e {skip=0}' "$file" > "$tmp"
  mv "$tmp" "$file"
  selinux_restore "$file"
  log "removed hbes block from ${file}"
}

# ---- module metadata --------------------------------------------------------
MODULES=(base toolchain python rust go node embedded dotfiles)

module_blurb() {
  case "$1" in
    base)      echo "gcc, make, git, curl — the non-negotiables" ;;
    toolchain) echo "clang, cmake, ninja, gdb — build-system glue" ;;
    python)    echo "pip, venv, pipx — PEP 668 aware" ;;
    rust)      echo "rustup + stable — per-user, no apt" ;;
    go)        echo "golang-go + gopls — straight from apt" ;;
    node)      echo "fnm + node LTS — per-user, no apt" ;;
    embedded)  echo "arm gcc, openocd, dtc — talks to hardware" ;;
    dotfiles)  echo "shell aliases + vim defaults — idempotent" ;;
    *)         echo "" ;;
  esac
}

# profiles: named bundles so you can declare a setup instead of clicking.
profile_modules() {
  case "$1" in
    minimal)     echo "base" ;;
    standard)    echo "base toolchain python" ;;
    workstation) echo "base toolchain python dotfiles" ;;
    full)        echo "base toolchain python go embedded dotfiles" ;;
    embedded)    echo "base toolchain embedded" ;;
    *)           return 1 ;;
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
  # only worth it if this box actually talks to hardware. serial-device paths
  # differ: /dev/ttyUSB* /dev/ttyACM* on linux, /dev/tty.usb* /dev/cu.usb* on macOS.
  if ls /dev/ttyUSB* /dev/ttyACM* /dev/tty.usb* /dev/cu.usb* >/dev/null 2>&1; then
    echo "serial device present — hardware attached"; return 0
  fi
  if has lsusb && lsusb 2>/dev/null | grep -qiE 'stmicro|segger|j-?link|ft232|ftdi|dfu'; then
    echo "debug probe / serial bridge seen on usb"; return 0
  fi
  if has arm-none-eabi-gcc; then
    echo "arm-none-eabi already partially set up"; return 0
  fi
  echo "no serial/usb probes detected"; return 1
}

recommend_dotfiles() {
  if [ -f "$HOME/.bashrc" ] && grep -qF "$HBES_MARK_BEGIN" "$HOME/.bashrc" 2>/dev/null; then
    echo "hbes dotfiles already applied"; return 1
  fi
  echo "shell aliases + vim defaults, marker-bounded & reversible"; return 0
}

# language toolchains are opt-in: suggested only if already partway installed,
# or if there's a project file for that language in the current directory.
recommend_rust() {
  if has rustc || has rustup; then echo "rust already installed"; return 1; fi
  [ -f Cargo.toml ] && { echo "Cargo.toml here — rust project"; return 0; }
  echo "optional — no rust project in this dir"; return 1
}

recommend_go() {
  if has go; then echo "go already installed"; return 1; fi
  [ -f go.mod ] && { echo "go.mod here — go project"; return 0; }
  echo "optional — no go project in this dir"; return 1
}

recommend_node() {
  if has node || has fnm; then echo "node already installed"; return 1; fi
  [ -f package.json ] && { echo "package.json here — node project"; return 0; }
  echo "optional — no node project in this dir"; return 1
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

# echo the space-separated list of modules recommended for this box.
recommended_list() {
  local m out=()
  for m in "${MODULES[@]}"; do
    if recommend_"$m" >/dev/null; then out+=("$m"); fi
  done
  echo "${out[*]:-}"
}

# print modules and profiles, then exit.
list_modules() {
  step "modules"
  local m
  for m in "${MODULES[@]}"; do
    printf '  %s%-10s%s %s\n' "$c_bold" "$m" "$c_reset" "$(module_blurb "$m")"
  done
  step "profiles"
  printf '  %-12s %s\n' "minimal"     "base"
  printf '  %-12s %s\n' "standard"    "base toolchain python"
  printf '  %-12s %s\n' "workstation" "base toolchain python dotfiles"
  printf '  %-12s %s\n' "full"        "base toolchain python go embedded dotfiles"
  printf '  %-12s %s\n' "embedded"    "base toolchain embedded"
}

# ---- main -------------------------------------------------------------------
main() {
  detect_platform
  [ "$HBES_PM" = brew ] && ensure_brew
  need_sudo

  # banner — suppressed on re-entry from the TUI so it only shows once
  if [ -z "${HBES_QUIET_BANNER:-}" ]; then
    printf '%s\n' "${c_bold}half baked env${c_reset} ${c_dim}v${HBES_VERSION}${c_reset}"
    printf '%sworks on my machine. ship it.%s\n' "$c_dim" "$c_reset"
    local sel=""; [ "$HBES_SELINUX" -eq 1 ] && sel=" ${c_dim}· selinux${c_reset}"
    printf '%splatform%s %s %s·%s %s%s\n' \
      "$c_dim" "$c_reset" "$HBES_DISTRO" "$c_dim" "$c_reset" "$HBES_PM" "$sel"
  fi

  local selected=() m reason def config="" want_tui=0 uninstall=0 skip_installed=0
  HBES_ALL=0

  # parse args. module-selecting flags fill `selected`; the rest are modifiers.
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --all) HBES_ALL=1; selected=("${MODULES[@]}") ;;
      --base|--toolchain|--python|--rust|--go|--node|--embedded|--dotfiles) selected+=("${1#--}") ;;
      --profile)
        shift; [ "$#" -gt 0 ] || { err "--profile needs a name (see --list)"; exit 1; }
        read -r -a selected <<< "$(profile_modules "$1")" || { err "unknown profile: $1"; exit 1; } ;;
      --profile=*)
        read -r -a selected <<< "$(profile_modules "${1#--profile=}")" || { err "unknown profile: ${1#--profile=}"; exit 1; } ;;
      --config) shift; [ "$#" -gt 0 ] || { err "--config needs a path"; exit 1; }; config="$1" ;;
      --config=*) config="${1#--config=}" ;;
      --dry-run|-n) DRY_RUN=1 ;;
      --tui) want_tui=1 ;;
      --uninstall) uninstall=1 ;;
      --skip-installed) skip_installed=1 ;;
      --status) show_status; exit 0 ;;
      --recommend) print_recommendations; echo; log "run again with --profile / module flags to install."; exit 0 ;;
      --list) list_modules; exit 0 ;;
      -h|--help) grep '^#' "$0" | sed 's/^#//'; exit 0 ;;
      *) warn "unknown arg: $1" ;;
    esac
    shift
  done

  # --config: let an hbes.toml declare modules, per-package overrides, dry-run.
  if [ -n "$config" ]; then
    [ -f "$config" ] || { err "config not found: $config"; exit 1; }
    has python3 || { err "--config needs python3 to read toml"; exit 1; }
    eval "$(python3 "${SCRIPT_DIR}/config.py" "$config")" || { err "could not parse $config"; exit 1; }
    read -r -a selected <<< "${HBES_CONFIG_MODULES:-}"
    [ "${HBES_DRY_RUN:-0}" -eq 1 ] && DRY_RUN=1
    log "config: ${config} -> [${selected[*]}]"
  fi

  # --uninstall: revert the named modules, or everything in the lockfile.
  if [ "$uninstall" -eq 1 ]; then
    if [ "${#selected[@]}" -eq 0 ]; then
      read -r -a selected <<< "$(lockfile_modules)" || true
    fi
    if [ "${#selected[@]}" -eq 0 ]; then
      warn "nothing to uninstall (no modules named, lockfile empty)."
      exit 0
    fi
    [ "$DRY_RUN" -eq 1 ] && warn "dry-run: nothing will actually be reverted."
    for m in "${selected[@]}"; do
      run_uninstall "$m"
      unrecord_lock "$m"
    done
    step "done"
    if [ "$DRY_RUN" -eq 1 ]; then log "[dry-run] uninstalled: ${selected[*]}"
    else log "uninstalled: ${selected[*]}"; fi
    exit 0
  fi

  # launch_tui — hand off to the questionary selector with recommended modules
  # pre-checked. it re-invokes install.sh with the chosen module flags.
  launch_tui() {
    local pre; pre="$(recommended_list)"
    if [ "$DRY_RUN" -eq 1 ]; then
      exec python3 "${SCRIPT_DIR}/tui.py" --preselect "$pre" --dry-run
    fi
    exec python3 "${SCRIPT_DIR}/tui.py" --preselect "$pre"
  }

  # --tui: explicit request for the checkbox selector.
  if [ "$want_tui" -eq 1 ]; then
    has python3 || { err "--tui needs python3"; exit 1; }
    launch_tui
  fi

  # nothing chosen on the command line -> interactive.
  if [ "${#selected[@]}" -eq 0 ] && [ -z "$config" ]; then
    if [ ! -t 0 ]; then
      err "no modules given and this isn't an interactive terminal."
      err "use --all, --profile <name>, --config FILE, or --recommend."
      exit 1
    fi
    # prefer the checkbox TUI; fall back to recommendation-driven y/n prompts.
    if has python3 && python3 -c 'import questionary' >/dev/null 2>&1; then
      launch_tui
    fi
    print_recommendations
    echo
    for m in "${MODULES[@]}"; do
      if reason="$(recommend_"$m")"; then def=y; else def=n; fi
      ask "install ${m} ($(module_blurb "$m"))" "$def" && selected+=("$m")
    done
  fi

  if [ "${#selected[@]}" -eq 0 ]; then
    warn "nothing selected. exiting."
    exit 0
  fi

  # --skip-installed: drop modules already recorded in the lockfile.
  if [ "$skip_installed" -eq 1 ]; then
    local before keep=(); before=" $(lockfile_modules) "
    for m in "${selected[@]}"; do
      case "$before" in
        *" $m "*) log "skip ${m} — already installed (omit --skip-installed to force)" ;;
        *) keep+=("$m") ;;
      esac
    done
    selected=()
    [ "${#keep[@]}" -gt 0 ] && selected=("${keep[@]}")
    if [ "${#selected[@]}" -eq 0 ]; then
      log "everything selected is already installed. nothing to do."
      exit 0
    fi
  fi

  [ "$DRY_RUN" -eq 1 ] && warn "dry-run: nothing will actually be installed or written."

  step "syncing ${HBES_PM} index + platform setup"
  pm_update
  platform_setup

  for m in "${selected[@]}"; do
    run_module "$m"
  done

  step "done"
  if [ "$DRY_RUN" -eq 1 ]; then log "[dry-run] modules: ${selected[*]}"
  else log "modules: ${selected[*]}"; fi
  [ "$DRY_RUN" -eq 0 ] && log "recorded in ${LOCKFILE} — see ./install.sh --status"
  log "if it works, we're still going to figure out why."
}

main "$@"
