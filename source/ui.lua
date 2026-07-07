-- UI: mixer-style screen. Header = song + transport, one row per MIDI
-- track (patch, poly, live activity meter, mute), footer = controls.

local gfx = playdate.graphics

UI = {}

local function drawHeader()
    gfx.fillRect(0, 0, 400, Config.HEADER_H)
    gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
    gfx.drawText("*" .. MidiPlayer.songName .. "*", 6, 5)
    local step = MidiPlayer.currentStep()
    local len = MidiPlayer.length()
    local state = MidiPlayer.playing and "PLAYING" or "STOPPED"
    local speed = string.format("%.2fx", MidiPlayer.speed)
    gfx.drawTextAligned(state .. "  " .. speed, 394, 5, kTextAlignment.right)
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
    -- progress bar along the header's bottom edge
    if len > 0 then
        gfx.setColor(gfx.kColorWhite)
        gfx.fillRect(0, Config.HEADER_H - 4, 400 * step / len, 3)
        gfx.setColor(gfx.kColorBlack)
    end
end

local function drawTrackRow(row, y, selected)
    local t = MidiPlayer.tracks[row]
    if selected then
        gfx.fillRect(0, y, 400, Config.ROW_H)
        gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
    end
    local label = string.format("%d  %s  (%d voices, %d notes)",
        t.index, t.patch, t.poly, t.noteCount)
    gfx.drawText(label, 8, y + 3)
    if t.muted then
        gfx.drawTextAligned("MUTE", 330, y + 3, kTextAlignment.right)
    end
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
    -- activity meter
    local level = t.muted and 0 or MidiPlayer.activity(row)
    local mx, mw = 340, 52
    if selected then gfx.setColor(gfx.kColorWhite) end
    gfx.drawRect(mx, y + 5, mw, 12)
    gfx.fillRect(mx, y + 5, mw * level, 12)
    gfx.setColor(gfx.kColorBlack)
end

function UI.draw(selectedRow)
    gfx.clear(gfx.kColorWhite)
    gfx.setColor(gfx.kColorBlack)
    drawHeader()
    local y = Config.HEADER_H + 4
    for row = 1, #MidiPlayer.tracks do
        drawTrackRow(row, y, row == selectedRow)
        y = y + Config.ROW_H
    end
    gfx.drawLine(0, 240 - Config.FOOTER_H, 400, 240 - Config.FOOTER_H)
    gfx.drawText("Ⓐ mute  Ⓑ play/stop  L/R patch  crank speed",
        8, 240 - Config.FOOTER_H + 3)
end
