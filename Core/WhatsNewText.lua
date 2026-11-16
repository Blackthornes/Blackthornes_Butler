-- Core/WhatsNewText.lua
-- Written by tools/make_whatsnew.py from NEWS.md. Never edit it by hand:
-- change NEWS.md and run the tool. UI/WhatsNew.lua shows it.

local _, ns = ...

ns.WHATS_NEW = {
    { version = "1.18.0", lines = {
        "A slim Butler Bar can sit under the vendor, mailbox and bank windows.",
        "Butler can mark the game's bag squares.",
        "Settings has a Keep page and an All Addons page.",
        "The window docks at more places, including the bank and the profession window.",
    } },
    { version = "1.17.0", lines = {
        "A new Reset This Item line is in the right-click menu of every item. It clears every choice you made for that item.",
        "Butler Bags now opens in a fight.",
    } },
    { version = "1.16.0", lines = {
        "Butler tells you why an item should wait, and Sell Anyway sells it when you disagree.",
        "A new Craft Details box on the General page adds what a craft makes and needs to the tooltip. It starts off.",
    } },
}
