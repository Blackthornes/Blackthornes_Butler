-- What the game hands back is kept whole (2026-11-24). Butler reads the
-- client inside a pcall. The answers were put in a table and unpacked, and
-- a table loses its length when an answer in the middle is nil and the last
-- ones are nil too: the loot window's quality, locked and quest flags, and
-- a mail's days left, could all read as nil.
--
-- What must hold:
--   1. Items.Call gives back every value, nils in the middle and at the end.
--   2. Locked loot is never offered a swap, whatever follows the flag.
--   3. The game's quest flag counts, whatever follows it.
--   4. A mail's days left are read when the header starts and ends in nils.
--   5. A call that raises still gives nothing.

local env = dofile(lfs_cwd .. "/tools/testenv.lua")
local suite = env.NewSuite("clientreturns")

local ns = env.Load()
local fake = env.FakeBags({
    { bag = 0, slot = 1, id = 701, name = "Broken Fang", quality = 0, price = 12, count = 3 },
    { bag = 0, slot = 2, id = 702, name = "Ruined Pelt", quality = 0, price = 5 },
})
fake.info[801] = { id = 801, name = "Ringed Helm", quality = 2, price = 300, stack = 1 }
fake.info[902] = { id = 902, name = "Murloc Fin", quality = 1, price = 0, stack = 1 }

_G.C_Container.GetContainerNumFreeSlots = function() return 0, 0 end
local loot = {}
local function Link(id, name) return ("|cffffffff|Hitem:%d::::::::|h[%s]|h|r"):format(id, name) end
_G.GetNumLootItems = function() return #loot end
_G.GetLootSlotType = function() return 1 end
_G.GetLootSlotLink = function(slot) local item = loot[slot]; return item and Link(item.id, item.name) end
-- As the game answers: no currency (nil), then quality, locked, the quest
-- flag, and no quest (nil, nil) at the end.
_G.GetLootSlotInfo = function(slot)
    local item = loot[slot]
    if not item then return nil end
    return 134400, item.name, 1, nil, item.quality or 1, item.locked or false,
        item.questFlag or false, nil, nil
end
_G.LootSlot = function() end
_G.LootFrame = env.Stub({ _shown = true })

env.Enable(ns)
local Swap = ns.SwapWhenFull
env.Fire("PLAYER_ENTERING_WORLD")
ns.db.swapWhenFull = true

local function Showing() return Swap.frame ~= nil and Swap.frame:IsShown() end
local function Open(items)
    env.Fire("LOOT_CLOSED")
    loot = items
    env.Fire("LOOT_OPENED")
end

-- 1.
_G.ButlerTestHoles = function() return "a", nil, "c", nil, 5, nil, nil end
local a, b, c, d, e, f, g = ns.Items.Call({ "ButlerTestHoles" })
suite.check("Items.Call keeps values past a nil", a == "a" and b == nil and c == "c" and d == nil and e == 5,
    tostring(a) .. " " .. tostring(c) .. " " .. tostring(e))
suite.check("and the nils at the end stay nil", f == nil and g == nil)

-- 2.
Open({ { id = 801, name = "Ringed Helm", quality = 2, locked = true } })
suite.check("locked loot is not offered", not Showing())
Open({ { id = 801, name = "Ringed Helm", quality = 2 } })
suite.check("the same loot unlocked is offered", Showing() and Swap.loot.itemID == 801)

-- 3.
Open({ { id = 902, name = "Murloc Fin", questFlag = true } })
suite.check("the game's quest flag counts", Showing() and Swap.loot and Swap.loot.itemID == 902 and Swap.loot.quest)

-- 4.
_G.GetInboxNumItems = function() return 1 end
_G.GetInboxHeaderInfo = function()
    -- No package icon, money only, never read, not from a GM.
    return nil, nil, "Bob Wither", nil, 15000, 0, 4.6, nil, nil, nil, nil, nil, nil
end
local info = ns.MailContents:Read(1)
suite.check("a mail's days left are read", info ~= nil and info.daysLeft == 4.6, tostring(info and info.daysLeft))
suite.check("and its gold", info ~= nil and info.money == 15000)

-- 1, again: the count.
suite.check("it gives back as many values as the game did",
    select("#", ns.Items.Call({ "ButlerTestHoles" })) == 7,
    tostring(select("#", ns.Items.Call({ "ButlerTestHoles" }))))

-- 5.
_G.ButlerTestHoles = function() error("secret") end
suite.check("a call that raises gives nothing", select("#", ns.Items.Call({ "ButlerTestHoles" })) <= 1
    and ns.Items.Call({ "ButlerTestHoles" }) == nil)

suite.done()
