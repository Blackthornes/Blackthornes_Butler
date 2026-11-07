-- Core/WhatsNewText.lua
-- Written by tools/make_whatsnew.py from NEWS.md. Never edit it by hand:
-- change NEWS.md and run the tool. UI/WhatsNew.lua shows it.

local _, ns = ...

ns.WHATS_NEW = {
    { version = "1.7.0", lines = {
        "Butler can keep a number of an item across all your characters, bank too. Right-click an item to set it, or find it in Settings on the Errands page. Anything over that number is handled as usual.",
    } },
    { version = "1.6.0", lines = {
        "When your bags are full, a Throw Away button under your bags clears out the item worth the least. It starts off. Turn it on in Settings, on the General page.",
    } },
    { version = "1.5.0", lines = {
        "Butler can now send only full stacks to your bank alt. Smaller stacks stay in your bags until they fill up.",
    } },
}
