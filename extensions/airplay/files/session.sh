#!/bin/sh
# Runs around each AirPlay session. shairport-sync calls it before play
# begins and after it ends; start.sh calls "reset" when the receiver starts
# and stops. The extension's settings come in the environment.
#
#   session.sh start   silence EmulationStation (if enabled) and boost the
#                      AirPlay sound, until the session ends
#   session.sh stop    give EmulationStation its sound back
#   session.sh reset   the same, right away
#
# Game sound is never touched.

export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/var/run}"
FLAG=/var/run/batox-airplay-active # in RAM: gone after a reboot
LOG="${BATOX_EXTENSION_DATA:-/tmp}/session.log"
MUTE="${BATOX_SETTING_MUTE_MENU_MUSIC:-1}"
BOOST="${BATOX_SETTING_VOLUME_BOOST:-100}"
case "$BOOST" in
'' | *[!0-9]*) BOOST=100 ;;
esac
if [ "$BOOST" -lt 100 ] || [ "$BOOST" -gt 200 ]; then
    BOOST=100
fi

# streams PATTERN: ids of the PipeWire streams whose application name matches.
streams() {
    LC_ALL=C pactl list sink-inputs | awk -v re="$1" '
        /^Sink Input #/ { id = substr($3, 2) }
        /application.name = / && $0 ~ re { print id }'
}

es_mute() {
    for id in $(streams emulationstation); do
        LC_ALL=C pactl set-sink-input-mute "$id" "$1"
    done
}

log() { echo "$(date '+%F %T') $*" >>"$LOG"; }

case "$1" in
start)
    [ -e "$FLAG" ] && exit 0
    touch "$FLAG"
    [ "$MUTE" = 1 ] && es_mute 1
    log "start: silence EmulationStation: $MUTE, boost: $BOOST%"
    (
        boosted=""
        while [ -e "$FLAG" ]; do
            # A game closes EmulationStation's stream and a new one opens after it.
            [ "$MUTE" = 1 ] && es_mute 1
            # The AirPlay stream opens once the music arrives; boost it once.
            for id in $(streams '"AirPlay"'); do
                case " $boosted " in
                *" $id "*) ;;
                *) LC_ALL=C pactl set-sink-input-volume "$id" "$BOOST%" && boosted="$boosted $id" ;;
                esac
            done
            sleep 2
        done
    ) >/dev/null 2>&1 &
    ;;
stop)
    rm -f "$FLAG"
    (
        sleep 3 # let the start loop see that the session ended
        es_mute 0
        log "stop: EmulationStation sound back"
        # During a game there is no EmulationStation stream, and PipeWire may
        # restore the next one muted: unmute it when it appears (up to 6 hours).
        i=0
        while [ -z "$(streams emulationstation)" ] && [ ! -e "$FLAG" ] && [ "$i" -lt 21600 ]; do
            sleep 2
            i=$((i + 2))
        done
        [ -e "$FLAG" ] || es_mute 0
    ) >/dev/null 2>&1 &
    ;;
reset)
    rm -f "$FLAG"
    es_mute 0
    ;;
*)
    echo "usage: $0 start|stop|reset" >&2
    exit 2
    ;;
esac
