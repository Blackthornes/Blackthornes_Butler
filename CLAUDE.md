# Notes for Claude

Read this before working in this repo. The owner runs one Claude project per
addon, and this one (**Blackthornes_Butler**) was set up from the Farmer
project. Its sisters are **Blackthornes_Farmer**, **Blackthornes_Tradeskills**,
**Blackthornes_Equipment** and **Blackthornes_Pets** (all under
`Blackthornes/`). The projects cannot read each other's memory, so what one
needs to know about another lives in the repos, in this file and in theirs.
Keep them current: when a change here leans on something new in another
addon, or a standing rule from the owner applies to all of them, add it to
each file.

Nothing private goes in this file (no local paths, emails or account names).
It never ships: `.pkgmeta` leaves it out of the zip and
`tools/check_package.py` refuses it.

## Keep the thread small

A thread that fills up dies and its work is lost. In this repo:

- Checks, quiet: `python tools/runtests.py -q` (failures and the total
  only; `-q trash menu` runs just the suites with those words in their
  name) and `python tools/syntaxcheck.py -q`. The plain forms print a line
  for every suite and file (about 18 KB a run); leave those to CI.
- `grep -n` first, then read 80 to 150 lines. Pipe long output through
  `tail` or `cut -c1-160`. Never `cat` a file from the big files list.
- Commit and push each step, so a new thread can pick up from the branch.

## Long notes live in Docs/claude-notes.md

Every feature history, call list and sister note is there (about 135 KB,
never read whole). List its sections with `grep -n '^## ' Docs/claude-notes.md`
and read the one you need. Add new feature notes there, not here. **Before
you change any saved key, global, call between addons or shared file, read
its section first** (`What Butler calls`, `How Butler talks to the other
four`, `The one window`, `The shared minimap button` and the like): those
calls must stay stable and are changed in both repos together.

## Checking a change

Before every PR, follow `.claude/skills/verify/SKILL.md`: a bug fix starts
with a test that fails the way the game failed; act the steps out in the
fake game; run `python tools/check_house_rules.py` (player words and dark
glass, lines this change adds) and `python tools/checklist_for_change.py`
(the items in `Docs/change-checklist.md` this change touches). Every PR
body ends with `Checked:` and `Not checked:` lines. After three failed
rounds, stop and ask the owner. A miss a diff could have shown gets a
checklist item in the fix's PR. Details under "Checking a change" in
`Docs/claude-notes.md`.

## Standing rules (short; full words under "Standing rules in full" in Docs/claude-notes.md)

Each is the same in every addon's notes. Read the full text before work
that touches one.

- **One key per character.** A character is its GUID in saved data and in
  every call between addons, never a name. A GUID the client won't read
  means write nothing and offer nothing for an alt. Old records stay
  readable; nothing is deleted. Ask `Errands:IsMe(name)` right before any
  errand that targets a character, and refuse the one playing. Tested in
  `tools/test_notme.lua`.
- **Never shorten a character's last name.** Show first and last, made to
  fit by growing or wrapping.
- **Mute All Sounds.** Every `PlaySound` and `PlaySoundFile` asks
  `ns.Muted()` first, a new one too. Saved as `muteSounds` and
  `muteSoundsAt` (never rename).
- **Window spots.** Windows remember where they were dragged
  (`SharedWindow.KeepSpot(frame, key)`, `windowSpots`,
  `oneWindowDockSpots`; never rename). `UI/SharedWindow.lua` is
  FILE_VERSION 13 (Butler at the vendor, shelves, dock places, All Addons gear, no placing mid-drag) and
  `UI/WhatsNew.lua` FILE_VERSION 7.
- **Writing for players.** Plain, warm, sixth grade. Short sentences. No
  hype, no filler, no em-dashes, no questions to the reader. deDE changes
  with the English, in the "du" voice. `About.NOTE` is the owner's own.
- **Every list is dark glass:** `glass` and `glassAlt` in turn, a 1 px
  `border` line under each, `glassHover` with a gold edge under the mouse,
  `glassActive` with a gold left edge when picked. Fade a gradient through
  `Theme.LightGradient`, never SetAlpha alone.
- **Clear to post.** Nothing is published or uploaded without the owner's
  go-ahead. He tags releases himself.
- **Keep his data safe.** Never commit saved variables, tokens or anything
  from his machine (`tools/check_private_files.py` refuses them). Never ask
  him to paste a key.
- **Changelogs come from git history,** never from asking him. The release
  PR sets `ns.RELEASED_VERSION` in `Core/Init.lua` to the newest CHANGELOG
  version (`tools/check_release.py`).
- **Every reply that ships code says the PR is ready and whether the game
  needs `/reload` or a full restart** (a restart when a file is added,
  removed or renamed, or the TOC changes). Never merge or pull by hand on
  github.com or GitHub Desktop.
- **CurseForge descriptions are features only.**
- **Smooth play first, never at the cost of looks.** Nothing on a timer
  redraws a whole list when one thing moved. Coalesce bag, loot and cast
  events, skip hidden windows, spread big work over frames.
- **The client is WoW: Forever** (`## Interface: 16001`, a retail engine,
  classic classes). Read client values inside a pcall; register events
  through `ns.RegisterEvent`. Never assume an API exists: check with the
  probe and note it in `docs/FOREVER_API_FINDINGS.md`.

## Big files (read these in pieces)

Reading a huge file whole fills the context and the thread dies. Sizes are
from 2026-11-16 and only grow. Find more with `find . -name '*.lua' | xargs wc -lc | sort -n`.

- Never read a file below whole. Use `grep -n` to find the spot, then read
  about 150 lines at a time (Read with `offset` and `limit`).
- Never read data tables or locale files whole. Grep them for one key.
- CLAUDE.md is big too. Grep it for a heading, then read that part only.
- Generated files (`Data/`) are written by their `tools/` script. Never edit
  them by hand, and never open them to see what they hold.

Data tables (generated, grep only): `Data/ForeverItems.lua` 1467 lines, 159 KB; `Data/ClassSpells.lua` 1538 lines, 87 KB.

Locale (grep one key, never read): `Locale/ruRU` 1151 lines, 112 KB; `frFR`, `deDE`, `esES`, `zhCN` are each about 1197 lines, 84 to 89 KB.

Code:
- `UI/MainWindow.lua` 2918 lines, 120 KB: the Butler window and its groups.
- `UI/Widgets.lua` 2082 lines, 77 KB: shared widgets.
- `Logic/Verdicts.lua` 2134 lines, 92 KB: the rules that decide each item.
- `Logic/Jobs.lua` 1512 lines, 62 KB: jobs on other characters.
- `UI/Settings.lua` 2050 lines, 88 KB: Settings pages.
- `UI/BagWindow.lua` 1654 lines, 62 KB: the Bags window.
- `Logic/ClassTraining.lua` 1041 lines, 42 KB: class training.
- `Logic/Errands.lua` 914 lines, 38 KB: mailbox and bank errands.

Over 800 lines, same rule: `UI/WhatsNew.lua`, `UI/SharedWindow.lua`, `UI/SettingsPages.lua`, `Logic/Travel.lua`.

The same file lives in several addons: `UI/SharedWindow.lua`, `UI/WhatsNew.lua`, `UI/SettingsPages.lua`, `Logic/Travel.lua`, `Logic/ClassTraining.lua`. A fix to one belongs in all.
