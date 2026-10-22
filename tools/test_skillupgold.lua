-- The cheapest skill-up when the gold on hand won't buy what's missing
-- (a player asked, the owner approved the words 2026-10-22).
--
-- What must hold:
--   1. With enough gold, or no toBuy from Tradeskills, the line reads as before.
--   2. Short of gold, the line's second part is the red note:
--      "You need about X to buy what's missing. You have Y."
--   3. The hover keeps the usual words and adds the note.
--   4. A capped profession never gets the note.

local env = dofile(lfs_cwd .. "/tools/testenv.lua")

local function Plain(text)
    return (tostring(text or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end
local suite = env.NewSuite("skillupgold")

local ns = env.Load()
local SkillUp, UI = ns.SkillUp, ns.UI

env.FakeBags({})
_G.C_Item.GetItemNameByID = function(id) return id == 1251 and "Linen Bandage" or nil end

local answer = {
    { profession = "First Aid", skill = 52, max = 75, recipeID = 3275, itemID = 1251, name = "Linen Bandage",
        tier = "optimal", cost = 18, toBuy = 4700 },
}
_G.BlackthornesTS = { Butler = {
    NextSkillUp = function()
        local copy = {}
        for i, entry in ipairs(answer) do
            local e = {}
            for k, v in pairs(entry) do e[k] = v end
            copy[i] = e
        end
        return copy
    end,
    QueueSkillUp = function() return true end,
} }

local purse = 10000
_G.GetMoney = function() return purse end

env.Enable(ns)
UI:Show("bags")
ns.db.skillUpLine = true

local function SkillRow()
    for _, row in ipairs(UI:Lines()) do
        if row.type == "skillup" then return row end
    end
end

local row = CreateFrame("Button")
UI.CreateRow(row)

-- 1. Enough gold.
local line = SkillRow()
suite.check("the line keeps what Tradeskills says it costs to buy", line and line.entry.toBuy == 4700)
UI.UpdateRow(row, line)
suite.check("enough gold: the usual words", Plain(row.reason:GetText()) == "First Aid 52/75. A sure point for about 18c.",
    row.reason:GetText())
suite.check("no note with enough gold", SkillUp.ShortNote(line.entry) == nil)

-- 2. Short of gold.
purse = 3000
UI.UpdateRow(row, SkillRow())
suite.check("short: the note in its place",
    Plain(row.reason:GetText()) == "You need about 47s 00c to buy what's missing. You have 30s 00c.", row.reason:GetText())
suite.check("in red", tostring(row.reason:GetText()):find("|c" .. ns.COLORS.bad, 1, true) == 1)

-- 3. The hover.
local added = {}
local addLine = GameTooltip.AddLine
GameTooltip.AddLine = function(self, text, ...) added[#added + 1] = Plain(text) return addLine(self, text, ...) end
do
    UI:Enter(row, SkillRow())
    local text = table.concat(added, "\n")
    suite.check("hover keeps the usual words", text:find("A sure point for about 18c.", 1, true) ~= nil, text)
    suite.check("hover has the note", text:find("You need about 47s 00c", 1, true) ~= nil, text)
end
GameTooltip.AddLine = addLine

-- 1b. No toBuy (an older Tradeskills).
answer[1].toBuy = nil
UI.UpdateRow(row, SkillRow())
suite.check("older Tradeskills: the usual words", Plain(row.reason:GetText()) == "First Aid 52/75. A sure point for about 18c.",
    row.reason:GetText())

-- 4. Capped.
suite.check("capped never gets the note", SkillUp.ShortNote({ capped = true, toBuy = 99999 }, 1) == nil)

suite.done()
