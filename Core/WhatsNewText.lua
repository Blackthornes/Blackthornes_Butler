-- Core/WhatsNewText.lua
-- Written by tools/make_whatsnew.py from NEWS.md. Never edit it by hand:
-- change NEWS.md and run the tool. UI/WhatsNew.lua shows it.

local _, ns = ...

ns.WHATS_NEW = {
    { version = "1.26.0", lines = {
        "The All Addons page in Settings has a Set Default button. Click Confirm and this addon's settings go back to how they started.",
    } },
    { version = "1.25.0", lines = {
        "Windows fold into a round button with the Butler badge.",
        "Butler fills mail for your bank alts without Tradeskills.",
    } },
    { version = "1.24.0", lines = {
        "Panels and rows have a warm brown-black look.",
        "Item rows link in chat and try on gear.",
        "Butler has its own key in Key Bindings.",
    } },
}
