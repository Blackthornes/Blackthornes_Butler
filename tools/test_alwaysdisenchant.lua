-- Greens go to auction when they sell for more, unless the player says to
-- break them (the owner, 2026-10-17: "Butler should recommend auctioning a
-- green that sells on the AH for more than its DE value, unless that item
-- can be DE'd for a skill up in Enchanting. The player can make the
-- decision to change it to always DE").
--
-- What must hold:
--   1. A green that sells for more than it breaks into goes to Auction.
--   2. On the Always disenchant list it goes under Disenchant, and back
--      to Auction when taken off.
--   3. When this character can't break it, it goes to the enchanter
--      Tradeskills names; with nobody, Look at it.
--   4. An upgrade to wear now is never broken.
--   5. Saved account wide as alwaysDisenchant, and the rule is on the
--      Order page's list.

local env = dofile(lfs_cwd .. "/tools/testenv.lua")
local suite = env.NewSuite("alwaysdisenchant")

local ns = env.Load()
env.FakeBags({
    { bag = 0, slot = 1, id = 801, name = "Ridge Cleaver", quality = 2, price = 400 },
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

local can, enchanter, upgrade = true, nil, false
_G.BlackthornesTS = { Butler = {
    Advise = function()
        return { auction = 50000, disenchant = 900, canDisenchant = can, enchanter = enchanter }
    end,
} }
_G.BlackthornesEquipment = { Butler = { Advise = function()
    if upgrade then return { upgrade = "now", gain = 5 } end
end } }

-- 1. Sells for more: Auction.
ns.UI:Show()
Verdicts:Changed(true)
suite.check("sells for more: auction", Find("Ridge Cleaver").verdict == "auction", Find("Ridge Cleaver").verdict)

-- 2. The player's pick wins.
Verdicts:SetChoice(801, "disenchant")
local row = Find("Ridge Cleaver")
suite.check("on the list: disenchant", row.verdict == "disenchant", row.verdict)
suite.check("saying why", row.reason == "On your Always disenchant list", row.reason)
suite.check("the choice reads back", Verdicts:Choice(801) == "disenchant")
suite.check("saved account wide", ns.db.alwaysDisenchant[801] == true)

-- 3. Can't break it here.
can, enchanter = false, "Dusty Anvil"
Verdicts:Changed(true)
row = Find("Ridge Cleaver")
suite.check("mailed to the enchanter", row.verdict == "mail" and row.mailTo == "Dusty Anvil", row.verdict)
enchanter = nil
Verdicts:Changed(true)
suite.check("nobody can: look at it", Find("Ridge Cleaver").verdict == "look", Find("Ridge Cleaver").verdict)
can = true

-- 4. An upgrade is kept whole.
upgrade = true
Verdicts:Changed(true)
suite.check("an upgrade is not broken", Find("Ridge Cleaver").verdict ~= "disenchant", Find("Ridge Cleaver").verdict)
upgrade = false

-- Taken off: back to auction.
Verdicts:SetChoice(801, nil)
suite.check("off the list: auction again", Find("Ridge Cleaver").verdict == "auction", Find("Ridge Cleaver").verdict)
suite.check("off the list in the save", ns.db.alwaysDisenchant[801] == nil)

-- 5. On the Order page.
local listed = false
for _, id in ipairs(Verdicts:Order()) do
    if id == "disenchantList" then listed = true end
end
suite.check("the rule is in the order", listed)
suite.check("the Order page names it", ns.RuleOrderUI == nil or ns.RuleOrderUI.RULES.disenchantList ~= nil)

suite.done()
