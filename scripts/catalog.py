#!/usr/bin/env python3
"""Builds the catalog BatoX reads (see docs/manifest.md).

    catalog.py release-info EXTENSION_DIR DIST_DIR REPO TAG
        Prints <id>.json for a release: the manifest plus the packages in
        DIST_DIR, with their download URL, SHA-256 and size.

    catalog.py merge REPO
        Prints catalog.json: the <id>.json of the latest release of every
        extension in extensions/. Reads GitHub's API (GH_TOKEN or GITHUB_TOKEN
        raises the rate limit).
"""

import datetime
import hashlib
import json
import os
import re
import sys
import urllib.parse
import urllib.request

PACKAGE_RE = r"^{id}-{version}-linux-(arm64|amd64)\.tar\.gz$"


def release_info(folder, dist, repo, tag):
    with open(os.path.join(folder, "extension.json"), encoding="utf-8") as f:
        info = json.load(f)
    pattern = re.compile(PACKAGE_RE.format(id=re.escape(info["id"]), version=re.escape(info["version"])))
    base = f"https://github.com/{repo}/releases/download/{urllib.parse.quote(tag)}"
    packages = {}
    for name in sorted(os.listdir(dist)):
        m = pattern.match(name)
        if not m:
            continue
        path = os.path.join(dist, name)
        digest = hashlib.sha256()
        with open(path, "rb") as f:
            for chunk in iter(lambda: f.read(1 << 20), b""):
                digest.update(chunk)
        packages[m.group(1)] = {
            "url": f"{base}/{name}",
            "sha256": digest.hexdigest(),
            "size": os.path.getsize(path),
        }
    missing = set(info["platforms"]) - set(packages)
    if missing:
        sys.exit(f"no package for {sorted(missing)} in {dist}")
    info["packages"] = packages
    return info


def api(url):
    req = urllib.request.Request(url, headers={"Accept": "application/vnd.github+json"})
    token = os.environ.get("GH_TOKEN") or os.environ.get("GITHUB_TOKEN")
    if token:
        req.add_header("Authorization", f"Bearer {token}")
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.load(r)


def version_key(v):
    return tuple(int(x) for x in v.split("."))


def merge(repo):
    releases = []
    page = 1
    while True:
        batch = api(f"https://api.github.com/repos/{repo}/releases?per_page=100&page={page}")
        releases += batch
        if len(batch) < 100:
            break
        page += 1

    extensions = []
    for ext in sorted(os.listdir("extensions")):
        tag_re = re.compile(rf"^{re.escape(ext)}-v(\d+\.\d+\.\d+)$")
        found = [
            (version_key(m.group(1)), r) for r in releases
            if not r.get("draft") and not r.get("prerelease") and (m := tag_re.match(r["tag_name"]))
        ]
        if not found:
            print(f"{ext}: not released yet, left out", file=sys.stderr)
            continue
        _, latest = max(found, key=lambda x: x[0])
        asset = next((a for a in latest["assets"] if a["name"] == f"{ext}.json"), None)
        if asset is None:
            sys.exit(f"{latest['tag_name']} has no {ext}.json")
        with urllib.request.urlopen(asset["browser_download_url"], timeout=30) as r:
            extensions.append(json.load(r))
        print(f"{ext}: {latest['tag_name']}", file=sys.stderr)

    return {
        "schema": 1,
        "updated": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "extensions": extensions,
    }


def main(argv):
    if len(argv) == 5 and argv[0] == "release-info":
        out = release_info(*argv[1:])
    elif len(argv) == 2 and argv[0] == "merge":
        out = merge(argv[1])
    else:
        sys.exit(__doc__)
    json.dump(out, sys.stdout, indent=2, ensure_ascii=False)
    print()


if __name__ == "__main__":
    main(sys.argv[1:])
