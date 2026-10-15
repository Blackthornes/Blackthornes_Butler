-- Buy on the Buy from a vendor row (the owner asked 2026-10-14 for
-- Tradeskills' Buy materials button, the one over the vendor window, in
-- Butler too).
--
-- What must hold:
--   1. Away from a vendor, or without Tradeskills, the row is as before
--      and has no button.
--   2. At a vendor with something for the queue, the row says what and how
--      much, and has Buy; its tooltip lists each material.
--   3. A vendor with nothing says so, and why when the auction house has it
--      for less; no button.
--   4. Buy is Tradeskills' own run; it says Buying... until the run is over.
--   5. Nothing in combat; an error from Tradeskills shows nothing and buys
--      nothing.

local env = dofile(lfs_cwd .. "/tools/testenv.lua")
local suite = env.NewSuite("vendor buy")

local ns = env.Load()
env.FakeBags({})
_G.C_Item.GetItemNameByID = function(id)
    return ({ [2321] = "Fine Thread", [2320] = "Coarse Thread", [3371] = "Empty Vial" })[id]
end
local Jobs, UI = ns.Jobs, ns.UI

local offer
local buys, buyAnswer = 0, { true }
_G.BlackthornesTS = { Butler = {
    Advise = function() return nil end,
    Holdings = function() return {} end,
    Mailbox = function() end,
    Jobs = function()
        return { { name = "Ana Blackthorne", isCurrent = true, steps = {
            { kind = "craft", recipeID = 21, itemID = 9001, name = "Thing", count = 1, forNames = {},
              ready = false, missing = { { itemID = 2321, count = 4, vendor = 10 } } } } } }
    end,
    VendorOffer = function() return offer end,
    BuyFromVendor = function()
        buys = buys + 1
        return buyAnswer[1], buyAnswer[2]
    end,
} }
env.Enable(ns)
Jobs:Changed()

local function BuyStep()
    for _, row in ipairs(Jobs:Lines()) do
        if row.type == "job" and row.step.kind == "buy" then return row.step end
    end
end

local step = BuyStep()
suite.check("the craft's thread is a Buy from a vendor step", step ~= nil)

-- 1. Away from a vendor.
ns.Selling.merchantOpen = false
offer = { count = 1, cost = 40, items = { { itemID = 2321, amount = 4, cost = 40 } }, cheaperElsewhere = 0 }
suite.check("away from a vendor nothing is read", Jobs:VendorOffer() == nil and Jobs.vendorKey == "")
suite.check("and no button", not Jobs.Buyable(step))
suite.check("the line is as before", Jobs.VendorText(step) == nil)

-- 2. At a vendor with the thread.
ns.Selling.merchantOpen = true
Jobs:VendorOffer()
suite.check("the offer is read", Jobs.offer and Jobs.offer.count == 1 and Jobs.offer.cost == 40)
suite.check("Buy shows", Jobs.Buyable(step))
local text = Jobs.VendorText(step)
suite.check("the line says what this vendor has", text:find("Buy 4 Fine Thread here", 1, true) ~= nil, text)
local tip = Jobs.BuyTooltip()
suite.check("the tooltip lists each material", tip:find("4 Fine Thread", 1, true) ~= nil, tip)
local key = Jobs.vendorKey
suite.check("the redraw key follows the offer", key ~= "")

-- The window draws Buy on the row.
local row = CreateFrame("Button")
UI.CreateRow(row)
UI.UpdateRow(row, { type = "job", step = step })
suite.check("the row has the Buy button", row.action:IsShown() and row.action.label:GetText() == "Buy",
    row.action.label:GetText())

-- 3. A vendor with nothing for the queue.
offer = { count = 0, cost = 0, items = {}, cheaperElsewhere = 0 }
Jobs:VendorOffer()
suite.check("no button at a vendor with nothing", not Jobs.Buyable(step))
UI.UpdateRow(row, { type = "job", step = step })
suite.check("and the row hides it", not row.action:IsShown())
text = Jobs.VendorText(step)
suite.check("it says this vendor doesn't sell it", text:find("doesn't sell", 1, true) ~= nil, text)
offer.cheaperElsewhere = 1
Jobs:VendorOffer()
text = Jobs.VendorText(step)
suite.check("or that the auction house has it for less", text:find("auction house", 1, true) ~= nil, text)
suite.check("the key moved", Jobs.vendorKey ~= key)

-- 4. Buying.
offer = { count = 1, cost = 40, items = { { itemID = 2321, amount = 4, cost = 40 } }, cheaperElsewhere = 0 }
Jobs:VendorOffer()
UI:Show("bags")
local looks = 0
local refresh = UI.Refresh
UI.Refresh = function(self, ...)
    looks = looks + 1
    if looks == 2 then offer = { count = 0, cost = 0, items = {}, cheaperElsewhere = 0 } end
    if looks == 1 then offer = { count = 0, cost = 0, items = {}, cheaperElsewhere = 0, buying = true } end
    return refresh(self, ...)
end
suite.check("Buy runs Tradeskills' buy", Jobs:BuyAtVendor() == true and buys == 1)
UI.Refresh = refresh
suite.check("it looks again until the run is over", looks == 2, looks)
offer = { count = 0, cost = 0, items = {}, cheaperElsewhere = 0, buying = true }
Jobs:VendorOffer()
suite.check("while buying the button stays", Jobs.Buyable(step))
suite.check("and the line says so", Jobs.VendorText(step):find("Buying", 1, true) ~= nil)

env.chat = {}
buyAnswer = { false, "no vendor is open" }
Jobs:BuyAtVendor()
suite.check("a reason handed back is said", env.ChatText():find("no vendor is open", 1, true) ~= nil)

-- 5. Combat and errors.
_G.InCombatLockdown = function() return true end
buys = 0
Jobs:BuyAtVendor()
suite.check("nothing is bought in combat", buys == 0)
_G.InCombatLockdown = nil
_G.BlackthornesTS.Butler.BuyFromVendor = function() error("boom") end
suite.check("an error buys nothing", Jobs:BuyAtVendor() == false)
_G.BlackthornesTS.Butler.VendorOffer = function() error("boom") end
suite.check("an error reads no offer", Jobs:VendorOffer() == nil and not Jobs.Buyable(step))
_G.BlackthornesTS.Butler.VendorOffer = function() return { items = "junk", cost = "x" } end
Jobs:VendorOffer()
suite.check("an offer of the wrong shape has nothing to buy", not Jobs.Buyable(step))

ns.Selling.merchantOpen = false
_G.BlackthornesTS = nil
suite.done()
