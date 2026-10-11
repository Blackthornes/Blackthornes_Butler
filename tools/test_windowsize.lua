-- The window's size: dragged at the grip below its bottom right corner,
-- saved account wide, kept on the screen, and the Sell button drawn at it.

local env = dofile(lfs_cwd .. "/tools/testenv.lua")
local suite = env.NewSuite("windowsize")

local ns = env.Load()
env.Enable(ns)

local UI = ns.UI

suite.check("sizes are kept between 60% and 150%",
    UI.ClampScale(0.2) == 0.6 and UI.ClampScale(3) == 1.5 and UI.ClampScale(1.234) == 1.23)
suite.check("a size that is not a number is the normal size", UI.ClampScale("big") == 1 and UI.ClampScale(0 / 0) == 1)
suite.check("the size reads as a percent", UI.ScaleText(0.85) == "85%")

UI:Show()
suite.check("the window has its size grip", UI.sizeGrip ~= nil)

UI:SetWindowScale(1.2)
suite.check("a size is saved", ns.db.windowScale == 1.2)

UI:SetWindowScale(1)
suite.check("right-click's normal size is saved too", ns.db.windowScale == 1)
UI:Hide()

suite.done()
