-- An item the game can't load is asked for a few times, then left alone.
--
-- Butler asks the game to load an item it has no name or price for, and
-- judges every item again when the answer comes. The game also answers for
-- an item it does not have (taken out by a patch, say), and Butler then
-- asked again, was answered again and judged again, without end, for as
-- long as the window was open.

local env = dofile(lfs_cwd .. "/tools/testenv.lua")
local suite = env.NewSuite("itemload")

local ns = env.Load()
env.Enable(ns)
local fake = env.FakeBags({
    { bag = 0, slot = 1, id = 1, name = "Linen Cloth", count = 20, quality = 1, price = 13 },
    -- No price: the game has not loaded it, and here it never will.
    { bag = 0, slot = 2, id = 2, name = "Gone Thing", count = 1, quality = 1 },
})

-- Timers and the game's answers wait their turn, as they do in the game.
local queue = {}
_G.C_Timer.After = function(_, fn) queue[#queue + 1] = fn end
local asked = {}
_G.C_Item.RequestLoadItemDataByID = function(id)
    asked[id] = (asked[id] or 0) + 1
    queue[#queue + 1] = function() env.Fire("GET_ITEM_INFO_RECEIVED", id, false) end
end

--- Run what waits, up to `most` rounds. Returns the round it went quiet on.
local function Run(most)
    for round = 1, most do
        if #queue == 0 then return round end
        local now = queue
        queue = {}
        for _, fn in ipairs(now) do fn() end
    end
    return nil
end

ns.HandleSlash("")
suite.check("the window is up", ns.UI.frame and ns.UI.frame:IsShown())
local quiet = Run(200)
suite.check("Butler stops asking for an item the game can't load", quiet ~= nil,
    ("still asking after 200 rounds, asked %d times"):format(asked[2] or 0))
suite.check("it was asked for, a few times at most",
    (asked[2] or 0) >= 1 and (asked[2] or 0) <= ns.Items.MISSES, tostring(asked[2]))

local before = ns.Verdicts.version
ns.Verdicts:Changed(true)
Run(50)
suite.check("a later look does not ask again", asked[2] <= ns.Items.MISSES, tostring(asked[2]))
suite.check("or judge again and again", ns.Verdicts.version - before <= 2,
    tostring(ns.Verdicts.version - before))

-- An item that loads late is still read: a miss is only counted while the
-- game has nothing for it.
fake.Put({ bag = 0, slot = 3, id = 3, name = "Late Thing", count = 1, quality = 1 })
local late = 0
_G.C_Item.RequestLoadItemDataByID = function(id)
    if id ~= 3 then return end
    late = late + 1
    queue[#queue + 1] = function()
        fake.info[3].price = 40
        env.Fire("GET_ITEM_INFO_RECEIVED", 3, true)
    end
end
env.Fire("BAG_UPDATE_DELAYED")
Run(50)
suite.check("an item that loads is asked for once", late == 1, tostring(late))
suite.check("and its price is read", ns.Items:SellPrice(3) == 40, tostring(ns.Items:SellPrice(3)))
suite.check("with no miss kept against it", (ns.Items.missed[3] or 0) == 0)

suite.done()
