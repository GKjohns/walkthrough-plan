---
name: walkthrough-plan
description: Turn a narrated video walkthrough of a space into a room-by-room cleanup and redecoration plan — a markdown checklist plus a shareable, styled HTML one-pager with a budget-tuned shopping list. Use when someone records themselves walking through a home, office, or room narrating what they want thrown out, moved, cleaned, organized, or bought, and wants an organized plan to execute. Triggers include "here's a walkthrough video of my place", "turn this video into a cleanup plan", "spring cleaning video", "process this room tour", or "what needs to happen to get this room from its current state to what I want".
---

# Walkthrough → Plan

Take a video of someone walking through a space narrating changes ("throw this out," "move this here," "I want art on this wall") and produce two things:

1. **`PLAN.md`** — the canonical, executable plan: an effort-sorted checklist, a "leave it alone" list, and a budget-tuned shopping list.
2. **`index.html`** — a calm, shareable one-pager (AirDrop to a phone, tick tasks off as you walk the space). Rendered from the bundled template.

The whole point is that the plan proves you **understood the video**, not just transcribed it. The signature moves below are what make that obvious — never drop them.

## Inputs

- **Video pointer** (required) — a path to the walkthrough video. If the user is vague ("the video in Downloads"), locate it (`ls`/`find` for recent `.mov`/`.mp4`).
- **Budget** (required) — ask for it if not given. Accept either:
  - an **exact** number ("$300", "around $500"), or
  - a **general** intent ("on a budget", "don't break the bank", "cheap as possible", "whatever it takes / spare no expense").

  **Ask exactly one question if the budget is missing**, then proceed. Don't interview.

## Requirements

- `ffmpeg` + `ffprobe`, `curl`, `python3` on PATH.
- `OPENAI_API_KEY` in the environment (used for Whisper transcription).

## Workflow

### 1. Confirm inputs
Locate the video; confirm/ask the budget. Map a general budget to a working number for the shopping list (see **Budget handling**).

### 2. Prep the media
Run the bundled script — it extracts compressed audio, samples frames every 5s, transcribes with Whisper, and writes a timestamped transcript:

```bash
bash scripts/prep.sh "<video_path>" "<workdir>"
```

Default `<workdir>` is `<video_dir>/walkthrough_plan`. Outputs: `audio.mp3`, `frames/frame_NNN.jpg`, `transcript.json`, `transcript_timestamped.md`. Each `frame_NNN` ≈ `(NNN-1)*5` seconds, so frames align to the transcript's timestamps.

### 3. Visual analysis — delegate to a subagent
**Do not pull the frames into the main loop** (dozens of images destroy context). Spawn one subagent to view the frames against the transcript and return **text-only** structured notes. Use a prompt like:

> You are doing a visual analysis of a space walkthrough. Frames are at `<workdir>/frames/frame_001.jpg …`, each `frame_NNN` ≈ `(NNN-1)*5` seconds in. The timestamped narration is at `<workdir>/transcript_timestamped.md`. Read the transcript first, then view frames in batches and align them to what the speaker says. Return **text only** (no images). For each room, in walkthrough order, give: **room name**; **current state/vibe** (2–4 concrete visual sentences); **objects the speaker references** (each: what it physically is as seen in-frame, where it is, the timestamp); and **anything relevant they didn't call out** (empty-wall size, clutter, lighting). Note measurements that inform purchases (counter overhang for stools, wall dimensions for art). Be specific enough for someone who has never seen the space to execute.

### 4. Synthesize `PLAN.md`
Write the canonical plan. **Required structure and signature moves:**

- **Summary line up top** — `N tasks · ~$X · 1 weekend · D decisions`. This is the screenshot.
- **Decisions / "before you start"** — pull genuine judgment calls (where does an heirloom go? approve a style?) to the very top. If one is already resolved, mark it done.
- **Effort-sorted checklist** (the canonical executable list), every line a `- [ ]` checkbox tagged with a verb and a room:
  - **Tier 1 — zero purchases.** Everything doable with bare hands this weekend. *Order matters: nobody should have to wait on a delivery to start.*
  - **Tier 2 — after one shopping run.**
- **"Leave it alone" list** — everything the speaker said to keep. This removes decisions ("am I supposed to deal with this? no") and is a top signal you listened.
- **⚠️ Warnings inline** — preserve hard constraints verbatim ("measure the overhang first," "NOT a crate"). These are the proof-of-understanding details.
- **Budget-tuned shopping list** — one pick per item (fewer decisions is the gift) plus one upgrade alternative. See **Sourcing**.

Verbs to use (kebabbed they map to badge colors in the template): `Give`, `Ask`, `Clear`, `Clean`, `Tidy`, `Put away`, `Toss`, `Place`.

### 5. Render the one-pager
Copy `assets/onepager_template.html` to `<workdir>/index.html` and replace **only the `DATA` object** near the bottom of the `<script>` with this plan's content (title, lede, summary stats, decisions, tier1, tier2, leave, shop, total, storeKey). The template handles all rendering and persists checkboxes in `localStorage`. Adjust the section subtitles in the HTML if a decision is already resolved (e.g. "Art's confirmed. Just one ask left."). Keep the design as-is — calm, one accent, soft badges. Don't add chartjunk.

### 6. Deliver
`open` both files. Give a tight summary: the headline numbers, the 1–2 decisions, and the proof-of-understanding callouts (the warnings, the leave-alone list). Offer one concrete next step.

## Budget handling

The budget changes the shopping list, not the cleanup. Map intent → behavior:

| Budget signal | Behavior |
|---|---|
| Exact number ("$300") | Hit it. Show one pick per item; total should land at/under the number. Note how to trim if over. |
| "on a budget" / "cheap" | Cheapest viable pick per item, mostly IKEA/Target/Amazon basics; art = print-a-digital-file. Skip nice-to-haves. |
| Unspecified after asking | Default to "cheaper side" (~the sum of cheapest viable picks). |
| "whatever it takes" / "spare no expense" | Lead with the quality pick; offer the budget option as the alternative. |

Offer **one** upgrade alternative per item — not two options for everything. Fewer decisions is the gift.

## Sourcing (keep links from rotting)

- **Prefer stable retailers** whose product URLs don't move (IKEA SKUs especially; Target/Amazon are okay).
- For Etsy/Displate/Society6 and anything that sells out, **lead with a search term**, not a deep link — the search query is the durable fallback. A demo where the first link 404s undercuts the whole thing.
- Default to the cheaper side unless the budget says otherwise.

## Output files (in `<workdir>`)

- `PLAN.md` — canonical plan (the thing the skill produces)
- `index.html` — shareable one-pager (the showpiece)
- `transcript_timestamped.md`, `transcript.json`, `frames/`, `audio.mp3` — working artifacts
