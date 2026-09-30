// Diagram specs for the PRD ASCII blocks. Each builder returns Excalidraw
// element skeletons; convertToExcalidrawElements binds labels to containers
// and arrows to their start/end shapes.

const INK = "#1e1e1e";
const C = {
  blue: "#dbe4ff",
  green: "#d3f9d8",
  yellow: "#fff3bf",
  red: "#ffe3e3",
  violet: "#e5dbff",
  grey: "#f1f3f5",
  cyan: "#c5f6fa",
  orange: "#ffe8cc",
};

export function makeKit(FF) {
  const FONT = FF.Excalifont;
  const MONO = FF.Cascadia;
  const boxes = {};

  function box(id, x, y, w, h, text, o = {}) {
    const el = {
      type: o.shape || "rectangle",
      id,
      x, y, width: w, height: h,
      strokeColor: INK,
      backgroundColor: o.bg || C.blue,
      fillStyle: "solid",
      strokeWidth: o.strokeWidth || 2,
      roughness: 1,
      roundness: o.shape === "ellipse" ? null : { type: 3 },
    };
    if (text != null) {
      el.label = {
        text,
        fontSize: o.fontSize || 20,
        fontFamily: o.mono ? MONO : FONT,
        textAlign: o.textAlign || "center",
        verticalAlign: o.verticalAlign || "middle",
        strokeColor: INK,
      };
    }
    boxes[id] = { x, y, w, h };
    return el;
  }
  // centred box
  function cbox(id, cx, y, w, h, text, o) {
    return box(id, cx - w / 2, y, w, h, text, o);
  }

  // point on the edge of box b, on the side facing (tx,ty)
  function edge(b, side) {
    const cx = b.x + b.w / 2, cy = b.y + b.h / 2;
    switch (side) {
      case "top": return [cx, b.y];
      case "bottom": return [cx, b.y + b.h];
      case "left": return [b.x, cy];
      case "right": return [b.x + b.w, cy];
    }
  }
  function autoSides(a, b) {
    const acx = a.x + a.w / 2, acy = a.y + a.h / 2;
    const bcx = b.x + b.w / 2, bcy = b.y + b.h / 2;
    if (b.y >= a.y + a.h - 1) return ["bottom", "top"];
    if (b.y + b.h <= a.y + 1) return ["top", "bottom"];
    return bcx > acx ? ["right", "left"] : ["left", "right"];
  }
  const GAP = 6;
  // arrow bound on both ends
  function arrow(from, to, label, o = {}) {
    const a = boxes[from], b = boxes[to];
    const [sa, sb] = o.sides || autoSides(a, b);
    let [x1, y1] = o.startAt || edge(a, sa);
    let [x2, y2] = o.endAt || edge(b, sb);
    // leave a small gap so the binding looks like Excalidraw's own
    const dx = x2 - x1, dy = y2 - y1, len = Math.hypot(dx, dy) || 1;
    x1 += (dx / len) * GAP; y1 += (dy / len) * GAP;
    x2 -= (dx / len) * GAP; y2 -= (dy / len) * GAP;
    const el = {
      type: "arrow",
      x: x1, y: y1,
      points: [[0, 0], [x2 - x1, y2 - y1]],
      strokeColor: INK,
      strokeWidth: 2,
      roughness: 1,
      endArrowhead: "arrow",
      start: { id: from },
      end: { id: to },
    };
    if (label) el.label = { text: label, fontSize: 18, fontFamily: FONT, strokeColor: INK };
    return el;
  }
  // arrow whose start is a free point (e.g. on a tree spine), bound at the end
  function arrowFrom(x1, y1, to, o = {}) {
    const b = boxes[to];
    const [x2, y2] = edge(b, o.side || "left");
    const dx = x2 - x1, dy = y2 - y1, len = Math.hypot(dx, dy) || 1;
    const ex = x2 - (dx / len) * GAP, ey = y2 - (dy / len) * GAP;
    return {
      type: "arrow",
      x: x1, y: y1,
      points: [[0, 0], [ex - x1, ey - y1]],
      strokeColor: INK, strokeWidth: 2, roughness: 1,
      endArrowhead: "arrow",
      end: { id: to },
    };
  }
  function line(x1, y1, x2, y2) {
    return {
      type: "line", x: x1, y: y1,
      points: [[0, 0], [x2 - x1, y2 - y1]],
      strokeColor: INK, strokeWidth: 2, roughness: 1,
    };
  }
  function text(x, y, t, o = {}) {
    return {
      type: "text", x, y, text: t,
      fontSize: o.fontSize || 20,
      fontFamily: o.mono ? MONO : FONT,
      strokeColor: INK,
      textAlign: o.textAlign || "left",
    };
  }
  return { box, cbox, arrow, arrowFrom, line, text, boxes };
}

