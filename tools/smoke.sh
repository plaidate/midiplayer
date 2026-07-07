#!/bin/bash
# Headless smoke test: build with the autopilot harness, run in the
# Simulator, watch the datastore heartbeat, report errors / completion.
set -u
cd "$(dirname "$0")/.."

DATA=~/Developer/PlaydateSDK/Disk/Data/com.sdwfrost.midiplayer
RUNTIME=${1:-90}   # seconds; 2 loops at 3x speed lands well under this

make smoke || exit 1

pkill -9 -f "Playdate Simulator" 2>/dev/null
sleep 1
rm -f "$DATA"/heartbeat.json "$DATA"/err.json "$DATA"/done.json

caffeinate -dimsu -t $((RUNTIME + 30)) &
CAF=$!
# 3.0.6 sim: must launch by explicit path with --args and WITHOUT -g;
# background/by-name launches load the pdx but never start the game
open "$HOME/Developer/PlaydateSDK/bin/Playdate Simulator.app" --args "$(pwd)/MidiPlayer-smoke.pdx"

echo "smoke: running up to ${RUNTIME}s..."
START=$(date +%s)
while true; do
    sleep 5
    NOW=$(date +%s)
    ELAPSED=$((NOW - START))
    if [ -f "$DATA/err.json" ]; then
        echo "smoke: RUNTIME ERROR"
        cat "$DATA/err.json"
        pkill -9 -f "Playdate Simulator"
        kill "$CAF" 2>/dev/null
        exit 1
    fi
    if [ -f "$DATA/done.json" ]; then
        echo "smoke: DONE (looped enough)"
        cat "$DATA/done.json"; echo
        break
    fi
    if [ "$ELAPSED" -ge "$RUNTIME" ]; then
        echo "smoke: time up"
        break
    fi
    if [ -f "$DATA/heartbeat.json" ]; then
        echo "hb[$ELAPSED s]: $(cat "$DATA/heartbeat.json")"
    fi
done

pkill -9 -f "Playdate Simulator"
kill "$CAF" 2>/dev/null
echo "smoke: final heartbeat:"
cat "$DATA/heartbeat.json" 2>/dev/null; echo
# scrub test data so it doesn't leak into real saves
rm -rf "$DATA"
exit 0
