#!/usr/bin/env python3
"""hbes TUI — a questionary checkbox selector that hands back to install.sh.

Invoked by `./install.sh --tui`. Picks modules, then re-execs install.sh with
the matching flags. Falls back to a plain numbered prompt if questionary isn't
installed, so it always works on a fresh box.
"""
import argparse
import glob
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
INSTALL = os.path.join(HERE, "install.sh")

# stable, sensible display order; unknown modules sort to the end
ORDER = ["base", "toolchain", "python", "rust", "go", "node", "embedded", "dotfiles"]
BLURBS = {
    "base": "gcc, make, git, curl",
    "toolchain": "clang, cmake, ninja, gdb",
    "python": "pip, venv, pipx",
    "rust": "rustup + stable",
    "go": "golang-go + gopls",
    "node": "fnm + node LTS",
    "embedded": "arm gcc, openocd, dtc",
    "dotfiles": "shell aliases + vim defaults",
}


def discover_modules():
    names = [
        os.path.splitext(os.path.basename(p))[0]
        for p in glob.glob(os.path.join(HERE, "modules", "*.sh"))
    ]
    names.sort(key=lambda n: ORDER.index(n) if n in ORDER else len(ORDER))
    return names


def handoff(modules, dry_run):
    if not modules:
        print("hbes: nothing selected.")
        return 0
    flags = ["--" + m for m in modules]
    if dry_run:
        flags.append("--dry-run")
    # banner already shown by the parent run; don't repeat it on re-entry
    os.environ["HBES_QUIET_BANNER"] = "1"
    os.execvp("bash", ["bash", INSTALL, *flags])  # replaces this process


def pick_questionary(modules, preselect, dry_run):
    import questionary

    choices = [
        questionary.Choice(
            f"{m:<10} {BLURBS.get(m, '')}", value=m, checked=(m in preselect)
        )
        for m in modules
    ]
    picked = questionary.checkbox(
        "select modules to install (space toggles, enter confirms)", choices=choices
    ).ask()
    if picked is None:  # ctrl-c / esc
        return 1
    if not dry_run:
        dry_run = bool(
            questionary.confirm(
                "dry-run (show what would happen, touch nothing)?", default=False
            ).ask()
        )
    return handoff(picked, dry_run)


def pick_fallback(modules, preselect, dry_run):
    print("hbes: 'questionary' not installed — using the plain selector.")
    print("      nicer UI with:  pipx install questionary\n")
    for i, m in enumerate(modules, 1):
        star = " *" if m in preselect else "  "
        print(f" {star} {i}) {m:<10} {BLURBS.get(m, '')}")
    default = " ".join(str(i) for i, m in enumerate(modules, 1) if m in preselect)
    print("\n  * = recommended for this box")
    raw = input(f"numbers to install, or 'all' [{default}]: ").strip()
    if raw == "":
        picked = [m for m in modules if m in preselect]
    elif raw.lower() == "all":
        picked = list(modules)
    else:
        picked = [
            modules[int(tok) - 1]
            for tok in raw.replace(",", " ").split()
            if tok.isdigit() and 1 <= int(tok) <= len(modules)
        ]
    return handoff(picked, dry_run)


def main():
    parser = argparse.ArgumentParser(add_help=False)
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--preselect", default="")
    args, _ = parser.parse_known_args()

    modules = discover_modules()
    preselect = set(args.preselect.split())
    try:
        import questionary  # noqa: F401
    except ModuleNotFoundError:
        sys.exit(pick_fallback(modules, preselect, args.dry_run))
    sys.exit(pick_questionary(modules, preselect, args.dry_run))


if __name__ == "__main__":
    main()
