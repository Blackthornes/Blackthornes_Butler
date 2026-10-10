# What the WoW: Forever client actually does, for bags, vendors and mail

Found with `/bbutler probe` in the game, not taken from documentation.
Tradeskills, Equipment and Pets keep files like this one for professions,
the auction house, gear, talents and pets; read them too before relying on
any API. Pets' first probe already found `C_Container.GetContainerItemInfo`
and `C_Item.GetItemCount` present, and the classic `GetItemCount` absent.

Nothing has been probed from Butler yet. Before the item list and Sell
ship, the probe should answer:

- which bag calls the client has (`C_Container` or the classic globals),
  and what `C_Container.GetContainerItemInfo` returns for an item;
- whether `C_Container.GetContainerItemQuestInfo` says an item is for, or
  starts, a quest;
- whether `C_Container.UseContainerItem` sells at an open vendor, and how
  many items the Buyback tab holds (`GetNumBuybackItems`);
- which Send Mail calls are there for filling the form.
