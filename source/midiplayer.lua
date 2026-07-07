-- MidiPlayer: loads a .mid into a playdate.sound.sequence and handles
-- the part the engine doesn't: assigning an instrument to every track.
-- Explicit per-song maps win; unmapped tracks fall back to a heuristic
-- (drums / bass / pad / lead from note statistics).

local snd = playdate.sound

MidiPlayer = {
    seq = nil,
    tracks = {},      -- {index, patch, poly, noteCount, muted, track}
    playing = false,
    loops = 0,
    baseTempo = nil,  -- steps/sec as loaded; nil if getTempo unavailable
    speed = 1.0,
    songName = "",
}

-- Guess a patch for an unmapped track from its note events.
local function guessPatch(trackIndex, notes, poly)
    if trackIndex == 10 then return "drums" end  -- GM channel 10 convention
    local sum, count = 0, #notes
    local distinct = {}
    for i = 1, count do
        sum = sum + notes[i].note
        distinct[notes[i].note] = true
    end
    local mean = sum / count
    local nDistinct = 0
    for _ in pairs(distinct) do nDistinct = nDistinct + 1 end
    -- few distinct pitches hit over and over reads as percussion
    if nDistinct <= 6 and count / nDistinct >= 12 then return "drums" end
    if mean < 48 then return "bass" end
    if poly >= 3 then return "pad" end
    return "lead"
end

-- song = {name, path, map={[trackIndex]="patch"}, volume={[trackIndex]=v}}
function MidiPlayer.load(song)
    MidiPlayer.stop()
    local seq = snd.sequence.new(song.path)
    assert(seq, "failed to load " .. song.path)

    MidiPlayer.seq = seq
    MidiPlayer.songName = song.name
    MidiPlayer.tracks = {}
    MidiPlayer.loops = 0
    MidiPlayer.speed = 1.0

    local ok, tempo = pcall(function() return seq:getTempo() end)
    MidiPlayer.baseTempo = ok and tempo or nil

    local map = song.map or {}
    for i = 1, seq:getTrackCount() do
        local track = seq:getTrackAtIndex(i)
        if track ~= nil then
            local notes = track:getNotes() or {}
            if #notes > 0 then
                local poly = track:getPolyphony()
                local patch = map[i] or guessPatch(i, notes, poly)
                local inst = Patches.instrument(patch, poly)
                local vol = (song.volume or {})[i]
                if vol then inst:setVolume(vol) end
                track:setInstrument(inst)
                MidiPlayer.tracks[#MidiPlayer.tracks + 1] = {
                    index = i,
                    patch = patch,
                    poly = poly,
                    noteCount = #notes,
                    muted = false,
                    track = track,
                }
                print(string.format("track %d: %d notes, poly %d -> %s",
                    i, #notes, poly, patch))
            end
        end
    end
end

local function onFinish()
    MidiPlayer.loops = MidiPlayer.loops + 1
    if MidiPlayer.playing then
        MidiPlayer.seq:goToStep(1)
        MidiPlayer.seq:play(onFinish)
    end
end

function MidiPlayer.play()
    if MidiPlayer.seq and not MidiPlayer.playing then
        MidiPlayer.playing = true
        MidiPlayer.seq:play(onFinish)
    end
end

function MidiPlayer.stop()
    if MidiPlayer.seq and MidiPlayer.playing then
        MidiPlayer.playing = false  -- clear first so onFinish doesn't loop
        MidiPlayer.seq:stop()
        MidiPlayer.seq:allNotesOff()
    end
end

function MidiPlayer.togglePlay()
    if MidiPlayer.playing then MidiPlayer.stop() else MidiPlayer.play() end
end

function MidiPlayer.toggleMute(row)
    local t = MidiPlayer.tracks[row]
    if t then
        t.muted = not t.muted
        t.track:setMuted(t.muted)
    end
end

-- Cycle the patch on a track row (left/right on the selected row).
function MidiPlayer.cyclePatch(row, dir)
    local t = MidiPlayer.tracks[row]
    if not t then return end
    local cur = 1
    for i, name in ipairs(Patches.names) do
        if name == t.patch then cur = i break end
    end
    local nxt = ((cur - 1 + dir) % #Patches.names) + 1
    t.patch = Patches.names[nxt]
    t.track:setInstrument(Patches.instrument(t.patch, t.poly))
end

function MidiPlayer.setSpeed(mult)
    mult = math.max(Config.SPEED_MIN, math.min(Config.SPEED_MAX, mult))
    MidiPlayer.speed = mult
    if MidiPlayer.seq and MidiPlayer.baseTempo then
        MidiPlayer.seq:setTempo(MidiPlayer.baseTempo * mult)
    end
end

function MidiPlayer.currentStep()
    return MidiPlayer.seq and MidiPlayer.seq:getCurrentStep() or 0
end

function MidiPlayer.length()
    return MidiPlayer.seq and MidiPlayer.seq:getLength() or 0
end

-- 0..1 activity level for a track row (for UI meters)
function MidiPlayer.activity(row)
    local t = MidiPlayer.tracks[row]
    if not t or t.poly == 0 then return 0 end
    local ok, n = pcall(function() return t.track:getNotesActive() end)
    if not ok or not n then return 0 end
    return math.min(1, n / t.poly)
end
