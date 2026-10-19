-- The cheapest skill-up in Jobs (a player asked, the owner said build it
-- 2026-10-19, off unless ticked).
--
-- What must hold:
--   1. Off by default: no lines, even with Tradeskills answering.
--   2. Ticked, a line a profession at the end of Jobs, with the words the
--      owner approved: a sure or a likely point, what it costs, or what
--      it makes back.
--   3. Queue puts one in Tradeskills' queue and the line reads Queued;
--      Queued does nothing more.
--   4. Without Tradeskills, or when it raises or answers junk, no lines.

local env = dofile(lfs_cwd .. "/tools/testenv.lua")

-- Item names come in their rarity colour; the checks read the words.
local function Plain(text)
    return (tostring(text or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end
local suite = env.NewSuite("skillup")

local ns = env.Load()
local SkillUp, Jobs, UI = ns.SkillUp, ns.Jobs, ns.UI

env.FakeBags({})
local names = { [1251] = "Linen Bandage", [4343] = "Brown Linen Pants" }
_G.C_Item.GetItemNameByID = function(id) return names[id] end

local answer = {
    { profession = "First Aid", skill = 52, max = 75, recipeID = 3275, itemID = 1251, name = "Linen Bandage",
        tier = "optimal", cost = 18 },
    { profession = "Tailoring", skill = 61, max = 75, recipeID = 3914, itemID = 4343, name = "Brown Linen Pants",
        tier = "medium", cost = -35 },
}
local queued = {}
_G.BlackthornesTS = { Butler = {
    NextSkillUp = function()
        local copy = {}
        for i, entry in ipairs(answer) do
            local e = {}
            for k, v in pairs(entry) do e[k] = v end
            e.queued = queued[entry.recipeID] == true
            copy[i] = e
        end
        return copy
    end,
    QueueSkillUp = function(_, recipeID)
        queued[recipeID] = true
        return true
    end,
} }

env.Enable(ns)
UI:Show("bags")

local function SkillRows()
    local rows = {}
    for _, row in ipairs(Jobs:Lines()) do
        if row.type == "skillup" then rows[#rows + 1] = row end
    end
    return rows
end

-- 1. Off by default.
suite.check("off unless ticked", ns.db.skillUpLine == false)
suite.check("no lines while off", #SkillRows() == 0)

-- 2. The lines.
env.chat = {}
ns.HandleSlash("skillup on")
suite.check("/bbutler skillup on ticks it", ns.db.skillUpLine == true)
suite.check("and says so", env.ChatText():find("Butler will show your cheapest skill-up in Jobs.", 1, true) ~= nil,
    env.ChatText())
local rows = SkillRows()
suite.check("one line a profession", #rows == 2, #rows)
local lines = Jobs:Lines()
suite.check("at the end of Jobs", lines[#lines].type == "skillup")

local row = CreateFrame("Button")
UI.CreateRow(row)
UI.UpdateRow(row, rows[1])
suite.check("the title names the item", Plain(row.name:GetText()) == "Next skill point: Linen Bandage",
    row.name:GetText())
suite.check("a sure point and its cost", Plain(row.reason:GetText()) == "First Aid 52/75. A sure point for about 18c.",
    row.reason:GetText())
suite.check("with a Queue button", row.action:IsShown() and row.action.label:GetText() == "Queue")
UI.UpdateRow(row, rows[2])
suite.check("a likely point that pays back",
    Plain(row.reason:GetText()) == "Tailoring 61/75. A likely point, and you make about 35c back.", row.reason:GetText())

answer[2].tier = "optimal"
suite.check("a sure point that pays back",
    Plain(select(2, SkillUp.Text(SkillRows()[2].entry))) == "Tailoring 61/75. A sure point, and you make about 35c back.")
answer[1].tier = "medium"
suite.check("a likely point and its cost",
    Plain(select(2, SkillUp.Text(SkillRows()[1].entry))) == "First Aid 52/75. A likely point for about 18c.")
answer[1].tier = "optimal"

-- 3. Queue.
rows = SkillRows()
UI.RowAction(rows[1])
suite.check("Queue puts it in the queue", queued[3275] == true)
UI.UpdateRow(row, SkillRows()[1])
suite.check("and the line reads Queued", row.action.label:GetText() == "Queued")
local before = 0
for _ in pairs(queued) do before = before + 1 end
UI.RowAction(SkillRows()[1])
local after = 0
for _ in pairs(queued) do after = after + 1 end
suite.check("Queued does nothing more", before == after)

-- 4. No Tradeskills, or a bad answer.
answer[#answer + 1] = { profession = "Cooking", skill = 75, max = 75, recipeID = 1, cost = 5, tier = "optimal" }
answer[#answer + 1] = { profession = "Mining", skill = 10, max = 75, recipeID = "x", cost = 5 }
suite.check("a maxed profession or junk is left out", #SkillRows() == 2)
_G.BlackthornesTS.Butler.NextSkillUp = function() error("boom") end
suite.check("Tradeskills raising shows nothing", #SkillRows() == 0)
_G.BlackthornesTS = nil
suite.check("no Tradeskills shows nothing", #SkillRows() == 0)

env.chat = {}
ns.HandleSlash("skillup off")
suite.check("/bbutler skillup off unticks it", ns.db.skillUpLine == false)
suite.check("and says so", env.ChatText():find("Butler won't show your cheapest skill-up anymore.", 1, true) ~= nil,
    env.ChatText())
suite.done()
