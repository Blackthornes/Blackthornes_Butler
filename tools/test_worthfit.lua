-- The worth column on Butler's rows shows its whole text, never "...".
-- A Later row read "8s 00c, 1 not pr..." in game: the column was a fixed
-- 96 pixels. It now grows to its measured text, up to UI.WORTH_MOST, and
-- wraps past that.

local env = dofile(lfs_cwd .. "/tools/testenv.lua")
local suite = env.NewSuite("worthfit")

local ns = env.Load()
local UI, Theme = ns.UI, ns.Theme

local row = CreateFrame("Frame", nil, UIParent)
UI.CreateRow(row)

row.worth:SetText("8s 00c")
UI.FitWorth(row)
suite.check("a short worth keeps the usual width", row.worth:GetWidth() == UI.WORTH_WIDTH, row.worth:GetWidth())

local long = "8s 00c, 1 not priced yet"
row.worth:SetText(long)
UI.FitWorth(row)
suite.check("a longer worth gets the room it needs",
    row.worth:GetWidth() >= Theme.TextWidth("small", long) and row.worth:GetWidth() <= UI.WORTH_MOST,
    row.worth:GetWidth())

row.worth:SetText(string.rep("x", 200))
UI.FitWorth(row)
suite.check("never wider than WORTH_MOST", row.worth:GetWidth() == UI.WORTH_MOST, row.worth:GetWidth())

row.worth:SetText("")
UI.FitWorth(row)
suite.check("empty goes back to the usual width", row.worth:GetWidth() == UI.WORTH_WIDTH, row.worth:GetWidth())

suite.done()
