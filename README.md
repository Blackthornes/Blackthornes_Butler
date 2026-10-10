# Blackthornes Butler

A WoW: Forever addon that tells you what to do with every item in your bags:
keep it, sell it, post it on the auction house, disenchant it, or mail it to
the alt who needs it.

Built for the WoW: Forever client (`## Interface: 16001`), without Ace3 or
LibStub, matching
[Blackthornes Farmer](https://github.com/Blackthornes/Blackthornes_Farmer),
[Blackthornes Tradeskills](https://github.com/Blackthornes/Blackthornes_Tradeskills),
[Blackthornes Equipment](https://github.com/Blackthornes/Blackthornes_Equipment)
and [Blackthornes Pets](https://github.com/Blackthornes/Blackthornes_Pets).
They share a palette and a framework on purpose, and Butler will ask each of
them about your items when they are installed. Without them it still works,
from vendor prices and the game's own quest marks.

So far this is the addon's frame: the Butler window (empty for now),
settings, a minimap button and `/bbutler probe`. The item list and selling
come next.

## Install

### Linked to your working copy (recommended while developing)

Run this once, and from then on testing a branch is pulling it and typing
`/reload`:

```powershell
.\tools\link.ps1
```

It junctions `Interface\AddOns\Blackthornes_Butler` to this folder, so the
client reads your checkout directly. Nothing is copied, so there is no deploy
step to forget.

Two things `/reload` will **not** pick up, because the client only reads them at
startup:

- a file that was **added, removed or renamed**
- any change to **`Blackthornes_Butler.toc`**

After pulling a branch that did either, restart the client once.

### Copied into the client

```powershell
.\deploy.ps1              # syntax check, lint, then mirror into Interface\AddOns
.\deploy.ps1 -SkipCheck   # skip the checks (not recommended)
```

Both scripts default to `D:\Blizzard\World of Warcraft\_classic_beta_`. Pass
`-GamePath` if the client lives somewhere else.

The addon folder name has to stay `Blackthornes_Butler`, matching the `.toc`
inside it. If they differ, the client ignores the folder and says nothing.

## Use

```
/bbutler           open the Butler window (so does clicking the minimap button)
/bbutler help      list every command
/bbutler probe     check what this client supports for bags, vendors and mail; it only reads
/bbutler settings  open the settings window (so does right-clicking the minimap button)
/bbutler minimap   show or hide the minimap button
```

The settings window is also under the game's Options > AddOns. Hover a
setting to see what it does, or tick **Show descriptions** to see it under
every row; **Find a setting** searches every page. **Text size** makes all
of the addon's text a point or two bigger after a `/reload`, and **Window
style** picks the house look or the game's own. Every command above has a
button there too.

`/butler` works too.

## Layout

| Folder | What is in it |
|---|---|
| `Core/` | Namespace, module registry, event dispatch, slash commands, saved variables |
| `UI/` | Theme, widgets, the house window frame, the minimap button, the Butler window and the settings window |
| `Media/` | The window frame's art (`Frame/*.tga`), drawn by `tools/make_frame_art.py` |
| `Probe/` | `/bbutler probe`, which checks what the running game actually supports instead of guessing |
| `tools/` | Checks, tests, the frame art script and the link script. Not shipped to the client |
| `docs/` | What the Forever client actually does, found with `/bbutler probe`. Not shipped |

`Data/` and `Logic/` arrive with the first features.

`Blackthornes_Butler.toc` lists every Lua file in load order. A file that is
not in it does not load, and WoW says nothing about it.

## Development

```bash
python tools/syntaxcheck.py   # parse every Lua file with a real 5.1 parser
python tools/lintcalls.py     # find calls to methods, and constants, never defined
python tools/runtests.py      # run the logic tests outside WoW
```

`tools/` requires `lupa` (`python -m pip install --user lupa`).

The checks exist because WoW silently disables an addon whose first TOC file
fails to compile, and because a call to a method that no longer exists is valid
Lua that fails only when that line runs. `deploy.ps1` runs the first two before
it copies anything, and `.github/workflows/tests.yml` runs all of them on every
push, along with `tools/check_private_files.py`, which fails any push that adds
saved variables, a WTF folder, `keys.txt` or a `.env` file.

The tests load the addon against a stub client (`tools/testenv.lua`), reading
the file list straight from the TOC. A new test is a new `tools/test_*.lua`
file and nothing else.

## Releasing

Releases are cut by pushing a tag like `v0.1.0`.
`.github/workflows/release.yml` then:

1. refuses the tag unless `CHANGELOG.md` opens with a `## 0.1.0` section
   (`tools/check_release.py`);
2. runs the tests;
3. builds the player-facing zip with the
   [BigWigs packager](https://github.com/BigWigsMods/packager), uploading
   nothing;
4. checks that zip is clear to post (`tools/check_package.py`): only the
   addon's own files, and nothing that looks private, such as a Windows path,
   an email address, a saved-variables dump or a token;
5. only then uploads that same zip to each site with a token, and attaches it
   to a GitHub release.

To release from GitHub Desktop: add the new version's section to the top of
`CHANGELOG.md` and merge it to `main`, pull `main`, then **History**, right-click
the newest commit, **Create Tag...**, name it `v0.1.0`, and **Push origin**.

The version is never typed by hand. The TOC says
`## Version: @project-version@` and the packager fills in the tag. Running
straight from a clone there is no packager, and the addon calls itself a
"dev build". The middle number moves for new behaviour, the last for fixes
alone; a tag like `v0.2.0-beta1` is uploaded as a beta.

`.pkgmeta` leaves `tools/`, `docs/`, `deploy.ps1`, `CLAUDE.md`, `NEWS.md` and this
README out of the zip. There is no CurseForge project yet; once there is, its
ID goes on the `X-Curse-Project-ID` line of the TOC.
Uploading also needs a `CF_API_KEY` repository secret in the repository's
settings on github.com. Without both, the workflow
still builds and checks the zip but uploads nothing to CurseForge.
