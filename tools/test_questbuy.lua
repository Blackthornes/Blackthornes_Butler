-- Buy quest items at the auction house (a player asked, the owner said
-- yes, 2026-10-18, off unless ticked).
--
-- What must hold:
--   1. Off by default: no rows, even at the auction house.
--   2. Ticked, at the auction house, each item to buy gets its own row
--      under For your quests, with Tradeskills' price when it has one.
--   3. Buy only asks the price. Nothing is spent until Pay, and Pay
--      spends that many, once.
--   4. A price that moves while it buys needs Pay again.
--   5. Short of gold, Pay buys nothing and says how much it needs.
--   6. Nobody selling, a failed buy or no answer: nothing is bought and
--      chat says so. Closing the auction house lets the buy go.
--   7. Items not sold in stacks get Search, never Buy.

local env = dofile(lfs_cwd .. "/tools/testenv.lua")
local suite = env.NewSuite("questbuy")

local ns = env.Load()
local Quests, QuestBuy, Jobs, UI = ns.Quests, ns.QuestBuy, ns.Jobs, ns.UI

local fake = env.FakeBags({
    { bag = 0, slot = 1, id = 730, name = "Murloc Eye", quality = 1, price = 16, count = 3 },
})
fake.money = 100000
local names = { [730] = "Murloc Eye", [731] = "Goretusk Snout", [50003] = "Old Sword" }
_G.C_Item.GetItemNameByID = function(id) return names[id] end

