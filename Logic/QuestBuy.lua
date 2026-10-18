-- Blackthornes Butler -- Logic/QuestBuy.lua
-- Buy quest items (a player asked on Discord, the owner said yes,
-- 2026-10-18, off unless ticked): at the auction house, the Jobs group
-- lists each item an open quest still needs (Quests:ToBuy) under the
-- "For your quests" line, with what it should cost and its own Buy button.
--
-- Nothing is bought without two clicks. Buy asks the game for the real
-- price of that many (C_AuctionHouse.StartCommoditiesPurchase), the row
-- then shows the total, and only Pay spends it
-- (ConfirmCommoditiesPurchase). A price that moves while it waits is shown
-- again and needs Pay again. Gear and other items not sold in stacks can't
-- be bought this way, so their row has Tradeskills' Search instead
-- (Quests:Search for that one item).
--
-- The price shown before the click is Tradeskills' public price
-- (_G.BlackthornesTS_API.GetPrice, read in a pcall); without it the row
-- has no price until Buy is clicked.
--
-- Saved, account wide, never rename it: questBuy (off unless ticked).
-- Settings, Selling page, "Buy Quest Items:", and /bbutler quests buy on|off.

local _, ns = ...
local L = ns.L

local QuestBuy = ns.NewModule("QuestBuy")

local Items = ns.Items

-- How long Buy waits for the game's price before it gives up.
QuestBuy.QUOTE_WAIT = 10
-- How long Pay waits for the game to say the buy went through.
QuestBuy.BUY_WAIT = 15

-- Moves whenever a row's words or button change.
QuestBuy.version = 0

-- The one buy under way: { itemID, count, phase = "asking" | "quoted" |
-- "buying", unit, total, at }, or nil.
QuestBuy.pending = nil

-- C_AuctionHouse's commodity status: 1 is an item sold one at a time.
local NOT_A_STACK = 1

local function Now()
    return type(GetTime) == "function" and GetTime() or 0
end

local function Moved()
    QuestBuy.version = QuestBuy.version + 1
    if ns.UI and ns.UI.IsShown and ns.UI:IsShown() then ns.UI:Refresh(true) end
end

function QuestBuy:IsOn()
    return ns.db ~= nil and ns.db.questBuy == true and ns.Quests ~= nil and ns.Quests:IsOn()
end

function QuestBuy:SetOn(on)
    ns.db.questBuy = on and true or false
    if not on then self:Cancel() end
    Moved()
end

--- Are the rows shown? At the auction house, ticked, on a client that
--- can buy from it.
function QuestBuy:Shows()
    return self:IsOn() and ns.Quests.auctionOpen == true
        and Items.Resolve("C_AuctionHouse.StartCommoditiesPurchase") ~= nil
end

