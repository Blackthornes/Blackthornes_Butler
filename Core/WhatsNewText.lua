-- Core/WhatsNewText.lua
-- Written by tools/make_whatsnew.py from NEWS.md. Never edit it by hand:
-- change NEWS.md and run the tool. UI/WhatsNew.lua shows it.

local _, ns = ...

ns.WHATS_NEW = {
    { version = "1.10.0", lines = {
        "See what is inside a mail just by hovering over it in your inbox.",
        "A little Pick button next to the To box lists your characters and the last name you mailed.",
        "Butler can warn you when mail is about to run out, so nothing gets sent back.",
        "Gear your class can never wear now goes under Sell.",
    } },
    { version = "1.9.0", lines = {
        "Send each kind of item to its own character from the Bank Alt page.",
    } },
    { version = "1.8.0", lines = {
        "The Bags window has a new Group By choice called By Bag. Each bag gets its own section, with its name and how many slots are free.",
    } },
}
