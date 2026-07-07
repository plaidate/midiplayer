import "CoreLibs/graphics"

import "smokeflag"
import "config"
import "patches"
import "songs"
import "midiplayer"
import "ui"

local gfx = playdate.graphics

playdate.display.setRefreshRate(30)

local selectedRow = 1
local songIndex = 1

-- load-time failures happen outside playdate.update's pcall, so catch
-- them here or headless runs die silently with no err.json
local function loadSong(i)
    songIndex = ((i - 1) % #Songs) + 1
    selectedRow = 1
    local ok, loadErr = pcall(function()
        MidiPlayer.load(Songs[songIndex])
        MidiPlayer.play()
    end)
    if not ok then
        print("LOAD ERROR: " .. tostring(loadErr))
        playdate.datastore.write(
            { error = "load[" .. songIndex .. "]: " .. tostring(loadErr) },
            "err")
    end
    return ok
end

playdate.getSystemMenu():addMenuItem("next song", function()
    loadSong(songIndex + 1)
end)

loadSong(1)

local function handleInput()
    if playdate.buttonJustPressed(playdate.kButtonUp) then
        selectedRow = math.max(1, selectedRow - 1)
    elseif playdate.buttonJustPressed(playdate.kButtonDown) then
        selectedRow = math.min(#MidiPlayer.tracks, selectedRow + 1)
    elseif playdate.buttonJustPressed(playdate.kButtonA) then
        MidiPlayer.toggleMute(selectedRow)
    elseif playdate.buttonJustPressed(playdate.kButtonB) then
        MidiPlayer.togglePlay()
    elseif playdate.buttonJustPressed(playdate.kButtonLeft) then
        MidiPlayer.cyclePatch(selectedRow, -1)
    elseif playdate.buttonJustPressed(playdate.kButtonRight) then
        MidiPlayer.cyclePatch(selectedRow, 1)
    end
    local crank = playdate.getCrankChange()
    if crank ~= 0 then
        MidiPlayer.setSpeed(
            MidiPlayer.speed + crank / 360 * Config.SPEED_PER_REV)
    end
end

-- ------------------------------------------------- smoke instrumentation

local frame = 0
local shots = 0
local songsVisited = 1

local function smokeUpdate()
    frame = frame + 1

    -- autopilot: exercise mute, patch cycling, speed, stop/start,
    -- and cycle through every registered song
    if frame == 60 then MidiPlayer.setSpeed(3.0) end
    if frame % 150 == 0 then
        selectedRow = (frame / 150 - 1) % math.max(1, #MidiPlayer.tracks) + 1
        MidiPlayer.toggleMute(selectedRow)
    end
    if frame % 400 == 0 then MidiPlayer.cyclePatch(selectedRow, 1) end
    if frame == 700 then MidiPlayer.stop() end
    if frame == 730 then MidiPlayer.play() end
    if frame % 240 == 0 and songIndex < #Songs then
        loadSong(songIndex + 1)
        songsVisited = songsVisited + 1
        MidiPlayer.setSpeed(3.0)
    end

    if frame % Config.HEARTBEAT_FRAMES == 0 then
        local trackinfo = {}
        for i, t in ipairs(MidiPlayer.tracks) do
            trackinfo[i] = string.format("%d:%s p%d n%d%s", t.index,
                t.patch, t.poly, t.noteCount, t.muted and " M" or "")
        end
        playdate.datastore.write({
            frame = frame,
            song = MidiPlayer.songName,
            songsVisited = songsVisited,
            step = MidiPlayer.currentStep(),
            len = MidiPlayer.length(),
            loops = MidiPlayer.loops,
            playing = MidiPlayer.playing,
            speed = MidiPlayer.speed,
            baseTempo = MidiPlayer.baseTempo or "n/a",
            tracks = trackinfo,
        }, "heartbeat")
    end

    if frame == 20 or frame % Config.SHOT_FRAMES == 0 then
        shots = shots + 1
        playdate.simulator.writeToFile(gfx.getDisplayImage(),
            Config.SMOKE_SHOT_DIR .. "/shot-" .. shots .. ".png")
    end

    if songsVisited >= #Songs and MidiPlayer.loops >= Config.SMOKE_LOOPS_DONE then
        playdate.datastore.write({
            frame = frame, loops = MidiPlayer.loops,
            songsVisited = songsVisited,
        }, "done")
    end
end

local function tick()
    handleInput()
    UI.draw(selectedRow)
    if SMOKE_BUILD then smokeUpdate() end
end

if SMOKE_BUILD then
    function playdate.update()
        local ok, err = pcall(tick)
        if not ok then
            playdate.datastore.write({ error = tostring(err) }, "err")
            error(err)
        end
    end
else
    playdate.update = tick
end
