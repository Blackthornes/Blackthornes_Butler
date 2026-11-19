-- Core/WhatsNewText.lua
-- Written by tools/make_whatsnew.py from NEWS.md. Never edit it by hand:
-- change NEWS.md and run the tool. UI/WhatsNew.lua shows it.

local _, ns = ...

ns.WHATS_NEW = {
    { version = "1.21.0", lines = {
        "Every window has a gold gem on its title bar. Click it to switch between the one window and separate windows.",
    } },
    { version = "1.20.0", lines = {
        "Item tooltips say \"You have\" and the count when only you have the item.",
        "Tooltips show what vendors pay for an item, and for the whole stack when you hold Shift.",
    } },
    { version = "1.19.1", lines = {
        "The Settings pages no longer overlap, and Butler no longer makes the window wider than it needs.",
    } },
}
