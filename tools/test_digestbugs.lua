-- Two players' reports (2026-10-13):
--   1. Fill mail for an alt's craft queue left two herbs out: a Farmer goal
--      here kept them, though the Jobs line said to mail them.
--   2. An item bought on the auction house to disenchant was offered to an
--      alt as an upgrade.
--
-- What must hold:
--   1. An alt's queued craft comes before a Farmer goal: its share is Mail.
--   2. Fill mail sends every item a Jobs mail step for this character
--      names, even one Butler keeps.
--   3. An item marked bought to disenchant is never an alt's upgrade.
--   4. Gear in an equipment set is Keep, whatever a list or a sister says,
--      and never goes in the mail (a player asked, 2026-10-13).

local env = dofile(lfs_cwd .. "/tools/testenv.lua")
local suite = env.NewSuite("digestbugs")

local ns = env.Load()
env.FakeBags({
    { bag = 0, slot = 1, id = 2452, name = "Swiftthistle", quality = 1, price = 15, count = 6 },
    { bag = 0, slot = 2, id = 2449, name = "Earthroot", quality = 1, price = 5, count = 8 },
    { bag = 0, slot = 3, id = 2318, name = "Light Leather", quality = 1, price = 10, count = 4 },
    { bag = 0, slot = 4, id = 405, name = "Heavy Woolen Pants", quality = 2, price = 100 },
    { bag = 0, slot = 5, id = 406, name = "Copper Band", quality = 2, price = 50 },
    { bag = 0, slot = 6, id = 407, name = "Dusty Boots", quality = 2, price = 80 },
})
C_EquipmentSet = {
    GetEquipmentSetIDs = function() return { 3 } end,
    GetEquipmentSetInfo = function(id) return id == 3 and "Tank" or nil end,
    GetItemIDs = function(id) return id == 3 and { [11] = 406, [8] = 407, [1] = -1 } or {} end,
}

local filled = {}
_G.BlackthornesTS = { Butler = {
    Advise = function(_, id)
        if id == 2452 then return { mailTo = "Bob Stone", mailCount = 6 } end
        if id == 405 then return { bought = 1, canDisenchant = true, disenchant = 300 } end
        if id == 406 then return { mailTo = "Bob Stone", mailCount = 1 } end
        return { auction = 0 }
    end,
    FillMail = function(_, name, items)
        filled[#filled + 1] = { name = name, items = items }
        return true
    end,
    Holdings = function()
        return {
            { key = "me", short = "Me Here", name = "Me Here", realm = "R", faction = "Horde", isCurrent = true },
            { key = "bob", short = "Bob Stone", name = "Bob Stone", realm = "R", faction = "Horde" },
        }
    end,
    Jobs = function()
        return {
            { key = "me", name = "Me Here", isCurrent = true, steps = {
                { kind = "mail", to = "Bob Stone", items = {
                    { itemID = 2452, count = 6 }, { itemID = 2449, count = 8 }, { itemID = 2318, count = 4 },
                } },
            } },
        }
    end,
    Mailbox = function() end,
} }
_G.BlackthornesFarmer = { Butler = { Advise = function(_, id)
    if id == 2452 or id == 2449 then return { goal = "herbs", have = 6, target = 20, need = 14 } end
end } }
_G.BlackthornesEquipment = { Butler = { Advise = function(_, link)
    if tostring(link):find("405") or tostring(link):find("407") then return { alt = { key = "bob", gain = 12 } } end
end } }
env.Enable(ns)
local Verdicts, UI = ns.Verdicts, ns.UI
ns.Verdicts:SetChoice(406, "sell")

local function VerdictOf(slot) return Verdicts:VerdictOf(ns.Bags.ReadSlot(0, slot)) end

UI:Show("bags")
Verdicts:Changed(true)

-- 1.
suite.check("the alt's share of a goal's herb is Mail", VerdictOf(1) == "mail", VerdictOf(1))
suite.check("a goal's herb no alt asked for is kept", VerdictOf(2) == "keep", VerdictOf(2))

-- 3.
suite.check("bought to disenchant is not mailed as an upgrade", VerdictOf(4) == "disenchant", VerdictOf(4))

-- 4.
suite.check("a set's ring is kept, though on Always sell and wanted by an alt's craft",
    VerdictOf(5) == "keep", VerdictOf(5))
suite.check("a set's boots are kept, though an alt's upgrade", VerdictOf(6) == "keep", VerdictOf(6))
suite.check("and it says which set", select(2, Verdicts:Judge(ns.Bags.ReadSlot(0, 6))) == "In your Tank equipment set")

-- 2.
env.Fire("MAIL_SHOW")
local ok = ns.Errands:FillMail("Bob Stone")
local counts = {}
for _, item in ipairs(filled[1] and filled[1].items or {}) do counts[item.itemID] = item.count end
suite.check("Fill mail filled", ok == true)
suite.check("both herbs and the leather go, as the Jobs line says",
    counts[2452] == 6 and counts[2449] == 8 and counts[2318] == 4,
    tostring(counts[2452]) .. " " .. tostring(counts[2449]) .. " " .. tostring(counts[2318]))
suite.check("the upgrade bought to disenchant does not go", counts[405] == nil)
suite.check("nor anything in a set", counts[406] == nil and counts[407] == nil)
env.Fire("MAIL_CLOSED")

_G.BlackthornesEquipment, _G.BlackthornesFarmer, _G.BlackthornesTS = nil, nil, nil
C_EquipmentSet = nil
suite.done()
