-- Core/WhatsNewText.lua
-- Written by tools/make_whatsnew.py from NEWS.md. Never edit it by hand:
-- change NEWS.md and run the tool. UI/WhatsNew.lua shows it.

local _, ns = ...

ns.WHATS_NEW = {
    { version = "0.5.0", lines = {
        "Your bags has a search box.",
        "Gear in your equipment sets is always kept.",
    } },
    { version = "0.3.0", lines = {
        "Ready transmutes and other cooldowns show in your Jobs list.",
        "Butler knows what vendors pay for most items from the start, so fewer items say \"price still loading\".",
    } },
    { version = "0.2.0", lines = {
        "Butler is in Deutsch on a German client.",
        "After you send a mail, Fill mail fills the next one.",
        "Butler mails your alts the materials their queued crafts need.",
        "Set how much gold each character keeps, and Butler offers a top-up at the mailbox.",
        "A Jobs list shows what to craft or mail on each character, and who to log in next.",
        "Item tooltips show which of your characters have it.",
        "Hunters get a Fill button for ammo at the vendor.",
        "Butler learns from what you sell and mail by hand, shows your free bag space on the backpack, and says \"You rang?\" when you open it.",
    } },
}
