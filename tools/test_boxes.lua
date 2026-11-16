-- The small boxes never open on top of each other, and one the player has
-- dragged opens where it was dropped (UI/Boxes.lua).

local env = dofile(lfs_cwd .. "/tools/testenv.lua")
local suite = env.NewSuite("boxes")

local ns = env.Load()
local Boxes = ns.Boxes

local function Box(left, top, width, height)
    local frame = CreateFrame("Frame", nil, UIParent)
    frame._shown = true
    function frame:GetLeft() return self._l end
    function frame:GetRight() return self._l + width end
    function frame:GetTop() return self._t end
    function frame:GetBottom() return self._t - height end
    function frame:SetPoint(_, _, _, x, y) self._l, self._t = x, y end
    frame._l, frame._t = left, top
    return frame
end

UIParent.GetRight = function() return 1600 end

local first = Box(700, 600, 300, 150)
local second = Box(710, 590, 300, 150)
Boxes.Add(first, "test.first")
Boxes.Add(second, "test.second")

suite.check("a box on another one moves", Boxes.Settle(second, "test.second") == true)
suite.check("it goes to the right of it", second._l == 700 + 300 + Boxes.GAP, second._l)
suite.check("with the tops level", second._t == 600, second._t)
suite.check("clear of it, it stays put", Boxes.Settle(second, "test.second") == false)

-- No room on the right: it goes to the left.
first._l, second._l, second._t = 1250, 1260, 590
Boxes.Settle(second, "test.second")
suite.check("no room on the right, it goes left", second._l == 1250 - Boxes.GAP - 300, second._l)

-- A hidden box is no one's neighbour.
first._l, first._shown = 700, false
second._l, second._t = 710, 590
suite.check("a hidden box moves no one", Boxes.Settle(second, "test.second") == false)

-- Dragged by the player: it stays where it was dropped.
first._shown = true
ns.db.windowSpots = { ["test.second"] = { x = 710, y = 590 } }
suite.check("a dragged box is kept", Boxes.Kept("test.second") == true)
suite.check("and never moved", Boxes.Settle(second, "test.second") == false and second._l == 710)
ns.db.windowSpots = nil

-- The three boxes sign up.
ns.BuyManyUI:Build()
ns.KeepAcrossUI:Build()
suite.check("nothing kept at first", Boxes.Kept("butler.buymany") == false)

suite.done()
