-- Butler's rows grow to fit their notes (a player's report, 2026-10-28: a
-- German note ran three lines and over the rows under it).
--
-- What must hold:
--   1. A short row keeps the usual height, and two lines still fit in it.
--   2. A row with a long note is taller, tall enough for every line.
--   3. Rows stack: each starts where the one above ends, so none overlap.
--   4. The list still scrolls to its last row, and a row that would run
--      past the foot waits for a scroll.
--   5. A list without heightFor lays out as before.

local env = dofile(lfs_cwd .. "/tools/testenv.lua")
local suite = env.NewSuite("rowfit")

local ns = env.Load()
env.Enable(ns)
local UI = ns.UI

-- 1. and 2. On a real Butler row.
local row = CreateFrame("Button")
row._width = 560
UI.CreateRow(row)
row.name:SetText("Linen Cloth")
row.reason:SetText("Sell it")
row.worth:SetText("1s")
suite.check("a short row keeps the usual height", UI.RowHeight(row) == 30, tostring(UI.RowHeight(row)))

-- About 150 pixels of room for the note: 40 characters is a line.
row.reason:SetText(string.rep("x", 60))
suite.check("two lines still fit the usual height", UI.RowHeight(row) == 30, tostring(UI.RowHeight(row)))

row.reason:SetText(string.rep("Ein sehr langer Grund ", 12))
local tall = UI.RowHeight(row)
local lines = math.ceil(ns.Theme.TextWidth("small", row.reason:GetText()) / (560 - 34 - 184 - 16 - 96 - 6))
suite.check("a long note makes the row taller", tall > 30, tostring(tall))
suite.check("tall enough for every line", tall >= lines * 13, tall .. " for " .. lines .. " lines")

row.reason:SetText("")
row.name:SetText(string.rep("Long item name ", 6))
suite.check("a long name grows the row too", UI.RowHeight(row) > 30, tostring(UI.RowHeight(row)))

-- 3. and 4. The list itself, with rows whose height the data gives.
local parent = CreateFrame("Frame")
local list = ns.Widgets.CreateRowList(parent, {
    rowHeight = 30,
    createRow = function(r) end,
    updateRow = function(r, data) r.want = data.h end,
    heightFor = function(r) return r.want end,
})
list._height = 200

local data = {}
for i = 1, 20 do data[i] = { i = i, h = (i % 3 == 0) and 70 or 30 } end
list:SetData(data)

local used, overlap, shown = 0, false, 0
for index, r in ipairs(list.rows) do
    if r:IsShown() then
        shown = shown + 1
        local point, _, _, x, y = r._point[1], nil, nil, r._point[2], r._point[3]
        if point ~= "TOPLEFT" or y ~= -used then overlap = true end
        used = used + r:GetHeight()
    end
end
suite.check("rows stack without overlap", not overlap)
suite.check("the rows on screen fit the list", used <= 200, tostring(used))
suite.check("tall rows are drawn tall", list.rows[3]:GetHeight() == 70, tostring(list.rows[3]:GetHeight()))
suite.check("as many rows as fit are shown", shown == 5, tostring(shown)) -- 30+30+70+30+30 = 190

local most = list:MaxOffset()
list.offset = most
list:Refresh()
local last
for _, r in ipairs(list.rows) do if r:IsShown() then last = r.data end end
suite.check("the last row can be scrolled to", last == data[20], last and tostring(last.i))
local total = 0
for i = most + 1, 20 do total = total + data[i].h end
suite.check("the end of the list fits on screen", total <= 200, tostring(total))
suite.check("one row further back would not fit", total + data[most].h > 200)

-- 5.
local plain = ns.Widgets.CreateRowList(parent, { rowHeight = 20 })
plain._height = 200
local many = {}
for i = 1, 50 do many[i] = { i = i } end
plain:SetData(many)
suite.check("a plain list still scrolls by whole rows", plain:MaxOffset() == 40, tostring(plain:MaxOffset()))

suite.done()
