# Extension format

This is the contract between this repository and BatoX: what an extension declares, what its
package contains, how BatoX runs it, and the catalog BatoX reads.

- [The manifest: extension.json](#the-manifest-extensionjson)
- [Settings](#settings)
- [Permissions](#permissions)
- [The package](#the-package)
- [How BatoX runs an extension](#how-batox-runs-an-extension)
- [The catalog](#the-catalog)

## The manifest: extension.json

Every extension has a folder in `extensions/<id>/` with an `extension.json`:

```json
{
  "schema": 1,
  "id": "airplay",
  "name": "AirPlay receiver",
  "version": "1.0.0",
  "summary": "Play music from an iPhone, iPad or Mac through the console.",
  "description": "Choose the console in AirPlay, in Spotify, Apple Music or any app...",
  "homepage": "https://github.com/monteirohat/batox-extensions/tree/main/extensions/airplay",
  "license": "MIT; includes shairport-sync (MIT), FFmpeg, libconfig and libsoxr (LGPL-2.1)",
  "platforms": ["arm64", "amd64"],
  "permissions": ["network", "audio"],
  "run": { "command": "bin/start.sh", "stopTimeoutSeconds": 10 },
  "settings": [
    { "key": "name", "label": "Name on the phone", "default": "Batocera", "control": { "type": "text" } }
  ]
}
```

| Field | Required | Description |
|---|---|---|
| `schema` | yes | `1`, the version of this format. |
| `id` | yes | Lower-case letters, digits and `-`; the folder name. Never changes. |
| `name` | yes | What BatoX shows, in English, sentence case. |
| `version` | yes | Semantic version (`1.2.3`). Releasing it needs the tag `<id>-v<version>`. |
| `summary` | yes | One sentence for the catalog card, up to 120 characters. |
| `description` | no | A longer explanation for the extension's page. |
| `homepage` | no | Where to read more. |
| `license` | yes | The extension's license and those of what it bundles. |
| `platforms` | yes | `arm64` (Raspberry Pi and other ARM boards) and/or `amd64` (x86_64 PCs). |
| `permissions` | yes | What the extension can do; shown before installing. See [Permissions](#permissions). |
| `run.command` | yes | The program to start, relative to the package root. |
| `run.stopTimeoutSeconds` | no | How long BatoX waits after `SIGTERM` before `SIGKILL`. Default `10`. |
| `settings` | no | What the user can change. See [Settings](#settings). |

## Settings

Each setting is shown in BatoX with the same controls as the Batocera settings screen:

```json
{ "key": "volume_boost", "label": "Volume boost", "description": "Raise the AirPlay sound...",
  "default": "100", "control": { "type": "range", "min": 100, "max": 200, "step": 10, "unit": "%" } }
```

| Field | Description |
|---|---|
| `key` | Lower-case letters, digits and `_`. Becomes an environment variable (below). |
| `label` | The setting's name in BatoX. |
| `description` | Optional help text. |
| `default` | The value before the user changes it, always a string. |
| `control` | `toggle` (`"1"` or `"0"`), `select` (with `choices`: `[{"value": "...", "label": "..."}]`), `range` (with `min`, `max`, optional `step` and `unit`), `number` or `text`. |

Values are always strings. Changing a setting restarts the extension.

## Permissions

| Permission | Meaning |
|---|---|
| `network` | Listens on the local network (for example, to be found by phones). |
| `audio` | Plays sound, or changes the volume of other programs (such as silencing EmulationStation's music). |
| `screen` | Draws on the TV, on top of games. |
| `games` | Closes or launches games through EmulationStation. |
| `power` | Can restart or power off the console. |

Extensions run as `root` on Batocera, like every service there, so permissions describe intent;
they are not a sandbox. That is why BatoX only installs extensions from this catalog, checks each
package's SHA-256, and runs no web page or script of an extension inside the BatoX web app.

## The package

A release publishes one package per platform, `<id>-<version>-linux-<arch>.tar.gz`, with no
top-level folder:

```
extension.json        the manifest, as released
bin/                  programs; run.command points here
lib/                  libraries Batocera lacks (found through an $ORIGIN rpath, not LD_LIBRARY_PATH)
LICENSES/             the licenses of everything bundled
SOURCES.md            versions and source links of everything bundled
```

Programs must run on Batocera 43 or newer: built against a glibc no newer than Batocera's (Debian
bookworm, glibc 2.36, is used here), and linked only to libraries Batocera ships or that are in
`lib/`. The build scripts check this.

## How BatoX runs an extension

BatoX installs an extension in `/userdata/system/batox/extensions/<id>/`, which survives Batocera
updates:

```
<id>/<version>/       the unpacked package
<id>/current          link to the version in use (updates switch it atomically)
<id>/data/            the extension's own files, kept across updates
<id>/data/log         its output (rotated by BatoX)
```

When an extension is enabled, BatoX starts `run.command` at boot and keeps it running:

- the working directory is the package root;
- it runs in a process group of its own; to stop it, BatoX sends `SIGTERM` to the group, then
  `SIGKILL` after `run.stopTimeoutSeconds`. Clean up on `SIGTERM` (for example, give back the sound
  of other programs);
- if it exits unexpectedly, BatoX starts it again, waiting longer after each failure;
- standard output and error go to `data/log`.

Environment variables:

| Variable | Value |
|---|---|
| `BATOX_EXTENSION_ID` | The extension's `id`. |
| `BATOX_EXTENSION_DIR` | The package root (`<id>/current`). |
| `BATOX_EXTENSION_DATA` | `<id>/data`, writable, kept across updates. |
| `BATOX_SETTING_<KEY>` | Each setting's value; the key in capitals (`volume_boost` → `BATOX_SETTING_VOLUME_BOOST`). |
| `XDG_RUNTIME_DIR` | `/var/run`, where Batocera's PipeWire and sway sockets are. |

## The catalog

Each release also publishes `<id>.json`: the manifest plus its packages:

```json
{
  "schema": 1, "id": "airplay", "name": "AirPlay receiver", "version": "1.0.0", "...": "...",
  "packages": {
    "arm64": { "url": "https://github.com/.../airplay-1.0.0-linux-arm64.tar.gz", "sha256": "...", "size": 1234567 },
    "amd64": { "url": "https://github.com/.../airplay-1.0.0-linux-amd64.tar.gz", "sha256": "...", "size": 1234567 }
  }
}
```

After every release, the workflow gathers the latest `<id>.json` of every extension into
`catalog.json`, published in the `catalog` release:

```
https://github.com/monteirohat/batox-extensions/releases/download/catalog/catalog.json
```

```json
{ "schema": 1, "updated": "2026-11-15T20:00:00Z", "extensions": [ { "id": "airplay", "...": "..." } ] }
```

BatoX reads this file to show the catalog, downloads the package for the console's platform, and
refuses it unless its SHA-256 matches.
