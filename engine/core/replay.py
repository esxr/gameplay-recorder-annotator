"""Rebuild state at any frame from nearest snapshot + merge-patch deltas."""
import copy
import json
import os


def merge_patch(target, patch):
    if not isinstance(patch, dict):
        return copy.deepcopy(patch)
    if not isinstance(target, dict):
        target = {}
    for k, v in patch.items():
        if v is None:
            target.pop(k, None)
        elif isinstance(v, dict) and isinstance(target.get(k), dict):
            target[k] = merge_patch(target[k], v)
        else:
            target[k] = copy.deepcopy(v)
    return target


def _stream(session_dir):
    with open(os.path.join(session_dir, "stream.jsonl")) as fh:
        for line in fh:
            if line.strip():
                yield json.loads(line)


def _index(session_dir):
    """Byte offsets of every line + list of snapshot frames (cached per mtime)."""
    p = os.path.join(session_dir, "stream.jsonl")
    key = (p, os.path.getmtime(p))
    if _index.cache.get("key") == key:
        return _index.cache["offs"], _index.cache["snaps"]
    offs, snaps = [], []
    with open(p, "rb") as fh:
        pos = 0
        for line in fh:
            offs.append(pos)
            if b'"kind":"snapshot"' in line[:120]:
                snaps.append(len(offs) - 1)
            pos += len(line)
    _index.cache = {"key": key, "offs": offs, "snaps": snaps}
    return offs, snaps


_index.cache = {}


def reconstruct(session_dir, f):
    """State at frame f = nearest snapshot ≤ f, then apply deltas up to f."""
    offs, snaps = _index(session_dir)
    f = max(0, min(int(f), len(offs) - 1))
    s0 = max([s for s in snaps if s <= f] or [0])
    state = None
    with open(os.path.join(session_dir, "stream.jsonl"), "rb") as fh:
        fh.seek(offs[s0])
        for i in range(s0, f + 1):
            rec = json.loads(fh.readline())
            if rec["kind"] == "snapshot":
                state = copy.deepcopy(rec["state"])
            else:
                state = merge_patch(state or {}, rec.get("delta") or {})
    return state


def dense_state(session_dir):
    """Yield (f, state) for every frame by sequential replay (direct replay reference)."""
    state = {}
    for rec in _stream(session_dir):
        if rec["kind"] == "snapshot":
            state = copy.deepcopy(rec["state"])
        else:
            state = merge_patch(state, rec.get("delta") or {})
        yield rec["f"], state
