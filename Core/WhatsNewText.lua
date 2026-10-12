-- Core/WhatsNewText.lua
-- Written by tools/make_whatsnew.py from NEWS.md. Never edit it by hand:
-- change NEWS.md and run the tool. UI/WhatsNew.lua shows it.

local _, ns = ...

ns.WHATS_NEW = {
    { version = "0.4.0", lines = {
        "Fill mail, Sell and the bank buttons now sit right on the line they work on.",
        "Gold top-ups and mailed upgrades are only counted once the mail really goes.",
        "Fixes for selling, soulbound gear and the All characters list.",
    } },
    { version = "0.3.0", lines = {
        "A new What's New window shows what changed after each update.",
        "Ready transmutes and other cooldowns show up in your Jobs list.",
        "Butler knows vendor prices right away, so fewer items say \"price still loading\".",
    } },
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
}
