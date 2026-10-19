-- The trash can: while the bags are full, a small can sits on the stack
-- worth the least among what Butler would sell anyway (the owner asked
-- 2026-10-13).
--
-- What must hold:
--   1. Nothing while the bags have room, or while no bag window is open.
--   2. Full bags: the can sits on the cheapest stack, never a quest item.
--   3. Its tooltip says what it is worth and why.
--   4. A click only picks the item up; Butler never deletes anything.
--   5. A slot that changed, or a cursor already holding something, is left.
--   6. Hidden in combat and at a vendor.
--   7. Settings and /bbutler trash turn it off and on.
--   8. A trade good only wins when it is well under the junk (MATERIAL_LEAN).
--   9. Two short stacks of one item that fit together: the can says to
--      stack them, and a click joins them; nothing is picked up to throw.

local env = dofile(lfs_cwd .. "/tools/testenv.lua")
local suite = env.NewSuite("trash")

local ns = env.Load()
local fake = env.FakeBags({
    { bag = 0, slot = 1, id = 701, name = "Broken Fang", quality = 0, price = 12, count = 3 },
    { bag = 0, slot = 2, id = 702, name = "Ruined Pelt", quality = 0, price = 5 },
    { bag = 0, slot = 3, id = 703, name = "Old Letter", quality = 0, price = 1, quest = "item" },
    { bag = 0, slot = 4, id = 704, name = "Shiny Rock", quality = 0, price = 2, locked = true },
})

local freeSlots = 10
_G.C_Container.GetContainerNumFreeSlots = function(bag) return bag == 0 and freeSlots or 0, 0 end

