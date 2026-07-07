# midiplayer — Developer Guide

A drop-in MIDI playback layer for Playdate games (Lua, SDK 3.0.6).

The Playdate engine already does the hard part: `playdate.sound.sequence.new("song.mid")`
parses a Standard MIDI File into a sequence of tracks. What it deliberately
does **not** do is decide what those tracks *sound like* — there is no General
MIDI sound set on the device, and program-change events in the file are
ignored. Every game has to supply its own instrumentation layer.

This module is that layer, plus quality-of-life playback control:

| File | Role |
|---|---|
| `source/patches.lua` | "GM-lite" synth patch bank + fully synthesized drum kit (no sample assets) |
| `source/midiplayer.lua` | Loads a `.mid`, assigns an instrument per track (explicit map or heuristic), transport, mute, patch cycling, tempo scaling, activity meters |
| `source/songs.lua` | Registry of bundled songs and their track→patch maps |
| `source/config.lua` | Tunables (speed range, voice cap, UI layout, smoke harness) |
| `source/ui.lua`, `source/main.lua` | The demo/test-bench app (not needed in your game) |
| `tools/mkmidi.py` | Dependency-free SMF Format-1 writer that generates the demo song |

Everything uses the globals-as-modules convention: each file defines one
global table (`MidiPlayer`, `Patches`, `Songs`, `Config`, `UI`).

## Integration: adding music to your game

1. Copy `patches.lua` and `midiplayer.lua` into your game's source, and
   either copy `config.lua` or add its three playback keys to your own
   config table:

   ```lua
   Config = Config or {}
   Config.SPEED_MIN  = 0.25   -- tempo multiplier clamp
   Config.SPEED_MAX  = 3.0
   Config.MAX_VOICES = 8      -- per-instrument voice cap (DSP budget)
   ```

2. Import in dependency order (Patches and Config before MidiPlayer):

   ```lua
   import "config"
   import "patches"
   import "midiplayer"
   ```

3. Bundle a `.mid` in your source tree (e.g. `songs/level1.mid` — `pdc`
   copies unknown file types through) and play it:

   ```lua
   MidiPlayer.load({
       name = "Level 1",
       path = "songs/level1.mid",
       map  = { [2] = "lead", [3] = "pad", [4] = "bass", [5] = "drums" },
       volume = { [3] = 0.6 },   -- optional per-track volume overrides
   })
   MidiPlayer.play()
   ```

4. Wrap `MidiPlayer.load` in `pcall` if you load at boot time: load-time
   failures happen outside `playdate.update`, where errors are easy to
   lose (the demo's `loadSong` in `main.lua` shows the pattern).

That's it — the sequence loops forever until you call `MidiPlayer.stop()`.

### Finding your track indices

Track indices are **file track order in the parsed sequence, not MIDI
channel numbers**. In a typical Format-1 file the tempo/meta track eats
index 1, so the first note-bearing track is index 2. Rather than guess,
load the file once with an empty `map = {}`: `MidiPlayer.load` prints one
line per note-bearing track to the console —

```
track 2: 128 notes, poly 1 -> lead
track 5: 328 notes, poly 3 -> drums
```

— then pin what you want in the map. Unmapped tracks keep the heuristic
guess, which is often right (see below) but not guaranteed.

## API reference

### `MidiPlayer.load(song)`

`song` is a table: `{ name = string, path = string, map = {[trackIndex] = patchName} or nil, volume = {[trackIndex] = 0..1} or nil }`.

Stops any current playback, parses the file (asserts on failure), and for
every track that contains at least one note:

- picks a patch: `song.map[i]` if present, else the heuristic guess;
- builds a `playdate.sound.instrument` via `Patches.instrument(patch, poly)`
  with one voice per simultaneous note (capped at `Config.MAX_VOICES`);
- applies `song.volume[i]` if given;
- appends `{index, patch, poly, noteCount, muted, track}` to
  `MidiPlayer.tracks`.

Also records `MidiPlayer.baseTempo` (steps/sec, used by `setSpeed`) and
resets `loops`, `speed`, and `songName`.

**The heuristic** (`guessPatch`, for unmapped tracks):

1. track index 10 → `drums` (GM channel-10 convention);
2. ≤6 distinct pitches each hit ≥12 times on average → `drums`;
3. mean pitch below MIDI note 48 → `bass`;
4. polyphony ≥3 → `pad`;
5. otherwise → `lead`.

### Transport

- `MidiPlayer.play()` — starts (or resumes from the current step) and
  installs a finish callback that rewinds to step 1 and replays, so songs
  **loop indefinitely**; each wrap increments `MidiPlayer.loops`.
- `MidiPlayer.stop()` — stops and calls `allNotesOff()` so pads don't ring.
- `MidiPlayer.togglePlay()`.

### Mixing and patches

- `MidiPlayer.toggleMute(row)` — mutes/unmutes a row of
  `MidiPlayer.tracks` (row = position in that array, not file track index).
- `MidiPlayer.cyclePatch(row, dir)` — replaces the row's instrument with
  the next/previous patch in `Patches.names`. Note: this rebuilds the
  instrument at default patch volume, so a `song.volume` override does not
  survive a cycle.
- `MidiPlayer.activity(row)` — 0..1 (active notes / polyphony), for level
  meters. Safe to call every frame.

### Tempo

- `MidiPlayer.setSpeed(mult)` — clamps to
  `[Config.SPEED_MIN, Config.SPEED_MAX]` and sets the sequence tempo to
  `baseTempo * mult`. The demo maps the crank to this
  (`Config.SPEED_PER_REV` = 1.0× per revolution). No-op if the file's
  tempo couldn't be read at load.

### Position

- `MidiPlayer.currentStep()`, `MidiPlayer.length()` — sequence steps, for
  progress bars. Both return 0 when nothing is loaded.

### Readable state

`MidiPlayer.tracks`, `.playing`, `.loops`, `.speed`, `.baseTempo`
(nil if unavailable), `.songName`.

### `Patches`

- `Patches.names` — `{ "lead", "pluck", "pad", "organ", "bass", "drums" }`.
- `Patches.instrument(name, poly)` — a new `playdate.sound.instrument`.
  Melodic patches are ADSR'd single-oscillator synths (square lead,
  sawtooth pluck, sine pad/organ, triangle bass) with `poly` voices;
  unknown names fall back to `lead`. `"drums"` returns the drum kit.
