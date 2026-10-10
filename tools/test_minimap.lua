-- The minimap button.
--
-- It is the way into the addon that does not involve typing, so what matters
-- is that it opens the settings, that dragging it remembers where it was put,
-- and that it can be got rid of and brought back, across a reload too.

local env = dofile(lfs_cwd .. "/tools/testenv.lua")
local suite = env.NewSuite("minimap")

local ns = env.Load()
_G.UnitClass = function() return "Hunter", "HUNTER" end

local MB, SettingsUI = ns.MinimapButton, ns.SettingsUI

-- PLAYER_LOGIN, as the client runs it.
for _, module in ipairs(ns.moduleOrder) do
    if module.OnEnable then module:OnEnable() end
end

local button = MB.button
suite.check("the button is built", button ~= nil)
suite.check("it is parented to the minimap", button._parent == Minimap)
suite.check("it starts visible", button:IsShown())
suite.check("it does not start on top of Farmer's and Tradeskills'",
    math.abs(ns.db.minimapAngle - math.rad(200)) > 0.1, ns.db.minimapAngle)
suite.check("or Equipment's",
    math.abs(ns.db.minimapAngle - math.rad(230)) > 0.1, ns.db.minimapAngle)

-- Clicking.
local click = button:GetScript("OnClick")
suite.check("settings start closed", not (SettingsUI.frame and SettingsUI.frame:IsShown()))
click(button, "LeftButton")
suite.check("a click opens the pets window", ns.UI.frame:IsShown())
click(button, "LeftButton")
suite.check("a second click closes it", not ns.UI.frame:IsShown())
click(button, "RightButton")
suite.check("a right-click opens them too", SettingsUI.frame:IsShown())
SettingsUI:Hide()

-- Tooltip.
button:GetScript("OnEnter")(button)
local lines = GameTooltip._lines
suite.check("the tooltip names the addon", lines[1] == "Blackthornes Butler", lines[1])
suite.check("then its version", lines[2] == ns.VersionLabel(), lines[2])
suite.check("and what a click does", lines[3] == "Click to open", lines[3])
suite.check("and a right-click", lines[4] == "Right-click for settings", lines[4])


-- Dragging round the ring. The stub cursor sits due east of the minimap's
-- centre, so one update swings the button to angle 0.
local startingAngle = ns.db.minimapAngle
button:GetScript("OnDragStart")(button)
suite.check("dragging is flagged", button.dragging == true)
button:GetScript("OnUpdate")(button)
suite.check("dragging moves it to the cursor's angle",
    math.abs(ns.db.minimapAngle) < 0.001, ns.db.minimapAngle)
suite.check("the angle changed", ns.db.minimapAngle ~= startingAngle)
button:GetScript("OnDragStop")(button)
suite.check("releasing stops following the cursor",
    button.dragging == false and button:GetScript("OnUpdate") == nil)

-- The orbit clears the ring on any size of minimap.
local function OrbitDistance()
    local x, y = button._point[4], button._point[5]
    return math.sqrt(x * x + y * y)
end
MB:Reposition()
local defaultDistance = OrbitDistance()
suite.check("it orbits outside a default minimap", defaultDistance > 70, defaultDistance)
Minimap._width = 240
MB:Reposition()
suite.check("a larger minimap pushes it further out", OrbitDistance() > defaultDistance)
Minimap._width = 140

-- Hiding it.
ns.HandleSlash("minimap")
suite.check("/bbutler minimap hides it", not button:IsShown())
suite.check("and the choice is saved", ns.db.minimapHidden == true)
ns.HandleSlash("minimap")
suite.check("/bbutler minimap brings it back", button:IsShown())

-- Hidden has to survive a reload: the button is rebuilt at every login.
ns.db.minimapHidden = true
MB.button = nil
MB:Build()
suite.check("a hidden button stays hidden after a reload", not MB.button:IsShown())

suite.done()
