-- Core/WhatsNewText.lua
-- Written by tools/make_whatsnew.py from NEWS.md. Never edit it by hand:
-- change NEWS.md and run the tool. UI/WhatsNew.lua shows it.

local _, ns = ...

ns.WHATS_NEW = {
    { version = "1.28.0", lines = {
        "Butler can mail your alts the materials for their Road to 300. It is off unless ticked.",
        "Butler can mail a recipe to the alt who can learn it. It is off unless ticked.",
        "A tick list lets you leave an alt out of both mails.",
        "Upgrade mail has one tick list of characters.",
    } },
    { version = "1.27.0", lines = {
        "A Right Now card sits at the top of the Butler window.",
        "Rows are calmer: one line each, greys folded.",
        "Butler Bank opens the bank in the Butler Bags style. It is off unless ticked.",
        "The Restock list tops items up from your bank, other characters and vendors.",
        "Search takes words such as gear, boe, quest and over 1g.",
        "Quick marks mark an item in one click or one key.",
    } },
    { version = "1.26.0", lines = {
        "The All Addons page in Settings has a Set Default button. Click Confirm and this addon's settings go back to how they started.",
    } },
}
