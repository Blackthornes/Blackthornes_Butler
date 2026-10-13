-- Core/WhatsNewText.lua
-- Written by tools/make_whatsnew.py from NEWS.md. Never edit it by hand:
-- change NEWS.md and run the tool. UI/WhatsNew.lua shows it.

local _, ns = ...

ns.WHATS_NEW = {
    { version = "0.5.0", lines = {
        "Your bags now has a search box.",
        "Gear in your equipment sets is always kept.",
        "Mailing upgrades to your other characters is now off until you turn it on.",
        "Fill mail sends everything a job needs, herbs too.",
        "The scroll bar moves the right way now.",
    } },
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
}
