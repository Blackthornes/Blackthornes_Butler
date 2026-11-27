-- Send Level Up Materials to Alts and Mail Recipes to Who Can Learn Them
-- (a player asked, the owner said build it, 2026-11-27).
--
-- What must hold:
--   1. Both off unless ticked: nothing changes.
--   2. Ticked, what an alt's road still needs goes under Mail to it, with
--      the reason, and Fill Mail sends only that many.
--   3. A stack past what it needs goes on down the rules, so it sells.
--   4. The player's Always sell list, this character's own Keep Level Up
--      Materials and its queue come first.
--   5. Never to the character playing, never a bound stack.
--   6. Tradeskills is asked once per look; one without the call, or one
--      that raises, mails nothing.
--   7. A recipe goes to who can learn it, with the skill when it must
--      train first; a second copy goes on down the rules.

local env = dofile(lfs_cwd .. "/tools/testenv.lua")
local suite = env.NewSuite("altlevelup")

local ns = env.Load()
local SILK, WOOL, BOUND, PATTERN = 4306, 2592, 2589, 6272
env.FakeBags({
    { bag = 0, slot = 1, id = SILK, name = "Silk Cloth", quality = 1, price = 50, count = 20 },
    { bag = 0, slot = 2, id = SILK, name = "Silk Cloth", quality = 1, price = 50, count = 20 },
    { bag = 0, slot = 3, id = WOOL, name = "Wool Cloth", quality = 1, price = 20, count = 40 },
    { bag = 0, slot = 4, id = BOUND, name = "Linen Cloth", quality = 1, price = 10, count = 5, bound = true },
    { bag = 0, slot = 5, id = PATTERN, name = "Pattern: Green Woolen Bag", quality = 1, price = 300, count = 1 },
    { bag = 0, slot = 6, id = PATTERN, name = "Pattern: Green Woolen Bag", quality = 1, price = 300, count = 1 },
})

local asked = 0
local needs = {
    [SILK] = { to = "Bob Stone", count = 20, profession = "Tailoring" },
    [WOOL] = { to = "Bob Stone", count = 40, profession = "Tailoring" },
    [BOUND] = { to = "Bob Stone", count = 5, profession = "Tailoring" },
}
local recipe = { to = "Bob Stone", profession = "Tailoring", skill = 115, now = true }
local advice, mats = {}, {}
local tsButler = {
    Advise = function(_, id) return advice[id] or { auction = 0 } end,
    Holdings = function()
        return {
            { key = "me", short = "Me Here", realm = "R", faction = "Horde", isCurrent = true },
            { key = "bob", short = "Bob Stone", realm = "R", faction = "Horde" },
        }
    end,
    Mailbox = function() end,
    LevelUpMaterials = function() return mats end,
    AltLevelUp = function()
        asked = asked + 1
        local copy = {}
        for id, need in pairs(needs) do copy[id] = { to = need.to, count = need.count, profession = need.profession } end
        return copy
    end,
    RecipeFor = function(_, id) if id == PATTERN then return recipe end end,
}
_G.BlackthornesTS = { Butler = tsButler }
env.Enable(ns)
local Verdicts = ns.Verdicts
ns.UI:Show("bags")

