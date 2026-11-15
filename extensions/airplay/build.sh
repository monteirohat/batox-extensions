#!/bin/sh
# Builds the AirPlay extension package for this machine's architecture:
#
#   build.sh <out-dir>
#
# Run it as root in Debian bookworm, as the workflows do on arm64 and amd64
# runners: its glibc (2.36) is older than Batocera's, so the programs run
# there. It builds
#   - a minimal static FFmpeg, with only the ALAC decoder that AirPlay audio
#     needs (shairport-sync's own decoders are deprecated for security);
#   - shairport-sync for classic AirPlay, with PulseAudio output (PipeWire on
#     Batocera) and Avahi,
# and adds the two libraries Batocera lacks, libconfig and libsoxr, in lib/.
set -eu

SHAIRPORT_VERSION=5.6.3
SHAIRPORT_SHA256=670f9cefdb9c2d70f7df71890e63ab0a31d08a815dd0734245d935bfd01e766e
FFMPEG_VERSION=8.1.3
FFMPEG_SHA256=7138d28c96d9d3e3af4ee3d8cad72741f8ffb40da90c1112235dea3ecd3178a3

# What the programs may link to: libraries Batocera 43 ships, and lib/.
ALLOWED="libc.so.6 libm.so.6 libpthread.so.0 libdl.so.2 librt.so.1 libgcc_s.so.1 libatomic.so.1
libz.so.1 libpopt.so.0 libssl.so.3 libcrypto.so.3 libavahi-client.so.3 libavahi-common.so.3
libdaemon.so.0 libpulse.so.0 libpulse-simple.so.0 libdbus-1.so.3 libasound.so.2 libgomp.so.1
libstdc++.so.6 ld-linux-aarch64.so.1 ld-linux-x86-64.so.2"
BUNDLED="libconfig.so.9 libsoxr.so.0"

HERE=$(cd "$(dirname "$0")" && pwd)
mkdir -p "$1"
OUT=$(cd "$1" && pwd)
WORK=$(mktemp -d)
PKG="$WORK/pkg"

echo "== Build tools and libraries"
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq --no-install-recommends \
    ca-certificates curl xz-utils build-essential dpkg-dev autoconf automake libtool pkg-config \
    patchelf libpopt-dev libconfig-dev libssl-dev libsoxr-dev libavahi-client-dev libpulse-dev \
    >/dev/null

ARCH=$(dpkg --print-architecture)
MULTIARCH=$(dpkg-architecture -qDEB_HOST_MULTIARCH)
VERSION=$(sed -n 's/^ *"version": *"\([^"]*\)".*/\1/p' "$HERE/extension.json" | head -n 1)
JOBS=$(nproc)

# fetch URL FILE SHA256
fetch() {
    curl -fsSL --retry 3 -o "$2" "$1"
    echo "$3  $2" | sha256sum -c -
}

echo "== FFmpeg $FFMPEG_VERSION: static, ALAC decoder only"
cd "$WORK"
fetch "https://ffmpeg.org/releases/ffmpeg-$FFMPEG_VERSION.tar.xz" ffmpeg.tar.xz "$FFMPEG_SHA256"
tar -xf ffmpeg.tar.xz
cd "ffmpeg-$FFMPEG_VERSION"
./configure --prefix="$WORK/ffmpeg" --enable-static --disable-shared --enable-pic \
    --disable-programs --disable-doc --disable-network --disable-autodetect --disable-x86asm \
    --disable-everything --enable-decoder=alac \
    --disable-avdevice --disable-avfilter --disable-swscale >/dev/null
make -j"$JOBS" >/dev/null
make install >/dev/null

echo "== shairport-sync $SHAIRPORT_VERSION: classic AirPlay"
cd "$WORK"
fetch "https://github.com/mikebrady/shairport-sync/archive/refs/tags/$SHAIRPORT_VERSION.tar.gz" \
    shairport.tar.gz "$SHAIRPORT_SHA256"
tar -xf shairport.tar.gz
cd "shairport-sync-$SHAIRPORT_VERSION"
autoreconf -fi >/dev/null 2>&1
# FFmpeg's static libraries need these after them on the link line.
PKG_CONFIG_PATH="$WORK/ffmpeg/lib/pkgconfig" LIBS="-lm -lpthread -latomic" \
    ./configure --sysconfdir=/etc --with-ffmpeg --with-pulseaudio --with-avahi \
    --with-ssl=openssl --with-soxr --with-metadata >/dev/null
make -j"$JOBS" >/dev/null

echo "== Package"
mkdir -p "$PKG/bin" "$PKG/lib" "$PKG/LICENSES"
cp "$HERE/extension.json" "$PKG/"
install -m 755 shairport-sync "$PKG/bin/"
strip "$PKG/bin/shairport-sync"
install -m 755 "$HERE/files/start.sh" "$HERE/files/session.sh" "$PKG/bin/"
for lib in $BUNDLED; do
    cp -L "/usr/lib/$MULTIARCH/$lib" "$PKG/lib/$lib"
done
# Found next to the program, without LD_LIBRARY_PATH.
patchelf --set-rpath '$ORIGIN/../lib' "$PKG/bin/shairport-sync"

cp COPYING "$PKG/LICENSES/shairport-sync.txt"
cp LICENSES "$PKG/LICENSES/shairport-sync-components.txt"
cp "$WORK/ffmpeg-$FFMPEG_VERSION/COPYING.LGPLv2.1" "$PKG/LICENSES/ffmpeg.txt"
for p in libconfig9 libsoxr0; do
    cp "/usr/share/doc/$p/copyright" "$PKG/LICENSES/$p.txt" 2>/dev/null ||
        echo "LGPL-2.1. See https://packages.debian.org/bookworm/$p" >"$PKG/LICENSES/$p.txt"
done
cat >"$PKG/SOURCES.md" <<EOF
# Sources

| Component | Version | Source | License |
|---|---|---|---|
| shairport-sync | $SHAIRPORT_VERSION | https://github.com/mikebrady/shairport-sync/releases/tag/$SHAIRPORT_VERSION | MIT and others, see LICENSES/ |
| FFmpeg (static: ALAC decoder) | $FFMPEG_VERSION | https://ffmpeg.org/releases/ffmpeg-$FFMPEG_VERSION.tar.xz | LGPL-2.1 |
| libconfig | $(dpkg-query -W -f='${Version}' libconfig9) | https://packages.debian.org/source/bookworm/libconfig | LGPL-2.1 |
| libsoxr | $(dpkg-query -W -f='${Version}' libsoxr0) | https://packages.debian.org/source/bookworm/libsoxr | LGPL-2.1 |

Built by extensions/airplay/build.sh in https://github.com/monteirohat/batox-extensions, which
also shows how to rebuild it, for example with another FFmpeg.
EOF

echo "== Libraries"
bad=""
for f in "$PKG/bin/shairport-sync" "$PKG"/lib/*; do
    for need in $(readelf -d "$f" | sed -n 's/.*(NEEDED).*\[\(.*\)\]/\1/p'); do
        case " $(echo $ALLOWED $BUNDLED) " in
        *" $need "*) echo "  $(basename "$f") -> $need" ;;
        *) bad="$bad $(basename "$f")->$need" ;;
        esac
    done
done
if [ -n "$bad" ]; then
    echo "Not on Batocera:$bad" >&2
    exit 1
fi
"$PKG/bin/shairport-sync" -V

tar -czf "$OUT/airplay-$VERSION-linux-$ARCH.tar.gz" --owner=0 --group=0 -C "$PKG" .
echo "== $OUT/airplay-$VERSION-linux-$ARCH.tar.gz"
