-- Core/WhatsNewText.lua
-- Written by tools/make_whatsnew.py from NEWS.md. Never edit it by hand:
-- change NEWS.md and run the tool. UI/WhatsNew.lua shows it.

local _, ns = ...

ns.WHATS_NEW = {
    { version = "1.5.0", lines = {
        "Butler can now send only full stacks to your bank alt. Smaller stacks stay in your bags until they fill up.",
    } },
    { version = "1.4.2", lines = {
        "The Bags window always shows your empty slots, so the Empty Slots tick box is gone.",
    } },
    { version = "1.4.0", lines = {
        "The one window now stays next to the auction house.",
        "Settings drop-down lists stay on top so you can always see them.",
        "Group headings show a small mark for what Butler says to do.",
        "Item icons get a soft ring for their quality and a count in the corner.",
    } },
}
