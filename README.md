<h1 align="center">BatoX Extensions</h1>

<p align="center">
  <strong>Official extensions for <a href="https://github.com/monteirohat/BatoX">BatoX</a>: add features to your Batocera console, installed and managed from the BatoX web app.</strong>
</p>

<p align="center">
  <a href="https://github.com/monteirohat/batox-extensions/actions/workflows/ci.yml"><img src="https://github.com/monteirohat/batox-extensions/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <a href="LICENSE"><img src="https://img.shields.io/github/license/monteirohat/batox-extensions" alt="License"></a>
</p>

---

BatoX's **Extensions** screen lists the extensions in this catalog. Install one with a click, turn
it on or off, and change its settings there: BatoX downloads the package for your console, checks
it, starts it with the console and keeps it running. Nothing to install by hand over SSH.

They run on Raspberry Pi (arm64) and x86_64 PCs with Batocera 43 or newer.

## Extensions

| Extension | What it does |
|---|---|
| [AirPlay receiver](extensions/airplay) | Play music from an iPhone, iPad or Mac through the console: choose it in AirPlay, in Spotify, Apple Music or any other app. EmulationStation's music goes quiet while it plays. |

## How it works

Each extension is a folder in `extensions/` with a manifest, `extension.json` (its name, version,
permissions, settings and how to run it), and a `build.sh` that builds its package. A release
publishes the packages for both platforms and updates `catalog.json`, the list BatoX reads.

[Extension format](docs/manifest.md) describes the manifest, the package, how BatoX runs an
extension and the catalog.

### Safety

Programs on Batocera run as `root`, extensions included, so BatoX:

- only installs extensions from this catalog;
- shows what an extension can do (its permissions) before installing it;
- refuses a package whose SHA-256 doesn't match the catalog;
- never runs an extension's own web page or script inside the BatoX web app.

Every package lists the versions, sources and licenses of what it bundles (`SOURCES.md` and
`LICENSES/`).

## Project layout

```
extensions/<id>/
  extension.json    the manifest
  build.sh          builds the package, in Debian bookworm
  files/            scripts that go into the package
  README.md         what it does, its settings and limits
scripts/
  validate.py       checks the manifests
  catalog.py        builds <id>.json for a release and catalog.json
docs/
  manifest.md       the extension format
```

## Releasing an extension

1. Raise `version` in its `extension.json` and commit.
2. Tag the commit `<id>-v<version>` and push the tag:

   ```bash
   git tag airplay-v1.0.0
   git push origin airplay-v1.0.0
   ```

The release workflow builds the extension on arm64 and amd64, publishes its packages and
`<id>.json` in a release named after the tag, and updates `catalog.json` in the `catalog` release:

```
https://github.com/monteirohat/batox-extensions/releases/download/catalog/catalog.json
```

Every push and pull request also builds every extension on both platforms.

## License

[MIT](LICENSE) for this repository. Each extension bundles third-party programs under their own
licenses, listed in its `extension.json` and in its package.

BatoX Extensions is an independent project, not affiliated with or endorsed by the Batocera
project or by Apple. AirPlay is a trademark of Apple Inc.
