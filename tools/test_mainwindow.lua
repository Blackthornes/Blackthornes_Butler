-- The Butler window: it opens and closes, wears the house frame, remembers
-- where it was put, and says what it will show while the list is still to
-- come.

local env = dofile(lfs_cwd .. "/tools/testenv.lua")
local suite = env.NewSuite("mainwindow")

local ns = env.Load()
local UI = ns.UI

UI:Show()
suite.check("it opens", UI.frame:IsShown())
suite.check("the header says what it shows", UI.subtitle:GetText() == "Your bags", UI.subtitle:GetText())
suite.check("the empty list says what is coming",
    UI.emptyLabel:GetText():find("bags", 1, true) ~= nil)
suite.check("in a well sunk into the window", UI.well ~= nil)

-- The house frame: the name on the plate, the satchel in the portrait, and
-- a close gem in place of the old X.
local trim = UI.frame.titan
suite.check("the window wears the house frame", trim ~= nil)
suite.check("its name is on the plate", trim and trim.plate.label:GetText() == "Blackthornes Butler")
suite.check("with the portrait", trim and type(trim.portrait) == "table")
trim.closeButton:GetScript("OnClick")(trim.closeButton)
suite.check("the close gem closes it", not UI.frame:IsShown())

-- /bbutler window, and /bbutler on its own.
ns.HandleSlash("window")
suite.check("/bbutler window opens it", UI.frame:IsShown())
ns.HandleSlash("")
suite.check("/bbutler on its own closes it again", not UI.frame:IsShown())
ns.HandleSlash("")
suite.check("and opens it", UI.frame:IsShown())

-- Its place is remembered.
UI.frame._point = { "TOPLEFT", nil, "TOPLEFT", 120, -80 }
UI:SavePosition()
suite.check("where it was dragged is saved", ns.db.point == "TOPLEFT" and ns.db.x == 120)
UI:Hide()
UI:Show()
suite.check("and it opens there again", UI.frame._point[1] == "TOPLEFT" and UI.frame._point[4] == 120)

suite.done()
