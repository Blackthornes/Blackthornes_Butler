-- Blackthornes Butler -- Logic/VendorPrices.lua
-- What a vendor charges for an item, for the tooltip line "Vendors sell it
-- for 25c" (a player asked for what you'd pay an NPC for each item; the
-- owner said build it, 2026-10-22).
--
-- Only an item a vendor is known to sell gets a price, never the price the
-- item data carries for everything (a drop no vendor stocks has one too).
-- Two places know:
--   1. Butler's own: every vendor the player opens is read, a few items a
--      frame, and each item's price for one kept account wide in
--      `vendorBuyPrices[itemID]` = copper (never rename it). Seen in game,
--      so it wins.
--   2. Tradeskills, when it is loaded: `Butler:VendorPrice(itemID)`, read
--      only, inside a pcall (what it saw at merchants, else Classic's
--      prices for the materials vendors keep in stock).
-- Items bought with tokens are skipped, and so is anything under a copper
-- for one (a stack of arrows), as Tradeskills does.

local _, ns = ...

local L = ns.L

local VendorPrices = ns.NewModule("VendorPrices")

-- Merchant items read a frame, and the wait after MERCHANT_UPDATE's burst.
VendorPrices.BUDGET = 20
VendorPrices.SETTLE = 0.3

-- The line's key for Off, Shift or Always (UI/TooltipShift.lua). Whether it
-- is on at all stays in ns.db.vendorPrice.
VendorPrices.SHIFT_KEY = "vendorPrice"

function VendorPrices:Enabled()
    return ns.db ~= nil and ns.db.vendorPrice ~= false
end

--- Turn the line on or off (Settings).
function VendorPrices:SetEnabled(on)
    ns.db.vendorPrice = on and true or false
end

local function Table()
    if type(ns.db) ~= "table" then return nil end
    if type(ns.db.vendorBuyPrices) ~= "table" then ns.db.vendorBuyPrices = {} end
    return ns.db.vendorBuyPrices
end

--- What Tradeskills says a vendor charges for one, or nil.
function VendorPrices.FromTradeskills(itemID)
    local ts = rawget(_G, "BlackthornesTS")
    local butler = type(ts) == "table" and rawget(ts, "Butler")
    if type(butler) ~= "table" or type(butler.VendorPrice) ~= "function" then return nil end
    local ok, price = pcall(butler.VendorPrice, butler, itemID)
    price = ok and tonumber(price) or nil
    if price and price > 0 then return price end
    return nil
end

--- Copper for one from a vendor, or nil when no vendor is known to sell it.
function VendorPrices:Price(itemID)
    itemID = tonumber(itemID)
    if not itemID then return nil end
    local kept = type(ns.db) == "table" and type(ns.db.vendorBuyPrices) == "table"
        and tonumber(ns.db.vendorBuyPrices[itemID]) or nil
    if kept and kept > 0 then return kept end
    return self.FromTradeskills(itemID)
end

--------------------------------------------------------------------------------
-- Learning at a vendor
--------------------------------------------------------------------------------

local function IDFromLink(link)
    return type(link) == "string" and tonumber(link:match("item:(%d+)")) or nil
end

--- Keep what one of the open vendor's items costs. True when it was kept.
function VendorPrices:LearnIndex(index)
    local itemID = IDFromLink(ns.Items.Call({ "GetMerchantItemLink" }, index))
    if not itemID then return false end
    local item = ns.Ammo and ns.Ammo.MerchantItem(index)
    if not (item and item.price and not item.extended) then return false end
    local each = math.floor(item.price / math.max(1, item.perBuy or 1))
    if each <= 0 then return false end
    local prices = Table()
    if not prices then return false end
    if prices[itemID] ~= each then prices[itemID] = each end
    return true
end

--- Read the open vendor's list, BUDGET items a frame. A new read starts
--- over; a read still going when the vendor closes stops.
function VendorPrices:Learn()
    self.run = (self.run or 0) + 1
    local run = self.run
    local count = tonumber((ns.Items.Call({ "GetMerchantNumItems" }))) or 0
    local index = 1
    local function Step()
        if run ~= VendorPrices.run then return end
        if not VendorPrices.open then return end
        local last = math.min(count, index + VendorPrices.BUDGET - 1)
        for i = index, last do
            pcall(VendorPrices.LearnIndex, VendorPrices, i)
        end
        index = last + 1
        if index <= count then C_Timer.After(0, Step) end
    end
    Step()
