-- Core/WhatsNewText.lua
-- Written by tools/make_whatsnew.py from NEWS.md. Never edit it by hand:
-- change NEWS.md and run the tool. UI/WhatsNew.lua shows it.

local _, ns = ...

ns.WHATS_NEW = {
    { version = "1.16.0", lines = {
        "Butler tells you why an item should wait, and Sell Anyway sells it when you disagree.",
        "A new Craft Details box on the General page adds what a craft makes and needs to the tooltip. It starts off.",
    } },
    { version = "1.15.0", lines = {
        "Windows now remember where you drag them, so they come back in the same spot.",
        "A new button on the General page puts every window back where it started.",
    } },
    { version = "1.14.0", lines = {
        "You can mark an item Always Auction, so it goes up for auction even when a vendor pays more.",
        "You can mail items to anyone, not just your own characters.",
        "A new Mail Rules list shows every mail rule in one place.",
        "A new box mutes every sound from all the Blackthornes addons at once. It starts off.",
    } },
}
