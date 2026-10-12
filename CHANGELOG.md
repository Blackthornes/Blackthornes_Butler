# Changelog

Versions follow [semantic versioning](https://semver.org): the middle number
moves for new behaviour, the last for fixes alone. The newest version goes at
the top; a release is refused if its version has no section here.

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
