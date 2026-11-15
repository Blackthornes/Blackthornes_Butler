-- Reset This Item: the right-click menu's last row clears every choice the
-- player made for one item, after a second click, and nothing else.

local env = dofile(lfs_cwd .. "/tools/testenv.lua")
local suite = env.NewSuite("resetitem")

local ns = env.Load()
env.FakeBags({
    { bag = 0, slot = 1, id = 2840, name = "Copper Bar", count = 20, price = 10, stack = 20 },
    { bag = 0, slot = 2, id = 2589, name = "Linen Cloth", count = 5, price = 13, stack = 20 },
})
local GUID = "Player-1-0000AAAA"
_G.UnitGUID = function(unit) if unit == "player" then return GUID end end
_G.UnitName = function() return "Mirelda Stormvale" end
env.Enable(ns)

local Verdicts, UI, KeepHere, KeepAcross = ns.Verdicts, ns.UI, ns.KeepHere, ns.KeepAcross
local printed = {}
local oldPrint = ns.Print
ns.Print = function(...) printed[#printed + 1] = table.concat({ ... }, " ") end

-- Nothing chosen: the row still shows, dim, and a click does nothing.
UI:Show()
UI:ShowMenu({ itemID = 2840, name = "Copper Bar" })
local empty = UI.menu.decide
suite.check("the reset row shows on an item with no choices", empty:IsShown() and empty.empty == true)
empty:GetScript("OnClick")(empty)
suite.check("a click with nothing to reset does nothing",
    not empty.armed and empty.label:GetText() == "Reset This Item", empty.label:GetText())
UI:HideMenu()

-- Choices of every kind for Copper Bar, and one for Linen Cloth.
Verdicts:SetChoice(2840, "sell")
KeepHere:Set(2840, 10)
KeepAcross:Set(2840, 40)
ns.db.noUpgradeMail = ns.db.noUpgradeMail or {}
ns.db.noUpgradeMail[2840] = { ["Dorgan Ashbrook"] = true }
Verdicts:SellAnyway(2840)
Verdicts:SetChoice(2589, "keep")
ns.db.sellBelow = 5000

UI:ShowMenu({ itemID = 2840, name = "Copper Bar" })
local row = UI.menu.decide
local heldTimers, runTimers = {}, _G.C_Timer.After
_G.C_Timer.After = function(_, fn) heldTimers[#heldTimers + 1] = fn end
suite.check("the row shows and reads Reset This Item", row:IsShown() and row.label:GetText() == "Reset This Item",
    row.label:GetText())
row:GetScript("OnClick")(row)
suite.check("the first click arms it to Confirm", row.armed and row.label:GetText() == "Confirm")
suite.check("and changes nothing yet", Verdicts:Choice(2840) == "sell" and KeepHere:Count(2840) == 10)
row:GetScript("OnClick")(row)

_G.C_Timer.After = runTimers
suite.check("the second click clears the Always list", Verdicts:Choice(2840) == nil)
suite.check("and the keep numbers", (KeepHere:Count(2840) or 0) == 0 and (KeepAcross:Count(2840) or 0) == 0)
suite.check("and the held mail", ns.db.noUpgradeMail[2840] == nil)
suite.check("and Sell Anyway", not Verdicts.sellAnyway[2840])
suite.check("other items are left alone", Verdicts:Choice(2589) == "keep")
suite.check("global settings are left alone", ns.db.sellBelow == 5000)
suite.check("chat says so", printed[#printed] and printed[#printed]:find("Butler will decide for", 1, true) ~= nil,
    printed[#printed])
suite.check("nothing left to reset", not Verdicts:HasOwnChoices(2840))

-- A fresh menu starts unarmed.
UI:ShowMenu({ itemID = 2589, name = "Linen Cloth" })
suite.check("a new menu starts unarmed", not UI.menu.decide.armed and UI.menu.decide.label:GetText() == "Reset This Item")
UI:HideMenu()

ns.Print = oldPrint
suite.done()
