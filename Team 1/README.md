# TECH 3650 — BreakBricks

**Student:** Matthew Ngoy

**Project:** Project 1 — Capture the Flag

**Report build:** Studio version 82, inspected October 13, 2026

**Saved place:** `breakbricks_proj1.rbxl`, saved October 16, 2026

**Experience:** https://www.roblox.com/games/104045118137429

Steal the opposing team's flag and return it to your own flag while yours is home. The first team to three captures wins; a five-minute timeout awards the round to the higher score or ends in a tie. After a ten-second intermission, scores reset and flags change locations.

## Files

- [Roblox place file](breakbricks_proj1.rbxl): download and open in Roblox Studio to inspect the map and game scripts.
- [Project report](BreakBricks_Project1_Submission.pdf): design, implementation, playtesting, AI attribution, and four process screenshots.
- [Editable report](BreakBricks_Project1_Editable_Text.txt).
- [CTF server script](source/CTFServer_v82.server.luau): unchanged snapshot from version 82.
- [Screenshots](evidence/): the original images used in the report.

## Access and testing

The `.rbxl` contains the map and game scripts. The separate server script is the historical version-82 snapshot used for the report; it belongs in `ServerScriptService`. Instructor access to the online experience link has not been verified.

The report distinguishes the earlier classmate playtest from AI-operated Studio checks. Those checks covered individual mechanics and round transitions; full-route traversal and multiplayer balance remain unverified. The October 16 place file has not had a new Studio playtest as part of this upload.

## Attribution

Matthew set the design requirements. Claude assisted with scripting and troubleshooting; ChatGPT/Codex assisted with inspection, testing, and documentation. The code credits HowToRoblox tutorial ideas, and the experience uses the third-party ClassicSword tool.
