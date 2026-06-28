# hbes — half baked env

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
- probes the box and **recommends** what's actually worth installing
- writes an `hbes.lock` so you know what got installed

## usage

```bash
git clone https://github.com/half-baked-studios/hbes
cd hbes
chmod +x install.sh

./install.sh                 # interactive — recommendations drive the defaults
./install.sh --recommend     # probe the box, print suggestions, install nothing
./install.sh --all           # everything, no prompts
./install.sh --base --python # just the modules you name
./install.sh --profile std   # install a named bundle (alias: --profile=standard)
./install.sh --list          # list modules and profiles
```

### recommend

`--recommend` (and the interactive defaults) inspect the machine instead of
guessing: missing `gcc`/`cmake`/`python` flips a module on, and `embedded` only
gets suggested when there's actually hardware attached (a `/dev/ttyUSB*` /
`/dev/ttyACM*` serial device, or a debug probe / serial bridge on USB). Every
line tells you *why* it was suggested — nothing is installed until you say so.

### profiles

Declare a setup instead of clicking through it:

| profile    | modules                                  |
|------------|------------------------------------------|
| `minimal`  | base                                     |
| `standard` | base, toolchain, python                  |
| `full`     | base, toolchain, python, embedded        |
| `embedded` | base, toolchain, embedded                |

## modules

| module      | what's in it                                  |
|-------------|-----------------------------------------------|
| `base`      | build-essential, git, curl, wget, vim         |
| `toolchain` | clang, lld, cmake, ninja, pkg-config, gdb     |
| `python`    | python3, pip, venv, dev headers, pipx         |
| `embedded`  | arm-none-eabi gcc, aarch64 cross, openocd, dtc|

Each module is a standalone file in `modules/`. Adding one is just
dropping in `modules/<name>.sh` with a `hbes_<name>()` function.

## what this is not

- not a distro
- not idempotent-guaranteed (re-running is usually fine, apt handles it)
- not tested on every Debian release (PRs welcome when it breaks)

## roadmap (half baked, naturally)

- [x] profiles so you can declare a setup instead of clicking through
- [x] `--recommend` that probes the box and suggests modules
- [ ] `hbes.toml` config (profiles in a file, per-package overrides)
- [ ] a real TUI selector (python + questionary)
- [ ] dotfiles module (shell, editor)
- [ ] dry-run mode

---

if it works, we're still going to figure out why. if it doesn't,
that's tonight's problem.
