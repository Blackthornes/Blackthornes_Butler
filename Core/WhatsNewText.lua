-- Core/WhatsNewText.lua
-- Written by tools/make_whatsnew.py from NEWS.md. Never edit it by hand:
-- change NEWS.md and run the tool. UI/WhatsNew.lua shows it.

local _, ns = ...

ns.WHATS_NEW = {
    { version = "1.2.0", lines = {
        "The General page holds Windows, Addons, Butler and Tooltips. Effects is a new choice there and starts on Full.",
        "Bags, Bank and Everyone hang below the Bags window like every other window tab. An empty list offers Clear Search.",
    } },
    { version = "1.1.0", lines = {
        "One minimap button now covers every Blackthornes addon you have. Click it to pick one. Turn it off with Combine Addon Buttons on the General page.",
        "Swap When Full offers to swap your cheapest item for better loot when your bags are full. It is off until you tick Swap When Full on the General page.",
    } },
    { version = "1.0.1", lines = {
        "The window has tabs: Your Bags, All Characters and Settings. Settings is the last tab, at the bottom right.",
    } },
}
