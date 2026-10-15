-- Core/WhatsNewText.lua
-- Written by tools/make_whatsnew.py from NEWS.md. Never edit it by hand:
-- change NEWS.md and run the tool. UI/WhatsNew.lua shows it.

local _, ns = ...

ns.WHATS_NEW = {
    { version = "0.9.0", lines = {
        "Shift-click an item at a vendor and type how many you want. Butler buys them all for you.",
        "A new option has Butler send every green to Disenchant on your disenchanter.",
    } },
    { version = "0.8.0", lines = {
        "Pick a character as your bank alt, and Butler mails it whole kinds of items, like all your cloth or herbs.",
    } },
    { version = "0.7.0", lines = {
        "Butler keeps the items your open quests need and can search the auction house for the ones you still lack.",
        "At a vendor, Butler shows what it has for your crafts and can buy it.",
    } },
}
