-- Levelling Enchanting with your own greens (the owner asked 2026-10-13:
-- "If a non-crafted green can DE into materials needed to guarantee an
-- increase in your enchanting skill Butler should recommend disenchanting
-- it").
--
-- What must hold:
--   1. A green Tradeskills names `forEnchanting` for goes under Disenchant,
--      even when the auction house pays more, saying which craft needs it.
--   2. Only as many as cover what Enchanting lacks; the rest get their
--      usual verdict.
--   3. Keeping and the Always sell list still win.
--   4. Not when this character can't break it, and never for a blue.

local env = dofile(lfs_cwd .. "/tools/testenv.lua")
local suite = env.NewSuite("levelenchanting")

local ns = env.Load()
env.FakeBags({
    { bag = 0, slot = 1, id = 701, name = "Ridge Cleaver", quality = 2, price = 400 },
    { bag = 0, slot = 2, id = 702, name = "Forest Leather Belt", quality = 2, price = 300 },
    { bag = 0, slot = 3, id = 703, name = "Brackwater Boots", quality = 2, price = 200 },
    { bag = 0, slot = 4, id = 704, name = "Silver Defias Belt", quality = 3, price = 900 },
})
env.Enable(ns)

local Verdicts = ns.Verdicts

local function Find(name)
    for _, group in ipairs(Verdicts:Groups()) do
        for _, row in ipairs(group.rows) do
            if row.name == name then return row end
        end
    end
end

local can, short, upgrade = true, 2, false
local wanted = { recipe = "Enchant Bracer - Minor Health", material = 10940,
    materialName = "Strange Dust", yield = 1.125 }
_G.BlackthornesTS = { Butler = {
    Advise = function(_, id)
        local answer = { auction = 50000, disenchant = 900, canDisenchant = can }
        if id ~= 704 then
            answer.forEnchanting = { recipe = wanted.recipe, material = wanted.material,
                materialName = wanted.materialName, yield = wanted.yield, short = short }
        end
        return answer
    end,
} }
_G.BlackthornesEquipment = { Butler = { Advise = function(_, link)
    local id = tonumber(tostring(link):match("item:(%d+)"))
    if id == 701 and upgrade then return { upgrade = "now", gain = 5 } end
end } }

local function Verdict(name) return Find(name).verdict end

-- 1 and 2. Two greens give about 2.25 dust, enough for the 2 short.
ns.UI:Show()
Verdicts:Changed(true)
local cleaver = Find("Ridge Cleaver")
suite.check("a green for a sure point goes under Disenchant", cleaver.verdict == "disenchant", cleaver.verdict)
suite.check("saying which craft needs what",
    cleaver.reason:find("To level Enchanting: Enchant Bracer - Minor Health needs Strange Dust", 1, true) ~= nil,
    cleaver.reason)
suite.check("the second green too", Verdict("Forest Leather Belt") == "disenchant", Verdict("Forest Leather Belt"))
suite.check("enough covered: the third goes to auction", Verdict("Brackwater Boots") == "auction",
    Verdict("Brackwater Boots"))
suite.check("a blue is left alone", Verdict("Silver Defias Belt") == "auction", Verdict("Silver Defias Belt"))
suite.check("the slot's verdict agrees with the row",
    Verdicts:VerdictOf(ns.Bags.slots["0:3"] or Find("Brackwater Boots").slots[1]) == "auction")

short = 10
Verdicts:Changed(true)
suite.check("more short: all three", Verdict("Brackwater Boots") == "disenchant", Verdict("Brackwater Boots"))

-- 3. Keeping and the Always sell list still win.
upgrade = true
Verdicts:Changed(true)
suite.check("an upgrade here is kept", Verdict("Ridge Cleaver") == "keep", Verdict("Ridge Cleaver"))
upgrade = false
Verdicts:SetChoice(702, "sell")
suite.check("the Always sell list wins", Verdict("Forest Leather Belt") == "sell", Verdict("Forest Leather Belt"))
Verdicts:SetChoice(702, nil)

-- 4. Not when this character can't break it.
can = false
Verdicts:Changed(true)
suite.check("can't disenchant: its usual verdict", Verdict("Ridge Cleaver") ~= "disenchant", Verdict("Ridge Cleaver"))
can = true
short = 0
Verdicts:Changed(true)
suite.check("nothing short: its usual verdict", Verdict("Ridge Cleaver") == "auction", Verdict("Ridge Cleaver"))

suite.done()
