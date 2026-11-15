#!/bin/sh
# Starts the AirPlay receiver with the settings chosen in BatoX, and gives
# EmulationStation its sound back when it stops. BatoX runs it with the
# BATOX_* variables described in docs/manifest.md.

DIR=$(cd "$(dirname "$0")/.." && pwd)
DATA="${BATOX_EXTENSION_DATA:-$DIR/data}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/var/run}"
mkdir -p "$DATA"

# The name goes inside a quoted string of the configuration file.
name=$(printf '%s' "${BATOX_SETTING_NAME:-Batocera}" | tr -d '"\\\r\n' | cut -c1-50)
[ -n "$name" ] || name=Batocera

if [ "${BATOX_SETTING_PHONE_VOLUME:-1}" = 0 ]; then
    volume='ignore_volume_control = "yes";'
else
    # Without a hardware mixer the phone's slider spans 60 dB, so its middle is
    # very quiet; 30 dB keeps the whole slider useful.
    volume='volume_range_db = 30;'
fi

conf="$DATA/shairport-sync.conf"
cat > "$conf" <<EOF
// Written by $DIR/bin/start.sh at every start: change the settings in BatoX.
general = {
  name = "$name";
  output_backend = "pulseaudio";
  mdns_backend = "avahi";
  $volume
};
sessioncontrol = {
  allow_session_interruption = "yes";
  run_this_before_play_begins = "$DIR/bin/session.sh start";
  run_this_after_play_ends = "$DIR/bin/session.sh stop";
  wait_for_completion = "no";
};
pulseaudio = {
  application_name = "AirPlay";
};
EOF

# A previous run may have ended in the middle of a session.
"$DIR/bin/session.sh" reset

pid=
trap '[ -n "$pid" ] && kill "$pid" 2>/dev/null && wait "$pid"; "$DIR/bin/session.sh" reset; exit 0' TERM INT
"$DIR/bin/shairport-sync" -c "$conf" &
pid=$!
wait "$pid"
status=$?
"$DIR/bin/session.sh" reset
exit "$status"
