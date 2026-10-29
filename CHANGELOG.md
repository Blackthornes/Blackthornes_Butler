# Changelog

Versions follow [semantic versioning](https://semver.org): the middle number
moves for new behaviour, the last for fixes alone. The newest version goes at
the top; a release is refused if its version has no section here.

## 1.1.0

For WoW: Forever (interface 16001). Files were added, so restart the game fully after updating (`/reload` is not enough).

- **Minimap button:** One minimap button now covers every Blackthornes addon you have. Click it to pick one. Turn it off with Combine Addon Buttons on the General page.
- **Swap When Full:** Swap When Full offers to swap your cheapest item for better loot when your bags are full. It is off until you tick Swap When Full on the General page.
- **Bug fixes:** several bug fixes for rows that cut off long notes.

## 1.0.1

For WoW: Forever (interface 16001). Files were added and the TOC changed, so
restart the game fully after updating (`/reload` is not enough).

- **Tabs:** the window has tabs for Your Bags, All Characters and Settings. Settings is the last tab, at the bottom right.
- **UI:** various UI improvements.

## 1.0.0

For WoW: Forever (interface 16001). Files were added and the TOC changed, so
restart the game fully after updating (`/reload` is not enough).

- **Characters:** Butler counts only characters on your realm and side.
- **Bags window:** the foot shows this character's gold beside everyone's.
- **Arrow Size:** pick 50%, 75% or 100% for the guide arrow.
- **Fold gem:** a small gem beside the close button folds a window down to its title and opens it again.
- **Settings:** word choices are drop-downs.

## 0.18.0

For WoW: Forever (interface 16001). Files were added and the TOC changed, so
restart the game fully after updating (`/reload` is not enough).

- **Profession Leveling:** a group under Jobs shows the next skill point for each profession. Turn it on with Cheapest Skill-Up on the Gold page of Settings.
- **Gold Goals:** each profession gets its own goal. A goal names its recipes, and a click shows the way to the trainer.
- **Bank Alt:** Auction Items sends what would go to the auction house to your bank alt. It's on the Bank Alt page.
- **Vendor Price:** an item's tooltip says what a vendor charges for it. It's on the General page.
- **Class training:** spells you skip leave the plan.
- **Bug fixes:** Disenchant Greens Here leaves greens that sell for more, Sell checks batch selling by itself, and several bug fixes for the Gold page.

## 0.17.0

For WoW: Forever (interface 16001). No files were added, so `/reload` is enough after updating.

- **Butler Bags:** a new Empty Slots box sits next to Sort. Each way of grouping remembers its own choice. The free space count is bigger too, on the window and on the backpack button.

## 0.16.0

For WoW: Forever (interface 16001). Files were added and the TOC changed, so
restart the game fully after updating (`/reload` is not enough).

- **Butler Bags:** a new replacement bag feature, off by default. Turn it on under Bags on the General page of Settings. Group by what to do, by item type or as one grid, search, and sort. Special bags sit on their own rows with One Grid.
- **Craft When It Pays More:** puts a craft that earns more than selling under Craft, with a Queue button. It's on the Selling page.
- **Cheapest Skill-Up:** shows your next skill point in Jobs, with a Queue button. It's on the Gold page.
- **Your Tradeskills lists:** each list can mail to a character and keep a number on each one. It's on the Lists page.
- **Bug fixes:** several bug fixes for class training and Jobs order.

## 0.15.0

For WoW: Forever (interface 16001). Files were added and the TOC changed, so
restart the game fully after updating (`/reload` is not enough).

- **Tooltips:** Who Has It and Butler on Tooltips can each be Off, Shift or Always. The choices are on the General page.
- **Jobs:** right-click a character's jobs to ignore them until that character next logs in.
- **Bug fixes:** class training lists only characters on your realm and side.

## 0.14.0

For WoW: Forever (interface 16001). Files were added and the TOC changed, so
restart the game fully after updating (`/reload` is not enough).

- **Languages:** on a Simplified Chinese, French, Spanish or Russian client, Butler's own words are in that language.
- **Always mail:** an item you set to always mail follows the usual rules once it is on the character it is mailed to.

## 0.13.0

For WoW: Forever (interface 16001). Files were added and the TOC changed, so
restart the game fully after updating (`/reload` is not enough).

- **Keep on each character:** right-click an item to keep a number of it on the
  character you are playing, or Keep All. Settings, Errands page, lists them.
- **Quest items:** Buy Quest Items on the Selling page adds a Buy row at the
  auction house for what your open quests need. Off until you tick it.
- **Vendors:** a Buy row shows at any vendor that has something your craft
  queue needs.
- **Upgrades:** only as many copies as a character can wear are kept. The spares
  go to the auction house.
- **Rarity colors:** item names use their rarity color in jobs, lists and
  tooltips.

## 0.12.1

For WoW: Forever (interface 16001). `/reload` is enough after updating.


## 0.12.0

For WoW: Forever (interface 16001). A file was added and the TOC changed, so
restart the game fully after updating (`/reload` is not enough).

- **Order:** Settings has an ORDER page that lists every rule Butler asks, in
  order. Drag a rule to a new place or turn it off. Set Default and Undo Move
  put things back.
- **Always mail:** an item on an Always mail list stays with you when it is an
  upgrade you can wear now.

## 0.11.0

For WoW: Forever (interface 16001). `/reload` is enough after updating.

- **Bank alt:** type the name of a character on your other account.
- **Disenchanting:** a green goes to your disenchanter, or to levelling
  Enchanting, only when breaking it pays at least what selling would.
  "Always Disenchant:" (Selling page, off until ticked) sends it anyway.
- **Trash can:** two short stacks of one item that fit in one slot come
  first, and a click joins them. A trade good counts as 1.5 times its worth,
  so close calls go to junk.

## 0.10.0

For WoW: Forever (interface 16001). `/reload` is enough.

- **Craft:** the Craft button opens the profession window first when it is
  closed, and the next click crafts.
- **Bag space:** crafts that free the most bag space come first, when
  Tradeskills' option for it is on.
- **Random suffixes:** your copy of suffix gear is priced by its own suffix.

## 0.9.0

For WoW: Forever (interface 16001). Files were added and the TOC changed, so
restart the game fully after updating (`/reload` is not enough).

- **Buy more:** Shift-click an item at a vendor and a box comes up beside
  the vendor window. Type how many, up to 9999, and it shows the price and
  says when your bags, gold or the vendor's stock allow fewer. Nothing is
  spent until you click Buy. It buys a stack at a time, with a Stop button,
  and stops if your bags fill, your gold runs out, the vendor sells out or a
  fight starts. "Buy more" in Settings, on unless unticked, and
  `/bbutler buy 200 water`.
- **Disenchant greens here:** with this ticked, every green the character
  set as your disenchanter can break goes under Disenchant, whatever it
  would sell for. Off unless ticked. Selling page, DISENCHANTING, and
  `/bbutler greens`. Needs the Tradeskills update.
- **Alt crafts:** materials another character's queued crafts need now go
  under Mail first, even when they are on your Always sell list, kept by a
  habit Butler learned, or something no vendor buys.
- Several bug fixes for the Disenchant button, Butler's buttons in front of
  the window and gold top-ups.

## 0.8.0

For WoW: Forever (interface 16001). A file was added and the TOC changed, so
restart the game fully after updating (`/reload` is not enough).

- **Bank alt:** pick one of your characters and tick the kinds of items to
  send it: cloth, leather, ore and stone, herbs, meat, elemental, enchanting
  materials, other trade goods, and green or better gear that binds when
  worn. With Tradeskills, everything on one of your shopping lists can go
  too. You choose where it sits in Butler's order: before selling, before a
  vendor, or only for what is left. The items show under Mail, so Fill mail
  sends them. A BANK ALT page in Settings and `/bbutler bankalt`.

## 0.7.0

For WoW: Forever (interface 16001). Files were added, so restart the game
fully after updating (`/reload` is not enough).

- **Items for your quests:** every item an open quest collects is kept, even
  on the Always sell list. Jobs leads with a "For your quests" line naming
  what is still to find and trade. At the auction house, with Tradeskills
  loaded, it has a Search button that looks them all up. "Items for your
  quests" on the Selling page and `/bbutler quests [on|off]`.
- **Buy from a vendor:** at a vendor the step says what it has for your
  crafts and what that costs, with a Buy button.
- **Always mail:** it holds back what your own queued crafts need and mails
  only the rest.
- **Always sell:** it keeps what a Farmer goal or your craft queue still
  needs.
- **Mail lines:** a mail of materials says what they are for.
- **Bug fixes:** several fixes for Jobs, Train all, gold goals, gold top-ups,
  the trash can, the tooltip line, bag search and `/bbutler goals`.

## 0.6.0

For WoW: Forever (interface 16001). Files were added, so restart fully
after updating; `/reload` is not enough.

- **Class spells to train:** the Jobs list leads with "Train N new spells".
  At a class trainer, Train all learns what your gold pays for, one spell
  at a time; anywhere else, Show the way points to the trainer (through
  TomTom when it is installed). Spells for the next level, and the other
  characters' training, wait in a Later group near the bottom. The window
  comes up by itself at a class trainer when something can be trained, and
  the gold fund keeps back what your spells cost. Turn it off with "Class
  training" on the Gold page or `/bbutler training off`.
- **Gold goals:** at the bottom of the window, your gold is split across
  class spells, profession training and riding, with a bar for each: ready,
  saving, or levels away. All characters shows the same for every
  character. Turn it off with "Gold goals" on the Gold page or `/bbutler
  goals off`.
- **Trash can:** when your bags are full, a small gold can sits on the
  item worth the least among the things Butler would sell, auction or
  disenchant. A click picks the item up; drop it outside your bags, where
  the game asks first. Butler never deletes anything. Turn it off with
  "Trash can when full" on the General page or `/bbutler trash`.
- **Butler on item tooltips:** the last line of the tooltip of an item in
  your bags says what Butler would do with it, such as "Butler: Sell", with
  what one is worth on the right. Turn it off with "Butler on tooltips" on
  the General page or `/bbutler tooltip`.
- **Free bag space:** the number on the backpack now shows when the game's
  own number there is something else, such as a hunter's ammo count. The
  ammo bag shows its ammo count.
- **Jobs in a better order:** mail waiting for a character goes first on its
  line. After that come the materials to buy from a vendor, then those to
  buy at the auction house or gather, then parts that other crafts need,
  then the crafts. A craft in a druid's form or a shaman's Ghost Wolf
  shows a Leave form button first.
- **Level Enchanting with your own greens:** a green you didn't craft that
  breaks into a material your Enchanting still lacks goes under
  Disenchant, with the recipe that needs it, until you have enough.
- **Bank upgrades:** at the bank, Take from bank also brings out gear
  Equipment calls an upgrade for you.
- **Wait for a better price:** items to auction fold away into a Wait group
  while the auction house pays well under their usual price, or while
  Tradeskills would refuse to list them at a loss.
- **Mail overflow:** what didn't fit in one mail (12 stacks) is filled into
  the next mail to the same character, cheap materials first.
- **Always sell and upgrades:** an item on your Always sell list that is
  an upgrade you can wear now shows under Look at it instead, and goes back
  to Sell once it is no upgrade.
- **About page:** Settings has an About page with the version, the Discord
  invite, how to report a bug and the other Blackthornes addons. Addons can
  also show one-time cards in What's New.

## 0.5.0

For WoW: Forever (interface 16001). No files were added, so `/reload` is
enough after updating.

- **Search Your bags:** the same search box as All characters. Typing
  shows only the items whose name or item ID matches, under their group
  headings, even folded ones.
- **Equipment sets are kept:** anything in one of your equipment sets
  shows under Keep ("In your Tank equipment set") before any other rule,
  so nothing sells, mails or breaks it.
- **Mailing upgrades to your characters is off unless ticked:** tick "Mail
  upgrades to your characters" under Upgrades for your characters on the
  Selling page, or type `/bbutler altupgrades`, to have that gear go under
  Mail again.
- **Fill mail:** puts in every item a Jobs mail line names, and an alt's
  queued craft now beats a Farmer goal here, so herbs it needs get mailed.
  Items bought to disenchant are never offered as upgrades for an alt.
- **Scroll bar:** dragging it now moves the list the same way, and a click
  above or below the thumb jumps there.
- **Settings:** the Window style box on the General page fits its words,
  and its Reload button sits under it.

## 0.4.0

For WoW: Forever (interface 16001). No files were added, so `/reload` is
enough after updating.

- **Buttons on their lines:** at a mailbox each character gets a Fill mail
  button on the first line that mails them (a Jobs mail step, a gold
  top-up or a Mail row), with the row's worth on its tooltip so the note
  keeps its full width. Sell, Disenchant, Move to bank and Take from bank
  sit on their group's heading. A button whose line is scrolled away waits
  at the window's foot until it comes back.
- **Mail and gold:** gold top-ups and alts' upgrades are written down only
  when Butler's own mail goes, so taking gold from the inbox or sending a
  mail by hand no longer hides or fakes a send. Gold that rides with items
  leaves room for their postage, and a character whose items didn't all
  fit in one mail is offered again.
- **Selling:** every slot is judged again right before it sells, and a sell
  or ammo run stops when the vendor closes. Using the Disenchant button at
  a vendor is no longer learned as selling by hand.
- **Soulbound copies:** a soulbound copy and an unbound copy of the same
  gear are judged apart, so the bound one is never offered to an alt.
- **Bank:** the reagent bag is never taken for a bank bag, so Take from
  bank can't put its items away.
- **Looting:** the window always redraws after the bags change, even when
  it was reading them at the time.
- **All characters:** the character you're on is listed once, the list is
  built once, who has an item shows once on its tooltip, and the open item
  is marked in dark gold.
- **What's New:** closing the window while holding its scroll bar lets go
  of it.

## 0.3.0

For WoW: Forever (interface 16001). Files were added, so restart the game
fully after updating (`/reload` is not enough).

- **What's New window:** the first time the game loads after an update,
  one window shows what changed in every Blackthornes addon that was
  updated, with dark glass cards and a little motion. "Motion" in Settings
  turns the movement off, "Show after updates" turns the window off (off
  in one addon is off in all of them), and the `whatsnew` command or a
  Settings button opens it any time.
- **Ready cooldowns as jobs:** when Tradeskills says a transmute,
  Mooncloth or Salt Shaker is ready, the Jobs list shows it as a step, with
  a Craft button on the character you're playing, or as the next character
  to log in to.
- **Forever vendor prices and bags:** Butler knows what a vendor pays for
  about 11,500 items, and which bags are quivers, ammo pouches and
  profession bags, from the Forever client's own data, so fewer items wait
  on "price still loading". The live game still wins.

## 0.2.0

For WoW: Forever (interface 16001). Butler now does more of the running
around for you: mail, gold, jobs on your other characters and ammo.

- **Deutsch:** on a Deutsch (German) client Butler speaks German, in a
  friendly butler's voice. English stays the same.
- **Fill the next mail:** after each Send, Butler fills the mail for the
  next character straight away, and says when that's all the mail for now.
  You still check each one and press Send. "Fill the next mail" in Settings
  turns it off.
- **Mail what your alts need:** an alt's share of the materials its queued
  crafts use goes under Mail ("Mail 80 to Ana for their crafts, keep 20 for
  yours"), and Fill mail sends just that many, even from your Always keep
  list. It asks Tradeskills again before it fills, so a stack you just made
  goes in whole.
- **Upgrades for your other characters:** gear Equipment calls an upgrade
  for another character on your realm and side goes under Mail, one copy a
  slot (two for rings and trinkets), and Butler remembers what it sent.
  Right-click to hold one back ("Don't mail this to NAME", or every upgrade
  for that character); Settings > Selling lists and undoes them.
- **Your disenchanter:** gear Tradeskills sends to your disenchanter goes
  under Mail to them. Items bought to disenchant come first under
  Disenchant, and a new Disenchant button beside Sell breaks the next one a
  click (never in combat). Right-click marks or unmarks an item as bought
  to disenchant.
- **Gold fund:** a Gold page in Settings sets how much each character
  keeps. At a mailbox, Gold rows offer a top-up to anyone below their
  amount, from what this character can spare, postage counted.
- **Jobs on your other characters:** a Jobs list shows what this character
  has to craft or mail for the queue, with a Craft button when the
  materials are in your bags, and who's next. It says when something has to
  come out of the bank first, puts first the character who can get on with
  it, and a Log out button sits on that character's line.
- **Who has it:** item tooltips show how many your characters have and
  where ("21 (20 bags, 1 mail)"). "Who has it" in Settings turns it off.
- **Ammo for hunters:** at a vendor with ammo for your bow, crossbow or
  gun, an Ammo row offers the best you can use, enough to fill your quiver
  or pouch, with a Fill button. Nothing is bought without that click.
- **Learns from you:** buy back something Butler sold and it's kept from
  then on; sell or mail an item by hand twice and Butler offers to do it
  next time. Your right-click choices always win, and "Learn from what you
  do" in Settings turns it off.
- **Free bag space** on the backpack button, amber when you're getting
  full and red when you're nearly out.
- **Butler's voice:** opening the window yourself gets "You rang?" from
  Karazhan's butler, and closing it his goodbye. "Butler's voice" in
  Settings turns it off.
- **Sister addons:** one line after login, once, names any Blackthornes
  addons you don't have yet.
- **Fixes:** Butler never offers a mail, a gold top-up or a Log out for the
  character you're on, under any old name. Ammo is read right on clients in
  other languages. A copy played from a checkout shows its real version
  instead of "dev build".

## 0.1.0

The first release. For WoW: Forever (interface 16001).

- **One answer for every bag item:** `/bbutler` or the minimap button opens
  a window that sorts your bags into Sell, Auction, Disenchant, Mail, Bank,
  Look at it and Keep, with what each stack is worth and the reason. Hover
  a row for the whole reason; click a heading to fold it.
- **Safe selling:** the window comes up at every vendor with a Sell button
  that sells what is under Sell, one stack a click (12 a click once Test
  selling has passed). Nothing leaves your bags without your click, and the
  vendor's Buyback tab holds the last 12.
- **Sell below:** set an amount in Settings (or `/bbutler sellbelow 50s`)
  and anything worth less joins Sell. Off until you set it; quest items,
  upgrades and anything you keep are never touched.
- **Asks the other Blackthornes addons:** Tradeskills for auction prices,
  how fast things sell, disenchant values and what your craft queue and
  alts need; Equipment for upgrades and gathering tools; Farmer for
  gathering goals; Pets for pet food. Each is optional.
- **Your own lists:** right-click an item to Always keep, Always sell,
  Always bank or Always mail it to one of your characters. `/bbutler lists`
  shows them all.
- **All characters:** one searchable list of every item on every
  character, with what is in each one's bags, bank and mail (needs
  Tradeskills).
- **Mailbox and bank:** Fill mail fills the Send Mail page with what one of
  your alts needs, and you press Send. Move to bank and Take from bank do
  the same at the banker. Nothing is ever mailed to the character you are
  playing.
- **Window:** long reasons wrap instead of being cut off, and the corner
  grip makes the window bigger or smaller (right-click it for normal size).
  Titanforged and Blizzard window styles, Text size, and a Settings button
  for every command.
