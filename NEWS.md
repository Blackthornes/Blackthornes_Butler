# News

What each release says in the Discord server's #general channel: a few
short bullets per version, in plain words for players, saying what they'll
notice, then one line thanking, by their Discord name, everyone whose
feedback or report led to the changes (each name once; no line when nobody
asked). Each release PR writes the new version's section here next to its
CHANGELOG.md section, and after the upload `tools/post_general.py` posts it
under a line with the addon's name and version that points players to
#announcements for the full list. No link or addon card goes with it. This
is the only report that names players. A version with no section here posts
nothing in #general.
This file does not ship in the addon, but its newest sections do, without
the thanks line: `python tools/make_whatsnew.py` writes them into
Core/WhatsNewText.lua for the in-game What's New window. Run it after
writing a section; the release check refuses a tag while it is behind.

## 0.3.0

- A new What's New window shows what changed after each update.
- Ready transmutes and other cooldowns show up in your Jobs list.
- Butler knows vendor prices right away, so fewer items say "price still loading".

## 0.2.0

- Butler speaks Deutsch now if your game is in German.
- Fill mail keeps going: send one and the next one's ready right away.
- Butler sends your alts the materials they need, and gear that's an upgrade for them. Don't want one sent? Just right-click it.
- Set how much gold each character should keep, and Butler tops them up by mail.
- A Jobs list shows what to craft or mail on each character, and who to log in next.
- Hover any item to see which of your characters have it.
- Hunters get a Fill button for ammo at the vendor.
- Butler learns from what you do, shows your free bag space, and says "You rang?" when you open it.

## 0.1.0

- Meet Butler! It looks at every item in your bags and tells you what to do with it: sell it, post it, disenchant it, mail it to an alt, bank it or keep it.
- Open it at any vendor and press Sell to clear out the junk. Nothing gets sold unless you click.
- Pick an amount, and anything worth less goes on the sell list.
- See every item on all your characters in one list.
- At the mailbox, it fills in a letter with what your alts need.

Thanks Ezmode and Voldar for the ideas!
