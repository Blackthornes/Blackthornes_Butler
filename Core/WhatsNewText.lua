-- Core/WhatsNewText.lua
-- Written by tools/make_whatsnew.py from NEWS.md. Never edit it by hand:
-- change NEWS.md and run the tool. UI/WhatsNew.lua shows it.

local _, ns = ...

ns.WHATS_NEW = {
    { version = "0.11.0", lines = {
        "Type the name of a character on your other account as your bank alt.",
        "Greens go to your disenchanter only when breaking them pays at least what selling would. A new option sends them anyway.",
        "When your bags are full, the trash can points at two short stacks you can join first, so nothing gets thrown away.",
    } },
    { version = "0.10.0", lines = {
        "The Craft button opens the profession window first when it's closed.",
    } },
    { version = "0.9.0", lines = {
        "Shift-click an item at a vendor and type how many you want. Butler buys them all for you.",
        "A new option has Butler send every green to Disenchant on your disenchanter.",
    } },
}
