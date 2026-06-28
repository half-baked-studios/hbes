# hbes — half baked env setup

works on my machine. ship it.

A dead-simple bootstrap for a Debian dev box. Picks the tools you
actually reinstall every time — gcc, make, pip, the usual — and gets
out of the way. No distro, no magic. Just bash that runs apt for you
and writes down what it did.

## what it does

- installs the non-negotiables (`build-essential`, git, curl)
- optional toolchain extras (clang, cmake, ninja, gdb)
- optional python tooling (pip, venv, pipx) — PEP 668 aware
- optional embedded/cross tools (arm gcc, openocd, dtc)
- optional dotfiles (shell aliases + vim defaults, reversible)
- probes the box and **recommends** what's actually worth installing
- `--dry-run` to see exactly what it would do, changing nothing
- writes an `hbes.lock` so you know what got installed

## usage

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
./install.sh --list          # list modules and profiles
```

`--dry-run` composes with everything — it prints every `apt-get` and every
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
| `full`        | base, toolchain, python, embedded, dotfiles|
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

`add`/`remove` adjust a module's apt package list, so you get the module's
structure with your packages. (`--config` parses TOML with python3 — already
there on any Debian box, and installed by the `python` module anyway.)

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
| `embedded`  | arm-none-eabi gcc, aarch64 cross, openocd, dtc|
| `dotfiles`  | tmux/fzf/rg/bat + managed `~/.bashrc`, `~/.vimrc`|

Each module is a standalone file in `modules/`. Adding one is just
dropping in `modules/<name>.sh` with a `hbes_<name>()` function — use the
shared `pkg_install`, `overrides`, and `write_block` helpers so dry-run and
per-package overrides work for free.

The `dotfiles` module writes **marker-bounded** blocks
(`# >>> hbes >>>` … `# <<< hbes <<<`) into your rc files, so it's idempotent
and you reverse it by deleting the block. It never clobbers what's already there.

## what this is not

- not a distro
- not idempotent-guaranteed (re-running is usually fine, apt handles it)
- not tested on every Debian release (PRs welcome when it breaks)

## roadmap (half baked, naturally)

- [x] profiles so you can declare a setup instead of clicking through
- [x] `--recommend` that probes the box and suggests modules
- [x] `hbes.toml` config (profiles in a file, per-package overrides)
- [x] a real TUI selector (python + questionary)
- [x] dotfiles module (shell, editor)
- [x] dry-run mode

the list is empty. that's the most half-baked thing here — we'll
think of more.

---

if it works, we're still going to figure out why. if it doesn't,
that's tonight's problem.
