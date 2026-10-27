-- Core/WhatsNewText.lua
-- Written by tools/make_whatsnew.py from NEWS.md. Never edit it by hand:
-- change NEWS.md and run the tool. UI/WhatsNew.lua shows it.

local _, ns = ...

ns.WHATS_NEW = {
    { version = "1.0.1", lines = {
        "The window has tabs: Your Bags, All Characters and Settings. Settings is the last tab, at the bottom right.",
    } },
    { version = "1.0.0", lines = {
        "Butler counts only the characters on your realm and side.",
        "The Bags window foot shows this character's gold beside everyone's.",
        "Arrow Size picks 50%, 75% or 100% for the guide arrow.",
        "A small gem beside the close button folds a window down to its title.",
    } },
    { version = "0.18.0", lines = {
        "Jobs has a Profession Leveling group with the next skill point for each profession. You turn it on with Cheapest Skill-Up on the Gold page of Settings.",
        "Each profession gets its own goal under Gold Goals, and a click shows the way to the trainer.",
        "Bank Alt can take the items that would go to the auction house. You pick it on the Bank Alt page.",
        "An item's tooltip can say what a vendor charges for it. You pick it on the General page.",
    } },
}
