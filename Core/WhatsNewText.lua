-- Core/WhatsNewText.lua
-- Written by tools/make_whatsnew.py from NEWS.md. Never edit it by hand:
-- change NEWS.md and run the tool. UI/WhatsNew.lua shows it.

local _, ns = ...

ns.WHATS_NEW = {
    { version = "0.15.0", lines = {
        "Who Has It and Butler on Tooltips can each be Off, Shift or Always. You pick on the General page of Settings.",
        "Right-click a character's jobs to ignore them until that character next logs in.",
    } },
    { version = "0.14.0", lines = {
        "Butler speaks Simplified Chinese, French, Spanish and Russian now if your game is in one of those.",
    } },
    { version = "0.13.0", lines = {
        "You can keep a number of an item on each character. Right-click an item, or use Keep on Each Character on the Errands page of Settings.",
        "Buy Quest Items on the Selling page adds a Buy row at the auction house for what your open quests need. It's off until you tick it.",
        "A Buy row shows at any vendor that has something your craft queue needs.",
    } },
}
