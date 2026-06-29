# hbes — Half Baked Studio Ofiicial Enviourment Setup Tool

[![ci](https://github.com/half-baked-studios/hbes/actions/workflows/ci.yml/badge.svg)](https://github.com/half-baked-studios/hbes/actions/workflows/ci.yml)
&nbsp;
![Debian/Ubuntu](https://img.shields.io/badge/Debian%2FUbuntu-apt-A81D33?logo=debian&logoColor=white)
![Fedora/RHEL](https://img.shields.io/badge/Fedora%2FRHEL-dnf-294172?logo=fedora&logoColor=white)
![Arch](https://img.shields.io/badge/Arch-pacman-1793D1?logo=archlinux&logoColor=white)
![macOS](https://img.shields.io/badge/macOS-brew-000000?logo=apple&logoColor=white)
![Windows/WSL](https://img.shields.io/badge/Windows-WSL-0078D6?logo=linux&logoColor=white)

works on my machine. ship it.

A dead-simple bootstrap for a dev box — Debian/Ubuntu, RHEL/Fedora, Arch, or
macOS. Picks the tools you actually reinstall every time — gcc, make, pip, the
usual — figures out your package manager (apt/dnf/pacman/brew), and gets out of
the way. Just bash that runs the installs for you and writes down what it did.

## what it does

- works across **apt / dnf / pacman / brew** — same modules, names mapped per platform
- installs the non-negotiables (compiler, git, curl)
- optional toolchain extras (clang, cmake, ninja, gdb)
- optional python tooling (pip, venv, pipx) — PEP 668 aware
- language toolchains: rust (rustup), go (system pkg), node (fnm + LTS)
- optional embedded/cross tools (arm gcc, openocd, dtc)
- optional dotfiles (shell aliases + vim defaults, reversible)
- probes the box and **recommends** what's actually worth installing
- `--dry-run` previews everything; `--status` / `--uninstall` use the lockfile
- writes an `hbes.lock` recording what got installed (and when)

## platforms

hbes detects your package manager and maps each module's package list to it
(so `build-essential` becomes `base-devel` on Arch, the Xcode CLT on macOS, etc):

| platform                | manager            | platform notes                                            |
|-------------------------|--------------------|-----------------------------------------------------------|
| Debian / Ubuntu         | `apt`              | the original target; `--backports` opts into newer packages |
| RHEL / Fedora / CentOS  | `dnf` (or `yum`)   | auto-enables **EPEL** on RHEL-likes (fzf/rg/bat live there); SELinux-aware |
| Arch                    | `pacman`           | also bootstraps **yay** (AUR helper) on first install     |
| macOS                   | `brew`             | checks Homebrew is present, points you at the installer if not |
| Windows (via WSL)       | `apt` / `dnf` / …  | runs as-is inside WSL — it's real Linux; native Windows is unsupported |

Same flags everywhere. Each run prints the detected `platform <distro> · <pm>`
(with a `· wsl` / `· selinux` tag where relevant) so you know what it's driving.

**Windows:** no native support — there's no system package manager to drive.
Use [WSL](https://learn.microsoft.com/windows/wsl/): `wsl --install`, open your
distro, and run hbes exactly like on Linux. From Git Bash / MSYS / Cygwin it
bails with a clear pointer to WSL instead of failing cryptically.

## quick start

one line, like brew — clones into `~/.hbes` and drops you in the picker:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/half-baked-studios/hbes/main/bootstrap.sh)"
```

want it unattended? pipe it and pass flags after `--`:

```bash
curl -fsSL https://raw.githubusercontent.com/half-baked-studios/hbes/main/bootstrap.sh | bash -s -- --profile standard
curl -fsSL .../bootstrap.sh | bash -s -- --all --dry-run
```

It uses git if you have it, a tarball if you don't. Override `HBES_DIR` to
clone somewhere other than `~/.hbes`.

Piping a script into a shell makes you nervous? Good instinct — audit it:

```bash
curl -fsSL .../bootstrap.sh | less                          # read it first
HBES_REF=v0.5.0 /bin/bash -c "$(curl -fsSL .../bootstrap.sh)" # pin a version
curl -fsSL .../bootstrap.sh | bash -s -- --all --dry-run      # preview, install nothing
```

Before handing off, bootstrap prints the repo, ref, and exact commit it
fetched, so you always know which version you're about to run.

## usage

…or clone it yourself and drive `install.sh` directly:

```bash
git clone https://github.com/half-baked-studios/hbes
cd hbes
chmod +x install.sh

./install.sh                 # interactive — checkbox TUI if available, else y/n
./install.sh --tui           # force the checkbox selector (python + questionary)
./install.sh --recommend     # probe the box, print suggestions, install nothing
./install.sh --all           # everything, no prompts
./install.sh --base --python # just the modules you name
./install.sh --profile std   # install a named bundle (alias: --profile=standard)
./install.sh --config hbes.toml   # drive the whole run from a file
./install.sh --dry-run --all # show what would happen, touch nothing
./install.sh --skip-installed --all  # only what's not already in the lockfile
./install.sh --backports --toolchain # (Debian) pull newer versions from backports
./install.sh --status        # what did hbes install here, and when
./install.sh --uninstall --dotfiles  # revert a module (removes its packages, asks first)
./install.sh --list          # list modules and profiles
```

`--dry-run` composes with everything — it prints every package install and every
dotfile write instead of running them, and never touches the lockfile.

### recommend

`--recommend` (and the interactive defaults) inspect the machine instead of
guessing: missing `gcc`/`cmake`/`python` flips a module on, and `embedded` only
gets suggested when there's actually hardware attached (a `/dev/ttyUSB*` /
`/dev/ttyACM*` serial device, or a debug probe / serial bridge on USB). Every
line tells you *why* it was suggested — nothing is installed until you say so.

### profiles

Declare a setup instead of clicking through it:

| profile       | modules                                   |
|---------------|-------------------------------------------|
| `minimal`     | base                                      |
| `standard`    | base, toolchain, python                   |
| `workstation` | base, toolchain, python, dotfiles         |
| `full`        | base, toolchain, python, go, embedded, dotfiles|
| `embedded`    | base, toolchain, embedded                 |

### config file (`hbes.toml`)

For a setup you keep around, declare it in a file instead of remembering flags.
Copy [`hbes.toml.example`](hbes.toml.example) to `hbes.toml`, edit, and run
`./install.sh --config hbes.toml`:

```toml
modules = ["base", "toolchain", "python", "dotfiles"]
dry_run = false

# per-package overrides — tweak a module without editing its .sh
[packages.toolchain]
add    = ["mold", "ccache"]
remove = ["valgrind"]

[packages.base]
remove = ["vim"]
```

`add`/`remove` adjust a module's package list, so you get the module's
structure with your packages. (`--config` parses TOML with python3 — already
there on most systems, and installed by the `python` module anyway.)

### interactive (TUI by default)

Plain `./install.sh` picks the nicest selector your box can run, with the
**recommended modules pre-selected** either way:

1. `questionary` available → a checkbox TUI (space toggles, enter confirms)
2. otherwise → the recommendation-driven `y/n` prompts
3. not a terminal at all (CI, piped) → it tells you to use `--all` / `--profile`
   / `--config` instead of hanging

`--tui` forces the checkbox path (`pipx install questionary` for the nice UI;
there's a plain numbered fallback if it's missing). Either way the selector just
hands your picks back to `install.sh`.

## modules

| module      | what's in it                                  |
|-------------|-----------------------------------------------|
| `base`      | build-essential, git, curl, wget, vim         |
| `toolchain` | clang, lld, cmake, ninja, pkg-config, gdb     |
| `python`    | python3, pip, venv, dev headers, pipx         |
| `rust`      | rustup + stable toolchain (per-user, no apt)  |
| `go`        | go toolchain + gopls (system pkg)             |
| `node`      | fnm + node LTS (per-user, no apt)             |
| `embedded`  | arm-none-eabi gcc, aarch64 cross, openocd, dtc|
| `dotfiles`  | tmux/fzf/rg/bat + managed `~/.bashrc`, `~/.vimrc`|

`rust`/`go`/`node` are opt-in: `--recommend` only suggests them when the matching
toolchain is already partway installed, or there's a project file (`Cargo.toml`,
`go.mod`, `package.json`) in the current directory.

Each module is a standalone file in `modules/`. Adding one is just
dropping in `modules/<name>.sh` with a `hbes_<name>()` function — use the
shared `pkg_install`, `overrides`, and `write_block` helpers so dry-run and
per-package overrides work for free. Add an `hbes_<name>_down()` and the module
becomes `--uninstall`-able too.

The `dotfiles` module writes **marker-bounded** blocks
(`# >>> hbes >>>` … `# <<< hbes <<<`) into your rc files, so it's idempotent
and you reverse it by deleting the block (or `--uninstall --dotfiles`). It never
clobbers what's already there.

### lockfile (`hbes.lock`)

Every install appends to `hbes.lock` — one `module<TAB>timestamp` line each,
cumulative, newest write wins. That record drives:

- `--status` — list what hbes installed here, and when
- `--skip-installed` — re-run a profile and skip what's already recorded
- `--uninstall [modules]` — revert named modules, or everything in the lockfile.
  Conservative by default: removes the packages a module installed (**no purge,
  no dependency cascade** — orphaned deps stay), strips dotfiles blocks, and
  `rustup self uninstall` / removes fnm for the per-user toolchains. It prints
  what it'll remove and **asks before touching anything** (skip the prompt only
  by piping `y`). Pair with `--dry-run` to preview.

## what this is not

- not a distro
- not idempotent-guaranteed (re-running is usually fine, the package manager handles it)
- not tested on every release — but CI runs the real installer on Ubuntu,
  Fedora, Arch, and macOS each push (shellcheck + a genuine install on each)

## roadmap (half baked, naturally)

done so far:

- [x] profiles, `--recommend`, `hbes.toml` config + per-package overrides
- [x] a real TUI selector (python + questionary)
- [x] dotfiles module, `dry-run`, `--status` / `--skip-installed` / `--uninstall`
- [x] rust / go / node modules
- [x] the brew-style `curl | bash` bootstrap
- [x] multi-platform: apt / dnf / pacman / brew (SELinux-aware, bootstraps yay)
- [x] CI: shellcheck + a real install on Ubuntu, Fedora, Arch, and macOS

still half baked:

- [x] uninstallers for every module (`*_down`, conservative package removal)
- [x] RHEL EPEL auto-enable; Debian `--backports`
- [x] tagged releases so `HBES_REF=vX.Y.Z` pins something real (`v0.5.0`)
- [ ] per-platform package overrides in `hbes.toml` (today overrides are global)

---

if it works, we're still going to figure out why. if it doesn't,
that's tonight's problem.
