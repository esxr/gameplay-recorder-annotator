#!/bin/bash
# Start server, open game in a background Chrome window (no focus steal), record only the canvas rect
# with GameplayRecorder.app, wait for the game to finish, stop, print mp4 path + truth line count.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TG="$ROOT/testgame"
SCR="$ROOT/scratch/testgame"
GRCTL="$ROOT/scratch/tools/grctl"
LOG="$HOME/Library/Logs/GameplayRecorder/app.log"
PORT=8777
URL="http://127.0.0.1:$PORT/"
MAIN_H=1117   # main screen height in points
mkdir -p "$SCR" "$TG/out"

# 1. server
pkill -f "testgame/server.py" 2>/dev/null; sleep 0.5
nohup "$ROOT/.venv/bin/python" "$TG/server.py" >"$SCR/server.log" 2>&1 &
SERVER_PID=$!
for i in $(seq 50); do curl -s "$URL/status" >/dev/null && break; sleep 0.1; done
curl -s "$URL/reset" >/dev/null

# 2. game window. my-browser/CDP was unavailable and a background Chrome window opens BEHIND the
# full-screen front app (so screen capture sees the other app). Instead host the page in a borderless,
# non-activating floating NSPanel (WKWebView) that is on top but never takes focus. Content rect == canvas.
GX=${GX:-100}; GY_TOP=${GY_TOP:-100}
CW=1280; CH=720
AY=$(( MAIN_H - GY_TOP - CH ))
[ -x "$SCR/gamehost" ] || swiftc -O "$TG/gamehost.swift" -o "$SCR/gamehost"
pkill -f "$SCR/gamehost" 2>/dev/null; sleep 0.3
"$SCR/gamehost" "$URL" "$GX" "$AY" >"$SCR/gamehost.log" 2>&1 &
HOST_PID=$!
for i in $(seq 100); do [ "$(curl -s "$URL/status" | grep -c '"geo": {')" = 1 ] && break; sleep 0.2; done
sleep 1.5
RECT="$GX,$AY,$CW,$CH"
echo "canvas rect top-left=($GX,$GY_TOP) appkit rect=$RECT"; cat "$SCR/gamehost.log"

# 4. recorder app (background), start recording rect
pgrep -f "GameplayRecorder.app/Contents/MacOS" >/dev/null || { open -g "$ROOT/build/GameplayRecorder.app"; sleep 3; }
LOGSTART=$(wc -l <"$LOG" 2>/dev/null || echo 0)
"$GRCTL" record "$RECT"
MP4=""
for i in $(seq 100); do
  MP4=$(tail -n +$((LOGSTART + 1)) "$LOG" | grep -o 'recording_started.*path=.*' | sed 's/.*path=//' | tail -1)
  [ -n "$MP4" ] && break; sleep 0.1
done
echo "recording_started: ${MP4:-<not seen in log>}"
sleep 1

# 5. start the game (truncates truth.jsonl), wait for done
curl -s "$URL/start" >/dev/null
T0=$(date +%s)
while :; do
  D=$(curl -s "$URL/status" | "$ROOT/.venv/bin/python" -c 'import json,sys; print(json.load(sys.stdin)["done"])')
  [ "$D" = "True" ] && break
  [ $(( $(date +%s) - T0 )) -gt 90 ] && { echo "timeout waiting for game"; break; }
  sleep 0.5
done
sleep 1.5   # capture a bit of GAME OVER + final flush

# 6. stop
"$GRCTL" stop
STOPPED=""
for i in $(seq 200); do
  STOPPED=$(tail -n +$((LOGSTART + 1)) "$LOG" | grep -o 'recording_stopped.*' | tail -1)
  [ -n "$STOPPED" ] && break; sleep 0.1
done
MP4=$(echo "$STOPPED" | sed 's/.*path=//')
echo "$STOPPED"
curl -s "$URL/status"; echo

# sort truth by gf (batched POSTs may arrive out of order)
"$ROOT/.venv/bin/python" - "$TG/out/truth.jsonl" <<'EOF'
import json,sys
p=sys.argv[1]; rs=[json.loads(l) for l in open(p) if l.strip()]
d={r["gf"]:r for r in rs}
open(p,"w").write("".join(json.dumps(d[k])+"\n" for k in sorted(d)))
EOF
ln -sf "$MP4" "$TG/out/session.mp4"
echo "MP4: $MP4"
echo "truth lines: $(wc -l <"$TG/out/truth.jsonl")"
# close the test browser instance and server
kill $HOST_PID 2>/dev/null
kill $SERVER_PID 2>/dev/null
