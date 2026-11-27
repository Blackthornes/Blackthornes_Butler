-- A player's report (2026-11-27): a new crafted pair of Toughened Leather
-- Gloves was kept as "In your equipment set" while the set's own pair was
-- worn. Butler read sets by item, so every copy counted.
--
-- What must hold:
--   1. With the set's copy worn, a bag copy is judged like any other item.
--   2. The set's own copy in the bags is still Keep.
--   3. A set copy the game can't find, or a client that won't say where,
--      still keeps every copy.

local env = dofile(lfs_cwd .. "/tools/testenv.lua")
local suite = env.NewSuite("setcopy")

local ns = env.Load()
env.FakeBags({
    { bag = 0, slot = 1, id = 4253, name = "Toughened Leather Gloves", quality = 2, price = 400 },
    { bag = 0, slot = 2, id = 4253, name = "Toughened Leather Gloves", quality = 2, price = 400 },
})
-- Packed spots as the game keeps them: worn on the hands, or bag 0 slot 2.
local WORN, INBAG = 0x00100000 + 10, 0x00300000 + 2
local spots = { [10] = WORN }
C_EquipmentSet = {
    GetEquipmentSetIDs = function() return { 3 } end,
    GetEquipmentSetInfo = function(id) return id == 3 and "Tank" or nil end,
    GetItemIDs = function(id) return id == 3 and { [10] = 4253 } or {} end,
    GetItemLocations = function() return spots end,
}
EquipmentManager_UnpackLocation = function(location)
    if location == WORN then return true, false, false, false, 10, nil end
    if location == INBAG then return true, false, true, false, 2, 0 end
end
env.Enable(ns)
local Verdicts = ns.Verdicts
local SET_WORDS = "In your Tank equipment set"

local function Why(slot) return select(2, Verdicts:Judge(ns.Bags.ReadSlot(0, slot))) end
local function Again()
    Verdicts:SetsChanged()
    Verdicts:Changed(true)
end

-- 1.
Again()
suite.check("with the set's pair worn, a bag pair is not held for the set",
    Why(1) ~= SET_WORDS, tostring(Why(1)))
suite.check("nor the other bag pair", Why(2) ~= SET_WORDS, tostring(Why(2)))

-- 2.
spots = { [10] = INBAG }
Again()
suite.check("the set's own pair in the bags is still kept", Why(2) == SET_WORDS, tostring(Why(2)))
suite.check("the other pair is not", Why(1) ~= SET_WORDS, tostring(Why(1)))

-- 3.
spots = { [10] = -1 }
Again()
suite.check("a set pair the game can't find keeps every pair", Why(1) == SET_WORDS, tostring(Why(1)))
spots = { [10] = WORN }
EquipmentManager_UnpackLocation = nil
Again()
suite.check("a client that won't say where keeps every pair", Why(1) == SET_WORDS, tostring(Why(1)))
EquipmentManager_GetLocationData = function(location)
    if location == WORN then return { isPlayer = true, isBags = false, slot = 10 } end
end
Again()
suite.check("the newer helper reads it worn too", Why(1) ~= SET_WORDS, tostring(Why(1)))

C_EquipmentSet, EquipmentManager_GetLocationData = nil, nil
suite.done()
