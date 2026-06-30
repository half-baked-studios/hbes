# Changelog

Notable changes to hbes. Format loosely follows [Keep a Changelog]; the project
is half baked, and so are the version bumps.

[Keep a Changelog]: https://keepachangelog.com/

## [0.6.1] - 2026-06-30

### Added
- dotfiles wires in per-user toolchains for new shells: sources `~/.cargo/env`
  (rust) and adds fnm to `PATH` + `eval`s `fnm env` (node), if installed.

### Fixed
- `--help` no longer prints the script's shebang line.
- bootstrap filters git's benign "tag is not a commit" note on pinned (tag)
  clones, without swallowing real errors.

## [0.6.0] - 2026-06-30

### Added
- Per-package-manager overrides in `hbes.toml`: a `[packages.<module>.<pm>]`
  sub-table (e.g. `[packages.toolchain.dnf]`) applies only on that package
  manager, on top of the global `[packages.<module>]` add/remove.
- `--version` / `-V` — print the version and exit.
- `--yes` / `-y` — skip the uninstall confirmation (for automation/CI).
- This CHANGELOG and a credits section.

### Fixed
- README title typos.

## [0.5.0] - 2026-06

### Added
- RHEL-likes auto-enable **EPEL** before the index sync (fzf/ripgrep/bat live
  there, not in the base repos); skipped on Fedora, which ships them.
- Debian `--backports` — opt into newer packages via `apt -t <codename>-backports`.
- Conservative uninstaller: every module has a `*_down`; `pkg_remove` dispatch
  (apt remove / dnf remove / pacman -R / brew uninstall — no purge, no
  dependency cascade); `--uninstall` confirms before removing.

### Fixed
- dnf: `vim` → `vim-enhanced` (RHEL/Rocky 9 has no bare `vim`); dropped `curl`
  from the dnf list (conflicts with `curl-minimal`).

## [0.4.0] - 2026-06

### Added
- Multi-platform support: **apt / dnf / yum / pacman / brew**, with each module's
  package list mapped per manager.
- SELinux-aware on RHEL (`restorecon` on files written); Arch bootstraps the
  **yay** AUR helper; macOS verifies Homebrew; **WSL** detected and tagged.
- Platform badges in the README.

## [0.3.0]

### Added
- `hbes.toml` config with per-package overrides; questionary **TUI** selector;
  **dotfiles** module (idempotent, marker-bounded); `--dry-run`.
- Lockfile is cumulative: `--status`, `--skip-installed`, `--uninstall`.
- **rust / go / node** modules; the brew-style `curl | bash` bootstrap.
- CI: shellcheck + real installs.

## [0.2.0]

### Added
- `--recommend` — probes the box and suggests modules.
- Named profiles (`minimal` / `standard` / `full` / …).

## [0.1.0]

### Added
- Initial release: `base` / `toolchain` / `python` / `embedded` modules over apt.
