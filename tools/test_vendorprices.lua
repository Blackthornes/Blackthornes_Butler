-- What a vendor charges, on item tooltips: "Vendors sell it for 25c" (a
-- player asked for what you'd pay an NPC for each item; the owner said
-- build it, 2026-10-22).
--
-- What must hold:
--   1. Opening a vendor keeps each item's price for one, account wide.
--   2. Token items and anything under a copper for one are not kept.
--   3. Any item a vendor is known to sell gets the line, carried or not,
--      under the Butler line; an item no vendor sells gets nothing.
--   4. Without a price of its own, Butler asks Tradeskills; its own wins.
--   5. Settings' Off, Shift or Always works on the line.

local env = dofile(lfs_cwd .. "/tools/testenv.lua")
local suite = env.NewSuite("vendorprices")

local ns = env.Load()
env.FakeBags({
    { bag = 0, slot = 1, id = 701, name = "Broken Fang", quality = 0, price = 125 },
})

local postCalls = {}
_G.Enum = { TooltipDataType = { Item = 0 } }
_G.TooltipDataProcessor = {
    AddTooltipPostCall = function(kind, fn) postCalls[#postCalls + 1] = { kind = kind, fn = fn } end,
}
local function Double(self, left, right) self._lines[#self._lines + 1] = left .. " | " .. right end
_G.GameTooltip.AddDoubleLine = Double

-- A vendor: thread, a token item, and a stack of arrows under a copper each.
local vendor = {
    { id = 2320, name = "Coarse Thread", price = 10, stack = 1 },
    { id = 9001, name = "Token Cloak", price = 0, stack = 1, extended = true },
    { id = 2512, name = "Rough Arrow", price = 10, stack = 200 },
}
_G.GetMerchantNumItems = function() return #vendor end
_G.GetMerchantItemLink = function(i)
    local item = vendor[i]
    return item and ("|Hitem:" .. item.id .. "::|h[" .. item.name .. "]|h") or nil
end
_G.C_MerchantFrame = { GetItemInfo = function(i)
    local item = vendor[i]
    if not item then return nil end
    return { name = item.name, price = item.price, stackCount = item.stack, numAvailable = -1,
        isUsable = true, isPurchasable = true, hasExtendedCost = item.extended }
end }

env.Enable(ns)
env.Fire("PLAYER_ENTERING_WORLD")
local VendorPrices = ns.VendorPrices

local function Hover(itemID)
    GameTooltip._lines = {}
    GameTooltip.GetOwner = function() return nil end
    for _, call in ipairs(postCalls) do call.fn(GameTooltip, { id = itemID }) end
    return GameTooltip._lines
end

suite.check("nothing known before a vendor opens", VendorPrices:Price(2320) == nil)

-- 1.
env.Fire("MERCHANT_SHOW")
suite.check("thread kept at 10c for one", ns.db.vendorBuyPrices[2320] == 10, tostring(ns.db.vendorBuyPrices[2320]))

-- 2.
suite.check("a token item is not kept", ns.db.vendorBuyPrices[9001] == nil)
suite.check("an arrow under a copper is not kept", ns.db.vendorBuyPrices[2512] == nil)
env.Fire("MERCHANT_CLOSED")

-- 3.
local lines = Hover(2320)
suite.check("an item not carried gets the vendor line",
    #lines == 1 and lines[1]:find("^Vendors sell it for 10") ~= nil, tostring(lines[1]))
lines = Hover(701)
suite.check("a carried item has it after the Butler line",
    (lines[1] or ""):find("^Butler:") ~= nil and #lines == 1, tostring(lines[1]))
ns.db.vendorBuyPrices[701] = 40
lines = Hover(701)
suite.check("and the vendor line under it",
    #lines == 2 and lines[2]:find("^Vendors sell it for 40") ~= nil, tostring(lines[2]))
suite.check("an item no vendor sells gets nothing", #Hover(4306) == 0)

-- 4.
_G.BlackthornesTS = { Butler = { VendorPrice = function(_, id)
    if id == 4306 then return 1500 end
    if id == 2320 then return 99 end
    if id == 666 then error("boom") end
end } }
suite.check("Tradeskills' price fills a gap", VendorPrices:Price(4306) == 1500)
suite.check("Butler's own price wins", VendorPrices:Price(2320) == 10)
suite.check("a Tradeskills error is no price", VendorPrices:Price(666) == nil)
_G.BlackthornesTS = nil

-- 5.
ns.HandleSlash("settings")
local stepper = ns.SettingsUI.controls.vendorPrice
suite.check("Settings shows it Always", stepper:GetValue() == ns.TooltipShift.ALWAYS)
stepper:Pick(stepper:GetValue() - 1)
lines = Hover(2320)
suite.check("Shift holds it back", #lines == 1 and (lines[1] or ""):find("Shift") ~= nil, tostring(lines[1]))
stepper:Pick(stepper:GetValue() - 1)
suite.check("Off turns it off", ns.db.vendorPrice == false and #Hover(2320) == 0)
stepper:Pick(stepper:GetValue() + 1)
stepper:Pick(stepper:GetValue() + 1)
suite.check("Always turns it back on", ns.db.vendorPrice == true and #Hover(2320) == 1)

suite.check("the probe counts what it learned", VendorPrices:ProbeText():find("^2 learned") ~= nil,
    VendorPrices:ProbeText())

suite.done()
