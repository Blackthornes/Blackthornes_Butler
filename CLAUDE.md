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

Phase 1 is built and seen in game (2026-10-10): Butler on its own.
`Logic/Bags.lua` reads the bags only while the window is up or a vendor is
open, 0.2 s after a burst of bag events, 40 slots a frame, and looks further
only at slots whose key (link, count, locked) changed (`Bags.version`).
`Logic/Verdicts.lua` judges each item in order (Always keep, quest item or
quest starter, no vendor value, Always sell, price still loading, grey,
else Look at it) and groups them Sell, Look at it, Keep (`Verdicts:Groups`,
kept until `Bags.version` or `Verdicts.version` moves). `Logic/Selling.lua`
is the Sell button (see the findings file for why it is secure).
`UI/MainWindow.lua` draws the groups with `Widgets.CreateRowList` (Farmer's,
with the dark glass rows) and Butler's own right-click menu. Rows are two lines tall so a long reason or name wraps rather than
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
  --   and bind on pickup), fast (true, false, or nil for middling),
  --   disenchant, canDisenchant, enchanter, need, mailTo, mailCount }
_G.BlackthornesEquipment.Butler:Advise(link, bag, slot)
  -- { upgrade = "now" | "later" | nil, gain, sell (its bag coin), tool }
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
redraw. The verdicts they feed, in order, are at the top of
`Logic/Verdicts.lua`. Soulbound green or better gear is never put under
Sell: Disenchant, or Look at it. `/bbutler probe` says which sisters are
loaded and which answer Butler.

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
burst. Search filters the built list. The Sell button stays off in this
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
  (`Verdicts:Decide`'s fifth return). The player presses Send; Butler never
  sends, hooks or moves the mail frame. There are no mailbox Take buttons
  (the owner had them removed from Tradeskills; never add them unasked).
  Nothing is ever mailed to the character playing (a player found Fill
  mail addressed to themselves, 2026-10-11): `Verdicts:Playing` is its
  short name from `Holdings()` (`Errands:PlayingName`), and an Always mail
  entry, a `mailTo` or an `enchanter` naming it is kept instead.
  Tradeskills' `FillMail` refuses it too, and its third return, the full
  name filled in, is what the chat line says.
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
  each count is covered.

Both bank moves use `C_Container.UseContainerItem` (the selling test found
it works from addon code), one stack every `Errands.STEP`, each slot read
again first; a stack that does not move means the other side is full, and
the run stops and says so. Nothing in combat. The bank is read only for a
click. Not yet seen in game.

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

## How this repo was set up

It copies Pets (itself Equipment's, itself Farmer's) on purpose, so check the
sisters before inventing a convention:

- **Layout** `Core/ Logic/ UI/ Probe/ tools/ docs/` so far (`Data/` comes
  when a feature needs it), one module per file through
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
#announcements)", so the thanks comes last. It carries no CurseForge link and no card (link previews
are turned off). No section or no secret means no post.
A player's name never goes in a report (the owner, 2026-10-09): no
CHANGELOG, #announcements post, commit or PR text names a player, and
`check_release.py` refuses a CHANGELOG section that credits one
(`names_a_player` in `post_general.py`). The #general post is the one
exception: its last line thanks, by their Discord name, everyone who asked
for or reported the changes, each name once ("Thanks Ana and Bob for the
ideas and reports!"); leave it out when nobody asked. Find who asked from
the project's threads. This tool is also the same in all the repos.
Changes to the Discord bots, the digest or the release posting tools
(like this one) never go in a CHANGELOG, #announcements or #general
section (the owner, 2026-10-10): they are not changes to the addon.

## The owner's standing rules (all the addons)

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
