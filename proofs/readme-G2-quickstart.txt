== Quick start in a fresh clone (2026-09-30 23:05 AEST, macOS 26.6)

$ git clone https://github.com/esxr/gameplay-recorder-annotator.git && cd gameplay-recorder-annotator
Cloning into 'gameplay-recorder-annotator'...
exit=0
HEAD 46d9fa6; build/ present before step 3: no; .venv present: no

$ brew install xcodegen ffmpeg tesseract && python3 -m venv .venv && .venv/bin/pip install -r engine/requirements.txt

[notice] A new release of pip is available: 26.0 -> 26.2.1
[notice] To update, run: <clone>/.venv/bin/python3.13 -m pip install --upgrade pip
exit=0

$ app/build.sh && open build/GameplayRecorder.app
** BUILD SUCCEEDED **
../build/GameplayRecorder.app: replacing existing signature

exit=0

$ .venv/bin/python engine/run.py samples/city-3d.mp4
STAGE change frames=600 flashes=0 secs=0.5
STAGE schedule C=8397 P=1527 V=17951 R=877 F=48 skip_vlm_pct=96.8 vlm_frames=18 vlm_pct=3.00
STAGE state entities=38 events=69 hud=['cash'] ocr_calls=3 value_ocr_calls=82
STAGE store frames=600 nb_frames=600 match=True bytes=262786 events=69 secs=12.4 out=samples/city-3d.mp4.session
exit=0
session dir: events.jsonl evidence meta.json stream.jsonl summary.json 

$ .venv/bin/python engine/api.py samples/city-3d.mp4.session ask "When did the cash first increase, and by how much?"
STAGE compile tokens=3848 budget=4000 evidence=20 ms=1
STAGE answer model=claude-haiku-4-5-20251001 in_tokens=6916 out_tokens=87 ms=1734
{
 "answer": "Frame 338 (5.63 seconds); increased by 25 (from 60 to 85)",
 "full": "ANSWER: Frame 338 (5.63 seconds); increased by 25 (from 60 to 85)\n\nThe hud.cash value timeline shows the cash value was 60 at f0, remained at 60 until f338, when it changed to 85. This is the first increase in cash during the video, representing a gain of 25 units.",
 "context_tokens": 3848,
 "input_tokens": 6916,
 "evidence": [
  {
   "f": 338,
   "crop": null
  },
  {
   "f": 0,
   "crop": null
  },
  {
   "f": 1,
   "crop": "evidence/f1_text_t1.jpg"
  },
  {
   "f": 10,
   "crop": "evidence/f10_e1.jpg",
   "id": "ev1"
  },
  {
   "f": 46,
   "crop": "evidence/f46_e3.jpg",
   "id": "ev4"
  },
  {
   "f": 68,
   "crop": "evidence/f68_e7.jpg",
   "id": "ev8"
  },
  {
   "f": 52,
   "crop": "evidence/f52_e6.jpg",
   "id": "ev7"
  },
  {
   "f": 83,
   "crop": "evidence/f83_e8.jpg",
   "id": "ev9"
  },
  {
   "f": 86,
   "crop": "evidence/f86_e9.jpg",
   "id": "ev10"
  },
  {
   "f": 87,
   "crop": "evidence/f87_e10.jpg",
   "id": "ev11"
  }
 ]
}
exit=0

== Results table vs proof files: 13 rows, 0 mismatches (every number in each row found in its linked proofs/pipeline-*.txt)
