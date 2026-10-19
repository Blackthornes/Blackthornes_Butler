-- Butler's rules for the player's Tradeskills lists (Logic/ListRules.lua,
-- the owner said build it, 2026-10-19).
--
-- What must hold:
--   1. With no rule set, an item on a list gets its usual verdict.
--   2. Mail To sends what is on the list to that character.
--   3. Keep Here keeps that many of each, and the rest is mailed; the
--      bigger keep wins against Butler's own.
--   4. Keep Here alone keeps that many and lets the rest go on.
--   5. On two lists, the higher one wins; a rename keeps the rule (by id).
--   6. Never mailed to the character playing, nor soulbound.
--   7. The rule can be turned off on the Order page.

local env = dofile(lfs_cwd .. "/tools/testenv.lua")
local suite = env.NewSuite("listrules")

local ns = env.Load()
env.FakeBags({
    { bag = 0, slot = 1, id = 2447, name = "Peacebloom", quality = 1, price = 5, count = 20 },
    { bag = 0, slot = 2, id = 2447, name = "Peacebloom", quality = 1, price = 5, count = 20 },
    { bag = 0, slot = 3, id = 785, name = "Mageroyal", quality = 1, price = 5, count = 14 },
})

local lists = {
    { name = "Cloth", id = 2, items = { [785] = 0 } },
    { name = "Herbs", id = 1, items = { [2447] = 40, [785] = 40 } },
}
local version = 1
_G.BlackthornesTS = { Butler = {
    Advise = function() return {} end,
    Lists = function() return lists, version end,
    Holdings = function()
        return {
            { key = "me", short = "Me Here", realm = "R", faction = "Horde", isCurrent = true },
            { key = "bob", short = "Bob Wither", realm = "R", faction = "Horde" },
        }
    end,
    Mailbox = function() end,
} }
env.Enable(ns)
local Verdicts, Rules, UI = ns.Verdicts, ns.ListRules, ns.UI

local function Rows(itemID)
    local out = {}
    for _, group in ipairs(Verdicts:Groups()) do
        for _, row in ipairs(group.rows) do
            if row.itemID == itemID then out[#out + 1] = row end
        end
    end
    return out
end

local function Count(rows, verdict)
    local n = 0
    for _, row in ipairs(rows) do
        if row.verdict == verdict then n = n + (row.count or 1) end
    end
    return n
end

UI:Show("bags")

-- 1. No rule.
Verdicts:Changed(true)
local rows = Rows(2447)
suite.check("no rule, no mail", Count(rows, "mail") == 0, rows[1] and rows[1].verdict)
suite.check("nothing saved yet", ns.db.listRules == nil or next(ns.db.listRules) == nil, ns.db.listRules)

-- 2. Mail To.
Rules:SetMailTo(1, "Bob Wither")
rows = Rows(2447)
suite.check("both stacks under Mail", Count(rows, "mail") == 40, Count(rows, "mail"))
suite.check("to the list's character", rows[1].mailTo == "Bob Wither", rows[1].mailTo)
suite.check("saying which list", rows[1].reason == "On your Herbs list", rows[1].reason)

-- 3. Keep Here with Mail To.
Rules:SetKeep(1, 20)
rows = Rows(2447)
suite.check("twenty kept", Count(rows, "keep") == 20, Count(rows, "keep"))
suite.check("twenty mailed", Count(rows, "mail") == 20, Count(rows, "mail"))
local mailRow
for _, row in ipairs(rows) do if row.verdict == "mail" then mailRow = row end end
suite.check("the mail says what stays", mailRow and mailRow.reason == "On your Herbs list, keeping 20",
    mailRow and mailRow.reason)
local keepRow
for _, row in ipairs(rows) do if row.verdict == "keep" then keepRow = row end end
suite.check("the keep names the list", keepRow and keepRow.reason == "Your Herbs list keeps 20 here",
    keepRow and keepRow.reason)

ns.KeepHere:Set(2447, 30)
Verdicts:Changed(true)
rows = Rows(2447)
suite.check("a bigger own keep wins", Count(rows, "keep") >= 30, Count(rows, "keep"))
suite.check("and says so in its own words", (Rows(2447)[1].reason or ""):find("on this character", 1, true) ~= nil
    or (Rows(2447)[2].reason or ""):find("on this character", 1, true) ~= nil)
ns.KeepHere:Set(2447, 0)

-- 4. Keep Here alone.
Rules:SetMailTo(1, nil)
Verdicts:Changed(true)
rows = Rows(2447)
suite.check("keep alone keeps twenty", Count(rows, "keep") == 20, Count(rows, "keep"))
suite.check("and mails nothing", Count(rows, "mail") == 0, Count(rows, "mail"))
Rules:SetKeep(1, 0)
suite.check("a list with no rules leaves no entry", ns.db.listRules[1] == nil, ns.db.listRules[1])

-- 5. Two lists: Mageroyal is on Cloth (higher) and Herbs.
Rules:SetMailTo(1, "Bob Wither")
rows = Rows(785)
suite.check("Cloth has no rule, so Herbs mails it", rows[1].verdict == "mail" and rows[1].reason == "On your Herbs list",
    rows[1].reason)
Rules:SetKeep(2, 14)
rows = Rows(785)
suite.check("Cloth, higher up, wins once it has a rule", rows[1].verdict == "keep", rows[1].verdict)
lists[1].name, version = "Fabric", 2
Verdicts:Changed(true)
rows = Rows(785)
suite.check("a rename keeps it", rows[1].reason == "Your Fabric list keeps 14 here", rows[1].reason)
Rules:SetKeep(2, 0)

-- 6. Never to the character playing, never soulbound.
Rules:SetMailTo(1, "Me Here")
rows = Rows(2447)
suite.check("not mailed to the one playing", Count(rows, "mail") == 0, Count(rows, "mail"))
Rules:SetMailTo(1, "Bob Wither")
ns.Bags.slots["0:1"] = ns.Bags.slots["0:1"]
for _, entry in pairs(ns.Bags.slots) do
    if entry.itemID == 2447 and entry.slot == 1 then entry.bound = true end
end
Verdicts:Changed(true)
rows = Rows(2447)
suite.check("soulbound stays", Count(rows, "mail") == 20, Count(rows, "mail"))
for _, entry in pairs(ns.Bags.slots) do entry.bound = nil end

-- 7. Turned off.
Verdicts:SetRuleOn("lists", false)
rows = Rows(2447)
suite.check("turned off, no mail", Count(rows, "mail") == 0, Count(rows, "mail"))
Verdicts:SetRuleOn("lists", true)
suite.check("it's on the Order page", ns.RuleOrderUI.RULES.lists ~= nil)

-- The Lists page.
ns.SettingsUI:Show()
local controls = ns.SettingsUI.controls
suite.check("the page lists the lists", controls.listsPick:GetName() == "Fabric", controls.listsPick:GetName())
suite.check("Mail To never offers the one playing", (function()
    for _, name in ipairs(controls.listsMailTo.names) do if name == "Me Here" then return false end end
    return true
end)())

suite.done()
