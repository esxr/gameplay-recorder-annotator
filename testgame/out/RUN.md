# testgame run (2026-09-30 03:51) — NOT A VALID CAPTURE, see caveats

- mp4: /Users/pranav/Movies/GameplayRecorder/Recording 2026-09-30 03.51.56.mp4 (symlink out/session.mp4)
  ffprobe: h264, 3440x1440, 60/1, 73.48 s, 4409 frames
- truth.jsonl: 4201 lines, gf 0..4200 contiguous; 42 HUD changes; objective change gf 2100; loading gf 3000-3059, level2 from 3060
- flash runs (gf,len): (317,1) (611,2) (953,1) (1277,2) (1589,1) (2213,2) (2531,1) (2867,2) (3391,1) (3713,2)
- decoded sync: -1 for all tested frames (100-104, 2000, 4000, 4300): the video does not contain the game

## Caveats
1. Wrong capture area: the recorder uses NSScreen.main (= screen with the key window). Focus was on another
   display (3440x1440 px = 1720x720 pt ultrawide), so rect 100,297,1280,720 was applied there and captured
   the Territorial.io tab instead of the game panel on the 1728x1117 laptop display.
2. 30 fps rendering: macOS Low Power Mode is on (pmset powermode 1); WebKit throttles rAF to 30 fps, so
   2101/4201 gf were not rendered (truth `rendered:false`). 6 of 15 flash frames never hit the screen.
3. Earlier Chrome attempt (open -g) opened behind the full-screen Arc window -> occluded, captured Arc.
