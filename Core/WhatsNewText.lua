-- Core/WhatsNewText.lua
-- Written by tools/make_whatsnew.py from NEWS.md. Never edit it by hand:
-- change NEWS.md and run the tool. UI/WhatsNew.lua shows it.

local _, ns = ...

ns.WHATS_NEW = {
    { version = "1.1.0", lines = {
        "One minimap button now covers every Blackthornes addon you have. Click it to pick one. Turn it off with Combine Addon Buttons on the General page.",
        "Swap When Full offers to swap your cheapest item for better loot when your bags are full. It is off until you tick Swap When Full on the General page.",
    } },
    { version = "1.0.1", lines = {
        "The window has tabs: Your Bags, All Characters and Settings. Settings is the last tab, at the bottom right.",
    } },
    { version = "1.0.0", lines = {
        "Butler counts only the characters on your realm and side.",
        "The Bags window foot shows this character's gold beside everyone's.",
        "Arrow Size picks 50%, 75% or 100% for the guide arrow.",
        "A small gem beside the close button folds a window down to its title.",
    } },
}
