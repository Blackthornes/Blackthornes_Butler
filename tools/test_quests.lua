-- Items for your quests (a player asked, the owner said build it,
-- 2026-10-14): Butler reads the open quests' "collect N" objectives.
--
-- What must hold:
--   1. An objective's text is read in Classic's and retail's ways, and in
--      another language's words.
--   2. An item a quest collects is Keep, even on the Always sell list,
--      with how many more the quest needs.
--   3. Jobs leads with "For your quests": what is still to find and can
--      be traded. A finished objective, a quest-only or bind on pickup
--      item, or one nothing can name is never offered to buy.
--   4. At the auction house, with Tradeskills, the line has Search: all at
--      once, or one a click ("Next 2/2") when the game takes one a search.
--   5. Turned off, nothing is kept or listed. Errors read as no quests.
--   6. Quest events only mark the log stale; the items are judged again
--      only when what the quests want changed.

local env = dofile(lfs_cwd .. "/tools/testenv.lua")
local suite = env.NewSuite("quests")

local ns = env.Load()
local Quests, Verdicts, Jobs, UI = ns.Quests, ns.Verdicts, ns.Jobs, ns.UI

-- Item names come in their rarity colour (Items:ColorName); these checks
-- read the words.
local Words = {}
for _, fn in ipairs({ "StepText", "Summary", "Short", "VendorText", "BuyTooltip", "SearchTooltip" }) do
    local raw = Jobs[fn]
    Words[fn] = function(...)
        local a, b, c = raw(...)
        return env.Plain(a), env.Plain(b), env.Plain(c)
    end
end

-- 1. Reading an objective.
local name, have, want = Quests.ParseObjective("Murloc Eye: 3/8")
suite.check("Classic's way", name == "Murloc Eye" and have == 3 and want == 8)
name, have, want = Quests.ParseObjective("3/8 Murloc Eye")
suite.check("retail's way", name == "Murloc Eye" and have == 3 and want == 8)
name, have, want = Quests.ParseObjective("|cffffffffMurlocauge: 0/8|r")
suite.check("German words and colours", name == "Murlocauge" and have == 0 and want == 8, name)
suite.check("a name with no counts is the name", Quests.ParseObjective("Garrick's Head") == "Garrick's Head")
suite.check("nothing is nothing", Quests.ParseObjective(nil) == nil and Quests.ParseObjective("  ") == nil)
suite.check("the data knows Westfall Stew's items",
    ns.QUEST_ITEMS[38] and ns.QUEST_ITEMS[38][2] == 730)

local fake = env.FakeBags({
    { bag = 0, slot = 1, id = 730, name = "Murloc Eye", quality = 1, price = 16, count = 3 },
    { bag = 0, slot = 2, id = 732, name = "Okra", quality = 1, price = 6, count = 3 },
    { bag = 0, slot = 3, id = 50001, name = "Glimmer Shard", quality = 1, price = 5 },
    { bag = 0, slot = 4, id = 50002, name = "Fox Pelt", quality = 1, price = 50 },
    { bag = 0, slot = 5, id = 2589, name = "Linen Cloth", quality = 1, price = 13, count = 10 },
})
local names = { [729] = "Stringy Vulture Meat", [730] = "Murloc Eye", [731] = "Goretusk Snout", [732] = "Okra",
    [50001] = "Glimmer Shard", [50002] = "Fox Pelt", [2589] = "Linen Cloth" }
