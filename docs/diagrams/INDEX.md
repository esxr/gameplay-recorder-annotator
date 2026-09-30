# PRD diagrams

Every `text` block in `knowledge/raw/semantic-video-state-engine-prd.md` that draws a flow, tree, timeline or layout. Each one is redrawn in Excalidraw (`<name>.excalidraw`) and exported with Excalidraw's `exportToSvg` (`<name>.svg`). The README shows the SVG in place of the ASCII block. PRD lines are the opening and closing fence lines.

| # | Name | PRD lines | PRD section | Why it is a diagram | Files |
|---|---|---|---|---|---|
| 1 | six-logical-layers | 414-437 | 11. Product Definition | Flow: screen through capture, change analysis, a perception/propagation split, world state, delta codec, LLM layer | [excalidraw](six-logical-layers.excalidraw) · [svg](six-logical-layers.svg) |
| 2 | world-state-tree | 492-526 | 13. Persistent Semantic World State | Tree: `WorldState(t)` with its branches and leaves | [excalidraw](world-state-tree.excalidraw) · [svg](world-state-tree.svg) |
| 3 | snapshot-delta-frames | 747-769 | 19. Semantic Delta Representation | Timeline layout: one snapshot frame followed by delta frames | [excalidraw](snapshot-delta-frames.excalidraw) · [svg](snapshot-delta-frames.svg) |
| 4 | model-hierarchy | 1025-1032 | 27. Model Hierarchy | Layered escalation ladder L0 to L5, cheapest to most expensive | [excalidraw](model-hierarchy.excalidraw) · [svg](model-hierarchy.svg) |
| 5 | death-context-timeline | 1060-1083 | 28. LLM Context Compiler | Timeline: timestamped state changes leading to the death event | [excalidraw](death-context-timeline.excalidraw) · [svg](death-context-timeline.svg) |
| 6 | semantic-cache | 1558-1563 | 46. Semantic Cache | Mapping flow: each visual pattern → its cached interpretation | [excalidraw](semantic-cache.excalidraw) · [svg](semantic-cache.svg) |
| 7 | strategic-differentiation | 2183-2202 | 67. Strategic Differentiation | Layout: two product groups converging on the engine | [excalidraw](strategic-differentiation.excalidraw) · [svg](strategic-differentiation.svg) |
| 8 | product-in-one-diagram | 2312-2360 | 72. Product in One Diagram | Flow: the full system from raw screen to LLM | [excalidraw](product-in-one-diagram.excalidraw) · [svg](product-in-one-diagram.svg) |

## Text blocks judged not to be diagrams

These stay as code blocks in the README: they are lists, formulas or data examples with no flow, tree or layout.

- 671-679 (§17): relationship triples, one per line.
- 801-807 (§20): the `State(frame N)` formula.
- 850-861 (§22): the `importance` weighted sum.
- 993-1011 (§26): list of perception modules starting "Scene classifier".
- 1147-1154 (§30): list of provenance kinds.
- 1191-1201 (§32): list of frame identity fields.
- 1312-1318 (§36): list of element counts.
- 1396-1412 (§39): Session Query API signatures.
- 1420-1430 (§40): streaming event types.
- 1453-1458 (§41): list of state kinds.
- 1521-1528 (§44): generic OCR vs game adapter example.
- 1595-1601 (§48): input action types.
- 1623-1635 (§49): per-attribute confidence example.
- 1842-1848 (§56): what persists or resets.
- 1957-1966 (§60): provider interface names starting "SegmentationProvider".
