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

## What this addon is for

The owner picked it (2026-10-10) from ten ideas for a new addon, and named
it **Blackthornes Butler**. It answers one question for every item in the
bags: what should I do with this? Keep it (for a quest, to wear, for a
Farmer goal, for a craft in Tradeskills' queue, as pet food), sell it, post
it on the auction house, disenchant it, mail it to the alt who needs it, bank
it, or look at it yourself. The full plan, with the order the verdicts are
decided in and the four phases, is `ideas/bag-butler-plan.md` in the
project's files.

**Equipment sets** (a player asked, the owner said check and fix,
2026-10-13): anything in one of the player's equipment sets is Keep,
"In your NAME equipment set", before every other rule, so no list or
sister can sell, mail or break it (`Verdicts:InSet`, step 0;
`C_EquipmentSet` read in a pcall, else the classic set calls, else no
sets; read again on `EQUIPMENT_SETS_CHANGED` and each time the window
opens). Matched by item ID, so a spare copy of a set piece is kept too.
Tested in `tools/test_digestbugs.lua`.

Phase 1 is built and seen in game (2026-10-10): Butler on its own.
`Logic/Bags.lua` reads the bags only while the window is up or a vendor is
open, 0.2 s after a burst of bag events, 40 slots a frame, and looks further
only at slots whose key (link, count, locked) changed (`Bags.version`).
`Logic/Verdicts.lua` judges each item in order (Always keep, quest item or
quest starter, no vendor value, Always sell, price still loading, grey,
else Look at it) and groups them Sell, Look at it, Keep (`Verdicts:Groups`,
kept until `Bags.version` or `Verdicts.version` moves). `Logic/Selling.lua`
is the Sell button (see the findings file for why it is secure).
Every button sits by the line it acts on (the owner, 2026-10-12: "the
buttons in Butler should go by the action that they need take"): Sell on
the Sell group's heading, Disenchant on Disenchant's, Move to bank on
Bank's, Take from bank on the Jobs heading, Fill mail on each character's
mail line, Log out on the next character's line, Craft and Fill on their
rows. A heading's button ends `UI.LINE_BUTTON_RIGHT` in from the right, so
the group's worth stays in sight; the secure ones (Sell, Disenchant) are
placed over it by screen position (`UI.PlaceOnLine`), the others anchored
to it (`UI:PlaceErrands`), all again whenever the list draws or scrolls
(`UI:PlaceButtons`). One whose line is out of sight waits at the window's
foot. A new button goes by its line too.
`UI/MainWindow.lua` draws the groups with `Widgets.CreateRowList` (Farmer's,
with the dark glass rows) and Butler's own right-click menu. The list's scroll bar is drawn and dragged by hand (`CreateScrollbar` in `UI/Widgets.lua`, the thumb following the cursor), not the game's Slider, which ran backwards on Forever (the owner, 2026-10-13); tested in `tools/test_scrollbar.lua`. Rows are two lines tall so a long reason or name wraps rather than
ending in "..." (the owner's rule). The window has the house size grip
below its bottom right corner (Tradeskills' window and Equipment's upgrade
quest panel have the same; asked 2026-10-11): drag to scale it 60% to 150%,
right-click for the normal size, saved as `windowScale` (account wide,
never rename it). The Sell button, a secure button outside the window, is
drawn at the window's scale. Saved and never
renamed: `alwaysKeep`, `alwaysSell`, `alwaysBank` (`[itemID] = true`),
`alwaysMail` (`[itemID]` = a character's short name), `sellTest`,
`sellBelow` (copper, nil when off),
`openAtVendor`, `openAtMailbox`, `openAtBank` (account), `folded` (per character). Not yet seen in game.

Rules from the plan that hold from the first feature on:

- **Nothing leaves the bags without the player's click.** No auto-sell, not
  even greys, unless a setting (off by default) says so. Sell all goes 12 at
  a time, what the vendor's Buyback tab holds, so every sale can be bought
  back. Quest items, upgrades, goal and queue materials, pet food under the
  limit and anything not yet judged ("Look at it") are never sold.
- **Mail only fills the game's own Send Mail form; the player presses
  Send.** Never hook or move the mail frame (Tradeskills v0.38.0 broke Send
  Mail that way).
- **Never touch a Blizzard frame:** no Hide, Show, HideUIPanel or field
  writes on the game's windows. The Butler window is its own frame, placed
  beside the bags by screen position, not parented to them.
- **Grey items are worth vendor only;** everything else is the best of
  vendor, auction (after the cut and deposit) and disenchant.

## How Butler talks to the other four

Phase 2 (2026-10-10, the owner said start): each sister has one call made
for Butler, so Butler never reaches into their insides. `Logic/Sisters.lua`
reads them, read only, inside a pcall, with no TOC dependency; a sister
that is not loaded, raises or answers something other than a table is
skipped, and a field of the wrong type counts as not given.

```lua
_G.BlackthornesTS.Butler:Advise(itemID)
  -- { auction (net copper each after the cut and deposit; nil for greys
  --   and bind on pickup), auctionNow (the same at today's cheapest
  --   listing by someone else, from a fresh scan only), belowCost (what
  --   one costs to make, when Tradeskills won't list it at its price),
  --   fast (true, false, or nil for middling),
  --   disenchant, canDisenchant, enchanter, need, mailTo, mailCount,
  --   bought (how many the account bought to disenchant), disenchanter
  --   (the disenchanter typed in its Settings, when its Mail page sends
  --   this gear there) }
_G.BlackthornesTS.Butler:SetBoughtToDisenchant(itemID, on, count)
  -- true, or false and why: the right-click menu's mark
_G.BlackthornesTS.Butler:FillMail(name, items, money)
  -- fills the Send Mail page; money (copper) is the gold fund's top-up
_G.BlackthornesTS.Butler:Jobs()
  -- each character's steps for the craft queue (see "Jobs on other
  --   characters")
_G.BlackthornesTS.Butler:Craft(recipeID)
  -- true and "crafting" or "opened", or false and why
_G.BlackthornesEquipment.Butler:Advise(link, bag, slot)
  -- { upgrade = "now" | "later" | nil, gain, sell (its bag coin), tool,
  --   alt = { key (a GUID), gain, level } when it is an upgrade for
  --   another character instead: a Mail row to the name
  --   Errands:NameOf(key) reads from Tradeskills' Holdings }
  -- nil for anything that is not gear; bag and slot let it see soulbound
_G.BlackthornesFarmer.Butler:Advise(itemID)
  -- { goal, have, target, need }: the character playing's own goals
_G.BlackthornesPets.Butler:Advise(itemID)
  -- { eats, buff, hours, count }: hours is for all the food carried and
  -- only a rough guess, so Butler shows it and never sells food on it
```

Each sister's `CLAUDE.md` lists its call under "What Butler calls here".
If one changes, change `Logic/Sisters.lua` and `Logic/Verdicts.lua` here
in the same breath. `Verdicts:Judge` keeps each item's verdict until
`Verdicts.version` moves, and `UI:Show` moves it (`Verdicts:Forget`), so the
sisters are asked once per item each time the window opens, never on a
redraw. How many of the item the bags hold (`Bags:Carried`) is part of the
kept key, since the sisters' answers move with it (an alt's `mailCount`, a
goal's `have`): only an item whose own count changed is asked again (eight
Medium Leather crafted one at a time were mailed as one, 2026-10-11). Fill
mail calls `Verdicts:Changed(true)` first, so the click sends what the alt's
queue wants then (`tools/test_mailcount.lua`). The verdicts they feed, in order, are at the top of
`Logic/Verdicts.lua`. Soulbound green or better gear is never put under
Sell: Disenchant, or Look at it. `/bbutler probe` says which sisters are
loaded and which answer Butler.

## Bought to disenchant

The owner asked (2026-10-11) for items bought on the auction house to
disenchant to be marked, easy to break, and followed by Butler.
Tradeskills keeps the marks, account wide (its `Logic/DisenchantBuys.lua`:
a buy after a search from its Disenchanting tab, or marked by hand), so
mail and the bank keep them. Butler reads `bought` from Advise
(`Verdicts:Bought`, step 8b, after the sisters' Keep; an item marked
bought is never an alt's upgrade, 2026-10-13): Disenchant whatever
else it would fetch, Mail to the enchanter when this character can't, else
Look at it. Bought rows head their group, their reason in violet; the
right-click menu's "Bought to disenchant" marks or unmarks through
`Sisters:MarkBought` (shown only with Tradeskills).

The Disenchant button (`Logic/Disenchanting.lua`) is a secure button like
Sell, outside the window and placed by screen position on the Disenchant
heading, or at the foot left of the Sell or errand buttons when that is out
of sight (`UI:FootRoom` calls `Disenchanting:Update(room)`). It shows
on Your bags while the character knows Disenchant and something is under
Disenchant, and casts once a click: its PreClick aims the spell at the next
slot (bought first) through `target-bag`/`target-slot`, re-reading the slot
and its verdict first, never a "/use" macro (that equips when the cast does
not start). Hidden, its aim emptied, in combat. Not yet seen in game.

## Always sell and upgrades

The owner asked (2026-10-13) that an item on the Always sell list that is
gear Equipment calls an upgrade to wear now (`upgrade == "now"`) is not
sold: `Verdicts:Decide` shows it as Look at it, "On your Always sell list,
but it's an upgrade for you", and the list keeps it. Back to Sell once it is
no upgrade. Tested in `tools/test_sellupgrade.lua`.

## Wait for a better price

The owner asked (2026-10-13) for items to auction to be folded away while
the auction house pays well under their usual price. In `Verdicts:Best`,
an Auction verdict becomes `wait` ("Wait for a better price") when
Tradeskills' `auctionNow` is under `Verdicts.LOW_NOW` (0.85) of `auction`;
the row keeps its usual worth. The group sits after Look at it and starts
folded on every character (`UI.FOLDED_AT_FIRST`, `UI.IsFolded`): an
opened one is saved as `folded.wait = false`. Nothing is sold or deleted.
It waits too when Tradeskills' Sell list would refuse it as a loss
(`belowCost`, what one costs to make, set only while "Recommend selling at
a loss" is off there; a player saw Butler say Auction for a craft
Tradeskills called a loss, 2026-10-13). A better way (disenchant) still
wins. Tested in `tools/test_waitprice.lua`. Not yet seen in game.

## Tradeskills' disenchanter

The owner asked (2026-10-11) for Butler to follow Tradeskills' disenchanter
setting (its Settings, Mail page: "Disenchanter" and "Mail gear up to").
Advise's `disenchanter` names that character when Tradeskills' own Mail
page would send the item there (its `QueueMail:GoesToDisenchanter`: green
up to the quality picked, can be disenchanted, never crafted gear, bind
on pickup or an upgrade for the character playing). `Verdicts:ForDisenchanter`, step 8c
after the sisters' Keep and Bought to disenchant, puts it under Mail to
that character, whatever the auction house or a vendor pays; a soulbound
copy and the character playing never get it. With nobody typed there,
Tradeskills picks the alt with the most Enchanting (more than the
character playing; its "Pick one for me", 2026-10-11), so Advise names
that one; with that unticked too, nothing changes. Tested in `tools/test_disenchantermail.lua`.

## All characters

A player asked for an account-wide inventory and the owner said build it
as the next phase (2026-10-10). The window's second view (`UI.view =
"all"`, the header's All characters button, `/bbutler all`, a Settings
button) lists every character's items with a search box: who has each,
how many in all, and a click opens a line per character with bags, bank
and mail and how old that read is. `Logic/Everyone.lua` builds it from one
call to Tradeskills, which already saves every character's bags, bank and
mail, inside a pcall, read only:

```lua
_G.BlackthornesTS.Butler:Holdings()
  -- { { key, name, short, realm, faction, isCurrent, linked,
  --     bags, bank, mail ([itemID] = count copies), bagsAt, bankAt, mailAt } }
```

The playing character's bags are Butler's own read (`Bags.slots`), the
freshest there is. Without Tradeskills (or when it raises) the view shows
only those bags and says so. Butler saves nothing for this view. Smooth
play: built only while shown, again when `Bags.version` moves or the window
opens, 300 counts and 40 new names a frame (`Everyone.BUDGET`,
`NAME_BUDGET`); a name the client has not loaded shows as "Item N", sorts
last and is filled in by `Everyone:NamesArrived` after `Items:Loaded`'s
burst. Search filters the built list. Your bags has its own box in the same
place (the owner said yes, 2026-10-13; `UI.bagSearch`, `UI:BagSearch`,
`UI.RowMatches`): by name or item ID, matches under their groups even when
folded, the ammo, jobs and gold lines left out while it has words, and
each view keeps its own words. Tested in `tools/test_bagsearch.lua`. The Sell button stays off in this
view, and a vendor opens the window on Your bags. Tradeskills'
`CLAUDE.md` lists `Holdings` under "What Butler calls here"; if it
changes, change `Logic/Everyone.lua` too. Not yet seen in game.

## At the mailbox and the bank

The plan's next phase (the owner said start, 2026-10-11).
`Logic/Errands.lua` watches `MAIL_SHOW`/`MAIL_CLOSED` and
`BANKFRAME_OPENED`/`BANKFRAME_CLOSED`, and the window comes up on Your bags
at every mailbox, and at the bank when there is something to do there
("Open at a mailbox" `openAtMailbox`, "Open at the bank" `openAtBank`,
account wide, on by default; `/bbutler mailbox` and `/bbutler bank` toggle
them), going when it closes. A window already up when a mailbox opens
belongs to the mailbox too, and walking away is also heard as
`PLAYER_INTERACTION_MANAGER_FRAME_HIDE` (mail or banker), in case the
client says that without `MAIL_CLOSED` (a player found the window left up,
2026-10-11).

Butler takes over the mailbox from Tradeskills' mail panel (the owner
picked it, 2026-10-11): while Butler's window is up at a mailbox,
`Errands:TellTradeskills` calls, inside a pcall and only when it changes,

```lua
_G.BlackthornesTS.Butler:Mailbox(covered)   -- true: its mail panel steps aside; false: it comes back
```

so closing Butler's window brings Tradeskills' panel back. Keep it stable;
Tradeskills' `UI/QueueMailPanel.lua` reads it.

- **Fill mail** fills the game's Send Mail page with the Mail group for one
  character a click (most items first; `Errands.filled` per visit), through
  `_G.BlackthornesTS.Butler:FillMail(name, items)` (Tradeskills'
  `QueueMail:Fill`). Mail rows carry `mailTo` and `mailCount`
  (`Verdicts:Decide`'s fifth return), and `Errands:Recipients` adds every
  item a Jobs mail step for this character names, so the mail holds what
  that line says (two herbs a Farmer goal kept were left out, 2026-10-13).
  An alt's queued craft also comes before a Farmer goal in
  `Verdicts:Kept`. A mail holds 12 stacks, so Fill mail puts the items taking the
  fewest stacks first (`Errands.FewestStacksFirst`; cheap vials were
  always last and left out, 2026-10-13), and once that mail goes,
  `Errands:Sent` fills what did not fit into the next one to the same
  character (`OnSendMail` counts what went). Tested in
  `tools/test_mailoverflow.lua`. The button sits on the first line
  that mails each character (the owner asked 2026-10-12, as Log out sits on
  the next character's line): a Jobs mail step, a gold top-up or a Mail
  row, set by `UI:PlaceMail` each time the lines are built (`UI.fillRows`,
  the row's own `row.action`, `Errands:FillMail(to)`). Only a character
  whose lines are all folded away keeps it at the window's foot. The
  player presses Send; Butler never
  sends, hooks or moves the mail frame. There are no mailbox Take buttons
  (the owner had them removed from Tradeskills; never add them unasked).
  Nothing is ever mailed to the character playing (a player found Fill
  mail addressed to themselves, 2026-10-11): `Errands:IsMe` (through
  `Verdicts:IsMe`) knows every name of it, from each `Holdings()` entry
  marked `isCurrent` or `playing`, and an Always mail entry, a `mailTo`,
  an `enchanter` or a gold top-up naming it is kept instead; Fill mail
  asks it once more last.
  Tradeskills' `FillMail` refuses it too, and its third return, the full
  name filled in, is what the chat line says.
  An item both this character's queue and an alt's want is a Mail row
  (2026-10-11, the owner: Butler handles queued crafts made on another
  character): `mailCount` is what Tradeskills spares once this
  character's crafts are kept back, so Fill mail sends that and the rest
  stays; with nothing to spare it is Keep. The Always keep list gives way
  to it the same way (`Verdicts:ForAltCraft`): the alt's share is a Mail
  row and the list keeps the rest. The Always bank list does not.
- **An alt's upgrade** (Equipment's `alt`, the owner asked 2026-10-11)
  is offered only while "Mail upgrades to your characters" is ticked
  (`altUpgrades`, account wide, off by default, never rename it;
  `Verdicts:AltUpgradesOn`, `/bbutler altupgrades`, Settings > Selling;
  the owner, 2026-10-13). Then it goes to them only as many as they wear: one, two for rings and trinkets
  (`Verdicts.Wears`, from the item's equip slot). `Verdicts:Groups` hands
  out copies in bag order, and a copy past that is judged again as if no
  alt wanted it (`Judge(entry, true)`), so it lands under Sell, Auction or
  wherever it belongs (a player found two pairs of pants in one mail).
  Clicks that act on a slot ask `Verdicts:VerdictOf(entry)`, the verdict
  the window shows, not `Judge`. Once a mail Butler filled goes, its alt
  upgrades are kept in `upgradeMailed[itemID] = { to, count, at }`
  (account wide, never rename it) and not offered again to that
  character for 30 days (`Verdicts.MAILED_KEEP`, when unclaimed mail goes
  back). Tested in `tools/test_altupgrade.lua`.
- **Holding an upgrade back** (the owner asked 2026-10-12): right-click a
  Mail upgrade row (`row.upgrade`) for "Don't mail this to NAME"
  (`Verdicts:HoldUpgrade`, `noUpgradeMail[itemID][name] = true`) or
  "Never mail upgrades to NAME" (`HoldAllUpgrades`, `noUpgradesFor[name]
  = true`), account wide by full name; never rename either. The alt
  branch skips a held item (`Verdicts:UpgradeHeld`), so it gets its next
  verdict and Fill mail leaves it. Settings > Selling > Upgrades for your
  characters picks a character, ticks Mail them upgrades and has Undo for
  its held items; `/bbutler upgrademail` lists them and `upgrademail undo
  NAME` undoes both. Tested in `tools/test_holdupgrade.lua`.
- **Fill the next mail** (the owner's goal, 2026-10-11: do the work for
  the player): once a mail Butler filled goes (`MAIL_SEND_SUCCESS`, with
  `Errands.sending` set by `FillMail`), `Errands:Sent` waits
  `Errands.NEXT_DELAY` for the bags, then fills the next character's, or
  says that's all. Only while the window is up at the mailbox and out of
  combat; a mail sent by hand fills nothing, and `MAIL_FAILED`
  (`SendFailed`) offers the same character again. "Fill the next mail"
  (`fillNext`, account wide, on unless unticked, never rename it;
  `/bbutler fillnext`). The player still presses every Send.
- **Always mail to** (the right-click menu, asked 2026-10-11) puts an item
  on the player's **Always mail** list for one of their characters
  (`alwaysMail`, `[itemID]` = the character's full name, account wide,
  never rename it; one saved as "Ana S." before names were whole is read
  as the full name by `Errands:FullName`, and left as saved):
  it goes under Mail addressed to them, all of it. The characters are
  Tradeskills' `Holdings()` on the same realm and side
  (`Errands:Characters`), so the choice shows only with Tradeskills;
  soulbound items are never offered and are kept if already listed.
- **Move to bank** puts the Bank group away: a new verdict for the
  player's **Always bank** list (`alwaysBank`, `[itemID] = true`, account
  wide, never rename it; the right-click menu and `reset confirm` cover it).
- **Take from bank** brings out what this character's own queued crafts
  want, `_G.BlackthornesTS.Butler:FromBank()`, smallest stacks first until
  each count is covered. It also brings out bank gear Equipment's
  `Advise` calls an upgrade to wear now (the owner asked 2026-10-13;
  `Errands:BankUpgrades`, the best for each slot, two for rings and
  trinkets), read only while the bank is open and kept until `Bags.version`
  moves or `PLAYERBANKSLOTS_CHANGED`.

Both bank moves use `C_Container.UseContainerItem` (the selling test found
it works from addon code), one stack every `Errands.STEP`, each slot read
again first; a stack that does not move means the other side is full, and
the run stops and says so. Nothing in combat. The bank is read only for a
click. Not yet seen in game.

## The gold fund

The owner asked (2026-10-11) for a minimum gold balance on his characters,
topped up by mail from a character with more. `Logic/Funds.lua`:
"Keep at least" on the Gold page of Settings (`goldMinimum`, copper,
account wide, nil when off; `/bbutler goldmin 50g`) and one character's
own amount (`goldMinimumFor[full name]`, 0 meaning it keeps nothing
back; the page's character picker, "They keep" and "Use the usual").
Never rename either. `Funds:Plan` reads Tradeskills' `Holdings()` (its
`gold` and `goldAt`, as last seen; live for the character playing) and,
for each character on this realm and side below its amount, biggest need
first, offers what the purse can spare above the sender's own amount, less
30 copper postage a mail. At a mailbox those are the Gold rows at the top
of the window (with how old each balance is), and `Errands:Recipients`
gives each its `money`, which Fill mail passes to Tradeskills'
`FillMail(name, items, money)`: with that character's items, or gold
alone. The player presses Send. Gold Butler filled and then saw leave the
purse (`Funds:Filled`, `PLAYER_MONEY`) is kept in `goldSent[full name]`
(never rename it) and counted toward that character until its own record
shows it took it, or 30 days pass (unclaimed mail goes back), so it is
never sent twice. `/bbutler gold` lists everyone. Smooth play: the plan is
worked out only while the window draws it, again only when the purse
(debounced 0.2 s) or a setting moves. Tested in `tools/test_funds.lua`.
Not yet seen in game.

## Filling the quiver

The owner asked (2026-10-11) for Butler to offer to fill a hunter's ammo
pouch at a vendor that can, "with the best ammo you can use, for the
weapon type you're using and pouch type you have on". `Logic/Ammo.lua`:
on a hunter (`UnitClass`), the weapon in the ranged slot (or main hand) is
a bow or crossbow (arrows) or gun (bullets), and the ammo bag is the bag
whose family holds arrows (quiver, 1) or bullets (ammo pouch, 2). At a
vendor, the window's first row is Ammo: the vendor's ammo of that kind the
hunter can use (`isUsable`, its level), most damage first (the tooltip's
"Adds X damage per second", read through the game's own
`AMMO_DAMAGE_TEMPLATE` so another language's line and decimal comma count,
the English words kept as a fallback; else item level), and how many whole lots fit
the bag's empty slots and the room left in its stacks of the same ammo.
The row's Fill button buys them, one `BuyMerchantItem(index)` (one lot)
every `Ammo.GAP`, each re-checked first; fewer lots when the purse is
short (said so), no button when it can't pay for one. The gold fund's
amount is only for mailing gold, never for spending (the owner,
2026-10-11), so Ammo and anything else that buys ignore it. A bag that
doesn't match the weapon, or no ammo bag, gets a row that says so and no
button; a full bag gets no row. `Ammo:Keeps` keeps the weapon's own ammo
out of Sell (step 4b). No setting: it shows only where it can help. Not
yet seen in game; `/bbutler probe` has an ammo line. Tested in
`tools/test_ammo.lua`.

## Forever's game tables

The owner asked (2026-10-12) for the Forever client's own game tables to be
put to use in every addon. Butler's part is `Data/ForeverItems.lua`,
written by `tools/make_forever_items.py <folder>` from the client's
ItemSparse table (kept privately in the project's files, never committed;
rerun it when Forever's build changes, never edit the data by hand). It
holds only two things: `SELL[itemID]`, what a vendor pays in copper, and
`BAGS[itemID]`, the bag family of containers that hold only some things
(quivers, ammo pouches, soul, herb, enchanting, mining and skinning bags).
The live game always wins: `Items:SellPrice` takes the tooltip, then item
info, and only for an item the client has not loaded yet answers
`Items.TableSellPrice` (not kept, so the live price replaces it on
`GET_ITEM_INFO_RECEIVED`); `Ammo:Bag` and `FreeSpace.Read` read a bag's
family from the client and fall back to `Items.TableBagFamily(bag)` only
when it gives none. `/bbutler probe` has a "forever tables" line comparing
the two for each bag. Never name where the tables were downloaded from;
say "the Forever client's game tables". Tested in
`tools/test_foreveritems.lua`.

## Learning from the player

The owner's goal (2026-10-11): the addons should work "almost like it's
magic", learning from what the player does. `Logic/Learning.lua` watches
three things the player does anyway, through post-hooks on single calls
(`hooksecurefunc` on `BuybackItem`, `C_Container.UseContainerItem` and
`SendMail`; no frame is touched) and one event each:

- a buyback of something Butler's Sell button sold this visit
  (`Selling.soldIDs`) is kept from then on;
- an item sold by hand at a vendor (not by Butler's button, a grey, quest,
  soulbound green or better, or already Sell) on `Learning.SELLS` (2)
  visits goes under Sell;
- an item mailed by hand to the same one of the player's characters
  (`Errands:Characters`, never the one playing, never mail an addon filled,
  `Learning.ADDON_SUBJECTS`) `Learning.MAILS` (2) times goes under Mail to
  them, so Fill mail sends it.

Saved, account wide, never renamed: `learned[itemID] = { verdict, to, at }`
and `learnTally = { sells, mails }`; "Learn from what you do" (`learn`, on
unless unticked) on the Errands page. A learned keep sits right after the
player's lists in `Verdicts:Decide`; a learned mail or sell only after the
sisters' Keep (steps 8d and 9b), so a habit never sells or mails an
upgrade, a goal or craft material or pet food. Any right-click pick clears
what was learned (`Verdicts:SetChoice` calls `Learning:Forget`), the menu
shows "Forget what Butler learned" for a learned item, `/bbutler lists`
shows them and `reset confirm` forgets them. Tested in
`tools/test_learning.lua`. Not yet seen in game.

## Jobs on other characters

The owner asked (2026-10-11) for a button per step that swaps to the
character who has to do it ("go craft Medium Leather on another, then
send back"). Addons don't run on the character list, so they can't pick a
character; the owner said yes to a step list with a Log out button
instead. `Logic/Jobs.lua` reads Tradeskills' `Butler:Jobs()` (one entry
per character this one can mail, never another account's: `name` in full,
`isCurrent`, `steps`; a step is a craft, `{ kind = "craft", recipeID,
itemID, name, count, forNames, ready, missing }`, or a mail, `{ kind =
"mail", to, items, crafts }`) and shows the Jobs group first on Your bags:
this character's steps (a Craft button on a craft it has the materials
for, which calls Tradeskills' `Butler:Craft(recipeID)`: it crafts with the
profession open, else opens its Queue tab, whose Open button opens the
profession), then "Next: NAME" for the other character that can get on
with a step, then "Then: NAME" for the rest. Mail steps are done with
Fill mail at a mailbox, as before.

The **Log out** button (`BlackthornesButlerLogout`) is a secure button
running the game's own `/logout` as a macro (addon code may not log out by
itself). It sits on the next character's row ("First:" or "Next:"), where
a craft's Craft button sits (the owner asked 2026-10-11: "the log out
button should be next to the step that needs the logout"), placed by
screen position over that row (`Jobs:UpdateLogout`, `Jobs.NextRow`, called
from the list's `onRefresh` so it follows a scroll, and from
`UI:FootRoom`). It shows only while that row is on screen, and hides in
combat, while the window moves and in All characters. There is no other
Log out button (the header and gold foot ones are gone); once nothing is
left here the footer says "Everything here is done" (`Jobs:DoneHere`).
Not yet seen in game; `/bbutler probe` has a jobs line (`Logout`,
`SLASH_LOGOUT1`).
When nothing here can be done yet and the next character can (the owner,
2026-10-11: "a sub craft on another character needs to go to a top step
if they already have the materials"), `Jobs:Plan`'s `goFirst` puts that
character's line, "First: NAME", above this character's steps, and Log out
sits on that line. Tradeskills names who holds a missing
material (`missing[i].from`, "NAME has it.") and gives that character a
mail step to the crafter (`forCraft`), the character playing too (an
item's `bank` is how many to take out of the bank first, and the step
says so); the next character is the one
whose `forCraft` mail feeds a craft here, before any other ready one.
The character playing is never one to log out for: a job named as
any name `Errands:IsMe` knows counts as here, whatever `isCurrent` says,
and a mail step to the character doing it is dropped (`Jobs.Clean`). A player
was told to log out for the character they were on, 2026-10-11.

Mail waiting (the owner, 2026-10-13: "if a character needs to visit the
mail for something sent to it, butler should move that up the priority
list"): Tradeskills' `Jobs()` gives a `{ kind = "pickup", items, forCraft
}` step for materials a character's crafts count on that sit in its
mailbox or are on their way, and for anything mailed to it not yet seen
arrive (its `Queue:InMailFor`, `QueueMail:InFlightItems`). `Jobs.Clean`
puts it first on that character's line ("Get your mail"), it counts as a
step that can be done now, and `Jobs:Plan` picks the next character by
rank: a `forCraft` mail that unblocks a craft here, then mail waiting for
its crafts, then any mail waiting, then the first that can get on with
it. Tested in `tools/test_jobs.lua`.

Profession cooldowns (the owner said yes, 2026-10-12): Tradeskills'
`Jobs()` also gives each character's ready cooldown as a step, `{ kind =
"cooldown", name (its group, "Transmute"), craft, recipeID or itemID }`
(its `Logic/Cooldowns.lua`). It counts as a step that can be done now, so
it can put a character on "Next:" with Log out; a recipe's has a Craft
button (Tradeskills' `Butler:Craft` makes it once, queued or not, with the
profession open), an item's (the Salt Shaker) says to use it from the
bags. Tested in `tools/test_jobs.lua`.

Logging in (`PLAYER_ENTERING_WORLD`'s initial login, `Jobs.LOGIN_DELAY`
later) on a character with a step brings the window up and says what it is
("Jobs at login", `jobsAtLogin`, account wide, on unless unticked, never
rename it; `/bbutler joblogin`). Once the last step here is gone,
`Jobs:Noticed` says who is next, once. `/bbutler jobs` lists everyone's.
Smooth play: Tradeskills is asked only while the window draws the list,
again only when `Bags.version` or `Jobs.version` (moved as the window
opens) moves; no timer. Tested in `tools/test_jobs.lua`.

## Class training

The owner said build it (2026-10-13), in Butler and Equipment: which class
spells the character (and the other characters) can train now and soon,
and what they cost. `Logic/ClassTraining.lua`, `Data/ClassSpells.lua` and
`tools/make_class_spells.py` are the same files in both addons (a fix to
one belongs in both); neither calls the other for it. The data is
generated from the Forever client's game tables (`make_class_spells.py
<tables folder> --build <build>`; never edit it by hand, never commit the
tables): each class's trainable spells with level, rank, races and the rank
before. With `--prices <Classic world database dump> --learn <a Classic
client's SpellEffect table>` it also writes `CLASS_SPELL_PRICES`,
Classic's trainer prices (the full price where Classic had a discount),
which stand in until a trainer shows its own (`ClassTraining.PriceOf`,
`spell.guess`); never name where either came from. Real prices, which spells no trainer teaches (a quest does) and where
the trainer stands are not in the tables: the first look at a class
trainer's window keeps them, account wide, in `classTrainingData = {
prices, notTaught, trainers, characters }` (never rename it), reading the
"unavailable" lines by turning the trainer's filter on and back. Each
character notes what it can train (`characters[guid]`) for the others.
"Class training" on the Gold page (`classTraining`, on unless unticked,
never rename it) and `/bbutler training [on|off]`.

In Butler: the Jobs group leads with "Train N new spells" (Train all at a
class trainer, one spell every `ClassTraining.GAP`, only what the purse
pays for; Show the way elsewhere, through TomTom or the game's map pin),
the next level's spells and a "Then:" line for each other character
(`Jobs:TrainingLines`, `UI.UpdateTrainRow`). The window comes up at a
class trainer with something to train (`Jobs:AtTrainer`). The gold fund
keeps back the playing character's `ReadyCost()` and tops another
character up by its `Other(guid).cost` (`Funds:Plan`). Tested in
`tools/test_classtraining.lua`. Not yet seen in game.

## Gold goals

The owner said build it (2026-10-13, from a mockup; "the purse section
goes at the bottom of Butler"). `Logic/GoldGoals.lua` works out three
goals, filled from one purse in order: class spells (`ClassTraining`'s
ready spells, else the next level's), profession training (the next rank
once the skill reaches it, from `GoldGoals.RANKS`, Classic's usual
prices, plus Tradeskills' `Butler:LearnCost()`, the trainers' recipes the
character could learn now) and riding (`GoldGoals.RIDING`). Each is
ready (green), saving (gold) or far (levels away, dim). The level cap is
read from the game (`GoldGoals.MaxLevel`: 30 in the beta, 60 at release,
60 when the game does not say); never hardcode it. A trainer's own price
and level, read at `TRAINER_SHOW` by spell name (not at a class trainer),
win over Classic's and are kept. The purse is less what the gold fund
will mail to another character (`GoldGoals.SetAside`); the fund never
limits spending.

`UI/GoldGoals.lua` draws it under the list (`UI:PlaceGoals`; the window
grows by its height, its top stays put): GOLD GOALS with the purse, a
segment per goal, and a dark glass row per goal with a glowing bar. A
click on the heading folds it (`folded.goldGoals`, per character). In All
characters the same place lists every character (`GoldGoals:Everyone`,
from each one's note in `goldGoalsData.characters[guid]`, gold from
Tradeskills' `Holdings` when it has it), with how many goals are met.
"Gold goals" on the Gold page (`goldGoals`, on unless unticked) and
`/bbutler goals [on|off]`. Never rename `goldGoals` or `goldGoalsData`.
Tested in `tools/test_goldgoals.lua`. Not yet seen in game.

## What Farmer calls here

Farmer's XP bar (2026-10-13) reads class training for its level-up cheer,
inside a pcall, read only, falling back to Equipment's copy:

```lua
_G.BlackthornesButler.ClassTraining:IsOn()
_G.BlackthornesButler.ClassTraining:Plan()   -- ready, cost, unknown
```

Keep these names and fields stable (they are the shared
`Logic/ClassTraining.lua`'s, so Equipment's too); if one has to change,
change Farmer's XP bar in the same breath.

## Sell below

A player asked for anything looted below a value they set to be marked
junk, and the owner said add it to Butler (2026-10-11). "Sell below" on
the Errands page (`Widgets.CreateMoneyBox`: gold, silver and copper boxes,
saved on Enter or leaving a box) and `/bbutler sellbelow 50s` (`off` to
stop) save `sellBelow`, copper, account wide, nil when off. It is step 11
in `Verdicts:Best`: after the player's lists, quest items, no vendor value
and every sister's Keep, an item whose most (vendor, Tradeskills' auction,
a usable disenchant) is under the amount goes under Sell, "Worth less than
X". Soulbound green or better is never included, and the step is skipped
when Tradeskills gave no answer, since without an auction price junk and a
good white item look the same. It only adds to Sell: nothing is deleted,
and selling is still the Sell button. Tested in `tools/test_sellbelow.lua`.

## Free bag space

The owner asked (2026-10-11) for the free bag slots on the game's own bag,
and picked the backpack button of the bag bar from a mockup
(`mockups/butler-free-space-bag-button.png` in the project files).
`UI/FreeSpace.lua` puts a number in the button's corner in the game's stack
count font: white, amber at 8 free or fewer (`FreeSpace.AMBER`), red at 3
or fewer (`FreeSpace.RED`). Only bags that take anything count; profession
bags (a bag family other than 0) and the reagent bag are listed apart on
the tooltip. Hovering the button adds each bag's free slots under the
game's own lines. "Free bag space" on the General page (`freeSpace`,
account wide, on unless unticked, never rename it) and `/bbutler
freespace` turn it off and on. When the game shows its own count on the
button (`MainMenuBarBackpackButtonCount`), Butler's stands down.

How it sits on a game frame without touching it: the number is Butler's own
frame, a child of `MainMenuBarBackpackButton` so it follows the button's
showing, scale and Edit Mode place; it takes no mouse and nothing is
written on the button, and the tooltip lines come through `HookScript`
("OnEnter"), which runs after the game's own script. No Hide, Show or
field writes. A bag addon that takes the bar away takes the number with
it. Smooth play: `BAG_UPDATE_DELAYED` and `BAG_CONTAINER_UPDATE` only mark
it stale, one read of a handful of calls follows 0.2 s later and only while
the number is visible (its `OnShow` reads what it missed), and the text is
set only when the number or its colour changed. `/bbutler probe` says
whether the button was found. Tested in `tools/test_freespace.lua`. Not
yet seen in game.

## Who has it

The owner said build it (2026-10-11). `UI/WhoHas.lua` adds lines to every item's tooltip
saying which characters hold it and where: "Your characters have 33", then
"Bob Wither   21 (20 bags, 1 mail)", most first, six names at most, the
character playing marked "(you)" and left off when only its own bags hold
it. It reads Tradeskills' `Butler:Holdings()` (the same call as All
characters), so without Tradeskills there are no lines; an old name-realm
record of the character playing (`playing` without `isCurrent`) is not
counted again. Only GameTooltip and ItemRefTooltip get lines (never the
compare tooltips), added through `TooltipDataProcessor`'s post call, or
`OnTooltipSetItem` by HookScript on a client without it; nothing is
written on the tooltip. Smooth play: a hover only looks its item up in a
lookup by item ID; bag, bank and mail events only mark it stale, and the
next hover builds it again at most once every `WhoHas.REBUILD_GAP` (1 s).
"Who has it" on the General page (`whoHas`, account wide, on unless
unticked, never rename it) and `/bbutler whohas`. Tested in
`tools/test_whohas.lua`. Not yet seen in game.

## Butler on tooltips

A player asked; the owner said yes (2026-10-13): "add Butler as the last
line on the tooltip and only if Butler is loaded". `UI/VerdictTip.lua`
adds one line to the tooltip of an item in the bags of the character
playing: "Butler: Sell" (or "Butler: Mail to FULL NAME"), with what one is
worth (the verdict's `unit`) on the right. Last line: its post call (or
`OnTooltipSetItem` script hook) goes in `VerdictTip.DELAY` (1 s) after the
first `PLAYER_ENTERING_WORLD`, so it runs after Who has it and the lines
other addons hook at login. Only GameTooltip and ItemRefTooltip; nothing
is written on them. Smooth play: a hover reads one slot (the hovered bag
button's `GetBagID`/`GetID`, else where Butler's last read saw the item,
read again to be sure), takes the window's row when `Verdicts.groupCache`
is current, else `Verdicts:Judge` for that one item (kept). Butler reads
the bags only while its window or a vendor is up, so a hover that finds
nothing on stale bags asks for one `Bags:Scan()`. "Butler on tooltips" on
the General page (`verdictTip`, account wide, on unless unticked, never
rename it) and `/bbutler tooltip`. Tested in `tools/test_verdicttip.lua`.
Not yet seen in game.

## The trash can

The owner asked (2026-10-13) for a small can on the item worth the least
when a player's bags are full. `UI/Trash.lua`: while a bag window is open
and the bags that take anything have no free slot (`Trash.FREE`, 0; the owner
asked, 2026-10-13, for it to go when a slot frees), a gold can
(`Media/Trash/TrashCan.tga`, drawn by `tools/make_trash_art.py`; rerun it,
never edit the TGA) sits on the top right of the stack worth the least
(`Trash:Pick`: the verdict's `unit` times the stack) among items Butler
would Sell, Auction or Disenchant anyway (`Trash.FROM`), priced, not
locked, not a quest item. Keep, Mail, Bank, Wait and Look at it never get
it. Butler never deletes: a click picks the item up
(`C_Container.PickupContainerItem`, after reading the slot again) and says
to drop it outside the bags, where the game's own box asks first. The can
is Butler's own button on UIParent, anchored to the game's item button
(found as Equipment's `BagIcons` does); the bag windows are only hooked
(`UpdateItems`, `OnShow`, `OnHide`). Hidden in combat, at a vendor and while
the cursor holds something. "Trash can when full" on the General page
(`trashCan`, account wide, on unless unticked, never rename it) and
`/bbutler trash`. Tested in `tools/test_trash.lua`. Not yet seen in game.
Farmer has the same can by its own prices (its `UI/Trash.lua`, same art
and tool) and stands down while `_G.BlackthornesButler.Trash` exists, so
only one shows; keep `ns.Trash` on the global, or change Farmer's
`Trash.ButlerHasIt` too.

## Butler's voice

The owner asked (2026-10-11) for Moroes, Karazhan's butler, to answer when
the player opens Butler ("You rang?", file 555818) and closes it ("Now,
where was I? Oh, yes...", 555814); he tested both IDs in game. `UI:Say`
plays the game's own file by ID (`PlaySoundFile(id, "Dialog")`), so no
Blizzard audio ships in this public repo. It must never speak over an
NPC, and the client can't say when one is talking, so a line is said only
when the player opens the window (`UI:Toggle`, `/bbutler all`) or closes
it (its OnHide, unless `LeftVendor`/`LeftPlace` closed it:
`closingByItself`), and never while a vendor, mailbox, bank or any NPC
(`UnitExists("npc")`) is open (`UI.AtAnNPC`). A window that comes up by
itself (`UI:Show`: vendor, mailbox, bank, Jobs at login) says nothing.
Each line waits `UI.VOICE_GAP` (180 s). "Butler's voice" on the General
page (`voice`, account wide, on unless unticked; never rename it). Tested
in `tools/test_voice.lua`. Not yet seen in game.

## German translation

The owner said yes (2026-10-12) to German in Butler, after Pets' pilot and
Farmer. Players are told the language as "Deutsch"; the code names stay
`deDE` and `Locale/deDE.lua`. It ships with 0.2.0.

- **English is the key and the fallback.** `Locale/Locale.lua` (first in
  the TOC, Pets' file) makes `ns.L`, whose missing keys answer the key
  itself; `L.Format(key, ...)` is `string.format` on the translation and
  puts values named by place (`%2$s ... %1$d`) in order.
- **Adding a string:** `L["English text"]` or `L.Format("English %s",
  value)`, a literal where it is written, one whole sentence a key (never
  pieces joined with `..`), both forms for a plural; add its line to
  `Locale/deDE.lua` (informal "du", a polite butler's voice) and run
  `python tools/check_locale.py` (warns only; keep it at 0 missing).
  `tools/test_locale.lua` loads Butler as a German client.
- **Left in English on purpose:** slash command words and typed words
  (`off`, g/s/c), saved and internal keys (verdict keys; `Verdicts.LABELS`
  only shows them; Ammo's `word`, with `label` shown), secure button
  macros, mail subjects that are matched (`Learning.ADDON_SUBJECTS`),
  Ammo's English DPS fallbacks, data and client names, debug lines and
  every `ProbeText` (`/bbutler probe`).
- German runs about 30% longer: buttons grow to fit and rows wrap; a new
  fixed width must wrap or grow, never end in "...".

## How this repo was set up

It copies Pets (itself Equipment's, itself Farmer's) on purpose, so check the
sisters before inventing a convention:

- **Layout** `Core/ Data/ Logic/ UI/ Probe/ tools/ docs/`, one module per file through
  `ns.NewModule`, no Ace3 or LibStub. The global is `_G.BlackthornesButler`,
  the commands `/bbutler` and `/butler`, the saved data
  `BlackthornesButlerDB` (account) and `BlackthornesButlerCharDB` (per
  character). Never rename them once released.
- **Palette** is the house one (`ns.COLORS`). `UI/Theme.lua`,
  `UI/Widgets.lua`, `UI/Minimap.lua` and `UI/Settings.lua` are Pets' with
  the pet parts taken out. The minimap button starts at 290 degrees, clear
  of Tradeskills' at 170, Farmer's at 200, Equipment's at 230 and Pets' at
  260. The TOC icon is `INV_Misc_Bag_08`.
- **Tools** (`syntaxcheck`, `lintcalls`, `runtests`, `check_release`,
  `check_package`, `check_private_files`, `announce_discord`,
  `post_general` and their tests, `link.ps1`, `deploy.ps1`) are Pets' with
  the names changed. If one of them gets a fix in a sister repo, bring it
  here too.
- **Tests** are `tools/test_*.lua`, found by name. `tools/testenv.lua` loads
  the files the TOC lists, so there is no second list to keep.
- **PRs** follow the sisters' habit: a "Before:" and an "After:" paragraph
  in plain words, then a short "How" naming the functions and tests touched,
  that the checks pass, and whether `/reload` is enough. Release PRs are
  `release/X.Y.Z` branches titled "Changelog for X.Y.Z".
- **CurseForge:** project **1739020** (the owner created it 2026-10-11),
  on the TOC's `X-Curse-Project-ID` line. The first release is 0.1.0. The
  repo needs the `CF_API_KEY`, `DISCORD_WEBHOOK_URL` and
  `DISCORD_GENERAL_WEBHOOK_URL` secrets, which he sets himself. The logo
  follows the house style: a dark 512 px tile, the gold satchel, grey
  "BLACKTHORNES" and gold "BUTLER".
- **API findings** go in `docs/FOREVER_API_FINDINGS.md`. Tradeskills',
  Equipment's and Pets' files of the same name record what the Forever client
  does for their areas; read them before relying on an API.

## The settings pages (from Tradeskills)

The owner asked (2026-10-09) for Tradeskills' Settings upgrade in Pets,
Equipment and Farmer, and Butler copied it. `UI/SettingsPages.lua` is the
same file in all four (a fix to it belongs in all four): category pages
along the top (`settingsPage`, the one left on), two columns a page, what a
setting does as the row's tooltip ("Show descriptions",
`settingsDescriptions`, off by default, puts it back under the rows), "Find
a setting", and Text size (`textSize` normal/large/larger adds 0/1/2 to
`Theme.sizes`, a lookup over `Theme.BASE_SIZES`; read once, so it waits for
/reload). The window fits its fullest page, so no page scrolls. Add a
setting with `pages:Row(page, column, label, description)` and
`pages:Section(page, column, "HEADING")` in `UI/Settings.lua`; every
`/bbutler` command has a button there, but never one that deletes data.
Butler has Selling and General so far; the plan's other pages (Verdicts,
Pet & craft, Window) come with their features. `reset confirm`, which
empties the player's lists, stays typed.

## The house frame (Titanforged)

The owner picked this look for all the addons on 2026-10-04 from two mockups
(the other was "Arcane Glass"), and Tradeskills got it first. It's the
game's own window shape with the light turned up: a gold metal rim with
corner gems, a round portrait with the addon's emblem, the name on a plate
across the top edge and a red close gem. Buttons are raised metal with gold
labels, and the main action is solid gold with dark "ink" lettering; a
primary button given its own dark `baseColor` keeps a gold label, or it
reads as an empty box (checked in `tools/test_titanforged.lua`).

It lives in `UI/Titanforged.lua` (`Titanforged:Dress(frame, opts)`,
`:Opened(frame)`), with the art in `Media/Frame/*.tga`, drawn by
`tools/make_frame_art.py`; rerun it, never edit the TGAs. All are
Tradeskills' copies (by way of Pets). Butler's emblem is the **satchel**
(`EMBLEM = "satchel"`): a bag with a handle, the flap's edge and a coin cut
out, drawn here so it reads at the 36 px the portrait shows it. The Butler
window wears the full frame, its list in a well (`Theme.Recess`); Settings
has the plate and close gem but no portrait, which would sit over its first
heading. Butler has no Window effects setting, so `Motion.Level()` is always
"full" and the glint always runs. Anything placed inside a dressed window
stays 6 pixels in from its edge, or it covers the rim.

List rows are dark glass, as in the other addons (the owner picked it
2026-10-10 over a gold glow that lit every row): `glass`/`glassAlt` bands
in the well with a fine line under each, the gold wash only under the
mouse. A gradient that fades goes through `Theme.LightGradient`, which
hides it at 0; faded with SetAlpha alone it stayed lit on Forever.

## The Blizzard window style

The owner asked (2026-10-10) for a choice of the game's own look beside
Titanforged, in every addon; Butler has it from the start. "Window style"
in Settings (`windowStyle`, `titanforged` or `blizzard`, Titanforged by
default; read once at login, so a change waits for /reload, as Text size
does). `UI/BlizzardLook.lua` is the same file in all five (a fix to it
belongs in all five): picked, it lays the game's colours over
`Theme.colors` (grey metal, the game's gold, plain rows with a blue bar for
the one picked) and puts out the halos; `Titanforged:Dress` hands the
window to `BlizzardLook.Dress` (silver rim, a title tab where the plate
sits, a silver-ringed portrait and the game's `UIPanelCloseButton`, with the
same trim fields); and the widgets call `BlizzardLook.Button`, `.Checkbox`
and `.Thumb` to wear the game's own texture files. Butler has no hanging
tabs or dropdown yet, so its Settings row is a stepper like Text size. It
never touches a Blizzard frame. Each file is checked once
(`BlizzardLook.HasArt`); a client without one keeps that widget in the
house look, and `/bbutler probe` lists what is missing. New widgets should
look right in both styles.

## Reading the probe

The owner asked (2026-10-10) for check results without screenshots, in every
addon; Butler has it from the start. `ns.KeepCheck(name, fn)` in
`Core/Init.lua` runs a check that prints to chat, keeps every line it prints
(colours and links taken out, a secret value kept as "(secret)") and saves
them in the account save as `lastProbe = { check, at, version, lines }`,
replacing the last one; chat adds "Saved for Claude, /reload to write it."
It wraps `/bts probe` (Tradeskills, saved under `BlackthornesTSDB.global`),
`/beq probe` and `/beq arrow check` (Equipment), `/bpet probe` and `/bpet
arrow check` (Pets), `/farm arrow check` and `/farm gathering check`
(Farmer, which has no probe), and `/bbutler probe` (Butler). Each has a
Settings button. Never rename `lastProbe`; a new check that players run for
a report goes through `ns.KeepCheck` too, and a fix to it belongs in all
five.

When the owner says "read the probe": he has run the check and typed
`/reload` (or logged out). In the thread, connect to his device, ask for
his game's WTF folder (already approved; the path is in the project's
memory) and stage the addon's account save from
`WTF\Account\<account>\SavedVariables\` (`Blackthornes_TS.lua`,
`Blackthornes_Farmer.lua`, `Blackthornes_Equipment.lua`,
`Blackthornes_Pets.lua` or `Blackthornes_Butler.lua`), read only. Read its
`lastProbe`: `check` says which one ran and `at` when; one older than his
message means the save was not written yet, so ask him to `/reload`. Use
only the probe lines; never commit the save or copy anything else out of
it.

## Discord

The addons share a Discord server, Blackthornes AddOns (public invite
https://discord.gg/f2geDecrw2, set up 2026-10-05). After a release uploads,
`release.yml` runs `tools/announce_discord.py`, which posts the version's
CHANGELOG section to the server's #announcements through a channel webhook
kept in the `DISCORD_WEBHOOK_URL` repository secret. The owner sets that secret
himself; never ask him to paste the webhook address anywhere. Without it the
step does nothing, and a failed post never undoes the upload. The tool is the
same in all the repos; a fix to it belongs in all of them.

The owner asked (2026-10-09) for one post in #general per release too,
and (2026-10-10) for it to be short: a few bullets in plain words, a
sixth-grade reading level, warm, in his voice (short, contractions, no
jargon, no file or setting names, never his name), saying what players will
notice. Each release PR writes the new version's section in `NEWS.md`
(`## X.Y.Z`, like CHANGELOG.md; it never ships) next to the CHANGELOG
section: the bullets, then one line of thanks. After the upload
`tools/post_general.py` scans it with `check_package.py`'s PRIVATE list and
posts it through the `DISCORD_GENERAL_WEBHOOK_URL` secret, which the owner
sets himself, under a line with the addon's name and version (so each
addon's bullets are their own group) and "(full list of changes in
#announcements)". It carries no CurseForge link and no card (link previews
are turned off). No section or no secret means no post.
A player's name never goes in a report (the owner, 2026-10-09): no
CHANGELOG, #announcements post, commit or PR text names a player, and
`check_release.py` refuses a CHANGELOG section that credits one
(`names_a_player` in `post_general.py`). The #general post is the one
exception: its last line thanks, by their Discord name, everyone who asked
for or reported the changes, each name once ("Thanks Ana and Bob for the
ideas and reports!"); leave it out when nobody asked. Find who asked from
the project's threads.
The thanks line no longer goes out with the webhook post (the owner,
2026-10-13: thank each player with a real @mention, so they get a
notification): `post_general.py` leaves out the paragraph that starts
"Thanks" (`without_thanks`), and the owner's bot, on his PC, posts it under
the release post with the mentions once he approves the wording, looking
the Discord names up there. Discord IDs never go in a repo. NEWS.md keeps
the thanks line, by Discord name, as before; ask the owner for any name
that isn't known.
This tool is also the same in all the repos.
Changes to the Discord bots, the digest or the release posting tools
(like this one) never go in a CHANGELOG, #announcements or #general
section (the owner, 2026-10-10): they are not changes to the addon.

## What's New

The owner asked (2026-10-12) for the Discord #general post to show in game,
the first time it loads after an update, in one window for every addon.
`UI/WhatsNew.lua` is the same file in all five (a fix to it belongs in all
five), and so are `tools/test_whatsnew.lua`, `tools/make_whatsnew.py` and
`tools/test_make_whatsnew.py`. There is no shared core addon: every copy
signs up in `_G.BlackthornesWhatsNew` as it loads, the first to reach
PLAYER_LOGIN starts the only timer (`WhatsNew.DELAY`, 5 s, never in a
fight), and that one check gathers what is new in all of them. The copy
with the highest `FILE_VERSION` draws the window (first in
`WhatsNew.ADDONS` on a tie); raise it when a change needs the newer copy.

The words are NEWS.md's: it never ships, so `tools/make_whatsnew.py` writes
its newest three sections, bullets only (the thanks line names players and
never ships), into `Core/WhatsNewText.lua` (`ns.WHATS_NEW`; never edit it by
hand). The window shows new features only (the owner,
2026-10-13): a section's
fixes and other changes go under a "Fixes and changes:" line, which go to
Discord but not the window, and every line is plain words with no hype,
no questions to the reader, no exclamation marks and no dashes as
punctuation (the tool notes one that trips `STYLE`). **Every release PR that writes a NEWS.md section runs
`python tools/make_whatsnew.py` too**; `check_release.py` refuses a tag
while the file is behind, and `tools/test_make_whatsnew.py` fails on every
push. The bullets stay in English, also on a German client.

Shown once a version: each addon keeps the newest version shown in its own
account save (`whatsNewSeen`); after an update the sections newer than that
(at most three) show, and an addon that never kept one shows its newest.
"After an update" (`whatsNewPopup`) and "What's New motion"
(`whatsNewMotion`) are on unless unticked, off in all when off in any;
`whatsNewScale` is the size grip's, where the addon has one. Never rename
them. The `whatsnew` command and a Settings button open it any time, with
each addon's newest. It rises in, its divider draws out, each addon's card
slides up with its icon popping and a light crossing it, and the Got it
button glows (one looping animation the game plays, only while it shows);
Motion off lands it all at once. Not yet seen in game.

## The About page and the note

The owner asked (2026-10-13) for a note on how the addons are made, once at
the top of What's New and kept on an About page in every addon's Settings.
`UI/About.lua` is the same file in all five (a fix to it belongs in all
five): `About.NOTE` is the owner's wording, a paragraph a key; change it
only when he asks, in all five, with each `Locale/deDE.lua`. `About:Note`
and `About:Info` build the page's two columns (the version, the Discord in
a box to copy, how to report a bug, a thank-you that names no player, a
What's New button and the other Blackthornes addons from
`SisterNote.ADDONS`); each addon's Settings places them on its "about"
page. `UI/WhatsNew.lua` (FILE_VERSION 3) puts the note at the top of the
next window that comes up by itself, alone when nothing is new, then sets
`aboutNoteSeen` in every sister's account save (never rename it); with the
window turned off it waits. Tested in `tools/test_whatsnew.lua`.

One-time cards (the owner, 2026-10-13): an addon can put cards in
`ns.WHATS_NEW_TIPS`, each `{ key, title, icon, paragraphs, hint, button,
run, due }`. The next window that comes up by itself shows each one after
the note, only when `due()` says so (in a pcall), with a button that calls
`run()` and closes the window. Looked at once either way: the key goes in
that addon's account save as `whatsNewTipsSeen[key]` (never rename it), so
a card never comes back; with the window turned off it waits.
`UI/WhatsNew.lua` is at FILE_VERSION 4 for it. Equipment's
`Logic/UpgradeQuest.lua` has the first, for the upgrade quest, due while
it is off.

## The sister note

The owner asked (2026-10-11) for the addons to say, once, which of the
others a player does not have. `Core/SisterNote.lua` is the same file in
all five (a fix to it belongs in all five), and so is
`tools/test_sisternote.lua`. Every copy signs up in `_G.BlackthornesSisterNote`
as it loads; the first to reach PLAYER_LOGIN starts the only timer
(`SisterNote.DELAY`, 8 s, no ticker), and that one check prints one line for
all of them: the sisters not installed (`C_AddOns.DoesAddOnExist`, else
`GetAddOnInfo`'s "MISSING"), each with what it adds. One installed but
turned off is never named. Once per account: what it named is kept in every
loaded addon's account save as `sisterNoteTold[folder] = true`, so only a
sister never named before (one released later) brings it back. "Sister
addons" in Settings (`sisterNote`, on unless unticked) and the `sisters`
command on each addon: off in any is off in all, and changing it writes all.
Never rename `sisterNote` or `sisterNoteTold`. A new addon goes in
`SisterNote.ADDONS` in all the copies. It names only our own addons.

## One key per character

The owner asked (2026-10-11) that a character can never be mistaken for
another again. Old records had sent errands to the character playing:
Butler filled a mail to itself and told a player to mail Medium Leather to,
and log out for, the character they were on (an old "Name-Realm" record of
Tradeskills' beside the GUID one), and a reload wiped alts' saved gear in
Equipment. The rule, in every addon:

- **A character is its GUID** (`UnitGUID("player")`) in saved data and in
  every call between the addons. Never a first name, "Name-Realm" or a
  short name: Forever lets characters share a first name. Names are for
  showing and for a mail's To line only, always first and last.
- **A GUID the client won't read (a dungeon) means "not sure who's
  playing":** write nothing under another key, and offer nothing for an
  alt. Tradeskills remembers each character's GUID in its own file
  (`BlackthornesTSCharDB.guid`) for that case.
- **Old records stay readable and count as the same character; nothing is
  deleted.** Tradeskills folds an old "Name-Realm" record into the GUID one
  at login, once (`Config:AdoptLegacyCharacter`): it is kept whole in
  `formerCharacters[old key]` with `retiredInto` (never rename either), what
  the GUID record lacks is filled from it when it carries that GUID, and
  the queue's references to the old key follow. Farmer reads a goal tagged
  "Name-Realm" as the character's and tags it with the GUID once the
  character gathers toward it or changes it.
- **One test per addon answers "the same character?" and "the one
  playing?"; never compare keys or names by hand.** Tradeskills:
  `Characters:Same`, `:IsPlaying` and `:Canonical` (`Core/Characters.lua`),
  and `playing` on each `Butler:Holdings()` entry. Butler:
  `Errands:IsMe(name)` (full name, first name alone, any old record's name,
  any case, with or without a realm). Farmer: `Goals:IsOwner`. Equipment:
  `Alts.PlayerGUID()`.
- **Every errand that targets a character asks that test right before it
  acts and refuses the character playing:** a mail, a gold top-up, a Log
  out, an alt's upgrade, a learned habit, the disenchanter.
- Tested in Tradeskills' `tools/test_onecharacter.lua`, Butler's
  `tools/test_notme.lua`, Farmer's `tools/test_goals.lua` and Equipment's
  `tools/test_alts.lua`. This rule is in every addon's notes; keep them the
  same.

## The owner's standing rules (all the addons)

- **Every list is dark glass** (the owner, 2026-10-12: "keep this as the
  standard across all Blackthornes addons", after Farmer's Kills & Loot
  panel was given the look of Tradeskills' queue). Rows or lines take
  `glass` and `glassAlt` in turn, by place, with a 1 px `border` line
  (alpha 0.6) under each; under the mouse `glassHover` and a gold edge,
  only on that row; the row picked or open is `glassActive` with a bright
  gold edge down its left. Never the older `row`/`rowAlt` bands for a
  list, a panel's lines or cards. A gradient fades through
  `Theme.LightGradient` or is hidden, never with SetAlpha alone (it stayed
  lit on Forever). This rule is in every addon's notes; keep them the same.
- **"Always check that it's clear to post."** Anything that goes public (a
  release, a CurseForge page, a post) is checked for private or unexpected
  content first, and nothing is published or uploaded without the owner's
  go-ahead. He tags releases himself.
- **Keep his data safe.** Never commit saved variables, tokens or anything
  from his machine; the upload keys are repository secrets he sets himself,
  so never ask him to paste one anywhere.
- **Changelogs come from git history.** Work out what changed since the last
  tag from the merged PRs and commits (`git log vX.Y.Z..origin/main --merges`);
  never ask the owner what went in. Claude drafts the CHANGELOG section in a PR;
  The owner merges, pulls `main`, tags and pushes.
- **A checkout shows the real version number** (the owner,
  2026-10-12). `ns.RELEASED_VERSION` in `Core/Init.lua` is the newest
  `## X.Y.Z` in CHANGELOG.md, shown when the packager has not filled in the
  TOC's `@project-version@` (he plays from a clone). The release PR that
  writes the CHANGELOG section changes it too; `tools/check_release.py`
  refuses a tag it does not match, and `tools/test_check_release.py` fails
  while the two disagree. This rule is in every addon's notes.
- **Every reply that ships code ends with the GitHub Desktop steps,** naming
  the branch: merge the PR on github.com (Ready for review, then Merge pull
  request); in GitHub Desktop switch **Current branch** to **main** and click
  **Pull origin**; then say whether the game needs `/reload` or a full restart
  (a full restart when a file is added, removed or renamed, or the TOC
  changes). For a release, add: History, right-click the newest commit,
  Create Tag, `vX.Y.Z`, Push origin. Remind him to pull `main` first, or the
  tag lands on an old commit and nothing runs.
- **CurseForge descriptions are features only.** Leave out privacy notes and
  any explanation of public emotes or their switches. Those belong in the
  README and CHANGELOG.
- **Keep his data safe, in the repo too.** `tools/check_private_files.py`
  (run by `.github/workflows/tests.yml`, tested by
  `tools/test_check_private_files.py`) fails any push or pull request that
  adds saved variables, a WTF folder, `keys.txt` or a `.env` file. It is
  the same in every repo (the owner asked 2026-10-10); a fix to it belongs
  in all of them.
- **Never shorten a character's last name** (the owner, 2026-10-11:
  "they must be included in WoW Forever"). Forever names are first and
  last together, so every place a character is named (menus, buttons,
  chat lines, lists, the mail's To line) shows the whole name, made to fit
  by growing or wrapping, never "Bob B." or the first name alone.
  Tradeskills' `Recipes:GetShortCharacterName` returns the full name now.
- **Forever is not retail for classes either.** The owner: "keep in mind this is
  WoW: Forever." Hunters have classic-style talent trees, held on Forever in
  one trait tree per class (see Equipment's findings). Never assume a retail
  or classic pet API exists (happiness, loyalty, the stable, demon summons):
  check with `/bpet probe` and record what it finds in
  `docs/FOREVER_API_FINDINGS.md`.
- **Smooth play comes first, but never at the cost of looks** (the owner,
  2026-10-09, after a hitch while crafting). Nothing on a timer or
  OnUpdate rebuilds or re-places a whole list, map or set of markers when
  only one thing moved: keep what is drawn, and redo only rows or pins
  whose inputs changed (a per-row key, a version number). Bag, loot,
  cast, skill and profession-list events arrive in bursts, several per
  craft or loot: coalesce them, read only what they changed, and skip
  work for windows that are hidden. Work over hundreds of items (recipes,
  sources, saved spots) is spread over frames (a worker with a small
  per-frame budget) rather than done in one frame, and shown when done.
  Clicks and typing still answer at once. The two causes found: Farmer's
  minimap markers gathered, sorted and re-placed every saved spot once a
  second because the clock second was in their redraw key (now only the
  fade moves, `MapMarkers:FadeMinimap`); and on every craft Tradeskills
  re-read every recipe in the profession window and repriced the whole
  craft pane in one frame (now `Recipes:NothingNewMidCraft` skips the
  re-read mid-run and `CraftPanel:RefreshInSlices` spreads the pane over
  frames). Visuals and usability are never traded away for speed. This
  rule is in all four addons' notes; keep them the same.
- **The client is WoW: Forever, a retail engine** (`## Interface: 16001`,
  modern Lua), not 1.12. Instances hand addons secret values that raise when
  compared, concatenated or formatted, so read client values inside a pcall.
  Registering an event the client does not know raises too, which is why
  `ns.RegisterEvent` wraps it.
