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

The window shows new features only. Write a section's features first, then
a "Fixes and changes:" line with the fixes and other changes under it: those
go to Discord but stay out of the window, and a section of only fixes puts
nothing in it. Say what each feature does in a few plain words, the way you'd
tell a friend: no hype, no questions to the reader, no exclamation marks
outside the thanks line, no dashes as punctuation, no "now you can". The
tool prints a note for a shipped line that reads like an advert.

## 0.18.0

- Jobs has a Profession Leveling group with the next skill point for each profession. You turn it on with Cheapest Skill-Up on the Gold page of Settings.
- Each profession gets its own goal under Gold Goals, and a click shows the way to the trainer.
- Bank Alt can take the items that would go to the auction house. You pick it on the Bank Alt page.
- An item's tooltip can say what a vendor charges for it. You pick it on the General page.

Fixes and changes:

- Spells you skip leave the class training plan.
- Disenchant Greens Here leaves greens that sell for more.

## 0.17.0

- Butler Bags has an Empty Slots box next to Sort, and the free space count is bigger.

## 0.16.0

- Butler Bags is a new replacement bag feature, off by default. Turn it on under Bags on the General page of Settings. Group by what to do, by item type or as one grid, search, and sort. Special bags sit on their own rows with One Grid.
- Craft When It Pays More puts a craft that earns more than selling under Craft, with a Queue button. It's on the Selling page.
- Cheapest Skill-Up shows your next skill point in Jobs, with a Queue button. It's on the Gold page.
- Your Tradeskills lists can mail to a character and keep a number on each one. It's on the Lists page.

Fixes and changes:

- Several bug fixes for class training and Jobs order.

## 0.15.0

- Who Has It and Butler on Tooltips can each be Off, Shift or Always. You pick on the General page of Settings.
- Right-click a character's jobs to ignore them until that character next logs in.

Fixes and changes:

- Class training lists only characters on your realm and side.

## 0.14.0

- Butler speaks Simplified Chinese, French, Spanish and Russian now if your game is in one of those.

Fixes and changes:

- Items you always mail to another character follow the usual rules once they're on that character.

## 0.13.0

- You can keep a number of an item on each character. Right-click an item, or use Keep on Each Character on the Errands page of Settings.
- Buy Quest Items on the Selling page adds a Buy row at the auction house for what your open quests need. It's off until you tick it.
- A Buy row shows at any vendor that has something your craft queue needs.

Fixes and changes:

- Only as many copies of an upgrade as a character can wear are kept. The spares go to the auction house.
- Item names use their rarity color in jobs, lists and tooltips.

## 0.12.1

Fixes and changes:

- Various fixes to Butler.

## 0.12.0

- Settings has a new page where you drag Butler's rules into the order you want, or turn them off.

Fixes and changes:

- An item on your Always mail list stays with you when it's an upgrade you can wear now.

## 0.11.0

- Type the name of a character on your other account as your bank alt.
- Greens go to your disenchanter only when breaking them pays at least what selling would. A new option sends them anyway.
- When your bags are full, the trash can points at two short stacks you can join first, so nothing gets thrown away.

Fixes and changes:

- Various fixes to Butler.

Thanks Ezmode for the ideas!

## 0.10.0

- The Craft button opens the profession window first when it's closed.

Fixes and changes:

- Crafts that free the most bag space come first.
- Gear with a random suffix is priced by its own suffix.

## 0.9.0

- Shift-click an item at a vendor and type how many you want. Butler buys them all for you.
- A new option has Butler send every green to Disenchant on your disenchanter.

Fixes and changes:

- Materials for another character's crafts go to Mail before they get sold.
- Several bug fixes for the Disenchant button, Butler's buttons and gold top-ups.

## 0.8.0

- Pick a character as your bank alt, and Butler mails it whole kinds of items, like all your cloth or herbs.

## 0.7.0

- Butler keeps the items your open quests need and can search the auction house for the ones you still lack.
- At a vendor, Butler shows what it has for your crafts and can buy it.

Fixes and changes:

- Always mail keeps what your queued crafts need and mails only the rest.
- Always sell holds back what a goal or your craft queue still needs.
- A mail of materials says what they are for.
- Several bug fixes for Train all, gold goals and the trash can.

## 0.6.0

- This is the largest AddOn update so far across the whole suite of Blackthornes addons.
- Butler tells you which class spells you can train, and has a Train all button at the trainer.
- Gold goals at the bottom show how close you are to your spells, trainers and riding.
- A little trash can shows on the cheapest item when your bags are full.
- The last line on an item's tooltip says what Butler would do with it.
- Your Jobs list puts mail, buying and parts first, so crafts come in the right order.

Fixes and changes:

- Greens that help level Enchanting go under Disenchant.
- Bank upgrades come out when you open the bank.
- Items wait for a better price when the auction house pays low.
- Mail that didn't fit goes in the next mail to the same alt.
- Always sell leaves out an upgrade you can wear.
- The backpack shows free slots even when the game shows another number.

## 0.5.0

- Your bags has a search box.
- Gear in your equipment sets is always kept.

Fixes and changes:

- Mailing upgrades to your other characters is off until you turn it on.
- Fill mail sends everything a job needs, herbs too.
- The scroll bar moves the right way.

Thanks Voldar and Ezmode for the ideas and reports!

## 0.4.0

Fixes and changes:

- Fill mail, Sell and the bank buttons sit on the line they work on.
- Gold top-ups and mailed upgrades only count once the mail goes.
- Fixes for selling, soulbound gear and the All characters list.

## 0.3.0

- Ready transmutes and other cooldowns show in your Jobs list.
- Butler knows what vendors pay for most items from the start, so fewer items say "price still loading".

## 0.2.0

- Butler is in Deutsch on a German client.
- After you send a mail, Fill mail fills the next one.
- Butler mails your alts the materials their queued crafts need.
- Set how much gold each character keeps, and Butler offers a top-up at the mailbox.
- A Jobs list shows what to craft or mail on each character, and who to log in next.
- Item tooltips show which of your characters have it.
- Hunters get a Fill button for ammo at the vendor.
- Butler learns from what you sell and mail by hand, shows your free bag space on the backpack, and says "You rang?" when you open it.

## 0.1.0

- Meet Butler! It looks at every item in your bags and tells you what to do with it: sell it, post it, disenchant it, mail it to an alt, bank it or keep it.
- Open it at any vendor and press Sell to clear out the junk. Nothing gets sold unless you click.
- Pick an amount, and anything worth less goes on the sell list.
- See every item on all your characters in one list.
- At the mailbox, it fills in a letter with what your alts need.

Thanks Ezmode and Voldar for the ideas!
