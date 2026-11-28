-- A bind-on-equip piece worn and put back in the same bag slot comes back
-- soulbound, with the same link, count and lock. The bag read must see it:
-- Butler must not go on offering to mail or auction it.
--
-- What must hold:
--   1. A slot whose item became bound is read again, and says bound.
--   2. A slot whose item lost its value (or gained it) is read again.
--   3. A slot that only became a quest item through a bind change gets its
--      quest read again with it.
--   4. A slot where nothing changed is not read again (smooth play).

local env = dofile(lfs_cwd .. "/tools/testenv.lua")
local suite = env.NewSuite("bagbound")

local ns = env.Load()
local fake = env.FakeBags({
    { bag = 0, slot = 1, id = 901, name = "Bear Helm", quality = 2, price = 500, count = 1, equipLoc = "INVTYPE_HEAD", bind = 2 },
    { bag = 0, slot = 2, id = 902, name = "Linen Cloth", quality = 1, price = 13, count = 20, class = 7 },
})
env.Enable(ns)

local queued = {}
_G.C_Timer.After = function(_, fn) queued[#queued + 1] = fn end
local function Scan()
    ns.Bags:Scan()
    while #queued > 0 do
        local now = queued
        queued = {}
        for _, fn in ipairs(now) do fn() end
    end
end

local Bags = ns.Bags
Scan()
suite.check("the helm starts unbound", Bags.slots["0:1"] and Bags.slots["0:1"].bound == false)

-- 1. Worn and put back: same link, count and lock, now bound.
local before = Bags.version
local cloth = Bags.slots["0:2"]
fake.bags[0][1].bound = true
Scan()
suite.check("the read sees the helm is bound", Bags.slots["0:1"].bound == true)
suite.check("and the bags count as changed", Bags.version ~= before)
suite.check("its verdict is not mail or auction", (function()
    local v = ns.Verdicts:VerdictOf(Bags.slots["0:1"])
    return v ~= "mail" and v ~= "auction"
end)())

-- 2. No value.
fake.bags[0][1].noValue = true
Scan()
suite.check("the read sees it has no value", Bags.slots["0:1"].noValue == true)

-- 3. Quest read again with a bind change.
fake.bags[0][1].bound = false
fake.bags[0][1].quest = "item"
Scan()
suite.check("the quest is read again with it", Bags.slots["0:1"].quest == "item")

-- 4. Nothing changed: the cloth's entry is the same table.
suite.check("an unchanged slot is not read again", Bags.slots["0:2"] == cloth)
local still = Bags.version
Scan()
suite.check("a read with no change keeps the version", Bags.version == still)

suite.done()
