-- Class spells to train (the owner said build it 2026-10-13).
--
-- What must hold:
--   1. Ready now: spells at or below the level, not known, whose rank
--      before is known or trained first; never another race's spell or one
--      no trainer teaches.
--   2. The next level's spells are listed apart.
--   3. A class trainer's window keeps prices, what it does not teach and
--      where it stands; the filter is put back as it was.
--   4. Train all buys one at a time, only what the purse pays for.
--   5. The Jobs group leads with the spells to train, and other
--      characters' waiting spells.
--   6. The gold fund keeps back what this character's spells cost and
--      tops up another character for theirs.
--   7. Turned off, nothing shows and no gold is kept back.

local env = dofile(lfs_cwd .. "/tools/testenv.lua")
local suite = env.NewSuite("classtraining")

local ns = env.Load()
local fake = env.FakeBags({})
fake.money = 100 * 10000

local G = 10000
local saved = {}
for _, name in ipairs({ "UnitGUID", "UnitRace", "UnitFactionGroup", "IsPlayerSpell", "GetNumTrainerServices",
    "GetTrainerServiceInfo", "GetTrainerServiceCost", "GetTrainerServiceLevelReq", "BuyTrainerService",
    "GetTrainerServiceTypeFilter", "SetTrainerServiceTypeFilter", "IsTradeskillTrainer",
    "GetRealZoneText", "GetSubZoneText" }) do
    saved[name] = rawget(_G, name)
end

-- A small spell list: { id, level, rank, name, races, rank before }.
ns.CLASS_SPELLS = { MAGE = {
    { 1, 4, 1, "Frostbolt" },
    { 2, 8, 2, "Frostbolt", nil, 1 },
    { 3, 10, 1, "Frost Nova" },
    { 4, 12, 3, "Frostbolt", nil, 2 },
    { 5, 12, 1, "Gnome Trick", { 7 } },
    { 6, 12, 1, "Quest Spell" },
    { 7, 12, 2, "Talent Thing", nil, 99 },
    { 8, 14, 1, "Arcane Explosion" },
    { 9, 14, 1, "Flamestrike" },
    { 10, 16, 1, "Later Spell" },
} }

-- Classic's price for Frost Nova, until a trainer says 200.
ns.CLASS_SPELL_PRICES = { [3] = 150 }

local level, known = 12, { [1] = true }
_G.UnitClass = function() return "Mage", "MAGE" end
_G.UnitLevel = function() return level end
_G.UnitRace = function() return "Human", "Human", 1 end
_G.UnitFactionGroup = function() return "Alliance" end
_G.UnitName = function(unit) return unit == "npc" and "Jennea Cannon" or "Me Here" end
_G.UnitGUID = function(unit)
    if unit == "npc" then return "Creature-0-1-2-3-5498-0000" end
    return "Player-1-AAA"
end
_G.IsPlayerSpell = function(id) return known[id] == true end
_G.GetRealZoneText = function() return "Stormwind City" end
_G.GetSubZoneText = function() return "Wizard's Sanctum" end
_G.C_Map = {
    GetBestMapForUnit = function() return 1453 end,
    GetPlayerMapPosition = function() return { GetXY = function() return 0.38, 0.79 end } end,
}

env.Enable(ns)
local CT, Jobs, Funds = ns.ClassTraining, ns.Jobs, ns.Funds

