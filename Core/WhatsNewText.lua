-- Core/WhatsNewText.lua
-- Written by tools/make_whatsnew.py from NEWS.md. Never edit it by hand:
-- change NEWS.md and run the tool. UI/WhatsNew.lua shows it.

local _, ns = ...

ns.WHATS_NEW = {
    { version = "1.25.0", lines = {
        "Windows fold into a round button with the Butler badge.",
        "Butler fills mail for your bank alts without Tradeskills.",
    } },
    { version = "1.24.0", lines = {
        "Panels and rows have a warm brown-black look.",
        "Item rows link in chat and try on gear.",
        "Butler has its own key in Key Bindings.",
    } },
    { version = "1.23.0", lines = {
        "The Butler Bar has a Buy button at vendors that sell what the craft queue needs.",
    } },
}
