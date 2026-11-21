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
--   6. What a vendor pays for one shows too ("Vendors pay 5c each"), and
--      with Shift on a bag stack, what that stack sells for (2026-11-18).

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
suite.check("an item not carried gets the vendor lines",
    #lines == 3 and lines[2]:find("^Vendor Pays: | ") ~= nil and lines[3]:find("^Vendor Sells For: | 10") ~= nil,
    table.concat(lines, " / "))
lines = Hover(701)
-- The block puts prices first, then what Butler says.
suite.check("a carried item has them before the Butler line",
    (lines[3] or ""):find("^Butler Says:") ~= nil and #lines == 3, table.concat(lines, " / "))
suite.check("what a vendor pays for one",
    (lines[2] or ""):find("^Vendor Pays: | 1.-s.- 25.-c.- each$") ~= nil, tostring(lines[2]))
ns.db.vendorBuyPrices[701] = 40
lines = Hover(701)
suite.check("and what a vendor charges under it",
    #lines == 4 and lines[3]:find("^Vendor Sells For: | 40") ~= nil, tostring(lines[3]))
suite.check("an item no vendor sells or buys gets nothing", #Hover(999999) == 0)

-- 6. With Shift on a stack in the bags, what that stack sells for.
env.FakeBags({
    { bag = 0, slot = 1, id = 701, name = "Broken Fang", quality = 0, price = 125, count = 20 },
    { bag = 0, slot = 2, id = 702, name = "Lone Fang", quality = 0, price = 125 },
})
local shiftDown = false
_G.IsShiftKeyDown = function() return shiftDown end
local function HoverSlot(itemID, slot)
    GameTooltip._lines = {}
    local button = env.Stub({ GetBagID = function() return 0 end, GetID = function() return slot end })
    GameTooltip.GetOwner = function() return button end
    for _, call in ipairs(postCalls) do call.fn(GameTooltip, { id = itemID }) end
    return GameTooltip._lines
end
local function Find(found, text)
    for i, line in ipairs(found) do
        if tostring(line):find(text, 1, true) then return i end
    end
    return nil
end
lines = HoverSlot(701, 1)
suite.check("no stack line with Shift up", Find(lines, "Stack of") == nil, table.concat(lines, " / "))
shiftDown = true
lines = HoverSlot(701, 1)
local at = Find(lines, "Stack of 20: | ")
suite.check("Shift adds the stack's worth under each", at ~= nil and Find(lines, "Vendor Pays: ") == at - 1
    and lines[at]:find("25.-s") ~= nil, table.concat(lines, " / "))
suite.check("a single item gets no stack line", Find(HoverSlot(702, 2), "Stack of") == nil)
suite.check("a slot holding something else gets no stack line", Find(HoverSlot(701, 2), "Stack of") == nil)
GameTooltip.GetOwner = function() return nil end
shiftDown = false
_G.IsShiftKeyDown = nil

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
local stepper = ns.SettingsUI.controls.tooltipLines
local vendorBox = ns.SettingsUI.controls.vendorPrice
suite.check("Settings shows it Always", stepper:GetValue() == ns.TooltipShift.ALWAYS and vendorBox:GetChecked())
stepper:Pick(stepper:GetValue() - 1)
lines = Hover(2320)
suite.check("Shift holds it back", #lines == 1 and (lines[1] or ""):find("Shift") ~= nil, tostring(lines[1]))
stepper:Pick(stepper:GetValue() - 1)
suite.check("Off turns it off", ns.db.vendorPrice == false and #Hover(2320) == 0)
stepper:Pick(stepper:GetValue() + 1)
stepper:Pick(stepper:GetValue() + 1)
suite.check("Always turns it back on", ns.db.vendorPrice == true and #Hover(2320) == 3)

suite.check("the probe counts what it learned", VendorPrices:ProbeText():find("^2 learned") ~= nil,
    VendorPrices:ProbeText())

suite.done()
