-- Core/WhatsNewText.lua
-- Written by tools/make_whatsnew.py from NEWS.md. Never edit it by hand:
-- change NEWS.md and run the tool. UI/WhatsNew.lua shows it.

local _, ns = ...

ns.WHATS_NEW = {
    { version = "1.14.0", lines = {
        "You can mark an item Always Auction, so it goes up for auction even when a vendor pays more.",
        "You can mail items to anyone, not just your own characters.",
        "A new Mail Rules list shows every mail rule in one place.",
        "A new box mutes every sound from all the Blackthornes addons at once. It starts off.",
    } },
    { version = "1.13.0", lines = {
        "Alt + right-click an item in the Bags window to open Butler's item menu.",
        "Auction rows now show about what you get after the auction cut.",
        "Buttons that ask for a second click now say Confirm.",
    } },
    { version = "1.12.0", lines = {
        "Right-click a character on the jobs list to clear what it was carrying. That way you stop getting sent to log in on it.",
        "Full Stacks Only now works for every mail. Short stacks wait until they are full.",
    } },
}
