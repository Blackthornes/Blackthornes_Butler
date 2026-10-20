-- The Bags window's new item glow: only items that really came in glow.
--
-- What must hold:
--   1. After a /reload (the bags not read yet), nothing already carried is
--      new once the first read is done.
--   2. An item that comes in after that is new; a hover ends it.
--   3. With the game's own flag, Butler follows it: a slot the game calls
--      new glows, one it doesn't never does.
--   4. The game's flags left on old items (its veiled bags never cleared
--      them) are cleared at the first full read and when the window closes,
--      and an empty slot never glows.
--   5. The template's own blue glow is kept out of sight on our squares.

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

-- 4. Stale flags on everything after a reload.
flags = { ["0:1"] = true, ["0:2"] = true, ["0:3"] = true, ["0:4"] = true }
removed = {}
BagView.seen, BagView.looked = nil, {}
BagView:NoteSeen()
suite.check("the first read clears old flags", not BagView:IsNew(Bags.slots["0:1"])
    and not BagView:IsNew(Bags.slots["0:2"]) and not BagView:IsNew(Bags.slots["0:3"]))
suite.check("an empty slot is never new", not BagView:IsNew(nil) and not BagView:IsNew({ bag = 0, slot = 4 }))
flags["0:3"] = true
suite.check("loot after that glows", BagView:IsNew(Bags.slots["0:3"]))
BagView:ClearNew()
suite.check("closing the window clears it", not BagView:IsNew(Bags.slots["0:3"]) and not flags["0:3"])

-- 5. The template's own glow.
local shown, stopped = true, false
local fake = {
    NewItemTexture = { SetAlpha = function() end, Hide = function() shown = false end },
    flashAnim = { Stop = function() stopped = true end },
}
ns.BagWindow.QuietTemplateGlow(fake)
suite.check("the template's blue glow is hidden", not shown and stopped)

_G.C_NewItems = savedNewItems
suite.done()
