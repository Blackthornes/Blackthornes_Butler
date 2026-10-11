# Changelog

Versions follow [semantic versioning](https://semver.org): the middle number
moves for new behaviour, the last for fixes alone. The newest version goes at
the top; a release is refused if its version has no section here.

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
