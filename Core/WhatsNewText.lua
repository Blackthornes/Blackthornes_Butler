-- Core/WhatsNewText.lua
-- Written by tools/make_whatsnew.py from NEWS.md. Never edit it by hand:
-- change NEWS.md and run the tool. UI/WhatsNew.lua shows it.

local _, ns = ...

ns.WHATS_NEW = {
    { version = "1.12.0", lines = {
        "Right-click a character on the jobs list to clear what it was carrying. That way you stop getting sent to log in on it.",
        "Full Stacks Only now works for every mail. Short stacks wait until they are full.",
    } },
    { version = "1.11.0", lines = {
        "The Bank tab in your Bags window now remembers your bank after you leave it.",
        "Quest items you don't need anymore can now be sold, mailed or put on the auction house.",
        "Butler won't break a green for a skill point when selling it pays a lot more.",
    } },
    { version = "1.10.0", lines = {
        "See what is inside a mail just by hovering over it in your inbox.",
        "A little Pick button next to the To box lists your characters and the last name you mailed.",
        "Butler can warn you when mail is about to run out, so nothing gets sent back.",
        "Gear your class can never wear now goes under Sell.",
    } },
}