local picked, deleted = {}, 0
_G.C_Container.PickupContainerItem = function(bag, slot) picked[#picked + 1] = bag .. ":" .. slot end
_G.DeleteCursorItem = function() deleted = deleted + 1 end
local holding = nil
_G.GetCursorInfo = function() return holding end

-- Retail's one bag window, listing its buttons.
_G.NUM_CONTAINER_FRAMES = 0
local buttons = {}
for slot = 1, 16 do
    buttons[slot] = env.Stub({
        GetBagID = function() return 0 end,
        GetID = function() return slot end,
        IsVisible = function() return true end,
        _width = 37,
    })
end
local bagWindow = env.Stub({ _shown = false })
bagWindow.EnumerateValidItems = function()
    local i = 0
    return function()
        i = i + 1
        if buttons[i] then return i, buttons[i] end
    end
end
_G.ContainerFrameCombinedBags = bagWindow

env.Enable(ns)
local Trash = ns.Trash
env.Fire("PLAYER_ENTERING_WORLD")

local function Showing()
    return Trash.can ~= nil and Trash.can:IsShown()
end

-- 1.
bagWindow._shown = true
env.Fire("BAG_UPDATE_DELAYED")
suite.check("no can while the bags have room", not Showing())

freeSlots = 1
bagWindow._shown = true
env.Fire("BAG_UPDATE_DELAYED")
suite.check("one free slot is not full, no can", not Showing())

freeSlots = 0
bagWindow._shown = false
env.Fire("BAG_UPDATE_DELAYED")
suite.check("no can while no bag window is open", not Showing())

-- 2.
bagWindow._shown = true
bagWindow._scripts.OnShow()
suite.check("full bags show the can", Showing())
local point = Trash.can._point
suite.check("on the cheapest stack, not the quest item or a locked one",
    point and point[2] == buttons[2], point and tostring(point[2]))
suite.check("Butler picked the Ruined Pelt", Trash.pick and Trash.pick.entry.itemID == 702)
suite.check("a red glow lies round the same slot",
    Trash.glow ~= nil and Trash.glow:IsShown() and Trash.glow:GetParent() == buttons[2]
        and Trash.glow._point and Trash.glow._point[2] == buttons[2])

-- 3.
GameTooltip._lines = {}
Trash.can:GetScript("OnEnter")(Trash.can)
local lines = table.concat(GameTooltip._lines, "\n")
suite.check("the tooltip says to throw it away", lines:find("Throw away to make room", 1, true) ~= nil, lines)
suite.check("and what it is worth", lines:find("the least in your bags", 1, true) ~= nil, lines)
suite.check("and why Butler would sell it", lines:find("Grey, vendor only", 1, true) ~= nil, lines)

-- 5. Something on the cursor already.
holding = "item"
Trash.can:GetScript("OnClick")(Trash.can)
suite.check("a full cursor is left alone", #picked == 0)
holding = nil

-- 4.
env.chat = {}
Trash.can:GetScript("OnClick")(Trash.can)
suite.check("a click picks the item up", picked[1] == "0:2", tostring(picked[1]))
suite.check("and nothing is deleted", deleted == 0)
holding = "item"
env.Fire("CURSOR_CHANGED")
suite.check("the can waits while the item is on the cursor", not Showing())
holding = nil
env.Fire("CURSOR_CHANGED")
suite.check("and comes back once it is put down", Showing())
suite.check("chat says how to throw it away",
    (env.chat[1] or ""):find("game will ask before it is destroyed", 1, true) ~= nil, env.chat[1])

-- 5. The slot changed under the can.
fake.bags[0][2] = { bag = 0, slot = 2, id = 705, name = "Pristine Pelt", quality = 1, price = 500 }
fake.info[705] = fake.bags[0][2]
local before = #picked
Trash:Take()
suite.check("a changed slot is not picked up", #picked == before)
fake.bags[0][2] = { bag = 0, slot = 2, id = 702, name = "Ruined Pelt", quality = 0, price = 5 }
env.Fire("BAG_UPDATE_DELAYED")
suite.check("and the can comes back once the bags are read", Showing())

-- 6.
env.Fire("PLAYER_REGEN_DISABLED")
suite.check("hidden in a fight", not Showing())
suite.check("the glow goes with it", not Trash.glow:IsShown() and Trash.glow:GetParent() == UIParent)
env.Fire("PLAYER_REGEN_ENABLED")
suite.check("back after it", Showing())
env.Fire("MERCHANT_SHOW")
suite.check("hidden at a vendor", not Showing())
env.Fire("MERCHANT_CLOSED")
suite.check("back when the vendor closes", Showing())

bagWindow._shown = false
bagWindow._scripts.OnHide()
suite.check("closing the bags hides it", not Showing())
bagWindow._shown = true
bagWindow._scripts.OnShow()

-- 7.
ns.HandleSlash("trash")
suite.check("/bbutler trash turns it off", ns.db.trashCan == false and not Showing())
ns.HandleSlash("settings")
local box = ns.SettingsUI.controls.trashCan
suite.check("the Settings box shows it off", box ~= nil and not box:GetChecked())
box:GetScript("OnClick")(box)
suite.check("ticking it turns it back on", ns.db.trashCan == true and Showing())

-- 8. A grey trade good a little cheaper than the pelt leaves the pelt.
local function Again()
    env.Fire("BAG_UPDATE_DELAYED")
end
fake.Put({ bag = 0, slot = 6, id = 710, name = "Frayed Cloth", quality = 0, price = 2, count = 2, class = 7 })
Again()
suite.check("cloth worth 4 against a pelt worth 5 leaves the pelt", Trash.pick and Trash.pick.entry.itemID == 702,
    tostring(Trash.pick and Trash.pick.entry.itemID))
fake.Put({ bag = 0, slot = 6, id = 710, name = "Frayed Cloth", quality = 0, price = 2, count = 1, class = 7 })
Again()
suite.check("cloth worth well under it is picked", Trash.pick and Trash.pick.entry.itemID == 710,
    tostring(Trash.pick and Trash.pick.entry.itemID))
fake.bags[0][6] = nil
Again()

-- 9. A second Broken Fang stack that the first fits on.
fake.Put({ bag = 0, slot = 5, id = 701, name = "Broken Fang", quality = 0, price = 12, count = 4 })
Again()
suite.check("two short stacks: the can says to stack them", Trash.pick and Trash.pick.merge == true)
suite.check("on the smaller stack", Trash.can._point and Trash.can._point[2] == buttons[1])
GameTooltip._lines = {}
Trash.can:GetScript("OnEnter")(Trash.can)
lines = table.concat(GameTooltip._lines, "\n")
suite.check("the tooltip says to stack them", lines:find("Stack these to make room", 1, true) ~= nil, lines)
suite.check("and never to throw away", lines:find("Throw away", 1, true) == nil, lines)
picked = {}
Trash.can:GetScript("OnClick")(Trash.can)
suite.check("a click picks up the small stack and drops it on the other",
    picked[1] == "0:1" and picked[2] == "0:5", table.concat(picked, ","))
suite.check("and nothing is deleted", deleted == 0)

-- A full stack beside a short one: nothing to stack, back to throwing away.
fake.Put({ bag = 0, slot = 5, id = 701, name = "Broken Fang", quality = 0, price = 12, count = 18, stack = 20 })
Again()
suite.check("stacks that don't fit together are left", Trash.pick and not Trash.pick.merge
    and Trash.pick.entry.itemID == 702, tostring(Trash.pick and Trash.pick.entry.itemID))

suite.done()
