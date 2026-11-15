# AirPlay receiver

The console appears in AirPlay as a speaker called **Batocera**. On an iPhone, iPad or Mac, choose
it in Spotify, Apple Music, YouTube or any other app (or in Control Center), and the music plays
through the console: on the TV, the headphone jack or wherever BatoX's **Audio** screen sends the
sound.

It works with every account and app, Spotify Family included, because the phone sends the audio:
nothing depends on a streaming service's own API.

## Settings

| Setting | Default | |
|---|---|---|
| Name in AirPlay | `Batocera` | How the console appears on phones and computers. |
| Silence EmulationStation while AirPlay plays | On | Its background music and menu sounds stop while AirPlay plays and come back when it ends. Game sound is never touched. |
| The phone's volume controls the sound | On | Off: AirPlay always plays at full volume, and the console's volume sets the level. |
| Volume boost | 100% | Raises the AirPlay sound (up to 200%), for music that sounds quieter than the console's. |

## Good to know

- **Pausing** on the phone keeps the AirPlay connection, so EmulationStation stays quiet; its music
  comes back when you disconnect (choose the phone as the output again).
- **During a game**, AirPlay plays along with the game's sound.
- The phone's volume slider covers 30 dB, so its middle is still clearly audible. Spotify's
  "Normalize volume" makes songs quieter than the console's music: turn it off, or raise the volume
  boost.
- AirPlay has about 2 seconds of delay, which only shows when you play or pause.
- This is classic AirPlay ("AirPlay 1"): one source at a time, no multi-room sync.

## How it works

`bin/start.sh` writes the configuration from the settings and runs
[shairport-sync](https://github.com/mikebrady/shairport-sync), built by `build.sh` for classic
AirPlay with PulseAudio output (PipeWire on Batocera) and Avahi, and a minimal static FFmpeg for
decoding. shairport-sync calls `bin/session.sh` when a session starts and ends: it mutes
EmulationStation's PipeWire stream and boosts the AirPlay one, and undoes it afterwards.

The package includes `libconfig` and `libsoxr`, which Batocera lacks. `SOURCES.md` and `LICENSES/`
in the package list their versions, sources and licenses.