local log = {
    { title = "Westfall Stew", questID = 38, objectives = {
        { type = "item", text = "Murloc Eye: 3/8", numFulfilled = 3, numRequired = 8, finished = false },
        { type = "item", text = "Goretusk Snout: 0/3", numFulfilled = 0, numRequired = 3, finished = false },
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

-- The auction house, as the game would answer.
local calls = {}
local status = {}
_G.C_AuctionHouse = {
    StartCommoditiesPurchase = function(id, count) calls[#calls + 1] = { "start", id, count } end,
    ConfirmCommoditiesPurchase = function(id, count) calls[#calls + 1] = { "confirm", id, count } end,
    CancelCommoditiesPurchase = function() calls[#calls + 1] = { "cancel" } end,
    GetItemCommodityStatus = function(id) return status[id] or 2 end,
}
_G.BlackthornesTS_API = { version = 1, GetPrice = function(id) return id == 730 and 240 or nil end }

-- Timers wait until the test says.
local timers = {}
_G.C_Timer.After = function(_, fn) timers[#timers + 1] = fn end
local function RunTimers()
    local list = timers
    timers = {}
    for _, fn in ipairs(list) do fn() end
end

env.Enable(ns)
UI:Show("bags")

local function BuyRows()
    local rows = {}
    for _, row in ipairs(Jobs:Lines()) do
        if row.type == "questbuy" then rows[#rows + 1] = row end
    end
    return rows
end

local function Count(kind)
    local n = 0
    for _, call in ipairs(calls) do if call[1] == kind then n = n + 1 end end
    return n
end

-- 1. Off by default.
suite.check("off unless ticked", ns.db.questBuy == false)
env.Fire("AUCTION_HOUSE_SHOW")
RunTimers()
suite.check("no rows while off", #BuyRows() == 0)

-- 2. The rows.
ns.HandleSlash("quests buy on")
suite.check("/bbutler quests buy on ticks it", ns.db.questBuy == true)
local rows = BuyRows()
suite.check("one row an item", #rows == 2, #rows)
local eye = rows[1].item
suite.check("most needed first", eye.itemID == 730 and eye.count == 5)

local row = CreateFrame("Button")
UI.CreateRow(row)
UI.UpdateRow(row, rows[1])
suite.check("the row names the item", row.name:GetText() == "Murloc Eye", row.name:GetText())
suite.check("with how many, the quest and the price",
    row.reason:GetText():find("5 for Westfall Stew. About", 1, true) ~= nil, row.reason:GetText())
suite.check("and the total on the right", row.worth:GetText() ~= "")
suite.check("and a Buy button", row.action:IsShown() and row.action.label:GetText() == "Buy")
UI.UpdateRow(row, rows[2])
suite.check("no price without one from Tradeskills", row.reason:GetText() == "3 for Westfall Stew.",
    row.reason:GetText())

-- 3. Buy asks, Pay spends.
UI.RowAction(rows[1])
suite.check("Buy asks the game for the price", Count("start") == 1 and calls[1][2] == 730 and calls[1][3] == 5)
suite.check("and buys nothing", Count("confirm") == 0)
UI.RowAction(rows[1])
suite.check("a second click before the price buys nothing", Count("confirm") == 0 and Count("start") == 1)
env.Fire("COMMODITY_PRICE_UPDATED", 250, 1250)
UI.UpdateRow(row, rows[1])
suite.check("the price shows with Pay", row.action.label:GetText() == "Pay"
    and row.reason:GetText():find("Click Pay", 1, true) ~= nil, row.reason:GetText())
suite.check("Pay's hover says what it buys", row.action.tooltipText:find("Buys 5 Murloc Eye", 1, true) ~= nil,
    row.action.tooltipText)
UI.RowAction(rows[1])
suite.check("Pay buys them", Count("confirm") == 1 and calls[#calls][3] == 5)
UI.RowAction(rows[1])
suite.check("and only once", Count("confirm") == 1)

-- 4. A price that moves while it buys.
env.Fire("COMMODITY_PRICE_UPDATED", 300, 1500)
suite.check("a new price waits for Pay again", QuestBuy.pending.phase == "quoted" and QuestBuy.pending.total == 1500)
UI.RowAction(rows[1])
suite.check("Pay again buys at it", Count("confirm") == 2)
env.chat = {}
env.Fire("COMMODITY_PURCHASE_SUCCEEDED")
suite.check("a buy that went through is said", env.ChatText():find("Bought 5 Murloc Eye", 1, true) ~= nil,
    env.ChatText())
suite.check("and is done", QuestBuy.pending == nil)
RunTimers()
suite.check("its wait says nothing after", not env.ChatText():find("Couldn't", 1, true))

-- 5. Short of gold.
UI.RowAction(rows[1])
env.Fire("COMMODITY_PRICE_UPDATED", 250, 1250)
fake.money = 100
env.chat = {}
UI.RowAction(rows[1])
suite.check("short of gold buys nothing", Count("confirm") == 2)
suite.check("and says how much", env.ChatText():find("You need", 1, true) ~= nil, env.ChatText())
fake.money = 100000

-- 6. Nobody selling, failures, closing.
env.chat = {}
UI.RowAction(rows[2])
suite.check("Buy on another item lets the first go", Count("cancel") == 1 and QuestBuy.pending.itemID == 731)
env.Fire("COMMODITY_PRICE_UNAVAILABLE")
suite.check("nobody selling is said", env.ChatText():find("Nobody is selling 3 Goretusk Snout", 1, true) ~= nil,
    env.ChatText())
suite.check("and nothing waits", QuestBuy.pending == nil)
timers = {}
UI.RowAction(rows[2])
RunTimers()
suite.check("no answer gives up", QuestBuy.pending == nil and env.ChatText():find("Couldn't buy", 1, true) ~= nil)
UI.RowAction(rows[2])
env.Fire("COMMODITY_PRICE_UPDATED", 100, 300)
UI.RowAction(rows[2])
env.Fire("COMMODITY_PURCHASE_FAILED")
suite.check("a failed buy is let go", QuestBuy.pending == nil)
UI.RowAction(rows[2])
env.Fire("AUCTION_HOUSE_CLOSED")
suite.check("closing the auction house lets it go", QuestBuy.pending == nil)
suite.check("and the rows go", #BuyRows() == 0)

-- 7. Not sold in stacks.
env.Fire("AUCTION_HOUSE_SHOW")
status[731] = 1
local starts = Count("start")
UI.UpdateRow(row, BuyRows()[2])
suite.check("no Search without Tradeskills", not row.action:IsShown())
local sent = {}
_G.BlackthornesTS = { Butler = { SearchAuctions = function(_, items) sent[#sent + 1] = items; return true, "all" end } }
UI.UpdateRow(row, BuyRows()[2])
suite.check("Search for one sold one at a time", row.action:IsShown() and row.action.label:GetText() == "Search")
suite.check("it says to pick it", row.reason:GetText():find("Pick it", 1, true) ~= nil)
UI.RowAction(BuyRows()[2])
suite.check("Search looks it up and buys nothing", #sent == 1 and sent[1][1].itemID == 731 and Count("start") == starts)

ns.HandleSlash("quests buy off")
suite.check("/bbutler quests buy off unticks it", ns.db.questBuy == false and #BuyRows() == 0)
suite.check("nothing was deleted from the bags", #fake.used == 0)
suite.done()
