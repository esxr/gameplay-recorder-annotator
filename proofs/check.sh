#!/bin/zsh
# Usage: proofs/check.sh <video.mp4>  — prints machine-checkable G2/G3/G4 evidence for one recording.
V="$1"; J="${V%.mp4}.annotations.jsonl"; LOG=~/Library/Logs/GameplayRecorder/app.log
echo "== ffprobe: $V"
ffprobe -v error -select_streams v:0 -show_entries stream=codec_name,width,height,r_frame_rate,avg_frame_rate,nb_frames -show_entries format=duration -of default=nw=1 "$V"
echo "== JSONL: $J"
N=$(grep -c . "$J"); echo "lines=$N"
jq -c . "$J" >/dev/null && echo "jq_parse=ok" || echo "jq_parse=FAIL"
NE=$(jq -c 'select((.entities|length)>0 or (.hud|length)>0)' "$J" | wc -l | tr -d ' '); echo "nonempty_entities_or_hud=$NE ($(( 100*NE/N ))%)"
echo "triggers: $(jq -r .trigger "$J" | sort | uniq -c | tr '\n' ' ')"
echo "== log timing"
B=$(basename "$V")
STOP=$(grep "recording_stopped" $LOG | grep -F "$B" | tail -1 | cut -d' ' -f1)
START=$(grep "annotation_started" $LOG | grep -F "$B" | tail -1 | cut -d' ' -f1)
echo "recording_stopped=$STOP"; echo "annotation_started=$START"
python3 -c "import sys,datetime as d;f=lambda s:d.datetime.fromisoformat(s.replace('Z','+00:00'));print('delta_s=%.3f'%(f('$START')-f('$STOP')).total_seconds())" 2>/dev/null
grep "review_markers" $LOG | tail -1
