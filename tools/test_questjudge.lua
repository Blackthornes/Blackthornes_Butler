-- A quest item looted judges only that item again (the owner's report,
-- 2026-11-25: a hitch each time he opened a Soft-shelled Clam for Clam
-- Bait with Butler Bags open).
--
-- What must hold:
--   1. When what a quest wants moves (one more Clam Meat), the other bag
--      items keep their verdicts and marks: the four sisters are not asked
--      about them again.
--   2. The item the quest wants is judged again and reads the new count.
--   3. An item a quest stops wanting is judged again too.

local env = dofile(lfs_cwd .. "/tools/testenv.lua")
local suite = env.NewSuite("questjudge")

local ns = env.Load()
local Verdicts, BagView = ns.Verdicts, ns.BagView

local items = {
    { bag = 0, slot = 1, id = 5503, name = "Clam Meat", quality = 1, price = 1, count = 3 },
    { bag = 0, slot = 2, id = 730, name = "Murloc Eye", quality = 1, price = 16, count = 2 },
}
for i = 1, 60 do
    items[#items + 1] = { bag = 0, slot = 2 + i, id = 60000 + i, name = "Thing " .. i, quality = 1, price = 10 }
end
env.FakeBags(items).numSlots = 64
local names = { [5503] = "Clam Meat", [730] = "Murloc Eye" }
for i = 1, 60 do names[60000 + i] = "Thing " .. i end
_G.C_Item.GetItemNameByID = function(id) return names[id] end

local log = {
    { title = "Clam Bait", questID = 900101, objectives = {
        { type = "item", text = "Clam Meat: 3/10", numFulfilled = 3, numRequired = 10, finished = false },
    } },
    { title = "Eyes", questID = 900102, objectives = {
        { type = "item", text = "Murloc Eye: 2/5", numFulfilled = 2, numRequired = 5, finished = false },
    } },
}
_G.C_QuestLog = {
    GetNumQuestLogEntries = function() return #log end,
    GetInfo = function(index)
        local quest = log[index]
        return quest and { title = quest.title, questID = quest.questID, isHeader = false }
    end,
    GetQuestObjectives = function(questID)
        for _, quest in ipairs(log) do
            if quest.questID == questID then return quest.objectives end
        end
    end,
}

-- The four sisters count what they are asked about.
local asked = {}
local function Count(key, id)
    id = tonumber(tostring(id):match("item:(%d+)")) or id
    asked[key] = (asked[key] or 0) + 1
    asked.items = asked.items or {}
    asked.items[id] = true
end
_G.BlackthornesEquipment = { Butler = { Advise = function(_, link) Count("equipment", link) end } }
_G.BlackthornesFarmer = { Butler = { Advise = function(_, id) Count("farmer", id) end } }
_G.BlackthornesTS = { Butler = { Advise = function(_, id) Count("ts", id) end } }
_G.BlackthornesPets = { Butler = { Advise = function(_, id) Count("pets", id) end } }

env.Enable(ns)
env.Fire("QUEST_LOG_UPDATE")
ns.Bags:Scan()

-- Everything the bag window draws: each slot's verdict and marks.
local function Look()
    local seen = {}
    for place, entry in pairs(ns.Bags.slots) do
        seen[place] = { Verdicts:VerdictOf(entry), BagView:Marks(entry) }
    end
    return seen
end
local function Asked()
    local total = 0
    for _, key in ipairs({ "equipment", "farmer", "ts", "pets" }) do total = total + (asked[key] or 0) end
    return total
end
local function Reason(itemID)
    for _, group in ipairs(Verdicts:Groups()) do
        for _, row in ipairs(group.rows) do
            if row.itemID == itemID then return row.reason, row.verdict end
        end
    end
end

Look()
suite.check("the first look asks about every item", Asked() >= 62, Asked())
suite.check("the clam meat is kept for the quest", Reason(5503) == "Clam Bait needs 7 more", Reason(5503))

-- 1 and 2. One more Clam Meat: the bags and the log both move.
asked = {}
local fake = env.bags
fake.bags[0][1].count = 4
log[1].objectives[1].numFulfilled = 4
log[1].objectives[1].text = "Clam Meat: 4/10"
ns.Bags:Scan()
env.Fire("QUEST_LOG_UPDATE")
Look()
local others = 0
for id in pairs(asked.items or {}) do if id ~= 5503 then others = others + 1 end end
suite.check("no other item is asked about again", others == 0, others .. " others, " .. Asked() .. " asks")
suite.check("the clam meat is asked about again", (asked.items or {})[5503] == true)
suite.check("and reads the new count", Reason(5503) == "Clam Bait needs 6 more", Reason(5503))
suite.check("the eyes keep their verdict", Reason(730) == "Eyes needs 3 more", Reason(730))

-- 3. A quest dropped: its item is judged again, and no longer kept for it.
asked = {}
table.remove(log, 2)
env.Fire("QUEST_REMOVED")
Look()
local reason = Reason(730)
suite.check("a dropped quest's item is judged again", (asked.items or {})[730] == true)
suite.check("and is no longer kept for it", reason ~= "Eyes needs 3 more", reason)
others = 0
for id in pairs(asked.items or {}) do if id ~= 730 then others = others + 1 end end
suite.check("and nothing else is asked about", others == 0, others)

suite.done()
