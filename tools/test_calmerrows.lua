-- Calmer rows (the owner said build it, 2026-11-26):
--   1. An item row shows a short tag in one line: the rule's own tag, else
--      the reason when it fits, else its first part, else nothing; never a
--      cut word.
--   2. The mouse on an item row opens its whole reason under it, and the
--      row grows to fit; leaving closes it.
--   3. Two or more greys under Sell fold into one line, "N grey items",
--      with their worth; a click shows each one, a second hides them.
--   4. A sale slides its row out and the Sell heading counts the gold up;
--      Effects Off skips the motion and shows the sum at once.

local env = dofile(lfs_cwd .. "/tools/testenv.lua")
local suite = env.NewSuite("calmerrows")

local ns = env.Load()
local fake = env.FakeBags({
    { bag = 0, slot = 1, id = 301, name = "Torn Bear Pelt", quality = 0, price = 108, count = 2 },
    { bag = 0, slot = 2, id = 302, name = "Small Pocket Watch", quality = 0, price = 87 },
    { bag = 0, slot = 3, id = 303, name = "Cracked Pottery", quality = 0, price = 47 },
    { bag = 0, slot = 4, id = 304, name = "Linen Cloth", quality = 1, price = 13, count = 9 },
})
fake.canSell = true
env.Enable(ns)
local UI, Verdicts, Motion = ns.UI, ns.Verdicts, ns.Motion
ns.UI:Show()

-- 1.
local long = "Vendor pays more than the auction house after its cut (about 9c): 13c each, "
    .. "which is a lot of words for one small row"
suite.check("the rule's own tag wins", UI.Tag({ tag = "Vendor pays more", reason = long }) == "Vendor pays more")
suite.check("a reason that fits shows whole", UI.Tag({ reason = "Grey, vendor only" }, 400) == "Grey, vendor only")
suite.check("a long one shows its first part", UI.Tag({ reason = long }, Theme and 400 or 400)
    == "Vendor pays more than the auction house after its cut")
suite.check("nothing rather than a cut word", UI.Tag({ reason = long }, 10) == "")
suite.check("a row with no reason has no tag", UI.Tag({}) == "")

-- 3.
Verdicts:SetChoice(304, "sell")
local function Lines() return UI:Lines() end
local greys, after
for i, line in ipairs(Lines()) do
    if line.type == "greys" then greys, after = line, Lines()[i + 1] end
end
suite.check("three greys fold into one line", greys and greys.count == 3, greys and greys.count)
suite.check("worth all of them together", greys and greys.worth == 216 + 87 + 47, greys and greys.worth)
suite.check("after the other Sell rows", (function()
    local seenCloth, order = false, true
    for _, line in ipairs(Lines()) do
        if line.name == "Linen Cloth" then seenCloth = true end
        if line.type == "greys" and not seenCloth then order = false end
    end
    return seenCloth and order
end)())
suite.check("the greys are not listed one by one yet", (function()
    for _, line in ipairs(Lines()) do if line.name == "Small Pocket Watch" then return false end end
    return true
end)())
local row = UI.list.rows[1]
UI.DrawRow(row, greys)
suite.check("the line reads 3 grey items", row.name:GetText() == "3 grey items", row.name:GetText())
suite.check("with their names beside it", row.reason:GetText():find("Small Pocket Watch", 1, true) ~= nil)
UI:Clicked(greys, "LeftButton")
suite.check("a click shows each one", (function()
    for _, line in ipairs(Lines()) do if line.name == "Small Pocket Watch" then return true end end
end)() == true)
for _, line in ipairs(Lines()) do
    if line.type == "greys" then UI:Clicked(line, "LeftButton") end
end
suite.check("a second click folds them again", UI.greysOpen == nil)
Verdicts:SetChoice(301, "keep")
local one = 0
for _, line in ipairs(Lines()) do if line.type == "greys" then one = one + 1 end end
suite.check("two greys still fold", one == 1)
Verdicts:SetChoice(302, "keep")
one = 0
for _, line in ipairs(Lines()) do if line.type == "greys" then one = one + 1 end end
suite.check("one grey alone keeps its own row", one == 0)
Verdicts:SetChoice(301, nil)
Verdicts:SetChoice(302, nil)

-- 2.
local cloth
for _, line in ipairs(Lines()) do if line.name == "Linen Cloth" then cloth = line end end
cloth.reason = long
local before = UI.RowHeight((function() UI.DrawRow(row, cloth) return row end)())
UI:OpenReason(row, cloth)
suite.check("the mouse on a row with more to say opens it", UI.openRow == cloth)
UI.DrawRow(row, cloth)
suite.check("the whole reason shows under the row", row.full:IsShown() and row.full:GetText() == long)
suite.check("and the row grows to fit it", UI.RowHeight(row) > before, UI.RowHeight(row) .. " " .. before)
row.data = cloth
UI:Left(row)
suite.check("leaving the row closes it", UI.openRow == nil)
UI.DrawRow(row, cloth)
suite.check("and the reason is gone", not row.full:IsShown())
cloth.reason = "Grey, vendor only"
UI:OpenReason(row, cloth)
suite.check("a row whose tag says it all opens nothing", UI.openRow == nil)

-- 4.
env.Fire("MERCHANT_SHOW")
ns.Selling.soldWorth = 350
Motion.SetLevel("off")
UI:Sold({ itemID = 302 })
suite.check("Effects Off shows the sum at once", UI.soldShown == 350)
local header
for _, line in ipairs(Lines()) do
    if line.type == "header" and line.group.verdict == "sell" then header = line end
end
UI.DrawRow(row, header)
suite.check("the Sell heading says what sold", row.reason:GetText():find("+", 1, true) ~= nil, row.reason:GetText())
Motion.SetLevel(nil)
ns.Selling.soldWorth = 0
UI.DrawRow(row, header)
suite.check("nothing sold, no sum", row.reason:GetText():find("+", 1, true) == nil)

-- A sold row slides out with Effects Full.
local sold
for _, line in ipairs(Lines()) do if line.name == "Linen Cloth" then sold = line end end
row.data = sold
UI.DrawRow(row, sold)
row.IsShown = function() return true end
local rows = UI.list.rows
UI.list.rows = { row }
ns.Selling.soldWorth = 117
UI:Sold({ itemID = 304 })
suite.check("the sold row is marked leaving", sold.leaving == true)
suite.check("and slides", Motion:Running(row, "leave"))
Motion:Step(1)
suite.check("fading out", row.top:GetAlpha() < 1, row.top:GetAlpha())
suite.check("the heading counted up to the sum", math.floor(UI.soldShown + 0.5) == 117, UI.soldShown)
UI.DrawRow(row, { type = "item", name = "Silk Cloth", count = 1, quality = 1, worth = 10, reason = "x" })
suite.check("a row handed new data comes back in place", row.top:GetAlpha() == 1)
UI.list.rows = rows

suite.done()