export const DIAGRAMS = {
  // §11 Product Definition — six logical layers
  "six-logical-layers": (k) => {
    const { cbox, arrow } = k;
    const W = 440, H = 56;
    return [
      cbox("screen", 0, 0, 260, H, "SCREEN / GAME", { bg: C.grey }),
      cbox("cap", 0, 110, W, H, "1. HIGH-FIDELITY CAPTURE", { bg: C.blue }),
      cbox("cma", 0, 220, W, H, "2. CHANGE + MOTION ANALYSIS", { bg: C.blue }),
      cbox("sel", -250, 370, 380, H, "3. SELECTIVE PERCEPTION", { bg: C.yellow }),
      cbox("prop", 250, 370, 380, H, "STATE PROPAGATION", { bg: C.green }),
      cbox("ws", 0, 520, 520, H, "4. PERSISTENT SEMANTIC WORLD STATE", { bg: C.violet }),
      cbox("codec", 0, 630, 520, H, "5. TEMPORAL SEMANTIC DELTA CODEC", { bg: C.violet }),
      cbox("llm", 0, 740, 520, H, "6. LLM CONTEXT / SEARCH / QUERY LAYER", { bg: C.orange }),
      arrow("screen", "cap"),
      arrow("cap", "cma"),
      arrow("cma", "sel"),
      arrow("cma", "prop", "unchanged"),
      arrow("sel", "ws"),
      arrow("prop", "ws"),
      arrow("ws", "codec"),
      arrow("codec", "llm"),
    ];
  },

  // §13 Persistent Semantic World State — WorldState(t) tree
  "world-state-tree": (k) => {
    const { box, cbox, arrowFrom, line, boxes } = k;
    const els = [];
    const COLW = 290;
    const BUS_Y = 100;
    const cols = [
      ["Scene", ["environment", "camera", "lighting/effects", "scene mode"]],
      ["Entities", ["characters", "enemies", "items", "vehicles", "projectiles", "environmental objects"]],
      ["UI / HUD", ["health", "armour", "ammo", "minimap", "status effects", "objective", "inventory", "notifications"]],
    ];
    const simple = ["Text", "Spatial Relationships", "Motion", "Events", "Audio State", "Confidence", "Evidence Pointers"];
    const totalW = COLW * 4 - 40;
    els.push(cbox("root", totalW / 2, 0, 240, 56, "WorldState(t)", { bg: C.violet, fontSize: 24 }));
    const colX = (i) => i * COLW;
    // bus from root down to the column heads
    els.push(line(totalW / 2, 56, totalW / 2, BUS_Y));
    els.push(line(colX(0) + 110, BUS_Y, colX(3) + 30, BUS_Y));
    cols.forEach(([name, leaves], i) => {
      const x = colX(i);
      const id = "c" + i;
      els.push(box(id, x, 140, 220, 48, name, { bg: C.blue, fontSize: 22 }));
      els.push(arrowFrom(x + 110, BUS_Y, id, { side: "top" }));
      const spineX = x + 24;
      const lastY = 210 + (leaves.length - 1) * 50 + 20;
      els.push(line(spineX, 188, spineX, lastY));
      leaves.forEach((leaf, j) => {
        const lid = id + "l" + j;
        els.push(box(lid, x + 56, 210 + j * 50, 220, 40, leaf, { bg: C.grey, fontSize: 18 }));
        els.push(arrowFrom(spineX, 210 + j * 50 + 20, lid));
      });
    });
    // fourth column: the leaf children of WorldState(t)
    const x3 = colX(3);
    const spineX = x3 + 30;
    const rowY = (j) => 140 + j * 58;
    els.push(line(spineX, BUS_Y, spineX, rowY(simple.length - 1) + 22));
    simple.forEach((name, j) => {
      const id = "s" + j;
      els.push(box(id, x3 + 62, rowY(j), 260, 44, name, { bg: C.blue, fontSize: 20 }));
      els.push(arrowFrom(spineX, rowY(j) + 22, id));
    });
    return els;
  },

  // §19 Semantic Delta Representation — snapshot then deltas, frame by frame
  "snapshot-delta-frames": (k) => {
    const { box, arrow } = k;
    const frames = [
      ["Frame 18471", "SNAPSHOT:\nplayer.health = 72\nweapon.ammo = 27\nenemy_17.visible = true\nenemy_17.x = .713", C.violet],
      ["Frame 18472", "DELTA:\nweapon.ammo: 27 → 26\nmuzzle_flash: false → true\ncrosshair.x: +0.008", C.yellow],
      ["Frame 18473", "DELTA:\nmuzzle_flash: true → false\nenemy_17.x: -0.004", C.yellow],
      ["Frame 18474", "DELTA:\n∅", C.grey],
    ];
    const els = [];
    let y = 0;
    frames.forEach(([f, body, bg], i) => {
      const h = 22 + body.split("\n").length * 25;
      els.push(box("h" + i, 0, y + (h - 50) / 2, 190, 50, f, { bg: C.blue, fontSize: 22 }));
      els.push(box("b" + i, 260, y, 380, h, body, { bg, mono: true, fontSize: 18 }));
      els.push(arrow("h" + i, "b" + i));
      if (i > 0) els.push(arrow("h" + (i - 1), "h" + i));
      y += h + 40;
    });
    return els;
  },

  // §27 Model Hierarchy — escalation ladder L0..L5
  "model-hierarchy": (k) => {
    const { cbox, arrow } = k;
    const rows = [
      ["L0: deterministic comparison", C.green],
      ["L1: motion / optical flow / codec analysis", C.green],
      ["L2: lightweight detector / OCR / embedding", C.cyan],
      ["L3: specialist perception model", C.yellow],
      ["L4: large vision-language model", C.orange],
      ["L5: human correction or offline adjudication", C.red],
    ];
    const els = [];
    rows.forEach(([t, bg], i) => {
      els.push(cbox("L" + i, 0, i * 90, 480 + i * 30, 56, t, { bg, fontSize: 20 }));
      if (i > 0) els.push(arrow("L" + (i - 1), "L" + i));
    });
    return els;
  },

  // §28 LLM Context Compiler — compiled context for "Why did I die here?"
  "death-context-timeline": (k) => {
    const { box, arrow } = k;
    const rows = [
      ["[12:33.140]", "health=61\nenemy_17 visible at screen-right\nenemy_17 weapon=rifle", C.grey],
      ["[12:33.223]", "enemy_17 firing event begins", C.yellow],
      ["[12:33.257]", "incoming_damage indicator from right\nhealth 61→34", C.orange],
      ["[12:33.441]", "health 34→7", C.orange],
      ["[12:33.508]", "player firing\nammo 14→13", C.yellow],
      ["[12:33.590]", "health 7→0\ndeath event", C.red],
    ];
    const els = [];
    let y = 0;
    rows.forEach(([ts, body, bg], i) => {
      const lines = body.split("\n").length;
      const h = Math.max(50, 18 + lines * 26);
      els.push(box("t" + i, 0, y + (h - 46) / 2, 170, 46, ts, { bg: C.blue, mono: true, fontSize: 18 }));
      els.push(box("e" + i, 240, y, 420, h, body, { bg, mono: true, fontSize: 18 }));
      els.push(arrow("t" + i, "e" + i));
      if (i > 0) els.push(arrow("t" + (i - 1), "t" + i));
      y += h + 40;
    });
    return els;
  },

  // §46 Semantic Cache — visual pattern → prior interpretation
  "semantic-cache": (k) => {
    const { box, arrow } = k;
    const rows = [
      ["visual embedding", "known UI icon"],
      ["screen crop", "prior OCR structure"],
      ["object appearance", "tracked entity identity"],
      ["menu template", "parsed semantic layout"],
    ];
    const els = [];
    rows.forEach(([a, b], i) => {
      els.push(box("a" + i, 0, i * 80, 250, 52, a, { bg: C.grey }));
      els.push(box("b" + i, 360, i * 80, 290, 52, b, { bg: C.green }));
      els.push(arrow("a" + i, "b" + i));
    });
    return els;
  },

  // §67 Strategic Differentiation — two groups feeding the engine
  "strategic-differentiation": (k) => {
    const { box, arrow } = k;
    const els = [];
    els.push(box("g1", 0, 0, 400, 330, "ANNOTATION / PERCEPTION", { bg: C.grey, verticalAlign: "top", fontSize: 22 }));
    ["Encord", "CVAT", "Supervisely", "SAM", "DeepStream"].forEach((t, i) => {
      els.push(box("p" + i, 100, 50 + i * 54, 200, 42, t, { bg: C.blue, fontSize: 18 }));
    });
    els.push(box("g2", 540, 0, 400, 330, "VIDEO REASONING", { bg: C.grey, verticalAlign: "top", fontSize: 22 }));
    ["Gemini", "TwelveLabs", "Video VLMs"].forEach((t, i) => {
      els.push(box("r" + i, 640, 50 + i * 54, 200, 42, t, { bg: C.yellow, fontSize: 18 }));
    });
    els.push(box("eng", 270, 440, 400, 250,
      "SEMANTIC STATE ENGINE\n\npersistent identities\nsemantic deltas\ntemporal memory\nadaptive inference\nevidence\nLLM context compiler",
      { bg: C.violet, fontSize: 20, strokeWidth: 3 }));
    els.push(arrow("g1", "eng", null, { sides: ["bottom", "top"], endAt: [410, 440] }));
    els.push(arrow("g2", "eng", null, { sides: ["bottom", "top"], endAt: [530, 440] }));
    return els;
  },

  // §72 Product in One Diagram
  "product-in-one-diagram": (k) => {
    const { cbox, arrow } = k;
    const els = [];
    const cx = 0;
    els.push(cbox("raw", cx, -10, 380, 70, "RAW SCREEN @ 60 FPS", { bg: C.grey, shape: "ellipse" }));
    els.push(cbox("cap", cx, 110, 320, 56, "Capture + Video Codec", { bg: C.blue }));
    els.push(cbox("sch", cx, 290, 280, 56, "Change Scheduler", { bg: C.yellow }));
    const bx = [-280, 0, 280];
    const br = [["unchanged", "COPY", C.green], ["moved", "PROPAGATE", C.cyan], ["changed", "RE-INFER", C.orange]];
    br.forEach(([lab, act, bg], i) => {
      els.push(cbox("act" + i, bx[i], 470, 200, 52, act, { bg }));
    });
    els.push(cbox("ws", cx, 610, 360, 250,
      "Persistent World State\n\nobjects\nUI / OCR\nmasks\nrelationships\nevents\nconfidence",
      { bg: C.violet, strokeWidth: 3 }));
    els.push(cbox("sd", cx, 940, 300, 52, "SNAPSHOT + DELTAS", { bg: C.grey }));
    els.push(cbox("ltm", -200, 1080, 260, 52, "Long-term memory", { bg: C.blue }));
    els.push(cbox("ev", 200, 1080, 260, 52, "Evidence store", { bg: C.blue }));
    els.push(cbox("cc", cx, 1220, 280, 56, "Context Compiler", { bg: C.orange }));
    els.push(cbox("llm", cx, 1350, 160, 56, "LLM", { bg: C.red, shape: "ellipse" }));
    els.push(arrow("raw", "cap"));
    els.push(arrow("cap", "sch", "codec / pixel / motion"));
    br.forEach(([lab], i) => els.push(arrow("sch", "act" + i, lab)));
    br.forEach((_, i) => els.push(arrow("act" + i, "ws")));
    els.push(arrow("ws", "sd"));
    els.push(arrow("sd", "ltm"));
    els.push(arrow("sd", "ev"));
    els.push(arrow("ltm", "cc"));
    els.push(arrow("ev", "cc"));
    els.push(arrow("cc", "llm"));
    return els;
  },
};
