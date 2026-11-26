-- The mouse resting on a row whose reason is open, when the list draws
-- again (a sale, a bag change): the game hung, then said "script ran too
-- long" (2026-11-26). The list leaves and enters the row under a still
-- mouse; leaving closed the reason and drew the list, entering opened it
-- and drew the list, each draw doing both again, without end.

local env = dofile(lfs_cwd .. "/tools/testenv.lua")
local suite = env.NewSuite("reasonredraw")

local ns = env.Load()
local fake = env.FakeBags({
    { bag = 0, slot = 1, id = 301, name = "Torn Bear Pelt", quality = 0, price = 108, count = 2 },
    { bag = 0, slot = 2, id = 304, name = "Linen Cloth", quality = 1, price = 13, count = 9 },
})
fake.canSell = true
env.Enable(ns)
local UI, Verdicts = ns.UI, ns.Verdicts
Verdicts:SetChoice(304, "sell")
UI:Show()
-- Room for every row, so the open one is never pushed off the list.
UI.list._height = 2000
UI.list:Refresh()

local long = "Vendor pays more than the auction house after its cut (about 9c): 13c each, "
    .. "which is a lot of words for one small row"

--- The row drawn for Linen Cloth, with a reason too long for one line.
local function ClothRow()
    for _, row in ipairs(UI.list.rows) do
        if row:IsShown() and row.data and row.data.name == "Linen Cloth" then
            row.data.reason, row.data.tag = long, nil
            return row
        end
    end
end

local row = ClothRow()
suite.check("the Linen Cloth row is drawn", row ~= nil)
-- The mouse is on it, and stays.
row.IsVisible = function() return true end
row.IsMouseOver = function() return true end

local draws = 0
local refresh = UI.list.Refresh
UI.list.Refresh = function(...)
    draws = draws + 1
    if draws > 50 then error("the list drew without end") end
    return refresh(...)
end

local ok, err = pcall(function() row:GetScript("OnEnter")(row) end)
suite.check("the mouse on the row opens its reason", ok and UI.openRow == row.data, tostring(err))
suite.check("in a few draws", draws <= 4, draws)

-- The bags change under the still mouse: the list draws again.
draws = 0
ok, err = pcall(function() UI.list:Refresh() end)
suite.check("a redraw under a still mouse ends", ok, tostring(err))
suite.check("in a few draws", draws <= 4, draws)
suite.check("and the reason stays open", UI.openRow == row.data and row.full:IsShown())

-- A sale: every row is judged again, so the row holds new data.
draws = 0
ok, err = pcall(function()
    Verdicts:Changed(true)
    UI:Refresh(true)
end)
suite.check("a redraw with new rows ends too", ok, tostring(err))
suite.check("in a few draws", draws <= 6, draws)
suite.check("and no reason is left open for a row that is gone", UI.openRow == nil)

-- The new row has a long reason too: it opens again.
local was = row
row = ClothRow()
suite.check("the same row frame holds the new data", row == was)
draws = 0
ok, err = pcall(function() row:GetScript("OnEnter")(row) end)
suite.check("the new row's reason opens", ok and UI.openRow == row.data, tostring(err))
suite.check("in a few draws", draws <= 4, draws)

-- The mouse leaves for real: the reason closes.
row.IsMouseOver = function() return false end
draws = 0
ok, err = pcall(function() row:GetScript("OnLeave")(row) end)
suite.check("leaving the row closes it", ok and UI.openRow == nil, tostring(err))
suite.check("in a few draws", draws <= 3, draws)

suite.done()
