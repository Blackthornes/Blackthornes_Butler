-- The Throw Away button: a gold plaque under the bag window that throws
-- away the item the trash can is on (the owner said build it, 2026-11-06).
--
-- What must hold:
--   1. Off unless ticked; Settings turns it on.
--   2. Nothing while the bags have room or no bag window is open.
--   3. Full bags: it names the can's item and its worth, under the bags.
--   4. The first click only turns it red, Click Again; nothing is deleted.
--   5. The second click destroys that item only, and says so in chat.
--   6. A slot that changed, or a cursor holding another item: nothing deleted.
--   7. Green or better is never destroyed: Pick Up, the game asks.
--   8. Two short stacks: Stack These, one click, nothing deleted.
--   9. Hidden in a fight, at a vendor and while the cursor holds something.

local env = dofile(lfs_cwd .. "/tools/testenv.lua")
local suite = env.NewSuite("throwaway")

local ns = env.Load()
local fake = env.FakeBags({
    { bag = 0, slot = 1, id = 701, name = "Broken Fang", quality = 0, price = 12, count = 3 },
    { bag = 0, slot = 2, id = 702, name = "Ruined Pelt", quality = 0, price = 5 },
})

local freeSlots = 10
_G.C_Container.GetContainerNumFreeSlots = function(bag) return bag == 0 and freeSlots or 0, 0 end

