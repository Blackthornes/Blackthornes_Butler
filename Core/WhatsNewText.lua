-- Core/WhatsNewText.lua
-- Written by tools/make_whatsnew.py from NEWS.md. Never edit it by hand:
-- change NEWS.md and run the tool. UI/WhatsNew.lua shows it.

local _, ns = ...

ns.WHATS_NEW = {
    { version = "1.24.0", lines = {
        "Panels and rows have a warm brown-black look.",
        "Item rows link in chat and try on gear.",
        "Butler has its own key in Key Bindings.",
    } },
    { version = "1.23.0", lines = {
        "The Butler Bar has a Buy button at vendors that sell what the craft queue needs.",
    } },
    { version = "1.22.0", lines = {
        "Butler mails extra pet food to your bank alt when Food to Keep is on in Pets.",
    } },
}
