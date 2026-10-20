-- The Bags window's new item glow: only items that really came in glow.
--
-- What must hold:
--   1. After a /reload (the bags not read yet), nothing already carried is
--      new once the first read is done.
--   2. An item that comes in after that is new; a hover ends it.
--   3. With the game's own flag, Butler follows it: a slot the game calls
--      new glows, one it doesn't never does, reload or not.

local env = dofile(lfs_cwd .. "/tools/testenv.lua")
local suite = env.NewSuite("bagnewglow")

local ns = env.Load()
env.FakeBags({
    { bag = 0, slot = 1, id = 802, name = "Linen Cloth", quality = 1, price = 13, count = 20, class = 7 },
    { bag = 0, slot = 2, id = 804, name = "Iron Sword", quality = 1, price = 300, class = 2, equipLoc = "INVTYPE_WEAPON" },
})
env.Enable(ns)

local BagView, Bags = ns.BagView, ns.Bags
local savedNewItems = _G.C_NewItems
_G.C_NewItems = nil

-- 1. A /reload: nothing read yet.
Bags.slots, Bags.stale, BagView.seen, BagView.looked = {}, true, nil, {}
BagView:NoteSeen()
Bags:Scan()
local linen = Bags.slots["0:1"]
suite.check("the first read is done", linen ~= nil)
suite.check("what was carried is not new", not BagView:IsNew(linen) and not BagView:IsNew(Bags.slots["0:2"]))

-- 2. Something comes in.
env.FakeBags({
    { bag = 0, slot = 1, id = 802, name = "Linen Cloth", quality = 1, price = 13, count = 20, class = 7 },
    { bag = 0, slot = 2, id = 804, name = "Iron Sword", quality = 1, price = 300, class = 2, equipLoc = "INVTYPE_WEAPON" },
    { bag = 0, slot = 3, id = 805, name = "Wool Cloth", quality = 1, price = 20, count = 2, class = 7 },
})
Bags.stale = true
Bags:Scan()
local wool = Bags.slots["0:3"]
suite.check("a new item is new", wool ~= nil and BagView:IsNew(wool))
suite.check("a hover says it was new", BagView:Saw(wool) == true)
suite.check("and it stops glowing", not BagView:IsNew(wool))

-- 3. The game's own flag.
local flags, removed = { ["0:2"] = true }, {}
_G.C_NewItems = {
    IsNewItem = function(bag, slot) return flags[bag .. ":" .. slot] or false end,
    RemoveNewItem = function(bag, slot) removed[#removed + 1] = bag .. ":" .. slot; flags[bag .. ":" .. slot] = nil end,
}
BagView.seen, BagView.looked = nil, {}
suite.check("the game's flag lights its slot", BagView:IsNew(Bags.slots["0:2"]))
suite.check("an unflagged slot stays dark, even before any count", not BagView:IsNew(Bags.slots["0:1"])
    and not BagView:IsNew(Bags.slots["0:3"]))
BagView:Saw(Bags.slots["0:2"])
suite.check("a hover clears it, as the game's bags do", removed[1] == "0:2" and not BagView:IsNew(Bags.slots["0:2"]))

_G.C_NewItems = savedNewItems
suite.done()
