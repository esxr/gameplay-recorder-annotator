== Quick start in a fresh clone (2026-09-30 22:05 AEST, macOS 26.6)

$ git clone https://github.com/esxr/gameplay-recorder-annotator.git && cd gameplay-recorder-annotator
Cloning into 'gameplay-recorder-annotator'...
exit=0
HEAD 786a80a; build/ present before step 3: no; .venv present: no

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
STAGE schedule C=8427 P=1518 V=17914 R=893 F=48 skip_vlm_pct=96.7 vlm_frames=16 vlm_pct=2.67
STAGE state entities=49 events=93 hud=['cash'] ocr_calls=0 value_ocr_calls=83
STAGE store frames=600 nb_frames=600 match=True bytes=299120 events=93 secs=10.0 out=samples/city-3d.mp4.session
exit=0
session dir: events.jsonl evidence meta.json stream.jsonl summary.json 

$ .venv/bin/python engine/api.py samples/city-3d.mp4.session ask "When did the cash first increase, and by how much?"
STAGE compile tokens=3847 budget=4000 evidence=20 ms=1
STAGE answer model=claude-haiku-4-5-20251001 in_tokens=6810 out_tokens=76 ms=3622
{
 "answer": "Frame 338, increase of 25 (from 60 to 85)",
 "full": "ANSWER: Frame 338, increase of 25 (from 60 to 85)\n\nJUSTIFICATION: The hud.cash timeline shows the value was 60 at f0, then changed to 85 at f338, representing the first increase. The amount increased is 85 - 60 = 25.",
 "context_tokens": 3847,
 "input_tokens": 6810,
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
   "f": 10,
   "crop": "evidence/f10_e1.jpg",
   "id": "ev1"
  },
  {
   "f": 37,
   "crop": "evidence/f37_e4.jpg",
   "id": "ev4"
  },
  {
   "f": 44,
   "crop": "evidence/f44_e6.jpg",
   "id": "ev6"
  },
  {
   "f": 46,
   "crop": "evidence/f46_e7.jpg",
   "id": "ev7"
  },
  {
   "f": 29,
   "crop": "evidence/f29_e3.jpg",
   "id": "ev3"
  },
  {
   "f": 42,
   "crop": "evidence/f42_e5.jpg",
   "id": "ev5"
  },
  {
   "f": 52,
   "crop": "evidence/f52_e10.jpg",
   "id": "ev10"
  },
  {
   "f": 85,
   "crop": "evidence/f85_e11.jpg",
   "id": "ev11"
  }
 ]
}
exit=0
