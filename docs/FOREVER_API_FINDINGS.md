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

## Selling at a vendor (built 2026-10-10, not yet seen in game)

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

## Buying ammo (built 2026-10-11, not yet seen in game)

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
