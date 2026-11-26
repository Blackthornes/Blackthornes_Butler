# What the WoW: Forever client actually does, for bags, vendors and mail

Found with `/bbutler probe` in the game, not taken from documentation.
Tradeskills, Equipment and Pets keep files like this one for professions,
the auction house, gear, talents and pets; read them too before relying on
any API. Pets' first probe already found `C_Container.GetContainerItemInfo`
and `C_Item.GetItemCount` present, and the classic `GetItemCount` absent.

Nothing has been probed from Butler yet. The item list and Sell are built
on these, each read inside a pcall, so the probe should answer:

- which bag calls the client has (`C_Container` or the classic globals),
  and what `C_Container.GetContainerItemInfo` returns for an item;
- whether `C_Container.GetContainerItemQuestInfo` says an item is for, or
  starts, a quest;
- whether `C_Container.UseContainerItem` sells at an open vendor, and how
  many items the Buyback tab holds (`GetNumBuybackItems`);
- which Send Mail calls are there for filling the form.

## Selling at a vendor (built 2026-10-10)

Tradeskills found (2026-10-07) that the Warcraft Wiki marks
`C_Container.UseContainerItem` as protected on current retail, so Butler's
Sell button is a secure button, as Tradeskills' Sell marked is: each click
sells one stack through a `/use bag slot` line set just before the click,
only while a vendor is open and the game's vendor window shows. `/bbutler
selltest` (Settings > Selling > Test selling) sells the cheapest grey from
Butler's own code and keeps whether the item left and gold came in
(`sellTest` in the account save); if it works, each click sells up to 12.
`/bbutler probe` shows the result as "sell from Butler".

**Seen in game 2026-10-10: selling from addon code works on Forever.**
`/bbutler selltest` sold a grey through `C_Container.UseContainerItem`
called from Butler's own code, gold came in, and the Sell button then sold
the Sell group up to 12 a click.

## Buying ammo (built 2026-10-11)

The Ammo row (Logic/Ammo.lua) reads the vendor with `GetMerchantNumItems`,
`GetMerchantItemLink` and `C_MerchantFrame.GetItemInfo` (classic's
`GetMerchantItemInfo` when that is missing), the ammo's damage from
`C_TooltipInfo.GetMerchantItem`, the weapon from `GetInventoryItemID`
(slot 18, then 16) and the ammo bag's family from
`C_Container.GetContainerNumFreeSlots`. It buys with
`BuyMerchantItem(index)` and no quantity, one lot a call, since classic
and retail read the quantity differently. `/bbutler probe` lists which of
these the client has and what weapon and ammo bag Butler sees; whether
Forever keeps ammo and quivers at all is still to be seen.

## The one window's docking

`UI/SharedWindow.lua` (2026-10-30) docks the one window beside the game's
own windows by screen position only; it never moves, hides or writes a
Blizzard frame. What it expects of Forever's retail engine, from the
retail client: `AUCTION_HOUSE_SHOW`/`AUCTION_HOUSE_CLOSED`
with `AuctionHouseFrame`, `MAIL_SHOW`/`MAIL_CLOSED` with `MailFrame`,
`MERCHANT_SHOW`/`MERCHANT_CLOSED` with `MerchantFrame`, and
`TRAINER_SHOW`/`TRAINER_CLOSED` with `ClassTrainerFrame`. The retail
client can close these through `PLAYER_INTERACTION_MANAGER_FRAME_HIDE`
(its argument an `Enum.PlayerInteractionType`: MailInfo 17, Merchant 5,
Trainer 7, Auctioneer 21) without the old close event, so that event
undocks too. Every event is registered inside a pcall.

## The bank (probe added 2026-11-26)

Asked before a Butler Bank window is built (Butler idea 8): a window with
real item squares beside Butler Bags at a banker. `/bbutler bankprobe`, run
at a banker, prints and keeps (`lastProbe`) what that needs:

- which bank calls the client has (`C_Bank.*`, `GetNumBankSlots`,
  `C_Container.SortBankBags` and the like), `Enum.BagIndex`'s bank keys and
  `NUM_BANKBAGSLOTS`;
- each bank container Butler reads (`Errands.BankBagIDs`), with its slots
  and items;
- which of the game's bank frames exist (`BankFrame`, `BankSlotsFrame`,
  `BankPanel`, `ReagentBankFrame`, the bank bag container frames), shown
  and protected;
- whether `ContainerFrameItemButtonTemplate` and
  `BankItemButtonGenericTemplate`, made by this addon on the first bank
  item, come out protected and read the bag (`GetBagID`);
- one live test: a square of the first bank item. A right-click on it
  should move the item to the bags as the game's bank does. Once the bags
  settle the probe says whether the item left the bank slot, whether it
  went on the cursor, and any `ADDON_ACTION_BLOCKED` or `_FORBIDDEN`.

In a fight it makes and shows nothing, and says so.

First run (2026-11-26, level 44, at a banker):

- The bank is in tabs, as on retail: `Enum.BagIndex.CharacterBankTab_1`
  is 6 (to `_6` = 11), `AccountBankTab_1` is 15. Tab 6 had 48 slots and the
  40 items the game's bank shows; 7 and 8 had 10 and 12 empty slots; 9 to
  12 had none. `NUM_BANKBAGSLOTS` is nil.
- Bag -1 still answers: 32 slots, 4 items. The game's bank shows none of
  them, and a right-click on one says the spot is empty. Treat -1 as not
  part of the bank when the client has tabs (`Errands.BankBagIDs` still
  lists it; the window build must leave it out).
- Present: `C_Bank.CanUseBank` (true), `C_Bank.FetchPurchasedBankTabData`,
  `C_Bank.FetchNumPurchasedBankTabs`, `C_Bank.AutoDepositItemsIntoBank`,
  `C_Container.SortBankBags`, `C_Container.GetBankAutosortDisabled`,
  `C_Container.ContainerIDToInventoryID`. Absent: `GetNumBankSlots`,
  `PurchaseSlot`, `GetBankSlotCost`, `BankButtonIDToInvSlotID`,
  `SortBankBags`, `DepositReagentBank`, `CloseBankFrame`.
- Frames: `BankFrame`, `BankPanel`, `BankItemSearchBox` (none protected);
  no `BankSlotsFrame`, `BankFrameItem1`, `ReagentBankFrame` or
  `AccountBankPanel`.
- `ContainerFrameItemButtonTemplate` made by Butler on a bank slot: not
  protected, `GetBagID` reads the holder's bag, `SetBagID` and `OnClick`
  present. `BankItemButtonGenericTemplate` does not exist (asking for it
  raised and printed a taint line), so the probe no longer tries it.
- Second run (11:09, from tab 6): a right-click on Butler's square moved
  the item from bank tab 6 slot 1 into the bags. Not on the cursor,
  nothing blocked, not in a fight. The Butler Bank window is built on this
  (`UI/BankWindow.lua`).

## Food and drink for the restock list

`Logic/Restock.lua` (2026-11-26) tells food from drink by the spell the
item casts: `C_Item.GetItemSpell(itemID)` (else `GetItemSpell`) compared
with the names of spell 433 (Food) and 430 (Drink) from
`C_Spell.GetSpellName` (else `GetSpellInfo`), so any language matches. It
first asks `C_Item.GetItemInfoInstant` for class 0, subclass 5 (Food &
Drink). Both are the retail client's; not yet seen on Forever. The
`/bbutler probe` "restock" line shows the two spell names and how up to
three bag items read.
