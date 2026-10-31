-- Butler's verdict marks and item rings (the owner said build it,
-- 2026-10-31, from the design review's mockups).
--
-- What must hold:
--   1. Each group heading wears its verdict's mark, its words in that colour.
--   2. An item row rings its icon in its quality and puts the count in the
--      corner, with no "x20" after the name.
--   3. A row drawn again as something else loses the mark, ring and count.
--   4. Every verdict Butler groups by has a mark.

local env = dofile(lfs_cwd .. "/tools/testenv.lua")
local suite = env.NewSuite("marks")

local ns = env.Load()
env.Enable(ns)
local UI, Marks, ItemLook = ns.UI, ns.Marks, ns.ItemLook

suite.check("both files load", Marks and ItemLook and true or false)

local row = CreateFrame("Frame", nil, UIParent)
UI.CreateRow(row)

-- 1.
UI.DrawRow(row, { type = "header", group = { verdict = "sell", label = "Sell", count = 3, worth = 120 } })
suite.check("a Sell heading wears the coin", Marks.KindOf(row.mark) == "sell" and row.mark:IsShown())
local color = row.name._color or {}
local r, g, b = color[1], color[2], color[3]
local mr, mg, mb = Marks.Color("sell")
suite.check("its words are the mark's colour", r == mr and g == mg and b == mb)
UI.DrawRow(row, { type = "header", group = { verdict = "wait", label = "Wait", count = 1, worth = 0 } })
suite.check("Wait wears the hourglass", Marks.KindOf(row.mark) == "waiting")

-- 2.
UI.DrawRow(row, { type = "item", name = "Linen Cloth", count = 20, quality = 2, worth = 260 })
suite.check("no mark on an item", not Marks.KindOf(row.mark) and not row.mark:IsShown())
suite.check("the name has no count", row.name:GetText() == "Linen Cloth", row.name:GetText())
suite.check("the count sits in the corner", ItemLook.CountShown(row.icon) == 20)
suite.check("the icon is ringed green", ItemLook.QualityShown(row.icon) == 2)

-- 3.
UI.DrawRow(row, { type = "header", group = { verdict = "keep", label = "Keep", count = 1, worth = 0 } })
suite.check("a heading drops the ring and count",
    ItemLook.QualityShown(row.icon) == nil and ItemLook.CountShown(row.icon) == nil)

-- 4.
for _, verdict in ipairs(ns.Verdicts.ORDER) do
    local kind = UI.MARK_FOR[verdict]
    suite.check("a mark for " .. verdict, kind and Marks.KINDS[kind] and true or false)
end

suite.done()
