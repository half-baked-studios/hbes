#!/usr/bin/env python3
"""Parse an hbes.toml and emit shell assignments for install.sh to eval.

Schema (everything optional, but give it *something* to install):

    modules = ["base", "toolchain", "python"]   # which modules to run
    dry_run = false                             # force dry-run

    [packages.<module>]
    add    = ["pkg", ...]    # extra apt packages to pull into that module
    remove = ["pkg", ...]    # packages to drop from that module's default set
"""
import shlex
import sys

try:
    import tomllib  # py 3.11+
except ModuleNotFoundError:  # pragma: no cover
    try:
        import tomli as tomllib
    except ModuleNotFoundError:
        sys.exit("hbes: need python>=3.11 or the 'tomli' package to read toml")


def _words(value):
    return " ".join(str(v) for v in value)


def main():
    if len(sys.argv) != 2:
        sys.exit("usage: config.py <hbes.toml>")

    try:
        with open(sys.argv[1], "rb") as fh:
            data = tomllib.load(fh)
    except (OSError, tomllib.TOMLDecodeError) as exc:
        sys.exit(f"hbes: {exc}")

    modules = data.get("modules", [])
    if not isinstance(modules, list):
        sys.exit("hbes: 'modules' must be a list")
    print(f"HBES_CONFIG_MODULES={shlex.quote(_words(modules))}")
    print(f"HBES_DRY_RUN={1 if data.get('dry_run') else 0}")

    for mod, spec in (data.get("packages") or {}).items():
        if not isinstance(spec, dict):
            continue
        if spec.get("add"):
            print(f"export HBES_ADD_{mod}={shlex.quote(_words(spec['add']))}")
        if spec.get("remove"):
            print(f"export HBES_REMOVE_{mod}={shlex.quote(_words(spec['remove']))}")


if __name__ == "__main__":
    main()
