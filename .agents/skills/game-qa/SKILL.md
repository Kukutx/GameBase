---
name: game-qa
description: Operate the running game to find, reproduce, fix and regression-test defects in behaviour, UI, text, audio routing, input, saving or performance. Use when the task is to play through or inspect the game and repair what is wrong; not for matching a reference (use replication) or for a code-only review.
---

# Game QA and continuous repair

This skill covers work on the game itself: functional bugs, crashes, wrong state, UI layout and fonts, untranslated or clipped text, animation, input and focus, save and load, long-run stability, and breakage after an engine, addon or dependency upgrade. When a reference exists and the goal is that the two agree, `replication` owns the flow.

The detailed capture procedure — which states to visit, when to take a screenshot, what to keep — is `.agents/prompts/recipes/game-qa.md`; read it when the task includes process screenshots or a full pass over a screen or flow.

## Read first

1. The scope the user named and where output may be written (`artifacts/`).
2. How the game is run: the editor or `godot --path games/<id>` for the windowed game (after `node tools/link.js`), `node tools/smoke_export.js --game <id>` for an exported build, `npm run --prefix tools/web_smoke smoke:web -- --game <id>` for the Web export in Chromium. The log is `user://logs/<id>.log`.
3. The code, tests and data of the area under test, and `.agents/rules/testing.md`.

## The loop

```text
operate the game
-> check task progress
-> check for anomalies
-> candidate problem
-> reset
-> replay
-> classify: game defect / agent or driver mistake / environment issue / expected behaviour / unknown
-> shortest reproduction
-> fix the cause
-> run again
-> replay the reproduction
-> necessary regression
-> continue exploring
```

## Two checks after every important action

- **Task progress**: did the action achieve what it was meant to?
- **Anomaly**: did anything unrelated go wrong — a visual jump, clipped or overflowing text, a label that kept the old language, a wrong state, an audio cue on the wrong bus, a slow frame, an `ERROR:` or `WARNING:` line in the log?

An anomaly is a candidate. It becomes a defect only after it has been replayed from a reset state, or when a crash, trace or state dump already points at the game's code; in that case keep the note that it could not be replayed.

## What to cover in this game

- Both locales (English and Simplified Chinese), switching the locale while a screen is open.
- Keyboard and gamepad: every menu opens with a valid focus target and focus never escapes to the screen behind it.
- The save lifecycle: save, load, quick save and quick load, every slot the game has (`GameDefinition.save_slots`), a slot whose autosave is newer than the player's save and one whose save is newer (Continue takes the newer; the pause menu loads the player's own), a save made before the change under test.
- Time passing: day change, festival days, staying up past the late-night minute, defeat.
- Travel between locations and the state that must survive it.
- The windowed game for anything guarded by a headless check, because the automated suite never runs that code (`.agents/rules/testing.md`).

## Make it stay fixed

A reproduction that is stable becomes a GUT test under `games/<id>/test/unit/` or a check in `games/farm1/test/runtime/world_services_smoke.gd`. Do not leave a fixed defect guarded only by repeating the steps by hand.

## Boundaries

- A mistake in the steps taken is not a game defect.
- Do not claim a runtime problem is fixed without running the game again after the fix.
- Do not hide the cause behind a swallowed error, a fake success or a wrapper.
- Testing does not authorize publishing, tagging or any write outside the repository.
- When the game cannot be run, the result is "not verified", and the report says which step did not run.

## Minimum verification

- The original failing path can be reproduced.
- The cause was changed, not only the symptom.
- The same path passes when replayed.
- The directly related regression passes: `node tools/validate.js --skip-soak` for an ordinary fix, with the soak when save, load or day progression was touched.
