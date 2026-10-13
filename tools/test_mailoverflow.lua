-- More than a mail holds: a player's vials for an alt's potions were never
-- mailed (2026-10-13). Mail rows go most valuable first, so the vials came
-- last, past the twelve stacks a mail carries, and the next mail Butler
-- fills skipped the alt it had just filled for.
--
-- What must hold:
--   1. Fill mail puts the items that take the fewest stacks first, so every
--      material fits in the first mail before a herb's extra stacks.
--   2. Once that mail goes, what did not fit is filled into the next mail
--      for the same character.

local env = dofile(lfs_cwd .. "/tools/testenv.lua")
local suite = env.NewSuite("mailoverflow")

local ns = env.Load()
local HERB, VIAL = 2447, 3371
local items = {}
-- Thirteen stacks of herbs, then one stack of vials (worth a copper).
for slot = 1, 13 do
    items[#items + 1] = { bag = 0, slot = slot, id = HERB, name = "Peacebloom", quality = 1, price = 5, count = 20 }
end
items[#items + 1] = { bag = 0, slot = 14, id = VIAL, name = "Empty Vial", quality = 1, price = 1, count = 13 }
local fake = env.FakeBags(items)

local wants = { [HERB] = 260, [VIAL] = 13 }
local filled = {}
_G.BlackthornesTS = { Butler = {
    Advise = function(_, id)
        if wants[id] and wants[id] > 0 then return { mailTo = "Alch Brew", mailCount = wants[id] } end
    end,
    FillMail = function(_, name, list)
        filled[#filled + 1] = { name = name, items = list }
        return true
    end,
    Holdings = function()
        return {
            { key = "me", short = "Me Here", realm = "R", faction = "Horde", isCurrent = true },
            { key = "alch", short = "Alch Brew", realm = "R", faction = "Horde" },
        }
    end,
    Mailbox = function() end,
} }
env.Enable(ns)
local UI, Errands = ns.UI, ns.Errands

env.Fire("MAIL_SHOW")
UI:Show("bags")
local ok = Errands:FillMail("Alch Brew")
local first = filled[1] and filled[1].items or {}
suite.check("the mail is filled", ok and #first == 2, #first)
-- 1. One stack of vials before thirteen of herbs.
suite.check("the vials go first", first[1] and first[1].itemID == VIAL and first[1].count == 13,
    first[1] and first[1].itemID)
suite.check("then the herbs", first[2] and first[2].itemID == HERB and first[2].count == 260)

-- What the game put in the mail: the vials and eleven stacks of herbs.
_G.GetSendMailItem = function(slot)
    if slot == 1 then return "Empty Vial", VIAL, 134400, 13 end
    if slot <= 12 then return "Peacebloom", HERB, 134400, 20 end
end
Errands:OnSendMail("Alch Brew", Errands.SUBJECT)

-- 2. The mail goes: the two stacks of herbs left are the next mail.
for slot = 1, 11 do fake.bags[0][slot] = nil end
fake.bags[0][14] = nil
wants = { [HERB] = 40 }
Errands.hookedSend = true
env.Fire("MAIL_SEND_SUCCESS")
local second = filled[2] and filled[2].items or {}
suite.check("what did not fit fills the next mail to the same character",
    filled[2] and filled[2].name == "Alch Brew" and second[1] and second[1].itemID == HERB and second[1].count == 40,
    filled[2] and filled[2].name)

-- Everything went: nothing more to fill.
_G.GetSendMailItem = function(slot)
    if slot <= 2 then return "Peacebloom", HERB, 134400, 20 end
end
Errands:OnSendMail("Alch Brew", Errands.SUBJECT)
fake.bags[0][12], fake.bags[0][13] = nil, nil
wants = {}
env.Fire("MAIL_SEND_SUCCESS")
suite.check("all of it went: no third mail", filled[3] == nil)

env.Fire("MAIL_CLOSED")
_G.GetSendMailItem = nil
_G.BlackthornesTS = nil
suite.done()
