-- Core/WhatsNewText.lua
-- Written by tools/make_whatsnew.py from NEWS.md. Never edit it by hand:
-- change NEWS.md and run the tool. UI/WhatsNew.lua shows it.

local _, ns = ...

ns.WHATS_NEW = {
    { version = "1.20.0", lines = {
        "Item tooltips say \"You have\" and the count when only you have the item.",
        "Tooltips show what vendors pay for an item, and for the whole stack when you hold Shift.",
    } },
    { version = "1.19.1", lines = {
        "The Settings pages no longer overlap, and Butler no longer makes the window wider than it needs.",
    } },
    { version = "1.19.0", lines = {
        "A new key opens and closes Butler's bag window.",
        "Butler can keep the materials your leveling still needs.",
        "Butler can put things away on your bank alt for you.",
        "Starred recipes show up at vendors and trainers with Buy or Learn.",
        "Various bug fixes for Butler.",
    } },
}
