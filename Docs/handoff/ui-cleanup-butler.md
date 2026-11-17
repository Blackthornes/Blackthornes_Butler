# Butler UI cleanup (2026-11-16)

The owner asked for a UI cleanup in every addon: fix bugs, fix what makes
sessions run out of room, and recommend (with mockups) how to stop windows
overlapping and how to tidy Settings. This is Butler's part. Recommendations
are not built until he says yes, one at a time. Every new player word below
needs his approval and goes into all six languages.

Mockups: one PNG per idea, named by number, kept outside the repo.

## What was checked and fixed

Checked by reading the code, not in game:

- Every OnUpdate and ticker (38 places). All but one run only while
  something moves or shows, or are throttled. Fixed: the item menu built a
  new function every frame it was up (`UI/MainWindow.lua`).
- Bag events. `BAG_UPDATE_DELAYED` is settled into one read in `Bags`,
  `Trash`, `FreeSpace` and `SwapWhenFull`; the bag read is spread over
  frames; the list redraws only when its key changes. Nothing to fix.
- Buttons. Built every window in all six languages and measured each
  label. `Widgets.CreateButton` already grows to its text, so none is cut.
- Windows. All main windows are clamped to the screen and keep their spot.
- Saved data. No table found that grows without end.

Not fixed here, found while checking (they are recommendations 3 and 4):

- The bank is not one of the one window's docking places
  (`SharedWindow.PLACES`), so at the bank Butler opens wherever it was last
  left, which can be on top of the bank.
- Docking always goes to the right of the game's window. With no room
  there the screen's edge pushes it back over the game's window or the bags.
- Buy More, Swap When Full and Keep Across Characters share one fallback
  spot (the middle, 80 up), so two at once sit on top of each other.

## What made sessions run out of room, and the fix

- All the repos' CLAUDE.md files load into every session,
  about 100 KB, and more than half is the same standing rules six times
  over. Butler's is now about 6 KB: each rule in short, the full words moved
  word for word to "Standing rules in full" in `Docs/claude-notes.md`.
  The same trim in Farmer, Tradeskills, Equipment, Pets and Farmer Retail
  would save about 50 KB in every session.
- `tools/runtests.py` printed about 13 KB a run and `syntaxcheck.py` 5 KB.
  Both take `-q` now (failures and the total only), and `runtests.py -q
  word` runs only the suites with that word in their name. CI is unchanged.
  `runtests.py` is the same file in every repo;
  the change belongs in all of them.
- The big files list in CLAUDE.md had old sizes (Settings had grown from
  1387 to 2050 lines). Updated.

## Recommendations

### 1. Butler bar on the game's window (`1-butler-bar.png`)

At a vendor, mailbox or bank the full window (620 by 500) opens beside the
game's window. Most visits need one button. Hang a slim house-look bar
under the game's own window instead (parented to UIParent, anchored to
`MerchantFrame`, `MailFrame` or `BankFrame` by position, never hiding or
changing them): the count, the worth and the one button for that place,
plus Open for the full window. The secure Sell button already docks
(`UI:Dock`), so it can dock on the bar. "Open at Vendors:" and its two
sisters keep their meaning for players who have them ticked: ticked opens
the full window as today; the bar is a new choice, off unless ticked.
New words: "12 to sell" (count line), a Settings row for the bar.
Size: medium. Butler only.

### 2. Butler's marks on the game's own bags (`2-marks-on-bags.png`)

`UI/Marks.lua` already draws the coin, letter, lock and star in Butler
Bags. Draw the same marks on the game's bag squares (the trash can already
finds them, `UI/Trash.lua`), from `BagView:Marks`, repainted only for
slots whose verdict changed. Off unless ticked. Nothing of the game's is
hidden. New words: "Marks on Bags:" and its description.
Size: medium. Butler only.

### 3. Dock on the free side, and at the bank (`3-free-side-and-bank.png`)

In `UI/SharedWindow.lua` (the same file in all five addons, so this goes
into all five together): add the bank to `PLACES`; before placing, measure
the room right and left of the game's window and pick the side that fits;
if neither does, scale down to the gap (never below the smallest window
size). A spot dragged by hand still wins (`oneWindowDockSpots`). No new
words. Size: medium. All five addons.

### 4. Small boxes line up (`4-small-boxes-line-up.png`)

Buy More and Swap When Full sign up with `SharedWindow.KeepSpot` (Keep
Across Characters already does), become draggable, and a box that would
open on another one opens beside it. No new words. Size: small. Butler
only.

### 5. Fewer rows on the General page (`5-settings-general.png`)

Ten rows become four: "Bag Helpers:" with three ticks (Free Space, Trash
Can, Swap When Full); "What's New:" with two ticks and Open; one "Show
Tooltip Lines:" Off, Shift or Always box with a tick for each line. Saved
keys stay as they are and no choice is changed: a player whose lines
differ today keeps them until they use the new box. New words: "Bag
Helpers:", "Free Space", "After Updates", "Motion", "Show Tooltip Lines:",
"Lines:". Size: small to medium. The What's New and tooltip rows are in
every addon; the same change would fit them all.

### 6. Split the long Errands page (`6-settings-errands-split.png`)

Errands holds 10 groups and 23 rows. Move YOUR LISTS, UPGRADES FOR YOUR
CHARACTERS, KEEP ON EACH CHARACTER and KEEP ACROSS CHARACTERS to a new
"KEEP" page; fold the three "Open at" rows into one "Open Butler At:" row
with three ticks; put JUNK and CRAFTING (one row each) under one heading.
New words: "KEEP", "OPEN BUTLER", "Open Butler At:", "JUNK AND CRAFTING".
Size: medium. Butler only. The rule order board and `/bbutler` commands
that open a page must follow.

### 7. Shared settings shown once (`7-shared-settings-once.png`)

Window Style, Text Size, Window Size, Effects, Mute All Sounds, Combine
Addon Buttons, One Window, Window Spots, Sister Addons and the What's New
rows are the same in all five General pages. In the one window they could
live on one shared page on the rail. New words: "ALL BLACKTHORNES ADDONS".
Size: large. All five addons together.

## Suggested order

4 (small, clear win), then 3, then 1 and 2, then Settings 5 and 6. 7 last,
once the other addons have reported.
