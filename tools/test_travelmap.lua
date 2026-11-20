-- The trip line on the world map (UI/TravelMap.lua, the same file in all
-- five addons). Found 2026-11-20: `local x, y = from and Place(...)` keeps
-- only the first value, so y was always nil, Draw raised inside its pcall
-- and the line and dots never showed.
--
-- What must hold:
--   1. Draw runs without an error for a trip with a leg, a stop and a place.
--   2. The stop and the place each get a dot, at the spot the map gave.
--   3. A leg with no start (where you stand is unknown) draws no line and
--      raises nothing.

local env = dofile(lfs_cwd .. "/tools/testenv.lua")
local suite = env.NewSuite("travelmap")

local ns = env.Load()
local TravelMap = ns.TravelMap

local canvas = CreateFrame("Frame", nil, UIParent)
local legs = {
    { kind = "walk", from = { continent = 1, north = 10, west = 10 },
        to = { continent = 1, north = 20, west = 20 }, stop = true },
}
local plan = { key = "test", done = 0, steps = {}, place = { continent = 1, north = 30, west = 30 } }

local keep = { Trip = TravelMap.Trip, WorldView = TravelMap.WorldView, Spot = TravelMap.Spot,
    Legs = TravelMap.Legs, Here = ns.Travel.Host.Here }
TravelMap.Trip = function() return { plan = plan } end
TravelMap.WorldView = function() return { canvas = canvas, mapID = 1, width = 1000, height = 600 } end
-- The map's answer: two values, x and y, as shares of the map.
TravelMap.Spot = function(_, _, north) return north / 100, north / 50 end
TravelMap.Legs = function() return legs end
ns.Travel.Host.Here = function() return { continent = 1, north = 10, west = 10 } end

local function Shown(list)
    local count = 0
    for _, item in ipairs(list or {}) do
        if item:IsShown() then count = count + 1 end
    end
    return count
end

TravelMap:Clear()
local ok, err = pcall(TravelMap.Draw, TravelMap)
suite.check("the trip draws without an error", ok, tostring(err))
local layer = TravelMap.layer
suite.check("the stop and the place each get a dot", layer ~= nil and Shown(layer.dots) == 2,
    layer and tostring(Shown(layer.dots)) or "no layer")

-- A leg that starts nowhere known: no line, no error, the dots stay.
legs[1].from = nil
plan.key = "test2"
ok, err = pcall(TravelMap.Draw, TravelMap)
suite.check("a leg with no start raises nothing", ok, tostring(err))
suite.check("its stop and the place still get dots", TravelMap.layer ~= nil and Shown(TravelMap.layer.dots) == 2)

-- No place on the plan: only the stop's dot.
plan.place = nil
plan.key = "test3"
ok, err = pcall(TravelMap.Draw, TravelMap)
suite.check("a plan with no place raises nothing", ok, tostring(err))
suite.check("only the stop's dot is left", TravelMap.layer ~= nil and Shown(TravelMap.layer.dots) == 1)

TravelMap:Clear()
TravelMap.Trip, TravelMap.WorldView, TravelMap.Spot, TravelMap.Legs = keep.Trip, keep.WorldView, keep.Spot, keep.Legs
ns.Travel.Host.Here = keep.Here

suite.done()
