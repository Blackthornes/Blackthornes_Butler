-- Disenchant greens here (the owner asked 2026-10-14: "auto recommending DE
-- of greens on the character set as the disenchanter. This would disregard
-- the value of greens. Again an option they must turn on").
--
-- What must hold:
--   1. Off until ticked: greens keep their usual verdict.
--   2. Ticked, on the disenchanter: a green it can break goes under
--      Disenchant when breaking it pays as much as selling, and even when
--      selling pays more once "Always Disenchant" is ticked.
--   3. Not on another character, not for a blue, not when it can't break
--      it, never a crafted green.
--   4. Keeping still wins: an upgrade, a goal, the Always sell list.
--   5. The tick box and /bbutler greens change the same saved value.

local env = dofile(lfs_cwd .. "/tools/testenv.lua")
local suite = env.NewSuite("disenchantgreens")

local ns = env.Load()
env.FakeBags({
    { bag = 0, slot = 1, id = 801, name = "Ridge Cleaver", quality = 2, price = 400 },
    { bag = 0, slot = 2, id = 802, name = "Forest Leather Belt", quality = 2, price = 300 },
    { bag = 0, slot = 3, id = 803, name = "Embossed Leather Gloves", quality = 2, price = 200 },
    { bag = 0, slot = 4, id = 804, name = "Silver Defias Belt", quality = 3, price = 900 },
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
local function Verdict(name) return Find(name).verdict end

local here, can, upgrade, goal = true, true, false, false
_G.BlackthornesTS = { Butler = {
    Advise = function(_, id)
        return { auction = 50000, disenchant = 900, canDisenchant = can,
            youDisenchant = here or nil, crafted = (here and id == 803) or nil }
    end,
} }
_G.BlackthornesEquipment = { Butler = { Advise = function(_, link)
    local id = tonumber(tostring(link):match("item:(%d+)"))
    if id == 801 and upgrade then return { upgrade = "now", gain = 5 } end
end } }
_G.BlackthornesFarmer = { Butler = { Advise = function(_, id)
    if id == 802 and goal then return { goal = "Forest Leather Belt", have = 1, target = 5, need = 4 } end
end } }

ns.UI:Show()

-- 1. Off by default.
suite.check("off unless ticked", ns.db.disenchantGreens == false and not Verdicts:DisenchantGreensOn())
Verdicts:Changed(true)
suite.check("off: a green goes to auction as before", Verdict("Ridge Cleaver") == "auction", Verdict("Ridge Cleaver"))

-- 2. Ticked, on the disenchanter.
ns.HandleSlash("greens on")
suite.check("/bbutler greens on ticks it", ns.db.disenchantGreens == true)
suite.check("a green that sells for more still goes to auction", Verdict("Ridge Cleaver") == "auction",
    Verdict("Ridge Cleaver"))
Verdicts:SetAlwaysDisenchant(true)
local cleaver = Find("Ridge Cleaver")
suite.check("a green goes under Disenchant, auction or not", cleaver.verdict == "disenchant", cleaver.verdict)
suite.check("saying why", cleaver.reason:find("You disenchant greens on this character", 1, true) ~= nil, cleaver.reason)
suite.check("and every green", Verdict("Forest Leather Belt") == "disenchant", Verdict("Forest Leather Belt"))

-- 3. Where it does not apply.
suite.check("never a crafted green", Verdict("Embossed Leather Gloves") == "auction", Verdict("Embossed Leather Gloves"))
suite.check("never a blue", Verdict("Silver Defias Belt") == "auction", Verdict("Silver Defias Belt"))
here = false
Verdicts:Changed(true)
suite.check("another character: as before", Verdict("Ridge Cleaver") == "auction", Verdict("Ridge Cleaver"))
here, can = true, false
Verdicts:Changed(true)
suite.check("can't break it: not Disenchant here", Verdict("Ridge Cleaver") ~= "disenchant", Verdict("Ridge Cleaver"))
can = true

-- 4. Keeping wins.
upgrade, goal = true, true
Verdicts:Changed(true)
suite.check("an upgrade is kept", Verdict("Ridge Cleaver") == "keep", Verdict("Ridge Cleaver"))
suite.check("a goal's item is kept", Verdict("Forest Leather Belt") == "keep", Verdict("Forest Leather Belt"))
upgrade, goal = false, false
Verdicts:SetChoice(802, "sell")
suite.check("the Always sell list wins", Verdict("Forest Leather Belt") == "sell", Verdict("Forest Leather Belt"))
Verdicts:SetChoice(802, nil)

Verdicts:SetAlwaysDisenchant(false)

-- 5. Settings and the command agree.
ns.SettingsUI:Show()
local box = ns.SettingsUI.controls.disenchantGreens
suite.check("the box shows it ticked", box:GetChecked())
box:GetScript("OnClick")(box)
suite.check("unticking turns it off", ns.db.disenchantGreens == false)
suite.check("and greens go back to their worth", Verdict("Ridge Cleaver") == "auction", Verdict("Ridge Cleaver"))
ns.HandleSlash("greens")
suite.check("/bbutler greens alone turns it on", ns.db.disenchantGreens == true and box:GetChecked())
ns.HandleSlash("greens off")
suite.check("/bbutler greens off turns it off", ns.db.disenchantGreens == false)

suite.done()
