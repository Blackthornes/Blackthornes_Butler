-- Core/WhatsNewText.lua
-- Written by tools/make_whatsnew.py from NEWS.md. Never edit it by hand:
-- change NEWS.md and run the tool. UI/WhatsNew.lua shows it.

local _, ns = ...

ns.WHATS_NEW = {
    { version = "0.7.0", lines = {
        "Butler keeps the items your open quests need and can search the auction house for the ones you still lack.",
        "At a vendor, Butler shows what it has for your crafts and can buy it.",
    } },
    { version = "0.6.0", lines = {
        "This is the largest AddOn update so far across the whole suite of Blackthornes addons.",
        "Butler tells you which class spells you can train, and has a Train all button at the trainer.",
        "Gold goals at the bottom show how close you are to your spells, trainers and riding.",
        "A little trash can shows on the cheapest item when your bags are full.",
        "The last line on an item's tooltip says what Butler would do with it.",
        "Your Jobs list puts mail, buying and parts first, so crafts come in the right order.",
    } },
    { version = "0.5.0", lines = {
        "Your bags has a search box.",
        "Gear in your equipment sets is always kept.",
    } },
}
