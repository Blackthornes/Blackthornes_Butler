-- Gear Equipment calls an upgrade for the character playing is kept, but
-- only as many copies as it wears (a player had five of the same robe all
-- kept, 2026-10-18). The rest get their own verdict, so they can go to
-- the auction house or a vendor.
--
-- What must hold:
--   1. One robe is kept; the other four go where they would otherwise.
--   2. Two rings are kept: a character wears two.
--   3. A soulbound copy is the one kept, since it can't be sold.
--   4. A spare copy of an upgrade to wear now can be sold too.

local env = dofile(lfs_cwd .. "/tools/testenv.lua")
local suite = env.NewSuite("upgradecopies")

local ns = env.Load()
local fake = env.FakeBags({
    { bag = 0, slot = 1, id = 4035, name = "Lesser Wizard's Robe", quality = 2, price = 1338 },
    { bag = 0, slot = 2, id = 4035, name = "Lesser Wizard's Robe", quality = 2, price = 1338 },
    { bag = 0, slot = 3, id = 4035, name = "Lesser Wizard's Robe", quality = 2, price = 1338 },
    { bag = 0, slot = 4, id = 4035, name = "Lesser Wizard's Robe", quality = 2, price = 1338 },
    { bag = 0, slot = 5, id = 4035, name = "Lesser Wizard's Robe", quality = 2, price = 1338 },
    { bag = 0, slot = 6, id = 406, name = "Copper Band", quality = 2, price = 50 },
    { bag = 0, slot = 7, id = 406, name = "Copper Band", quality = 2, price = 50 },
    { bag = 0, slot = 8, id = 406, name = "Copper Band", quality = 2, price = 50 },
    { bag = 0, slot = 9, id = 701, name = "Thendal Boots", quality = 2, price = 300 },
    { bag = 0, slot = 10, id = 701, name = "Thendal Boots", quality = 2, price = 300, bound = true },
})
local instant = C_Item.GetItemInfoInstant
C_Item.GetItemInfoInstant = function(id)
    local a, b, c, _, e, f, g = instant(id)
    return a, b, c, id == 406 and "INVTYPE_FINGER" or "INVTYPE_CHEST", e, f, g
end

_G.BlackthornesTS = { Butler = { Advise = function(_, id)
    if id == 4035 then return { auction = 5000 } end
    return { auction = 0 }
end } }
_G.BlackthornesEquipment = { Butler = { Advise = function(_, link)
    local text = tostring(link)
    if text:find("4035", 1, true) then return { upgrade = "later", gain = 12 } end
    if text:find("406", 1, true) then return { upgrade = "later" } end
    if text:find("701", 1, true) then return { upgrade = "now" } end
end } }
env.Enable(ns)
local Verdicts, UI = ns.Verdicts, ns.UI

local function Count(verdict, itemID)
    local group = Verdicts:Group(verdict)
    local n = 0
    for _, row in ipairs(group and group.rows or {}) do
        if row.itemID == itemID then n = n + row.count end
    end
    return n
end

UI:Show("bags")

-- 1.
suite.check("one robe is kept", Count("keep", 4035) == 1, Count("keep", 4035))
suite.check("four robes go to the auction house", Count("auction", 4035) == 4, Count("auction", 4035))

-- 2.
suite.check("two rings are kept", Count("keep", 406) == 2, Count("keep", 406))
suite.check("the third ring is its own", Count("keep", 406) + Count("sell", 406) == 3 and Count("sell", 406) == 1,
    Count("sell", 406))

-- 3 and 4.
local boundBoots = ns.Bags.ReadSlot(0, 10)
local looseBoots = ns.Bags.ReadSlot(0, 9)
suite.check("the soulbound boots are the pair kept", Verdicts:VerdictOf(boundBoots) == "keep",
    Verdicts:VerdictOf(boundBoots))
suite.check("the spare pair to wear now can be sold", Verdicts:VerdictOf(looseBoots) == "sell",
    Verdicts:VerdictOf(looseBoots))

-- A click asks again and agrees with the window.
suite.check("a spare robe reads as Auction when a click checks it",
    Verdicts:VerdictOf(ns.Bags.ReadSlot(0, 5)) == "auction", Verdicts:VerdictOf(ns.Bags.ReadSlot(0, 5)))

_G.BlackthornesEquipment = nil
_G.BlackthornesTS = nil
suite.done()
