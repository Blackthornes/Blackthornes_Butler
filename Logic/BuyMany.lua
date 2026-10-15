-- Blackthornes Butler -- Logic/BuyMany.lua
-- Buying any amount of a vendor item at once (the owner asked 2026-10-14:
-- "the ability to purchase 200 of a vendor item at once").
--
-- The game lets a player buy at most one stack a click. Shift-click an
-- item at a vendor and Butler's Buy more box (UI/BuyMany.lua) asks how
-- many; this file works out what that comes to and buys it.
--
-- What it plans (BuyMany:Plan): the amount asked for, in whole lots when
-- the vendor sells several at a time, and never more than the bags have
-- room for, the purse pays for or a vendor with limited stock has left.
-- The box shows that and its cost before anything is spent; nothing is
-- bought without the player's Buy click.
--
-- How it buys (BuyMany:Start): one stack (or one lot) every BuyMany.GAP
-- seconds, each checked again first: the vendor still open with the same
-- item in that place, no fight, gold to pay, stock left, and the bags
-- keeping up with what was bought (BuyMany.BEHIND). It stops when the
-- bags fill (the game's "Inventory is full"), the gold runs out, the
-- vendor sells out or closes, a fight starts, or the player clicks Stop,
-- and says in chat what it bought and why it stopped early.
--
-- Only items priced in gold: a vendor that wants tokens or honor is left
-- to the game's own window. The gold fund's amount (Logic/Funds.lua) is
-- for mailing gold only, never for spending (the owner, 2026-10-11).

local _, ns = ...
local L = ns.L

local BuyMany = ns.NewModule("BuyMany")

local Items = ns.Items

-- Between one stack bought and the next.
BuyMany.GAP = 0.25
-- The most the box takes.
BuyMany.MOST = 9999
-- How many buys may wait to reach the bags before the next one waits too,
-- and how long it waits before calling it stuck.
BuyMany.BEHIND = 2
BuyMany.STUCK = 5

-- Why a run stopped early, as the player reads it.
local STOPPED = {
    room = L["Stopped early: your bags are full."],
    gold = L["Stopped early: you ran out of gold."],
    stock = L["Stopped early: the vendor sold out."],
    closed = L["Stopped early: the vendor window closed."],
    combat = L["Stopped early: a fight started."],
    stuck = L["Stopped early: the vendor stopped selling it."],
    player = L["Stopped early: you clicked Stop."],
}
BuyMany.STOPPED = STOPPED

local function Call(paths, ...)
    return Items.Call(paths, ...)
end

local function InCombat()
    local fn = rawget(_G, "InCombatLockdown")
    return type(fn) == "function" and fn() and true or false
end

local function Purse()
    local fn = rawget(_G, "GetMoney")
    if type(fn) ~= "function" then return nil end
    local ok, money = pcall(function() return tonumber(fn()) end)
    return ok and money or nil
end

local function Now()
    local fn = rawget(_G, "GetTime")
    if type(fn) ~= "function" then return 0 end
    local ok, now = pcall(fn)
    return ok and tonumber(now) or 0
end

local function IDFromLink(link)
    if type(link) ~= "string" then return nil end
    local ok, id = pcall(function() return tonumber(link:match("item:(%d+)")) end)
    return ok and id or nil
end

local function Number(value)
    local ok, read = pcall(function() return tonumber(value) end)
    return ok and read or nil
end

--- Is the Shift-click box turned on? (Settings, /bbutler buy on|off.)
function BuyMany:IsOn()
    return ns.db ~= nil and ns.db.buyMany ~= false
end

function BuyMany:SetOn(on)
    ns.db.buyMany = on and true or false
    if not on and ns.BuyManyUI then ns.BuyManyUI:Hide() end
end

--------------------------------------------------------------------------------
-- The vendor's item
--------------------------------------------------------------------------------

--- The vendor's item at `index`: Ammo.MerchantItem's fields (name, icon,
--- price a lot, perBuy, available, purchasable, extended) with index,
--- itemID, link, stack (the most one bag slot holds) and perCall (the most
--- one buy takes), or nil.
function BuyMany.Item(index)
    index = tonumber(index)
    if not index then return nil end
    local item = ns.Ammo.MerchantItem(index)
    if not item then return nil end
    local link = Call({ "GetMerchantItemLink" }, index)
    local itemID = IDFromLink(link)
    if not itemID then return nil end
    item.index, item.itemID, item.link = index, itemID, link
    local name, _, _, _, _, _, _, stack = Call({ "C_Item.GetItemInfo", "GetItemInfo" }, itemID)
    if not name then Items:RequestLoad(itemID) end
    item.name = item.name or name
    local perCall = Number((Call({ "GetMerchantItemMaxStack" }, index)))
    stack = Number(stack)
    -- Not loaded yet: the vendor's own most a buy, else one lot, which
    -- never counts more room than there is.
    item.stack = math.max(stack or perCall or 0, item.perBuy, 1)
    item.perCall = math.max(perCall or item.stack, 1)
    return item
end

--- The first item at this vendor whose name holds `text` (any case), or nil.
function BuyMany.Find(text)
    if type(text) ~= "string" or text == "" then return nil end
    local want = text:lower()
    local count = tonumber((Call({ "GetMerchantNumItems" }))) or 0
    for index = 1, count do
        local item = BuyMany.Item(index)
        if item and type(item.name) == "string" and item.name:lower():find(want, 1, true) then
            return item
        end
    end
    return nil
end

--------------------------------------------------------------------------------
-- Room in the bags
--------------------------------------------------------------------------------

-- Does a bag of `family` take an item of `itemFamily`? 0 takes anything.
local function Takes(family, itemFamily)
    if family == 0 then return true end
    if not itemFamily or itemFamily == 0 then return false end
    local band = rawget(_G, "bit") and bit.band
    if band then return band(family, itemFamily) ~= 0 end
    for b = 0, 31 do
        local p = 2 ^ b
        if math.floor(family / p) % 2 == 1 and math.floor(itemFamily / p) % 2 == 1 then return true end
    end
    return false
end
BuyMany.Takes = Takes

--- How many of `itemID` fit in the bags: empty slots in every bag that
--- takes it, and the room left in its own stacks. Read live, on a click
--- or a keystroke in the box, never on a timer.
function BuyMany.Room(itemID, stack)
    local itemFamily = Number((Call({ "C_Item.GetItemFamily", "GetItemFamily" }, itemID)))
    local last = tonumber(rawget(_G, "NUM_BAG_SLOTS")) or 4
    local room = 0
    for bag = 0, last do
        local family = 0
        if bag > 0 then
            local _, read = Call({ "C_Container.GetContainerNumFreeSlots", "GetContainerNumFreeSlots" }, bag)
            family = Number(read) or Items.TableBagFamily(bag) or 0
        end
        if Takes(family, itemFamily) then
            local slots = tonumber((Call({ "C_Container.GetContainerNumSlots", "GetContainerNumSlots" }, bag))) or 0
            for slot = 1, slots do
                local entry = ns.Bags.ReadSlot(bag, slot)
                if not entry then
                    room = room + stack
                elseif entry.itemID == itemID then
                    room = room + math.max(0, stack - entry.count)
                end
            end
        end
    end
    return room
end

--------------------------------------------------------------------------------
-- The plan
--------------------------------------------------------------------------------

--- What buying `amount` of the vendor's item at `index` comes to:
--- { state, item, asked, lots, count, cost, room, short = { room, gold,
--- stock } }, each `short` the most that one allows when it is less than
--- asked. `state` is "buy" (the Buy button), "none" (no amount yet),
--- "full" (no room), "poor" (can't pay for one), "soldout", "extended"
--- (not priced in gold) or "cantbuy". Nil with no such item.
function BuyMany:Plan(index, amount)
    local item = self.Item(index)
    if not item then return nil end
    amount = math.min(math.max(math.floor(tonumber(amount) or 0), 0), self.MOST)
    local plan = { item = item, asked = amount, short = {}, lots = 0, count = 0, cost = 0 }
    if item.extended or not item.price then
        plan.state = "extended"
        return plan
    end
    if not item.purchasable then
        plan.state = "cantbuy"
        return plan
    end
    if amount < 1 then
        plan.state = "none"
        return plan
    end

    local lots = math.ceil(amount / item.perBuy)
    if item.available >= 0 and item.available < lots then
        lots = math.floor(item.available)
        plan.short.stock = lots * item.perBuy
    end
    plan.room = self.Room(item.itemID, item.stack)
    local fit = math.floor(plan.room / item.perBuy)
    if fit < lots then
        lots = fit
        plan.short.room = fit * item.perBuy
    end
    if item.price > 0 then
        local afford = math.floor((Purse() or 0) / item.price)
        if afford < lots then
            lots = afford
            plan.short.gold = afford * item.perBuy
        end
    end

    plan.lots = math.max(lots, 0)
    plan.count = plan.lots * item.perBuy
    plan.cost = plan.lots * item.price
    if plan.lots > 0 then
        plan.state = "buy"
    elseif item.available == 0 then
        plan.state = "soldout"
    elseif fit < 1 then
        plan.state = "full"
    else
        plan.state = "poor"
    end
    return plan
end

--- The box's lines for a plan: what it buys and costs, and a note.
function BuyMany.Describe(plan)
    if not plan then return "", "" end
    local item = plan.item
    local count = ns.Ammo.Thousands
    if plan.state == "extended" then
        return "", L["Butler only buys with gold. Use the vendor's window for this one."]
    elseif plan.state == "cantbuy" then
        return "", L["The vendor won't sell you this one."]
    elseif plan.state == "none" then
        return "", L["Type how many you want."]
    elseif plan.state == "soldout" then
        return "", L["The vendor has none left."]
    elseif plan.state == "full" then
        return "", L["Your bags have no room for it."]
    elseif plan.state == "poor" then
        return "", L.Format("You can't pay for one yet (%s).", Items.FormatMoney(item.price))
    end

    local main = L.Format("%s for %s", count(plan.count), Items.FormatMoney(plan.cost))
    local notes = {}
    if plan.short.room then
        notes[#notes + 1] = L.Format("Your bags have room for %s.", count(plan.short.room))
    end
    if plan.short.gold then
        notes[#notes + 1] = L.Format("You can pay for %s.", count(plan.short.gold))
    end
    if plan.short.stock then
        notes[#notes + 1] = L.Format("The vendor has %s left.", count(plan.short.stock))
    end
    if item.perBuy > 1 and plan.count ~= plan.asked and not next(plan.short) then
        notes[#notes + 1] = L.Format("Sold %s at a time.", count(item.perBuy))
    end
    return main, table.concat(notes, " ")
end

--------------------------------------------------------------------------------
-- Buying
--------------------------------------------------------------------------------

local function CountOf(itemID)
    return Number((Call({ "C_Item.GetItemCount", "GetItemCount" }, itemID)))
end

--- Buy what `plan` says, a stack (or a lot) at a time. Only on the
--- player's Buy click. `onDone(bought, reason)` runs at the end.
function BuyMany:Start(plan, onDone)
    if self.running or not (plan and plan.state == "buy") then return false end
    local item = plan.item
    self.run = (self.run or 0) + 1
    local run = self.run
    self.running = { plan = plan, bought = 0, spent = 0 }
    local state = self.running
    local startCount = CountOf(item.itemID)
    local waitingSince

    local function Done(reason)
        if self.run ~= run then return end
        self.run = self.run + 1
        self.running = nil
        if state.bought > 0 then
            ns.Print(L.Format("bought %s %s for %s.", ns.Ammo.Thousands(state.bought),
                item.name or L["items"], Items.FormatMoney(state.spent)))
        end
        if reason and STOPPED[reason] then ns.Print(STOPPED[reason]) end
        if onDone then onDone(state.bought, reason) end
    end
    state.Done = Done

    local function Step()
        if self.run ~= run then return end
        local left = plan.count - state.bought
        if left <= 0 then return Done() end
        if state.reason then return Done(state.reason) end
        if not (ns.Selling and ns.Selling:MerchantOpen(true)) then return Done("closed") end
        if InCombat() then return Done("combat") end
        if IDFromLink(Call({ "GetMerchantItemLink" }, item.index)) ~= item.itemID then return Done("closed") end
        local now = ns.Ammo.MerchantItem(item.index)
        if now and now.available == 0 then return Done("stock") end

        -- The bags keep up, or the next buy waits; long enough and the
        -- vendor isn't selling any more.
        if startCount then
            local have = CountOf(item.itemID)
            local perStep = item.perBuy > 1 and item.perBuy or math.min(item.perCall, item.stack)
            if have and have - startCount < state.bought - perStep * self.BEHIND then
                waitingSince = waitingSince or Now()
                if Now() - waitingSince > self.STUCK then return Done("stuck") end
                C_Timer.After(self.GAP, Step)
                return
            end
        end
        waitingSince = nil

        local fn = Items.Resolve("BuyMerchantItem")
        if not fn then return Done("stuck") end
        local purse = Purse() or 0
        local ok, units, cost
        if item.perBuy > 1 then
            -- Lots go one a buy: what a quantity means for them differs
            -- between clients.
            if purse < item.price then return Done("gold") end
            units, cost = item.perBuy, item.price
            ok = pcall(fn, item.index)
        else
            units = math.min(left, item.perCall, item.stack)
            if item.price > 0 then units = math.min(units, math.floor(purse / item.price)) end
            if units < 1 then return Done("gold") end
            cost = units * item.price
            ok = pcall(fn, item.index, units)
        end
        if not ok then return Done("stuck") end
        state.bought = state.bought + units
        state.spent = state.spent + cost
        C_Timer.After(self.GAP, Step)
    end

    Step()
    return true
end

--- Stop a run (the Stop button, the box closing).
function BuyMany:Stop(reason)
    local state = self.running
    if state then state.reason = reason or "player" end
end

--- Is a run going?
function BuyMany:Running()
    return self.running ~= nil
end

--- The game said the bags are full: stop at the next step.
function BuyMany:HeardError(...)
    local state = self.running
    if not state then return end
    local full = {}
    for _, key in ipairs({ "ERR_INV_FULL", "ERR_BAG_FULL", "ERR_ITEM_MAX_COUNT", "ERR_NOT_ENOUGH_MONEY",
        "ERR_VENDOR_SOLD_OUT" }) do
        local text = rawget(_G, key)
        if type(text) == "string" then full[text] = key end
    end
    local args = { ... }
    for i = 1, select("#", ...) do
        local ok, key = pcall(function() return full[args[i]] end)
        if ok and key then
            state.reason = (key == "ERR_NOT_ENOUGH_MONEY" and "gold")
                or (key == "ERR_VENDOR_SOLD_OUT" and "stock") or "room"
            return
        end
    end
end

function BuyMany:OnEnable()
    ns.RegisterEvent(self, "UI_ERROR_MESSAGE", function(_, _, ...) BuyMany:HeardError(...) end)
    ns.RegisterEvent(self, "MERCHANT_CLOSED", function()
        if BuyMany.running then BuyMany.running.Done("closed") end
    end)
    ns.RegisterEvent(self, "PLAYER_REGEN_DISABLED", function() BuyMany:Stop("combat") end)
end
