-- Settings rows that share one row (2026-11-16): the bag helpers, What's
-- New and the tooltip lines. Their ticks flow under the label and wrap at
-- the column's width, and each keeps the saved key it always had.

local env = dofile(lfs_cwd .. "/tools/testenv.lua")
local suite = env.NewSuite("settingsrows")

local ns = env.Load()
ns.HandleSlash("settings")
local SettingsUI = ns.SettingsUI
local controls = SettingsUI.controls

local function Tick(box) box:GetScript("OnClick")(box) end

-- The flow wraps and the row grows by the lines used.
local grown
local row = { compactHeight = 24, Grow = function(_, by) grown = by end }
local function Fake(width)
    local placed = {}
    return { GetWidth = function() return width end, ClearAllPoints = function() end,
        SetPoint = function(_, _, x, y) placed.x, placed.y = x, y end, placed = placed }
end
local a, b, c = Fake(150), Fake(150), Fake(150)
local lines = SettingsUI.Flow(row, { a, b, c })
suite.check("two fit on a line, the third wraps", lines == 2 and a.placed.y == -24 and b.placed.y == -24
    and b.placed.x == 150 + SettingsUI.FLOW_GAP and c.placed.x == 0 and c.placed.y == -24 - SettingsUI.FLOW_LINE)
suite.check("the row grows by its lines", grown == 2 * SettingsUI.FLOW_LINE)

-- Each tick writes the key it always did.
suite.check("the helpers start as saved", controls.freeSpace:GetChecked() and controls.trashCan:GetChecked()
    and not controls.swapWhenFull:GetChecked())
Tick(controls.trashCan)
suite.check("Trash Can unticked saves trashCan off", ns.db.trashCan == false and ns.db.freeSpace ~= false)
Tick(controls.swapWhenFull)
suite.check("Swap When Full ticked saves swapWhenFull on", ns.db.swapWhenFull == true)
Tick(controls.whatsNewMotion)
suite.check("Motion unticked turns What's New's motion off", ns.WhatsNew:IsMotionOn() == false)
Tick(controls.whatsNewPopup)
suite.check("After Updates unticked turns the pop-up off", ns.WhatsNew:IsOn() == false)

-- The search finds a shared row by a tick's words.
local pages = SettingsUI.pages
pages:Search("trash can")
local lit = 0
for _, entry in ipairs(pages.searchables) do
    if entry.glow:IsShown() then lit = lit + 1 end
end
suite.check("searching a tick's name lights its row", lit >= 1)
pages:Search("")

suite.done()
