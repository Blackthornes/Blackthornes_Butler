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
--   5. A capped profession names the trainer's next rank, or the level it
--      opens at; none past the last rank, nor for Cooking past Journeyman.
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
    for _, row in ipairs(UI:Lines()) do
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
local inJobs = false
for _, line in ipairs(Jobs:Lines()) do inJobs = inJobs or line.type == "skillup" end
suite.check("not in Jobs anymore", not inJobs)
local lines, heading, firstSkill = UI:Lines(), nil, nil
for index, line in ipairs(lines) do
    if line.type == "header" and line.group.verdict == "leveling" then heading = heading or index end
    if line.type == "skillup" then firstSkill = firstSkill or index end
end
suite.check("its own Profession Leveling group", heading ~= nil and lines[heading].group.label == "Profession Leveling")
suite.check("the lines sit under it", heading and firstSkill == heading + 1)
suite.check("it counts professions", lines[heading].group.count == 2 and lines[heading].group.many == "professions")
UI.Folded(UI).leveling = true
suite.check("it folds on its own", #SkillRows() == 0)
UI.Folded(UI).leveling = nil

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

-- 5. Capped professions: the trainer's next rank.
_G.UnitLevel = function() return 30 end
answer[#answer + 1] = { profession = "Enchanting", english = "Enchanting", skill = 150, max = 150, capped = true }
answer[#answer + 1] = { profession = "Blacksmithing", english = "Blacksmithing", skill = 225, max = 225, capped = true }
answer[#answer + 1] = { profession = "Mining", english = "Mining", skill = 75, max = 75, capped = true }
answer[#answer + 1] = { profession = "Cooking", english = "Cooking", skill = 150, max = 150, capped = true }
answer[#answer + 1] = { profession = "Alchemy", english = "Alchemy", skill = 300, max = 300, capped = true }
local trains = {}
for _, r in ipairs(SkillRows()) do
    if r.entry.capped then trains[r.entry.profession] = r end
end
suite.check("Cooking past Journeyman has no line", trains.Cooking == nil)
suite.check("the top rank has no line", trains.Alchemy == nil)
UI.UpdateRow(row, trains.Enchanting)
suite.check("names the next rank", Plain(row.name:GetText()) == "Train Expert Enchanting", row.name:GetText())
suite.check("visit an Enchanting trainer",
    Plain(row.reason:GetText()) == "Enchanting 150/150. Visit an Enchanting trainer to raise your cap to 225, about 50s 00c.",
    row.reason:GetText())
suite.check("no Queue button", not row.action:IsShown())
UI.UpdateRow(row, trains.Mining)
suite.check("visit a Mining trainer",
    Plain(row.reason:GetText()) == "Mining 75/75. Visit a Mining trainer to raise your cap to 150, about 5s 00c.",
    row.reason:GetText())
UI.UpdateRow(row, trains.Blacksmithing)
suite.check("Artisan waits for its level", Plain(row.name:GetText()) == "Train Artisan Blacksmithing", row.name:GetText())
suite.check("and says which",
    Plain(row.reason:GetText()) == "Blacksmithing 225/225. You can train it at level 35 to raise your cap to 300.",
    row.reason:GetText())
local count = 0
for _ in pairs(queued) do count = count + 1 end
UI.RowAction(trains.Enchanting)
local now = 0
for _ in pairs(queued) do now = now + 1 end
suite.check("a capped line queues nothing", count == now)
for _ = 1, 5 do table.remove(answer) end
_G.UnitLevel = nil

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
