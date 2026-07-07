#!/usr/bin/env python3
"""Generate the demo Standard MIDI File for the midiplayer module.

Hand-rolled SMF (format 1) writer -- no dependencies. 8 bars of a
four-part groove (lead / pad / bass / drums) over Am F C G at 120bpm.
Each part gets its own MIDI track AND its own channel (drums on channel
10) so the Playdate loader's track indexing can be observed in smoke
runs and pinned in songs.lua.

Usage: python3 tools/mkmidi.py [out.mid]
"""

import struct
import sys

TPQN = 480  # ticks per quarter note


def vlq(n):
    """Encode n as a MIDI variable-length quantity."""
    out = [n & 0x7F]
    n >>= 7
    while n:
        out.append(0x80 | (n & 0x7F))
        n >>= 7
    return bytes(reversed(out))


def track_chunk(events):
    """events: list of (tick, bytes). Returns a complete MTrk chunk."""
    events = sorted(events, key=lambda e: e[0])
    data = b""
    last = 0
    for tick, ev in events:
        data += vlq(tick - last) + ev
        last = tick
    data += vlq(0) + b"\xff\x2f\x00"  # end of track
    return b"MTrk" + struct.pack(">I", len(data)) + data


def note(events, ch, beat, num, dur_beats, vel):
    on = int(beat * TPQN)
    off = int((beat + dur_beats) * TPQN)
    events.append((on, bytes([0x90 | ch, num, vel])))
    events.append((off, bytes([0x80 | ch, num, 0])))


def meta_track():
    ev = []
    ev.append((0, b"\xff\x58\x04\x04\x02\x18\x08"))       # 4/4
    ev.append((0, b"\xff\x51\x03" + (500000).to_bytes(3, "big")))  # 120bpm
    return ev


# chord progression: two bars each of Am, F, C, G (8 bars, beats 0-31)
CHORDS = [
    ("Am", 33, (57, 60, 64), [76, 79, 81, 79, 76, 74, 72, 74]),
    ("F",  29, (53, 57, 60), [77, 81, 84, 81, 77, 76, 72, 76]),
    ("C",  36, (52, 55, 60), [79, 76, 84, 76, 79, 72, 76, 79]),
    ("G",  31, (50, 55, 59), [74, 79, 83, 79, 74, 71, 67, 71]),
]


def lead_track(ch):
    ev = [(0, b"\xff\x03\x04lead")]
    for half in range(2):                     # progression plays twice
        for ci, (_, _, _, riff) in enumerate(CHORDS):
            bar = half * 4 + ci
            for i, n in enumerate(riff):
                vel = 105 if i == 0 else 88
                note(ev, ch, bar * 4 + i * 0.5, n, 0.45, vel)
    return ev


def pad_track(ch):
    ev = [(0, b"\xff\x03\x03pad")]
    for half in range(2):
        for ci, (_, _, triad, _) in enumerate(CHORDS):
            bar = half * 4 + ci
            for n in triad:
                note(ev, ch, bar * 4, n, 3.9, 72)
    return ev


def bass_track(ch):
    ev = [(0, b"\xff\x03\x04bass")]
    for half in range(2):
        for ci, (_, root, _, _) in enumerate(CHORDS):
            bar = half * 4 + ci
            for b, (n, vel) in enumerate(
                [(root, 100), (root, 84), (root + 7, 92), (root + 12, 88)]
            ):
                note(ev, ch, bar * 4 + b, n, 0.9, vel)
    return ev


def drum_track(ch):
    KICK, SNARE, HAT, OPEN_HAT = 36, 38, 42, 46
    ev = [(0, b"\xff\x03\x05drums")]
    for bar in range(8):
        t = bar * 4
        note(ev, ch, t + 0, KICK, 0.4, 110)
        note(ev, ch, t + 2, KICK, 0.4, 104)
        note(ev, ch, t + 1, SNARE, 0.4, 100)
        note(ev, ch, t + 3, SNARE, 0.4, 100)
        for e in range(8):
            if bar % 4 == 3 and e == 7:
                note(ev, ch, t + e * 0.5, OPEN_HAT, 0.45, 80)
            else:
                note(ev, ch, t + e * 0.5, HAT, 0.2, 66)
    return ev


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else "source/songs/demo.mid"
    tracks = [
        meta_track(),
        lead_track(0),
        pad_track(1),
        bass_track(2),
        drum_track(9),  # channel 10 (0-indexed 9) = GM drums
    ]
    chunks = b"".join(track_chunk(t) for t in tracks)
    header = b"MThd" + struct.pack(">IHHH", 6, 1, len(tracks), TPQN)
    with open(out, "wb") as f:
        f.write(header + chunks)
    print(f"wrote {out}: {len(tracks)} tracks, 8 bars @120bpm, {TPQN} tpqn")


if __name__ == "__main__":
    main()
