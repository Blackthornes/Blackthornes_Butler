-- Core/WhatsNewText.lua
-- Written by tools/make_whatsnew.py from NEWS.md. Never edit it by hand:
-- change NEWS.md and run the tool. UI/WhatsNew.lua shows it.

local _, ns = ...

ns.WHATS_NEW = {
    { version = "0.17.0", lines = {
        "Butler Bags has an Empty Slots box next to Sort, and the free space count is bigger.",
    } },
    { version = "0.16.0", lines = {
        "Butler Bags is a new replacement bag feature, off by default. Turn it on under Bags on the General page of Settings. Group by what to do, by item type or as one grid, search, and sort. Special bags sit on their own rows with One Grid.",
        "Craft When It Pays More puts a craft that earns more than selling under Craft, with a Queue button. It's on the Selling page.",
        "Cheapest Skill-Up shows your next skill point in Jobs, with a Queue button. It's on the Gold page.",
        "Your Tradeskills lists can mail to a character and keep a number on each one. It's on the Lists page.",
    } },
    { version = "0.15.0", lines = {
        "Who Has It and Butler on Tooltips can each be Off, Shift or Always. You pick on the General page of Settings.",
        "Right-click a character's jobs to ignore them until that character next logs in.",
    } },
}
