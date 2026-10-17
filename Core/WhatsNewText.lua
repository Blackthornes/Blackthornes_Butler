-- Core/WhatsNewText.lua
-- Written by tools/make_whatsnew.py from NEWS.md. Never edit it by hand:
-- change NEWS.md and run the tool. UI/WhatsNew.lua shows it.

local _, ns = ...

ns.WHATS_NEW = {
    { version = "0.13.0", lines = {
        "Green gear that sells for more at the auction house goes to Auction instead of getting broken down. If breaking it would give you an Enchanting skill point, Butler still says to break it. Right-click an item and pick Always disenchant to break it anyway.",
    } },
    { version = "0.12.0", lines = {
        "Settings has a new page where you drag Butler's rules into the order you want, or turn them off.",
    } },
    { version = "0.11.0", lines = {
        "Type the name of a character on your other account as your bank alt.",
        "Greens go to your disenchanter only when breaking them pays at least what selling would. A new option sends them anyway.",
        "When your bags are full, the trash can points at two short stacks you can join first, so nothing gets thrown away.",
    } },
}
