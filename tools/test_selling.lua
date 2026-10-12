-- Selling: only at a vendor, only the Sell group, only with a click, a stack
-- a click until the selling test says the game lets Butler sell up to 12.

local env = dofile(lfs_cwd .. "/tools/testenv.lua")
local suite = env.NewSuite("selling")

local ns = env.Load()
local items = {}
for slot = 1, 15 do
    items[#items + 1] = { bag = 0, slot = slot, id = 200 + slot, name = "Junk " .. slot,
        quality = 0, price = 10 }
end
items[#items + 1] = { bag = 0, slot = 16, id = 300, name = "Linen Cloth", quality = 1, price = 13 }
local fake = env.FakeBags(items)
fake.canSell = true
env.Enable(ns)

local Selling, UI = ns.Selling, ns.UI

-- Placed by screen position over the window's foot.
local function Place(frame)
    frame.GetRight = function() return 800 end
    frame.GetBottom = function() return 200 end
end

-- At a vendor, the window comes up by itself.
env.Fire("MERCHANT_SHOW")
suite.check("the window comes up at a vendor", UI:IsShown() and UI.openedByVendor)
Place(UI.frame)
Selling:Update()
local button = Selling.button
suite.check("with the Sell button", button and button:IsShown())
suite.check("over the window's foot, not anchored to it", button._point[2] == UIParent)
suite.check("in a layer above the window, so the window never covers it",
    button:GetFrameStrata() == "FULLSCREEN_DIALOG" and UI.frame:GetFrameStrata() == "DIALOG")
suite.check("which names the stack it sells", button.label:GetText() == "Sell Junk 1", button.label:GetText())
suite.check("and the version label makes room", not UI.versionLabel:IsShown())

-- A click: the secure button gets one /use line, set just before.
button:GetScript("PreClick")(button)
suite.check("one stack a click, through a /use line", button:GetAttribute("type") == "macro"
    and button:GetAttribute("macrotext") == "/use 0 1")
button:GetScript("PostClick")(button)
suite.check("nothing is left aimed at a slot after", button:GetAttribute("macrotext") == nil)
suite.check("counted", Selling.sold == 1)

-- A slot that changed under the button is left alone.
fake.bags[0][1] = { bag = 0, slot = 1, id = 300, name = "Linen Cloth", quality = 1, price = 13 }
button:GetScript("PreClick")(button)
local aimed = button:GetAttribute("macrotext")
suite.check("a slot holding something else now is skipped", aimed ~= nil and aimed ~= "/use 0 1", aimed)
button:GetScript("PostClick")(button)

-- White items never go unless the player said so.
local queue = Selling:Queue()
local white = false
for _, item in ipairs(queue) do if item.itemID == 300 then white = true end end
suite.check("Look at it items are never in the queue", not white)

-- Leaving the vendor takes the window and the button away.
env.Fire("MERCHANT_CLOSED")
suite.check("the window that came up for the vendor goes", not UI:IsShown())
suite.check("and the Sell button", not button:IsShown())
button:GetScript("PreClick")(button)
suite.check("a click away from a vendor sells nothing", button:GetAttribute("type") == nil)

-- In combat the button hides and sells nothing.
env.Fire("MERCHANT_SHOW")
Place(UI.frame)
Selling:Update()
_G.InCombatLockdown = function() return true end
env.Fire("PLAYER_REGEN_DISABLED")
suite.check("hidden in combat", not button:IsShown())
_G.InCombatLockdown = nil
env.Fire("PLAYER_REGEN_ENABLED")
suite.check("back after", button:IsShown())

-- The selling test: sells the cheapest grey and keeps what happened.
fake.used = {}
ns.HandleSlash("selltest")
suite.check("the test sold one grey", #fake.used == 1)
suite.check("and found selling works", ns.db.sellTest.result == "works")
suite.check("so the button sells a batch", button.label:GetText():find("^Sell") ~= nil
    and Selling:CanSellBatch())

-- One click sells up to 12, so all of them can be bought back.
fake.used = {}
env.Fire("BAG_UPDATE_DELAYED")
button:GetScript("PreClick")(button)
suite.check("a batch needs no /use line", button:GetAttribute("type") == nil)
button:GetScript("PostClick")(button)
suite.check("one click sells at most 12", #fake.used == 12, #fake.used)
for _, place in ipairs(fake.used) do
    local slot = tonumber(place:match(":(%d+)$"))
    suite.check("only greys were sold (" .. place .. ")", items[slot].id ~= 300 and slot ~= 16)
end

-- The window that the player opened stays when the vendor closes.
env.Fire("MERCHANT_CLOSED")
UI:Show()
env.Fire("MERCHANT_SHOW")
env.Fire("MERCHANT_CLOSED")
suite.check("a window the player opened stays open", UI:IsShown())

-- Open at a vendor, unticked.
-- At every vendor, even with nothing under Sell (asked 2026-10-10), and it
-- goes again when the vendor closes.
UI:Hide()
fake.bags[0] = {}
env.Fire("BAG_UPDATE_DELAYED")
env.Fire("MERCHANT_SHOW")
suite.check("it comes up with nothing to sell", UI:IsShown() and UI.openedByVendor)
suite.check("with no Sell button", not button:IsShown())
env.Fire("MERCHANT_CLOSED")
suite.check("and goes when the vendor closes", not UI:IsShown())

ns.db.openAtVendor = false
env.Fire("MERCHANT_SHOW")
suite.check("with Open at a vendor off, it stays shut", not UI:IsShown())

suite.done()