-- 1. Ready now.
local plan = CT:Plan()
local ids = {}
for _, spell in ipairs(plan.ready) do ids[#ids + 1] = spell.id end
suite.check("ready: rank 2, Frost Nova, rank 3 after rank 2, the quest spell",
    table.concat(ids, ",") == "2,3,4,6", table.concat(ids, ","))
suite.check("never another race's spell", not table.concat(ids, ","):find("5"))
suite.check("never a rank whose rank before nobody here has", not table.concat(ids, ","):find("7"))
suite.check("Classic's price stands in until a trainer is seen", plan.cost == 150 and plan.unknown == 3
    and plan.guessed == 1, plan.cost .. " " .. plan.unknown)

-- 2. The next level.
suite.check("the next level is 14", plan.nextLevel == 14 and #plan.next == 2)

-- 3. At a class trainer. The list hides spells not learnable yet; the
-- addon shows them to read prices, then hides them again.
local filterShown = false
local filterSets = {}
local services = {
    { "Frostbolt", "Rank 2", "available", 100, 8, 2 },
    { "Frost Nova", "", "available", 200, 10, 3 },
    { "Frostbolt", "Rank 3", "available", 300, 12, 4 },
    { "Arcane Explosion", "", "unavailable", 1000, 14, 8 },
    { "Flamestrike", "", "unavailable", 1200, 14, 9 },
}
local function Shown()
    local list = {}
    for _, s in ipairs(services) do
        if s[3] ~= "unavailable" or filterShown then list[#list + 1] = s end
    end
    return list
end
_G.IsTradeskillTrainer = function() return false end
_G.GetTrainerServiceTypeFilter = function(kind) return kind ~= "unavailable" or filterShown end
_G.SetTrainerServiceTypeFilter = function(kind, on)
    filterSets[#filterSets + 1] = kind .. "=" .. tostring(on)
    if kind == "unavailable" then filterShown = on == 1 end
end
_G.GetNumTrainerServices = function() return #Shown() end
_G.GetTrainerServiceInfo = function(i) local s = Shown()[i] return s[1], s[2], s[3] end
_G.GetTrainerServiceCost = function(i) return Shown()[i][4] end
_G.GetTrainerServiceLevelReq = function(i) return Shown()[i][5] end
local boughtIndex = {}
_G.BuyTrainerService = function(i)
    local s = Shown()[i]
    boughtIndex[#boughtIndex + 1] = s[1] .. " " .. s[2]
    fake.money = fake.money - s[4]
    s[3] = "used"
    known[s[6]] = true
end

env.Fire("TRAINER_SHOW")
local data = CT:Data()
suite.check("prices kept, the later ones too", data.prices[2] == 100 and data.prices[3] == 200
    and data.prices[8] == 1000 and data.prices[9] == 1200)
suite.check("the filter is put back as it was", not filterShown and #filterSets == 2)
suite.check("a spell the trainer doesn't list is not taught there", data.notTaught[6] == true)
suite.check("a spell it lists is", not data.notTaught[2])
suite.check("another race's spell is not marked", not data.notTaught[5])
local spot = data.trainers.MAGE and data.trainers.MAGE[5498]
suite.check("the trainer's spot is kept", spot and spot.name == "Jennea Cannon" and spot.mapID == 1453
    and spot.x == 0.38 and spot.zone == "Stormwind City")
suite.check("it says where", CT.Where(spot) == "Wizard's Sanctum in Stormwind City")
plan = CT:Plan()
suite.check("the trainer's own price wins", plan.guessed == 0)
suite.check("the quest spell leaves the list", #plan.ready == 3 and plan.cost == 600 and plan.unknown == 0,
    #plan.ready .. " " .. plan.cost)
suite.check("the next level is priced", plan.nextCost == 2200 and plan.nextUnknown == 0)
suite.check("this character is written down", data.characters["Player-1-AAA"]
    and #data.characters["Player-1-AAA"].ready == 3)

-- 5. The Jobs group leads with it.
local rows = Jobs:TrainingLines()
suite.check("a row for now and one for the next level", rows[1] and rows[1].type == "train"
    and rows[2] and rows[2].type == "trainnext")
local jobRows = Jobs:Lines()
suite.check("Jobs leads with the spells to train now only", jobRows[1] and jobRows[1].type == "train"
    and not (jobRows[2] and jobRows[2].type == "trainnext"))
local later = Jobs:LaterLines()
suite.check("the next level waits under Later", later[1] and later[1].type == "trainnext")

-- 4. Train all, with the purse short for the last.
fake.money = 350
CT:TrainAll()
suite.check("bought one at a time, cheapest level first, while the purse pays",
    table.concat(boughtIndex, ",") == "Frostbolt Rank 2,Frost Nova ", table.concat(boughtIndex, ","))
suite.check("and says so", env.ChatText():find("trained 2 spells", 1, true) ~= nil)
suite.check("the rest waits", #CT:Plan().ready == 1 and CT:Plan().ready[1].id == 4, #CT:Plan().ready .. " " .. tostring(CT:Plan().ready[1] and CT:Plan().ready[1].id))
fake.money = 100 * G
CT:TrainAll()
suite.check("the next click trains the last", known[4] == true and #CT:Plan().ready == 0)
env.Fire("TRAINER_CLOSED")
suite.check("closed, nothing more can be bought", #CT:Buyable() == 0)

-- 6. The gold fund. Another character with spells waiting.
level = 14
CT:Changed()
data.characters["Player-1-BBB"] = { name = "Bob Stone", class = "MAGE", level = 14, ready = { 8, 9 }, at = 1 }
local holdings = {
    { key = "Player-1-AAA", short = "Me Here", realm = "R", faction = "Alliance", isCurrent = true, gold = fake.money, goldAt = 1 },
    { key = "Player-1-BBB", short = "Bob Stone", realm = "R", faction = "Alliance", gold = 10 * G, goldAt = 1 },
}
_G.BlackthornesTS = { Butler = { Holdings = function() return holdings end, Mailbox = function() end } }
Funds:SetMinimum(10 * G)
local fund = Funds:For("Bob Stone")
suite.check("an alt's training is added to its amount", fund and fund.amount == 2200, fund and fund.amount)
suite.check("and the row says why", fund and Funds.Reason(fund):find("to train new spells", 1, true) ~= nil)
fake.money = 10 * G + 2200 + 2200 + Funds.POSTAGE
Funds:MoneyChanged()
fund = Funds:For("Bob Stone")
suite.check("the sender keeps back its own training first", fund and fund.amount == 2200, fund and fund.amount)
fake.money = 10 * G + 2200 + 1000
Funds:MoneyChanged()
fund = Funds:For("Bob Stone")
suite.check("so it gives only what is left", fund and fund.amount == 1000 - Funds.POSTAGE, fund and fund.amount)

rows = Jobs:TrainingLines()
local alt
for _, row in ipairs(rows) do if row.type == "trainalt" then alt = row end end
suite.check("the other character has its own line", alt and alt.other.name == "Bob Stone" and alt.other.count == 2)
local laterAlt
for _, row in ipairs(Jobs:LaterLines()) do if row.type == "trainalt" then laterAlt = row end end
suite.check("and it waits under Later", laterAlt ~= nil)
for _, row in ipairs(Jobs:Lines()) do
    suite.check("not in Jobs", row.type ~= "trainalt" and row.type ~= "trainnext")
end

-- 7. Turned off.
ns.HandleSlash("training off")
suite.check("off is saved", ns.db.classTraining == false)
suite.check("no rows", #Jobs:TrainingLines() == 0)
suite.check("no gold kept back", CT:ReadyCost() == 0)
ns.HandleSlash("training on")
suite.check("and on again", CT:IsOn())

-- The window draws the rows without error.
ns.UI:Show("bags")
suite.check("the window shows with training rows", ns.UI:IsShown())
ns.UI:Hide()

for name, value in pairs(saved) do _G[name] = value end
_G.BlackthornesTS = nil
_G.C_Map = nil

suite.done()
