-- Core/WhatsNewText.lua
-- Written by tools/make_whatsnew.py from NEWS.md. Never edit it by hand:
-- change NEWS.md and run the tool. UI/WhatsNew.lua shows it.

local _, ns = ...

ns.WHATS_NEW = {
    { version = "0.10.0", lines = {
        "The Craft button opens the profession window first when it's closed.",
    } },
    { version = "0.9.0", lines = {
        "Shift-click an item at a vendor and type how many you want. Butler buys them all for you.",
        "A new option has Butler send every green to Disenchant on your disenchanter.",
    } },
    { version = "0.8.0", lines = {
        "Pick a character as your bank alt, and Butler mails it whole kinds of items, like all your cloth or herbs.",
    } },
}
