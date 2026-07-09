# midiplayer

> Part of **[plAIdate](https://plaidate.github.io)** — AI-built 1-bit games, ports, and engines for the Playdate.

A reusable MIDI playback module for Playdate (SDK 3.0.6), wrapped in a
mixer-style demo app.

**[DEVGUIDE.md](DEVGUIDE.md)** — API walkthrough, integration steps, and
the supported-MIDI-subset table.

## Play it

Prebuilt PDX: grab `MidiPlayer.pdx.zip` from the GitHub Releases page
(or `dist/` in a checkout), then sideload it at
<https://play.date/account/sideload/> or unzip it into the Playdate
Simulator. The demo app auditions the bundled songs: d-pad selects a
track, Ⓐ mutes, Ⓑ stops/starts, ←/→ swaps the patch, crank scales the
tempo, and the system menu jumps to the next song.

## The module

The Playdate engine already parses `.mid` files
into `playdate.sound.sequence` objects — what it deliberately leaves to
the game is *instrumentation* (there is no General MIDI sound set).
This module supplies that layer:

- **`patches.lua`** — a "GM-lite" bank of synth patches (`lead`,
  `pluck`, `pad`, `organ`, `bass`) plus a fully synthesized drum kit
  (per-note voices on the GM percussion map; no sample assets needed).
- **`midiplayer.lua`** — loads a `.mid`, walks its tracks, and assigns
  an instrument per track: an explicit per-song map wins, otherwise a
  heuristic guesses (track 10 → drums, few distinct pitches hit often →
  drums, low mean pitch → bass, chordal → pad, else lead). Also:
  play/stop, per-track mute, live patch cycling, crank-driven tempo
  scaling, and per-track activity levels for UI meters.
- **`songs.lua`** — the registry: bundle a `.mid` under `songs/` and
  add `{name, path, map}` here.
- **`ui.lua` / `main.lua`** — the demo app: one row per track with a
  live meter; d-pad selects, Ⓐ mutes, Ⓑ stops/starts, ←/→ cycles the
  selected track's patch, crank scales tempo 0.25–3×.

## Building

```
make build      # generates songs/demo.mid if needed, builds MidiPlayer.pdx
make run        # build + open in the Simulator
tools/smoke.sh  # headless autopilot run (heartbeat + screenshots)
```

`tools/mkmidi.py` (dependency-free SMF writer) generates the bundled
demo song: 8 bars of Am–F–C–G with lead/pad/bass on channels 1–3 and
drums on channel 10.

## Status

- Scaffold + build: done (`pdc` 3.0.6, compiles clean; demo.mid
  validated structurally).
- Runtime: smoke-verified 2026-07-04 — playback, looping, mute, patch
  cycling, and tempo scaling all exercised; screenshots in
  `smoke-out/`. The heuristic mapper identified all four demo tracks
  correctly; the indices are now pinned in `songs.lua`.
- 3.0.6 Simulator gotcha: launch with
  `open <path-to>/Playdate Simulator.app --args <pdx>` — the old
  `open -g -a "Playdate Simulator" <pdx>` form loads the pdx but never
  starts the game.

## Known engine limitations (upstream, not fixable here)

- Program changes in the file are ignored — hence the mapping layer.
- SMF Type 0 files collapse to one track; convert to Type 1 offline.
- Mid-song tempo maps are unreliable; bake to a fixed tempo on export.
- CC data arrives as control signals but is inert until wired to a
  modulation input.
