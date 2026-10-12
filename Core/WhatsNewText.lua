-- Core/WhatsNewText.lua
-- Written by tools/make_whatsnew.py from NEWS.md. Never edit it by hand:
-- change NEWS.md and run the tool. UI/WhatsNew.lua shows it.

local _, ns = ...

ns.WHATS_NEW = {
    { version = "0.2.0", lines = {
        "Butler speaks Deutsch now if your game is in German.",
        "Fill mail keeps going: send one and the next one's ready right away.",
        "Butler sends your alts the materials they need, and gear that's an upgrade for them. Don't want one sent? Just right-click it.",
        "Set how much gold each character should keep, and Butler tops them up by mail.",
        "A Jobs list shows what to craft or mail on each character, and who to log in next.",
        "Hover any item to see which of your characters have it.",
        "Hunters get a Fill button for ammo at the vendor.",
        "Butler learns from what you do, shows your free bag space, and says \"You rang?\" when you open it.",
    } },
    { version = "0.1.0", lines = {
        "Meet Butler! It looks at every item in your bags and tells you what to do with it: sell it, post it, disenchant it, mail it to an alt, bank it or keep it.",
        "Open it at any vendor and press Sell to clear out the junk. Nothing gets sold unless you click.",
        "Pick an amount, and anything worth less goes on the sell list.",
        "See every item on all your characters in one list.",
        "At the mailbox, it fills in a letter with what your alts need.",
    } },
}