_G.C_Item.GetItemNameByID = function(id) return names[id] end
-- How each binds: the Glimmer Shard on pickup, the Fox Pelt not at all.
local binds = { [50001] = 1, [50002] = 0 }
local getInfo = _G.C_Item.GetItemInfo
_G.C_Item.GetItemInfo = function(id)
    local results = { getInfo(id) }
    if results[1] and binds[id] then
        for index = #results + 1, 13 do results[index] = 0 end
        results[14] = binds[id]
    end
    return unpack(results, 1, math.max(#results, 14))
end

local log = {
    { title = "Westfall Stew", questID = 38, objectives = {
        { type = "item", text = "Murloc Eye: 3/8", numFulfilled = 3, numRequired = 8, finished = false },
        { type = "item", text = "Okra: 3/3", numFulfilled = 3, numRequired = 3, finished = true },
        { type = "item", text = "Goretusk Snout: 0/3", numFulfilled = 0, numRequired = 3, finished = false },
        { type = "monster", text = "Murloc Raider slain: 2/8", numFulfilled = 2, numRequired = 8 },
    } },
    { title = "Shard Hunt", questID = 900001, objectives = {
        { type = "item", text = "Glimmer Shard: 1/4", numFulfilled = 1, numRequired = 4, finished = false },
    } },
    { title = "Pelts for Pa", questID = 900002, objectives = {
        { type = "item", text = "Fox Pelt: 1/2", numFulfilled = 1, numRequired = 2, finished = false },
        { type = "item", text = "Mystery Thing: 0/5", numFulfilled = 0, numRequired = 5, finished = false },
    } },
}
local reads = 0
_G.C_QuestLog = {
    GetNumQuestLogEntries = function() reads = reads + 1; return #log + 1 end,
    GetInfo = function(index)
        if index == 1 then return { isHeader = true, title = "Westfall" } end
        local quest = log[index - 1]
        return quest and { title = quest.title, questID = quest.questID, isHeader = false }
    end,
    GetQuestObjectives = function(questID)
        for _, quest in ipairs(log) do
            if quest.questID == questID then return quest.objectives end
        end
    end,
}

env.Enable(ns)
ns.db.alwaysSell = { [730] = true }

local function Find(itemName)
    for _, group in ipairs(Verdicts:Groups()) do
        for _, row in ipairs(group.rows) do
            if row.name == itemName then return row end
        end
    end
end

UI:Show("bags")

-- 2. Keep.
local eye = Find("Murloc Eye")
suite.check("Murloc Eyes are kept, Always sell or not", eye and eye.verdict == "keep", eye and eye.verdict)
suite.check("with how many more the quest needs", eye and eye.reason == "Westfall Stew needs 5 more", eye and eye.reason)
local okra = Find("Okra")
suite.check("Okra it has enough of is kept for the hand-in", okra and okra.verdict == "keep" and okra.reason == "For Westfall Stew",
    okra and okra.reason)
suite.check("a bind on pickup quest item is kept too", Find("Glimmer Shard").verdict == "keep", Find("Glimmer Shard").verdict .. " " .. tostring(Find("Glimmer Shard").reason))
suite.check("cloth no quest wants is judged as before", Find("Linen Cloth").verdict ~= "keep")

-- 3. The Jobs line.
local step
for _, row in ipairs(Jobs:Lines()) do
    if row.type == "job" and row.step.kind == "quest" then step = row.step end
end
suite.check("Jobs has a For your quests line", step ~= nil)
local ids = {}
for _, item in ipairs(step and step.items or {}) do ids[item.itemID] = item.count end
suite.check("it wants 5 Murloc Eye and 3 Goretusk Snout", ids[730] == 5 and ids[731] == 3)
suite.check("and the Fox Pelt, by its name in the bags", ids[50002] == 1)
suite.check("never the finished Okra", ids[732] == nil)
suite.check("never the bind on pickup shard", ids[50001] == nil)
suite.check("most needed first", step.items[1].itemID == 730)
local title, detail, hint = Words.StepText(step)
suite.check("it is called For your quests", title == "For your quests")
suite.check("and says what", detail:find("5 Murloc Eye", 1, true) ~= nil, detail)
suite.check("away from the auction house it says where Search is", hint ~= nil)
suite.check("the footer does not say everything here is done", Jobs:DoneHere() == false)

-- 4. Search.
local row = CreateFrame("Button")
UI.CreateRow(row)
UI.UpdateRow(row, { type = "job", step = step })
suite.check("no Search away from the auction house", not row.action:IsShown())

local sent, answer = {}, { true, "all" }
_G.BlackthornesTS = { Butler = {
    Advise = function() return nil end,
    SearchAuctions = function(_, items)
        sent[#sent + 1] = items
        return answer[1], answer[2]
    end,
} }
env.Fire("AUCTION_HOUSE_SHOW")
suite.check("the auction house is seen", Quests.auctionOpen == true)
UI.UpdateRow(row, { type = "job", step = step })
suite.check("Search shows there", row.action:IsShown() and row.action.label:GetText() == "Search",
    row.action.label:GetText())
suite.check("its tooltip names the quest", row.action.tooltipText:find("Westfall Stew", 1, true) ~= nil)
UI.RowAction({ type = "job", step = step })
suite.check("a click sends every item", #sent == 1 and #sent[1] == #step.items and sent[1][1].count == 5)
suite.check("all at once leaves it on Search", Jobs.SearchLabel(step) == "Search")

answer = { true, "one" }
UI.RowAction({ type = "job", step = step })
suite.check("one a search moves on to the next", Jobs.SearchLabel(step) == ("Next 2/%d"):format(#step.items),
    Jobs.SearchLabel(step))
UI.RowAction({ type = "job", step = step })
suite.check("the next click starts from the second", sent[3][1].itemID == step.items[2].itemID)

env.chat = {}
answer = { false, "a scan is running; search again once it finishes" }
UI.RowAction({ type = "job", step = step })
suite.check("a reason handed back is said", env.ChatText():find("scan is running", 1, true) ~= nil)
_G.BlackthornesTS.Butler.SearchAuctions = function() error("boom") end
suite.check("an error searches nothing", Quests:Search(step.items) == false)

env.Fire("AUCTION_HOUSE_CLOSED")
suite.check("closing the auction house takes Search away", not Jobs.Searchable(step))
_G.BlackthornesTS = nil
env.Fire("AUCTION_HOUSE_SHOW")
suite.check("no Search without Tradeskills", not Jobs.Searchable(step))
env.Fire("AUCTION_HOUSE_CLOSED")

-- 6. Events only mark it stale; a log that says the same changes nothing.
local version = Verdicts.version
env.Fire("QUEST_LOG_UPDATE")
suite.check("the same log judges nothing again", Verdicts.version == version)
log[1].objectives[1].numFulfilled = 8
log[1].objectives[1].finished = true
env.Fire("QUEST_LOG_UPDATE")
suite.check("a change has the items judged again", Verdicts.version > version)
UI:Refresh(true)
suite.check("enough Murloc Eyes: they are for the hand-in", Find("Murloc Eye").reason == "For Westfall Stew",
    Find("Murloc Eye").reason)

-- 5. Off.
ns.HandleSlash("quests off")
suite.check("/bbutler quests off turns it off", ns.db.questItems == false)
UI:Refresh(true)
suite.check("then the eyes are back on the Always sell list", Find("Murloc Eye").verdict == "sell",
    Find("Murloc Eye").verdict)
suite.check("and there is no quest line", Quests:Step() == nil)
ns.HandleSlash("quests on")
suite.check("and back on", Quests:IsOn() and Find("Murloc Eye").verdict == "keep")
env.chat = {}
ns.HandleSlash("quests")
suite.check("/bbutler quests lists them", env.ChatText():find("Goretusk Snout", 1, true) ~= nil, env.ChatText())

_G.C_QuestLog.GetInfo = function() error("secret") end
env.Fire("QUEST_LOG_UPDATE")
suite.check("a log that raises reads as no quests", Quests:Step() == nil)

-- Classic's calls, by log index.
_G.C_QuestLog = nil
_G.GetNumQuestLogEntries = function() return 1 end
_G.GetQuestLogTitle = function() return "Westfall Stew", 10, nil, false, nil, nil, nil, 38 end
_G.GetNumQuestLeaderBoards = function() return 1 end
_G.GetQuestLogLeaderBoard = function() return "Goretusk Snout: 1/3", "item", false end
Quests:Read()
local snout = Quests:For(731)
suite.check("Classic's quest log calls work too", snout and snout.need == 2, snout and snout.need)

suite.check("nothing was deleted from the bags", #fake.used == 0)
suite.done()