--- The rows under the For your quests line: one an item.
function QuestBuy:Rows(step)
    local rows = {}
    if not (step and self:Shows()) then return rows end
    for _, item in ipairs(step.items or {}) do
        rows[#rows + 1] = { type = "questbuy", item = item }
    end
    return rows
end

--- Tradeskills' price for one, in copper, or nil.
function QuestBuy.Estimate(itemID)
    local api = rawget(_G, "BlackthornesTS_API")
    if type(api) ~= "table" or type(api.GetPrice) ~= "function" then return nil end
    local ok, price = pcall(api.GetPrice, itemID)
    price = ok and tonumber(price) or nil
    if price and price > 0 then return math.floor(price) end
    return nil
end

--- "buy" for an item sold in stacks (or one the game can't say yet),
--- "search" for one sold one at a time.
function QuestBuy.Kind(itemID)
    local status = Items.Call({ "C_AuctionHouse.GetItemCommodityStatus" }, itemID)
    local ok, value = pcall(function()
        if type(status) == "number" then return status end
        local enum = rawget(_G, "Enum") and Enum.ItemCommodityStatus
        if enum and status == enum.Item then return NOT_A_STACK end
        return nil
    end)
    if ok and value == NOT_A_STACK then return "search" end
    return "buy"
end

--- The buy under way for this item, or nil.
function QuestBuy:PendingFor(itemID)
    local pending = self.pending
    if pending and pending.itemID == itemID then return pending end
    return nil
end

local function QuestNames(item)
    local names = table.concat(item.quests or {}, ", ")
    if names == "" then names = L["your quest"] end
    return names
end

--- The row's line under the name, and the money shown on its right.
function QuestBuy:Text(item)
    local pending = self:PendingFor(item.itemID)
    if pending and pending.total and (pending.phase == "quoted" or pending.phase == "buying") then
        return L.Format("%d for %s. Click Pay to buy them.", pending.count, Items.FormatMoney(pending.total)),
            pending.total
    end
    local quests = QuestNames(item)
    if QuestBuy.Kind(item.itemID) == "search" then
        return L.Format("%d for %s. Pick it in the auction house window.", item.count, quests), nil
    end
    local each = QuestBuy.Estimate(item.itemID)
    if each then
        return L.Format("%d for %s. About %s each.", item.count, quests, Items.FormatMoney(each)), each * item.count
    end
    return L.Format("%d for %s.", item.count, quests), nil
end

--- The row's button: its words, its hover and whether it can be clicked,
--- or nil for no button.
function QuestBuy:Button(item)
    if QuestBuy.Kind(item.itemID) == "search" then
        if not ns.Quests.CanSearch() then return nil end
        return L["Search"], nil, true
    end
    local pending = self:PendingFor(item.itemID)
    if pending and (pending.phase == "quoted" or pending.phase == "buying") then
        return L["Pay"], L.Format("Buys %d %s for %s.", pending.count, ns.Jobs.ItemName(item.itemID),
            Items.FormatMoney(pending.total)), pending.phase == "quoted"
    end
    return L["Buy"], L["Checks the price. Nothing is bought until you click Pay."], pending == nil
end

--------------------------------------------------------------------------------
-- The clicks
--------------------------------------------------------------------------------

local function Money()
    if type(GetMoney) ~= "function" then return nil end
    local ok, money = pcall(function() return tonumber(GetMoney()) end)
    return ok and money or nil
end

--- Give up on the buy under way, telling the game when it was asked.
function QuestBuy:Cancel()
    local pending = self.pending
    if not pending then return end
    self.pending = nil
    if pending.phase ~= "buying" then
        pcall(function()
            local cancel = Items.Resolve("C_AuctionHouse.CancelCommoditiesPurchase")
            if cancel then cancel() end
        end)
    end
    Moved()
end

local function After(seconds, fn)
    if C_Timer and C_Timer.After then C_Timer.After(seconds, fn) end
end

--- The row's button was clicked.
function QuestBuy:Click(item)
    if not (item and item.itemID) then return end
    if QuestBuy.Kind(item.itemID) == "search" then
        if ns.Quests:Search({ { itemID = item.itemID, count = item.count } }) then Moved() end
        return
    end
    local pending = self:PendingFor(item.itemID)
    if pending and pending.phase == "quoted" then return self:Pay(pending) end
    if pending then return end
    if not self:Shows() then return end
    -- Another item's buy waiting on Pay is let go.
    if self.pending then self:Cancel() end
    local start = Items.Resolve("C_AuctionHouse.StartCommoditiesPurchase")
    local ok = start and pcall(start, item.itemID, item.count)
    if not ok then
        ns.Print(L.Format("Couldn't buy %s. Try again.", ns.Jobs.ItemName(item.itemID)))
        return
    end
    local mine = { itemID = item.itemID, count = item.count, phase = "asking", at = Now() }
    self.pending = mine
    Moved()
    After(QuestBuy.QUOTE_WAIT, function()
        if QuestBuy.pending == mine and mine.phase == "asking" then
            QuestBuy:Cancel()
            ns.Print(L.Format("Couldn't buy %s. Try again.", ns.Jobs.ItemName(mine.itemID)))
        end
    end)
end

--- Pay was clicked: spend the total the row shows.
function QuestBuy:Pay(pending)
    local money = Money()
    if money and pending.total and money < pending.total then
        ns.Print(L.Format("You need %s for that.", Items.FormatMoney(pending.total)))
        return
    end
    local confirm = Items.Resolve("C_AuctionHouse.ConfirmCommoditiesPurchase")
    local ok = confirm and pcall(confirm, pending.itemID, pending.count)
    if not ok then
        self:Cancel()
        ns.Print(L.Format("Couldn't buy %s. Try again.", ns.Jobs.ItemName(pending.itemID)))
        return
    end
    pending.phase = "buying"
    pending.at = Now()
    Moved()
    After(QuestBuy.BUY_WAIT, function()
        if QuestBuy.pending == pending and pending.phase == "buying" then
            QuestBuy.pending = nil
            Moved()
            ns.Print(L.Format("Couldn't buy %s. Try again.", ns.Jobs.ItemName(pending.itemID)))
        end
    end)
end

--------------------------------------------------------------------------------
-- What the game answers
--------------------------------------------------------------------------------

--- The game's price for the buy asked for. A price that comes while it is
--- buying moved under it, so it waits for Pay again.
function QuestBuy:PriceUpdated(unit, total)
    local pending = self.pending
    if not pending then return end
    total = tonumber(total)
    if not total then return end
    pending.unit = tonumber(unit)
    pending.total = math.floor(total)
    pending.phase = "quoted"
    Moved()
end

function QuestBuy:Unavailable()
    local pending = self.pending
    if not pending then return end
    self.pending = nil
    Moved()
    ns.Print(L.Format("Nobody is selling %d %s right now.", pending.count, ns.Jobs.ItemName(pending.itemID)))
end

function QuestBuy:Succeeded()
    local pending = self.pending
    if not pending then return end
    self.pending = nil
    ns.Print(L.Format("Bought %d %s.", pending.count, ns.Jobs.ItemName(pending.itemID)))
    -- The bags and the quest log say it next; read them again.
    if ns.Quests then ns.Quests:Stale() end
    Moved()
end

function QuestBuy:Failed()
    local pending = self.pending
    if not pending then return end
    self.pending = nil
    Moved()
    ns.Print(L.Format("Couldn't buy %s. Try again.", ns.Jobs.ItemName(pending.itemID)))
end

function QuestBuy:OnEnable()
    ns.RegisterEvent(self, "COMMODITY_PRICE_UPDATED", function(_, _, unit, total) QuestBuy:PriceUpdated(unit, total) end)
    ns.RegisterEvent(self, "COMMODITY_PRICE_UNAVAILABLE", function() QuestBuy:Unavailable() end)
    ns.RegisterEvent(self, "COMMODITY_PURCHASE_SUCCEEDED", function() QuestBuy:Succeeded() end)
    ns.RegisterEvent(self, "COMMODITY_PURCHASE_FAILED", function() QuestBuy:Failed() end)
    ns.RegisterEvent(self, "AUCTION_HOUSE_CLOSED", function() QuestBuy:Cancel() end)
end

function QuestBuy:ProbeText()
    return ("on %s, StartCommoditiesPurchase %s, ConfirmCommoditiesPurchase %s, Tradeskills price %s"):format(
        tostring(self:IsOn()),
        Items.Resolve("C_AuctionHouse.StartCommoditiesPurchase") and "found" or "missing",
        Items.Resolve("C_AuctionHouse.ConfirmCommoditiesPurchase") and "found" or "missing",
        type(rawget(_G, "BlackthornesTS_API")) == "table" and "yes" or "no")
end
