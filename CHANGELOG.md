# Changelog

For game version 2.5.

## 1.0.1 - 2026-11-23
### Fixed
- TRACK and UNTRACK pop their button colours before they call the game, so an error in that call cannot leave colours pushed on every other CET window.

### Published build
- Untracking calls Keep Tracked Quest's `ToggleByKey` only inside a protected call. If the function is missing (it exists only in a locally patched copy of that mod) or fails, the quest is untracked through the game's journal. The build installed on the author's PC calls `ToggleByKey` without this guard.

Not run in game. Mock test: 129 of 129.

## 1.0.0 - 2026-11-23
- First version: the window with tabs, counts, search, sort by last update or distance, details pane, tracking and untracking.

Not run in game. Mock test: 129 of 129.
