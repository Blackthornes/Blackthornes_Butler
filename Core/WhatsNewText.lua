-- Core/WhatsNewText.lua
-- Written by tools/make_whatsnew.py from NEWS.md. Never edit it by hand:
-- change NEWS.md and run the tool. UI/WhatsNew.lua shows it.

local _, ns = ...

ns.WHATS_NEW = {
    { version = "1.13.0", lines = {
        "Alt + right-click an item in the Bags window to open Butler's item menu.",
        "Auction rows now show about what you get after the auction cut.",
        "Buttons that ask for a second click now say Confirm.",
    } },
    { version = "1.12.0", lines = {
        "Right-click a character on the jobs list to clear what it was carrying. That way you stop getting sent to log in on it.",
        "Full Stacks Only now works for every mail. Short stacks wait until they are full.",
    } },
    { version = "1.11.0", lines = {
        "The Bank tab in your Bags window now remembers your bank after you leave it.",
        "Quest items you don't need anymore can now be sold, mailed or put on the auction house.",
        "Butler won't break a green for a skill point when selling it pays a lot more.",
    } },
}
