#!/usr/bin/env python3
"""Checks extension manifests against docs/manifest.md.

    validate.py [EXTENSION_DIR ...] [--version VERSION]

Without folders, checks every folder in extensions/. With --version, also
checks that the (single) extension has that version, as a release tag needs.
"""

import json
import os
import re
import sys

ID_RE = re.compile(r"^[a-z0-9][a-z0-9-]{0,39}$")
KEY_RE = re.compile(r"^[a-z][a-z0-9_]{0,39}$")
VERSION_RE = re.compile(r"^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$")
PLATFORMS = {"arm64", "amd64"}
PERMISSIONS = {"network", "audio", "screen", "games", "power"}
CONTROLS = {"toggle", "select", "range", "number", "text"}


def check_setting(s, where):
    errors = []
    key = s.get("key")
    if not isinstance(key, str) or not KEY_RE.match(key):
        errors.append(f"{where}: key {key!r} must be lower-case letters, digits and _")
    for field in ("label", "default"):
        if not isinstance(s.get(field), str):
            errors.append(f"{where}: {field} must be a string")
    control = s.get("control") or {}
    kind = control.get("type")
    if kind not in CONTROLS:
        errors.append(f"{where}: control type {kind!r} must be one of {sorted(CONTROLS)}")
        return errors
    default = s.get("default")
    if not isinstance(default, str):
        return errors
    if kind == "toggle" and default not in ("0", "1"):
        errors.append(f"{where}: a toggle's default is \"0\" or \"1\"")
    if kind == "select":
        values = [c.get("value") for c in control.get("choices") or []]
        if len(values) < 2 or default not in values:
            errors.append(f"{where}: a select needs two choices or more, the default among them")
    if kind in ("range", "number"):
        try:
            n = float(default)
        except ValueError:
            errors.append(f"{where}: the default must be a number")
            return errors
        if kind == "range":
            lo, hi = control.get("min"), control.get("max")
            if not isinstance(lo, (int, float)) or not isinstance(hi, (int, float)) or lo >= hi:
                errors.append(f"{where}: a range needs min < max")
            elif not lo <= n <= hi:
                errors.append(f"{where}: the default must be between min and max")
    return errors


def check(folder, version=None):
    path = os.path.join(folder, "extension.json")
    try:
        with open(path, encoding="utf-8") as f:
            m = json.load(f)
    except (OSError, ValueError) as e:
        return [f"{path}: {e}"]

    errors = []
    name = os.path.basename(os.path.normpath(folder))
    if m.get("schema") != 1:
        errors.append(f"{path}: schema must be 1")
    if not isinstance(m.get("id"), str) or not ID_RE.match(m["id"]):
        errors.append(f"{path}: id must be lower-case letters, digits and -")
    elif m["id"] != name:
        errors.append(f"{path}: id {m['id']!r} must match the folder name {name!r}")
    if not isinstance(m.get("version"), str) or not VERSION_RE.match(m["version"]):
        errors.append(f"{path}: version must look like 1.2.3")
    elif version is not None and m["version"] != version:
        errors.append(f"{path}: version is {m['version']}, but the tag says {version}")
    for field in ("name", "summary", "license"):
        if not isinstance(m.get(field), str) or not m[field].strip():
            errors.append(f"{path}: {field} is required")
    if isinstance(m.get("summary"), str) and len(m["summary"]) > 120:
        errors.append(f"{path}: summary is longer than 120 characters")
    platforms = m.get("platforms")
    if not isinstance(platforms, list) or not platforms or not set(platforms) <= PLATFORMS:
        errors.append(f"{path}: platforms must list some of {sorted(PLATFORMS)}")
    permissions = m.get("permissions")
    if not isinstance(permissions, list) or not set(permissions) <= PERMISSIONS:
        errors.append(f"{path}: permissions must be some of {sorted(PERMISSIONS)}")
    run = m.get("run") or {}
    command = run.get("command")
    if not isinstance(command, str) or command.startswith("/") or ".." in command.split("/"):
        errors.append(f"{path}: run.command must be a path inside the package")
    timeout = run.get("stopTimeoutSeconds", 10)
    if not isinstance(timeout, int) or not 1 <= timeout <= 120:
        errors.append(f"{path}: run.stopTimeoutSeconds must be 1 to 120")

    keys = set()
    for i, s in enumerate(m.get("settings") or []):
        where = f"{path}: settings[{i}]"
        if not isinstance(s, dict):
            errors.append(f"{where}: must be an object")
            continue
        errors += check_setting(s, where)
        if s.get("key") in keys:
            errors.append(f"{where}: key {s['key']!r} is repeated")
        keys.add(s.get("key"))
    return errors


def main(argv):
    version = None
    if "--version" in argv:
        i = argv.index("--version")
        version = argv[i + 1]
        argv = argv[:i] + argv[i + 2:]
    folders = argv or sorted(
        os.path.join("extensions", d) for d in os.listdir("extensions")
        if os.path.isdir(os.path.join("extensions", d))
    )
    if version is not None and len(folders) != 1:
        sys.exit("--version needs exactly one extension folder")
    errors = []
    for folder in folders:
        errors += check(folder, version)
    for e in errors:
        print(e, file=sys.stderr)
    if errors:
        sys.exit(1)
    print(f"{len(folders)} manifest(s) OK")


if __name__ == "__main__":
    main(sys.argv[1:])
