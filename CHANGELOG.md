# Changelog

For game version 2.5.

## 1.1.0 - 2026-11-26
### Added
- A time skip line under the header, like the pause-menu journal: game day and clock (`DAY 4  21:04`; dashes while an effect glitches the clock), then `TIME SKIP AVAILABLE` or `TIME SKIP BLOCKED: <REASON>`.
- The verdict is the game's own `GameTimeUtils.CanPlayerTimeSkip`, plus Immersive Timeskip's extra checks (elevator, slowed time) when that mod is used. The reason is the first vanilla check that fails: combat, a no-time-skip effect, jumping or falling, diving, entering or leaving a vehicle, driving fast, a scene, a restricted area, a phone call, carrying a body and others.
- Read only: there is no Skip Time button. The line is read with the journal every 1.5 seconds.

Tested in game, not extensively. Mock test: 156 of 156 (13 new time skip cases).

## 1.0.1 - 2026-11-23
### Fixed
- TRACK and UNTRACK pop their button colours before they call the game, so an error in that call cannot leave colours pushed on every other CET window.

### Published build
- Untracking calls Keep Tracked Quest's `ToggleByKey` only inside a protected call. If the function is missing (it exists only in a locally patched copy of that mod) or fails, the quest is untracked through the game's journal. The build installed on the author's PC calls `ToggleByKey` without this guard.

In use in the author's game and working (installed build); tested, not extensively. Mock test: 129 of 129.

## 1.0.0 - 2026-11-23
- First version: the window with tabs, counts, search, sort by last update or distance, details pane, tracking and untracking.

Tested, not extensively. Mock test: 129 of 129.