end

--- MERCHANT_SHOW and MERCHANT_UPDATE come in bursts: one read after.
function VendorPrices:LearnSoon()
    if self.soon then return end
    self.soon = true
    C_Timer.After(self.SETTLE, function()
        VendorPrices.soon = false
        if VendorPrices.open then VendorPrices:Learn() end
    end)
end

--------------------------------------------------------------------------------
-- The tooltip line
--------------------------------------------------------------------------------

--- How many of `itemID` sit in the bag slot a tooltip belongs to, or nil
--- when it is not a bag slot holding that item. Never raises.
function VendorPrices.StackCount(tooltip, itemID)
    local tip = ns.VerdictTip
    if not (tooltip and tip and tip.OwnerSlot and ns.Bags and ns.Bags.ReadSlot) then return nil end
    local ok, count = pcall(function()
        local bag, slot = tip.OwnerSlot(tooltip)
        if not bag then return nil end
        local entry = ns.Bags.ReadSlot(bag, slot)
        if entry and entry.itemID == itemID then return entry.count end
    end)
    if ok and type(count) == "number" and count > 0 then return count end
    return nil
end

--- What a vendor pays for one, or nil when it can't be sold. Never raises.
function VendorPrices.SellPrice(itemID)
    if not (ns.Items and ns.Items.SellPrice) then return nil end
    local ok, price = pcall(ns.Items.SellPrice, ns.Items, itemID)
    if ok and type(price) == "number" and price > 0 then return price end
    return nil
end

--- Add "Vendors pay 5c each" (and, with Shift on a bag stack, "This stack
--- of 20: 1s"), then "Vendors sell it for 25c", under the other lines (a
--- player asked for the sell price, the owner said build it, 2026-11-18).
--- True when they were held back for Shift. Never raises.
function VendorPrices:AddLine(tooltip, itemID, data)
    if not (itemID and self:Enabled()) then return false end
    local held = false
    local ok = pcall(function()
        local price = self:Price(itemID)
        local sell = VendorPrices.SellPrice(itemID)
        if not (price or sell) then return end
        if not ns.TooltipShift:Shows(self.SHIFT_KEY) then
            held = true
            return
        end
        local money = ns.Items.FormatMoney
        if sell then
            tooltip:AddLine(L.Format("Vendors pay %s each", money(sell)), 1, 1, 1)
            local count = ns.TooltipShift.ShiftDown() and VendorPrices.StackCount(tooltip, itemID)
            if count and count > 1 then
                tooltip:AddLine(L.Format("This stack of %d: %s", count, money(sell * count)), 1, 1, 1)
            end
        end
        if price then
            tooltip:AddLine(L.Format("Vendors sell it for %s", money(price)), 1, 1, 1)
        end
        if not data and tooltip.Show then tooltip:Show() end
    end)
    if not ok then ns.Debug("vendor price tooltip failed") end
    return held
end

--- One line for /bbutler probe.
function VendorPrices:ProbeText()
    local count = 0
    for _ in pairs(type(ns.db) == "table" and type(ns.db.vendorBuyPrices) == "table"
        and ns.db.vendorBuyPrices or {}) do count = count + 1 end
    local ts = rawget(_G, "BlackthornesTS")
    local asks = type(ts) == "table" and type(rawget(ts, "Butler")) == "table"
        and type(ts.Butler.VendorPrice) == "function"
    return ("%d learned, Tradeskills %s%s"):format(count, asks and "answers" or "not asked",
        self:Enabled() and "" or ", turned off")
end

function VendorPrices:OnEnable()
    ns.RegisterEvent(self, "MERCHANT_SHOW", function()
        VendorPrices.open = true
        VendorPrices:LearnSoon()
    end)
    ns.RegisterEvent(self, "MERCHANT_UPDATE", function()
        if VendorPrices.open then VendorPrices:LearnSoon() end
    end)
    ns.RegisterEvent(self, "MERCHANT_CLOSED", function() VendorPrices.open = false end)
end
