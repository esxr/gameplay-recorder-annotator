---
title: Auxiliary Channels (Audio and Input)
type: concept
created: 2026-09-30
updated: 2026-09-30
tags: [audio, input, multimodal, provenance, causality]
sources: [raw/semantic-video-state-engine-prd.md]
prd_sections: [8, 9.6, 13, 26, 30, 31, 32, 47, 48, 59, 64]
---

# Auxiliary Channels (Audio and Input)

**Definition.** Optional non-visual streams (game/system audio, microphone, and mouse/keyboard/controller input) captured in sync with video to resolve visual ambiguity and causality. "Screen pixels are the primary source of truth". Auxiliary channels "can be attached … but the visual pipeline must work without them" (PRD §8).

## Audio (PRD §47)

Optional audio semantics: speech transcription, alarms, footsteps, gunshots, UI sounds, music transitions, explosions, voice activity, and direction where available. The rationale is that audio carries information that is "visually ambiguous". [[twelvelabs]] is cited as showing the value of jointly representing visual, speech and non-speech audio for retrieval and generation (PRD §47). Capture of game/system audio and microphone is optional (PRD §31). `Audio State` is a branch of the world state (PRD §13). Audio-event detector and speech-to-text are listed perception modules (PRD §26).

## Input actions (PRD §48)

Optional synchronized input "materially improves causal interpretation". Examples are `mouse_click`, `key_down`, `key_up`, `controller_axis` and `controller_button`. Input capture is an optional synchronized auxiliary stream (PRD §31).

**Key distinction.** The engine "must preserve the distinction between *visually inferred action* and *directly recorded input*" (PRD §48). This mirrors the §30 provenance split between `observed`/`inferred` modes (see [[evidence-and-provenance]]).

[[vpt]] is the precedent for aligning gameplay pixels with native mouse and keyboard actions. Its inverse-dynamics model labelled 70,000 hours of Minecraft video, and its policy acted at 20 Hz. The product "should not require action data to operate" (PRD §9.6, §48).

> 🔎 Unverified: VPT's 70,000 hours and 20 Hz figures are as reported in the PRD (PRD §9.6).

## Requirements satisfied

No dedicated FR. These channels support FR-12/FR-13 (relationships, events) and causal benchmark questions (§53). Extensions: controller/input reconstruction and audio-event reasoning (PRD §64). Input is captured at the OS level, not by hooking the game ([[game-integrity-boundary]], §59).

## Risks

Clock skew between channels corrupts causal ordering. Recorded input may be treated as proof of on-screen effect. Microphone capture raises privacy risk ([[privacy-and-security]]). See [[failure-modes]].

> ⚠️ Tension: §30's annotation modes (observed, propagated, copied, derived, inferred, human_verified) have no value for "directly recorded from an auxiliary sensor". A recorded key press and a visually observed one both land in `observed`, which blurs the §48 distinction the PRD calls mandatory.

> ⚠️ Tension: Frame identity (§32) and evidence references (§30) are defined only for video: frame number and bounding region. The PRD does not say how audio events or input events (sampled at their own rates, not frame-aligned) are timestamped, referenced as evidence, or mapped to frame IDs.

> ⚠️ Tension: §13 puts `Audio State` in the core world state, and §47 says only that audio "can provide important information". No audio provider appears in the §60 interface list, so FR-22 replaceability does not cover audio.

## Related

[[perception-modules]] · [[evidence-and-provenance]] · [[frame-identity-and-capture]] · [[persistent-world-state]] · [[relationships-and-events]] · [[privacy-and-security]] · [[game-integrity-boundary]] · [[vpt]] · [[twelvelabs]] · [[failure-modes]]