- **Drum kit**: per-note synth voices on the GM percussion map — kick
  (35/36, sine thump), snare/clap/e-snare (38/39/40, noise), toms
  (41/43/45/47, triangle), closed/pedal hat (42/44), open hat (46),
  crash (49), ride (51). Drum notes outside this set are silent — add a
  voice in `drumKit()` if your file needs more.

Adding a patch: one line in `RECIPES`
(`{waveform, attack, decay, sustain, release, volume}`) plus its name in
`Patches.names`.

## Supported MIDI subset

What survives the Playdate sequence parser (upstream engine behavior,
SDK 3.0.6 — not fixable in this module):

| Feature | Status |
|---|---|
| SMF **Format 1** (multi-track) | ✔ the format to use |
| SMF Format 0 (single track) | ⚠ parses, but all channels collapse into one track → one instrument. Convert to Format 1 offline. |
| Note on/off, velocity | ✔ |
| Polyphony | ✔ per-track via `getPolyphony()`; voice count capped by `Config.MAX_VOICES` |
| Initial tempo | ✔ read at load (`baseTempo`) |
| Mid-song tempo changes | ✖ unreliable — bake to a fixed tempo on export |
| Program changes | ✖ ignored — that's why this module exists |
| Control changes (CC) | ⚠ arrive as control signals but are inert until you wire them to a modulation input |
| Channel 10 drums | ⚠ no special engine handling; handled here by map/heuristic |

**Preparing a file**: export Format 1, one instrument per track, fixed
tempo, drums on their own track. Anything from a DAW or
`github.com/ldrolez/free-midi-chords` (three of which ship as test songs)
works out of the box.

## `tools/mkmidi.py` — the SMF generator

A ~130-line, dependency-free Format-1 writer, useful both for the demo
song and as a starting point for generating music procedurally:

```
python3 tools/mkmidi.py [out.mid]     # default: source/songs/demo.mid
```

It emits a meta track (4/4, 120 bpm) plus lead/pad/bass on channels 1–3
and drums on channel 10 — 8 bars of Am–F–C–G. Building blocks: `vlq()`
(variable-length quantities), `note(events, ch, beat, num, dur_beats, vel)`,
and `track_chunk()` which sorts events and delta-encodes them. Compose
your own track functions from those three and append them to the `tracks`
list in `main()`.

## The demo app and smoke harness

`main.lua` + `ui.lua` are a mixer-style test bench: one row per track
with a live activity meter; d-pad selects, Ⓐ mutes, Ⓑ stops/starts, ←/→
cycles the selected row's patch, crank scales tempo, and a system-menu
item advances to the next registered song.

`make smoke` stages a build with `SMOKE_BUILD = true`, which adds an
autopilot to `playdate.update`: it exercises mute, patch cycling, speed,
stop/start, and every registered song, writing a `heartbeat` datastore
JSON every 90 frames, screenshots to `smoke-out/`, and a `done` marker
once every song has been visited and the sequence has looped.
`tools/smoke.sh` builds, launches the Simulator headlessly, tails the
heartbeat, and fails on any `err.json`. (SDK 3.0.6 note: the Simulator
must be launched as `open <app path> --args <pdx>` — the old
`open -g -a` form loads the pdx but never starts it.)