local function Rows(id)
    local rows = {}
    for _, group in ipairs(Verdicts:Groups()) do
        for _, row in ipairs(group.rows or {}) do
            if row.itemID == id then rows[#rows + 1] = row end
        end
    end
    return rows
end
local function MailRow(id)
    for _, row in ipairs(Rows(id)) do
        if row.verdict == "mail" then return row end
    end
end
local function Sent(to, id)
    for _, recipient in ipairs(ns.Errands:Recipients()) do
        if recipient.to == to then
            for _, item in ipairs(recipient.items) do
                if item.itemID == id then return item.count end
            end
        end
    end
    return 0
end

-- 1.
Verdicts:Changed(true)
suite.check("both off by default", ns.db.altLevelUp == false and ns.db.altRecipes == false
    and not Verdicts:AltLevelUpOn() and not Verdicts:AltRecipesOn())
suite.check("off, no silk goes in the mail", MailRow(SILK) == nil)
suite.check("off, no recipe goes in the mail", MailRow(PATTERN) == nil)
suite.check("off, Tradeskills is not asked", asked == 0, tostring(asked))

-- 2.
Verdicts:SetAltLevelUp(true)
local row = MailRow(SILK)
suite.check("ticked, silk goes to Bob", row ~= nil and row.mailTo == "Bob Stone", row and tostring(row.mailTo))
suite.check("with the reason", row and row.reason == "Used to level Bob Stone's Tailoring. Needs 20 more.",
    row and tostring(row.reason))
suite.check("Fill Mail sends 20 silk", Sent("Bob Stone", SILK) == 20, tostring(Sent("Bob Stone", SILK)))
suite.check("one stack of wool, all of it", Sent("Bob Stone", WOOL) == 40, tostring(Sent("Bob Stone", WOOL)))

-- 3.
local other
for _, r in ipairs(Rows(SILK)) do if r.verdict ~= "mail" then other = r end end
suite.check("the other silk stack goes on down the rules", other ~= nil and other.count == 20,
    other and (other.verdict .. " " .. tostring(other.count)) or "none")

-- 6.
suite.check("Tradeskills asked once for the whole look", asked == 1, tostring(asked))

-- 5.
suite.check("a bound stack never goes", MailRow(BOUND) == nil)
needs[WOOL].to = "Me Here"
Verdicts:Changed(true)
suite.check("never to the character playing", MailRow(WOOL) == nil)
needs[WOOL].to = "Bob Stone"

-- 4.
ns.Verdicts:MarkList("alwaysSell")[WOOL] = true
Verdicts:Changed(true)
local wool = Rows(WOOL)[1]
suite.check("the Always sell list still wins", wool and wool.verdict == "sell", wool and wool.verdict)
ns.Verdicts:MarkList("alwaysSell")[WOOL] = nil
mats[WOOL] = "Tailoring"
Verdicts:SetKeepLevelUp(true)
wool = Rows(WOOL)[1]
suite.check("this character's own leveling comes first", wool and wool.verdict == "keep", wool and wool.verdict)
Verdicts:SetKeepLevelUp(false)
mats[WOOL] = nil
advice[WOOL] = { auction = 0, need = 40 }
Verdicts:Changed(true)
wool = Rows(WOOL)[1]
suite.check("this character's queue comes first", wool and wool.verdict == "keep", wool and wool.verdict)
advice[WOOL] = nil

-- 6.
tsButler.AltLevelUp = function() error("boom") end
Verdicts:Changed(true)
suite.check("a Tradeskills that raises mails nothing", MailRow(SILK) == nil)
tsButler.AltLevelUp = nil
Verdicts:Changed(true)
suite.check("an older Tradeskills mails nothing", MailRow(SILK) == nil)

-- 7.
Verdicts:SetAltRecipes(true)
row = MailRow(PATTERN)
suite.check("ticked, the pattern goes to Bob", row ~= nil and row.mailTo == "Bob Stone")
suite.check("who can learn it now", row and row.reason == "Bob Stone can learn this", row and tostring(row.reason))
suite.check("only one copy goes", Sent("Bob Stone", PATTERN) == 1, tostring(Sent("Bob Stone", PATTERN)))
local spare
for _, r in ipairs(Rows(PATTERN)) do if r.verdict ~= "mail" then spare = r end end
suite.check("the second copy goes on down the rules", spare ~= nil)
recipe.now = false
Verdicts:Changed(true)
row = MailRow(PATTERN)
suite.check("one who must train first is named with the skill",
    row and row.reason == "Bob Stone can learn this at Tailoring 115", row and tostring(row.reason))
tsButler.RecipeFor = function() return nil end
Verdicts:Changed(true)
suite.check("nobody can learn it: no mail", MailRow(PATTERN) == nil)

suite.done()
