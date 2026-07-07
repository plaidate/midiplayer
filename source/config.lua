-- Config: tunables shared by every module.

Config = {
    -- playback speed multiplier range (crank-controlled)
    SPEED_MIN = 0.25,
    SPEED_MAX = 3.0,
    SPEED_PER_REV = 1.0,   -- one crank revolution = +/- 1.0x

    -- cap voices per instrument so a dense file can't eat the DSP budget
    MAX_VOICES = 8,

    -- UI layout
    HEADER_H = 26,
    ROW_H = 22,
    FOOTER_H = 18,

    -- smoke harness
    HEARTBEAT_FRAMES = 90,
    SHOT_FRAMES = 300,
    SMOKE_LOOPS_DONE = 1,  -- finish smoke run after this many loops
    SMOKE_SHOT_DIR = "/Users/sdwfrost/Projects/playdate/midiplayer/smoke-out",
}