local picked, deleted = {}, 0
local holding, heldID, heldFrom = nil, nil, nil
local swapItem = nil
_G.C_Container.PickupContainerItem = function(bag, slot)
    picked[#picked + 1] = bag .. ":" .. slot
    if holding then holding, heldID, heldFrom = nil, nil, nil; return end
    local item = swapItem or (fake.bags[bag] and fake.bags[bag][slot])
    if item then holding, heldID, heldFrom = "item", item.id, { bag, slot } end
end
_G.DeleteCursorItem = function()
    deleted = deleted + 1
    if heldFrom then fake.bags[heldFrom[1]][heldFrom[2]] = nil end
    holding, heldID, heldFrom = nil, nil, nil
end
_G.GetCursorInfo = function() return holding, heldID end

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
bagWindow.GetLeft = function() return 900 end
bagWindow.GetBottom = function() return 200 end
bagWindow.EnumerateValidItems = function()
    local i = 0
    return function()
        i = i + 1
        if buttons[i] then return i, buttons[i] end
    end
end
_G.ContainerFrameCombinedBags = bagWindow

env.Enable(ns)
-- The red Click Again waits its seconds: hold timers until a test runs them.
local timers = {}
local runNow = _G.C_Timer.After
_G.C_Timer.After = function(delay, fn)
    if delay == ns.ThrowAway.ARMED then timers[#timers + 1] = fn else runNow(delay, fn) end
end
local Throw, Trash = ns.ThrowAway, ns.Trash
env.Fire("PLAYER_ENTERING_WORLD")

local function Showing() return Throw.button ~= nil and Throw.button:IsShown() end
local function Again() env.Fire("BAG_UPDATE_DELAYED") end
local function Lines()
    local b = Throw.button
    return env.Plain(b.first:GetText() or ""), env.Plain(b.second:GetText() or "")
end
local function Click() Throw.button:GetScript("OnClick")(Throw.button) end

-- 1.
freeSlots = 0
bagWindow._shown = true
bagWindow._scripts.OnShow()
suite.check("the can shows", Trash.can ~= nil and Trash.can:IsShown())
suite.check("off unless ticked", ns.db.throwAwayButton ~= true and not Showing())
ns.HandleSlash("settings")
local box = ns.SettingsUI.controls.throwAwayButton
suite.check("Settings has the box, unticked", box ~= nil and not box:GetChecked())
box:GetScript("OnClick")(box)
suite.check("ticking it turns it on", ns.db.throwAwayButton == true)
Again()

-- 3.
suite.check("full bags: the plaque shows", Showing())
local first, second = Lines()
suite.check("it names the pelt", first:find("Throw Away", 1, true) ~= nil and first:find("Ruined Pelt", 1, true) ~= nil, first)
suite.check("and says it is the least", second:find("the least in your bags", 1, true) ~= nil, second)
local point = Throw.button._point
suite.check("under the bag window", point and point[2] == UIParent and point[4] == 900, point and tostring(point[4]))

-- 2.
freeSlots = 1
Again()
suite.check("room in the bags: gone", not Showing())
freeSlots = 0
bagWindow._shown = false
bagWindow._scripts.OnHide()
suite.check("no bag window: gone", not Showing())
bagWindow._shown = true
bagWindow._scripts.OnShow()
suite.check("back with the bags", Showing())

-- 4.
Click()
first, second = Lines()
suite.check("first click: Click Again", first == "Click Again", first)
suite.check("and names what goes", second:find("Ruined Pelt", 1, true) ~= nil, second)
suite.check("nothing picked up or deleted yet", #picked == 0 and deleted == 0)
suite.check("red while armed", Throw.button.red:IsShown())
Throw.button:GetScript("OnLeave")(Throw.button)
suite.check("moving off lets go", not Throw.armed)
Click()
for _, fn in ipairs(timers) do fn() end
timers = {}
suite.check("and so does the time running out", not Throw.armed and deleted == 0)

-- 6. A changed slot.
Click()
local realRead = ns.Bags.ReadSlot
ns.Bags.ReadSlot = function(bag, slot)
    local s = realRead(bag, slot)
    if s and bag == 0 and slot == 2 then s = setmetatable({ key = "changed" }, { __index = s }) end
    return s
end
Click()
ns.Bags.ReadSlot = realRead
suite.check("a changed slot: nothing deleted", deleted == 0 and #picked == 0, tostring(#picked))
Again()

-- 6. The cursor brings up another item.
Click()
swapItem = { id = 705 }
Click()
swapItem = nil
suite.check("the wrong item: nothing deleted", deleted == 0, tostring(deleted))
suite.check("and it is put back", holding == nil and #picked == 2, table.concat(picked, ","))
Again()

-- 5.
picked = {}
env.chat = {}
suite.check("showing again", Showing())
Click()
Click()
suite.check("second click destroys the pelt", deleted == 1 and fake.bags[0][2] == nil and picked[1] == "0:2",
    table.concat(picked, ","))
suite.check("chat says so", (env.chat[1] or ""):find("Threw away", 1, true) ~= nil, env.chat[1])
Again()
suite.check("the next cheapest comes up", Showing() and Trash.pick and Trash.pick.entry.itemID == 701,
    tostring(Trash.pick and Trash.pick.entry.itemID))

-- 7.
local green = { entry = { itemID = 801, quality = 2, count = 1, bag = 0, slot = 1 }, row = { name = "Ringed Helm" }, worth = 300 }
suite.check("green or better is Pick Up", Throw.Mode(green) == "pickup")
first, second = Throw.Lines(green)
first, second = env.Plain(first), env.Plain(second)
suite.check("Pick Up line", first:find("Pick Up", 1, true) ~= nil, first)
suite.check("the game asks", second:find("The game asks", 1, true) ~= nil, second)
local before = deleted
Throw.pick = green
local took = 0
local realTake = Trash.Take
Trash.Take = function() took = took + 1 end
Throw:Click()
Trash.Take = realTake
suite.check("a click picks it up through the can, no delete", took == 1 and deleted == before)
Again()

-- 8.
fake.Put({ bag = 0, slot = 5, id = 701, name = "Broken Fang", quality = 0, price = 12, count = 4 })
Again()
suite.check("two short stacks: Stack These", Trash.pick and Trash.pick.merge and Showing())
first, second = Lines()
suite.check("the words", first:find("Stack These", 1, true) ~= nil and second == "Nothing is thrown away", first .. " / " .. second)
picked = {}
Click()
suite.check("one click joins them", picked[1] == "0:1" and picked[2] == "0:5", table.concat(picked, ","))
suite.check("nothing deleted", deleted == before)
fake.bags[0][5] = nil
Again()

-- 9.
suite.check("showing before the fight", Showing())
env.Fire("PLAYER_REGEN_DISABLED")
suite.check("hidden in a fight", not Showing())
env.Fire("PLAYER_REGEN_ENABLED")
Again()
env.Fire("MERCHANT_SHOW")
suite.check("hidden at a vendor", not Showing())
env.Fire("MERCHANT_CLOSED")
Again()
holding = "item"
env.Fire("CURSOR_CHANGED")
suite.check("hidden while the cursor holds something", not Showing())
holding = nil
env.Fire("CURSOR_CHANGED")
suite.check("back once it is put down", Showing())

suite.done()
