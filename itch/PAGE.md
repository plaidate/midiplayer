# MIDI Player (midiplayer)

**Tagline:** Drop-in MIDI music for Playdate games — synth patch bank, track mapper, live mixer.

## Description

Your Playdate can already parse `.mid` files — `playdate.sound.sequence`
does it natively. What it can't do is decide what the tracks *sound like*:
there's no General MIDI sound set on the device, and program changes in
the file are silently ignored. So your carefully arranged song comes out
as… nothing, until you hand-build an instrument for every track.

**midiplayer** is that missing layer, MIT-licensed and ready to drop into
your game. A "GM-lite" patch bank (lead, pluck, pad, organ, bass, and a
fully synthesized drum kit on the GM percussion map — zero sample assets)
plus a loader that assigns an instrument to every track: pin them
explicitly per song, or let the heuristic guess from note statistics
(drums, bass, pad, lead). It ships wrapped in a mixer-style demo app —
one row per track with live level meters — so you can audition any MIDI
file on the device, mute tracks, swap patches, and crank the tempo from
0.25× to 3× in real time. A dependency-free Python SMF generator and a
headless smoke-test harness are included.

## Features

- Instrumentation layer for `playdate.sound.sequence` — the part the SDK leaves to you
- 5 synth patches + a sample-free drum kit covering the common GM percussion notes
- Per-song track→patch maps, with a note-statistics heuristic for unmapped tracks
- Transport with seamless looping, per-track mute, live patch cycling
- Crank-driven tempo scaling (0.25×–3×) and per-track activity meters
- Mixer demo app doubles as a MIDI audition tool for your own files
- `tools/mkmidi.py`: dependency-free SMF Format-1 writer for procedural music
- DEVGUIDE.md with full API walkthrough and the supported-MIDI-subset table
- MIT licensed; pure Lua, SDK 3.0.6

## Controls (demo app)

- **d-pad up/down** — select track
- **Ⓐ** — mute/unmute selected track
- **Ⓑ** — stop / start playback
- **d-pad left/right** — cycle selected track's patch
- **crank** — playback speed (0.25×–3×)
- **menu → next song** — cycle bundled songs

## Install (no dev toolchain needed)

Download `MidiPlayer.pdx.zip` from Releases (or `dist/`), then sideload at
https://play.date/account/sideload/ or unzip into the Playdate Simulator.

Developers: clone the repo and see DEVGUIDE.md for integrating the module
into your own game.
