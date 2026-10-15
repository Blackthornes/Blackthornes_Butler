-- The Open button for clams, sacks and lockboxes, and opening after loot.
--
-- What must hold:
--   1. Only slots with loot are offered, never what is kept on purpose: the
--      Always keep list, quest items, a Farmer goal's or the craft queue's
--      needs, a locked lockbox.
--   2. The button is an icon inside the window, "Open" on hover, aimed at
--      one slot just before the click and at nothing after.
--   3. Never in combat, nor at a vendor (a /use there sells).
--   4. Opening after loot runs only when ticked and the test said it works,
--      and leaves alone one that stayed shut.

local env = dofile(lfs_cwd .. "/tools/testenv.lua")
local suite = env.NewSuite("opening")

local ns = env.Load()
env.FakeBags({
    { bag = 0, slot = 1, id = 701, name = "Small Barnacled Clam", quality = 1, price = 0, count = 3, loot = true },
    { bag = 0, slot = 2, id = 702, name = "Bag of Marbles", quality = 1, price = 5, loot = true },
    { bag = 0, slot = 3, id = 703, name = "Thick-shelled Clam", quality = 1, price = 0, loot = true },
    { bag = 0, slot = 4, id = 704, name = "Battered Junkbox", quality = 1, price = 0, loot = true },
    { bag = 0, slot = 5, id = 705, name = "Linen Cloth", quality = 1, price = 13, count = 20 },
    { bag = 0, slot = 6, id = 706, name = "Sealed Crate", quality = 1, price = 0, loot = true, quest = "item" },
})
env.Enable(ns)

local Opening, UI, Bags = ns.Opening, ns.UI, ns.Bags

-- A Farmer goal wants the marbles; the junkbox is still locked.
_G.BlackthornesFarmer = { Butler = { Advise = function(_, id)
    if id == 702 then return { goal = "Bag of Marbles", have = 1, target = 5, need = 4 } end
end } }
_G.LOCKED = "Locked"
_G.C_TooltipInfo = { GetBagItem = function(bag, slot)
    if bag == 0 and slot == 4 then return { lines = { { leftText = "Battered Junkbox" }, { leftText = "Locked" } } } end
    return { lines = {} }
end }

UI:Show()
Bags:Scan()

-- 1. What is offered.
local function Offered()
    local ids = {}
    for _, entry in ipairs((Opening:Queue())) do ids[#ids + 1] = entry.itemID end
    return table.concat(ids, ",")
end
suite.check("clams with loot are offered, in bag order", Offered() == "701,703", Offered())
local _, total = Opening:Queue()
suite.check("counting every one in a stack", total == 4, total)

ns.Verdicts:SetChoice(703, "keep")
suite.check("the Always keep list keeps it shut", Offered() == "701", Offered())
ns.Verdicts:SetChoice(703, nil)
suite.check("and off the list it is offered again", Offered() == "701,703", Offered())

_G.BlackthornesTS = { Butler = { Advise = function(_, id)
    if id == 701 then return { need = 2 } end
end } }
ns.Verdicts:Changed(true)
suite.check("a craft the queue needs keeps it shut", Offered() == "703", Offered())
_G.BlackthornesTS = nil
ns.Verdicts:Changed(true)

-- 2. The button.
UI:FootRoom()
local button = Opening.button
suite.check("the Open button shows", button and button:IsShown())
suite.check("inside the window", button:GetParent() == UI.frame)
suite.check("no words on it", button.label:GetText() == "")
suite.check("the count in its corner", button.count:GetText() == "4", button.count:GetText())
local said
GameTooltip.SetText = function(_, text) said = text end
button:GetScript("OnEnter")(button)
suite.check("Open on hover", said == "Open", tostring(said))

button:GetScript("PreClick")(button)
suite.check("a click uses the first clam", button:GetAttribute("type") == "macro"
    and button:GetAttribute("macrotext") == "/use 0 1", button:GetAttribute("macrotext"))
button:GetScript("PostClick")(button)
suite.check("nothing left aimed after", button:GetAttribute("type") == nil
    and button:GetAttribute("macrotext") == nil)

-- A slot that changed under the button is skipped.
env.bags.bags[0][1] = { bag = 0, slot = 1, id = 705, name = "Linen Cloth", quality = 1, price = 13 }
button:GetScript("PreClick")(button)
suite.check("a slot holding something else now is skipped", button:GetAttribute("macrotext") == "/use 0 3",
    button:GetAttribute("macrotext"))
button:GetScript("PostClick")(button)
env.bags.bags[0][1] = { bag = 0, slot = 1, id = 701, name = "Small Barnacled Clam", quality = 1, price = 0,
    count = 3, loot = true }

-- 3. Combat and vendors.
_G.InCombatLockdown = function() return true end
env.Fire("PLAYER_REGEN_DISABLED")
suite.check("hidden in combat", not button:IsShown())
_G.InCombatLockdown = nil
env.Fire("PLAYER_REGEN_ENABLED")
suite.check("back after", button:IsShown())

ns.Selling.merchantOpen = true
UI:FootRoom()
suite.check("hidden at a vendor, where /use would sell", not button:IsShown())
button:GetScript("PreClick")(button)
suite.check("and a click there aims at nothing", button:GetAttribute("macrotext") == nil)
ns.Selling.merchantOpen = false
UI:FootRoom()

Opening:SetOn(false)
suite.check("unticked, it hides", not button:IsShown())
Opening:SetOn(true)
suite.check("ticked, it is back", button:IsShown())

UI.view = "all"
UI:FootRoom()
suite.check("not on All characters", not button:IsShown())
UI.view = "bags"
UI:FootRoom()

-- 4. The test and opening after loot.
local used = {}
_G.C_Container.UseContainerItem = function(bag, slot)
    used[#used + 1] = bag .. ":" .. slot
    local item = env.bags.bags[bag][slot]
    if item then
        item.count = (item.count or 1) - 1
        if item.count < 1 then env.bags.bags[bag][slot] = nil end
    end
end
Opening:Test()
suite.check("the test opens one from addon code", used[1] == "0:1", used[1])
suite.check("and keeps what it found", ns.db.openTest and ns.db.openTest.result == "works")

used = {}
env.Fire("LOOT_CLOSED")
suite.check("nothing opens by itself while unticked", #used == 0)

Opening:SetAuto(true)
env.Fire("LOOT_CLOSED")
suite.check("ticked, the next one opens after loot", used[1] == "0:1", used[1])

ns.Selling.merchantOpen = true
used = {}
env.Fire("LOOT_CLOSED")
suite.check("never at a vendor", #used == 0)
ns.Selling.merchantOpen = false

_G.InCombatLockdown = function() return true end
env.Fire("LOOT_CLOSED")
suite.check("never in a fight", #used == 0)
_G.InCombatLockdown = nil

-- One that stays shut is left for the session.
_G.C_Container.UseContainerItem = function(bag, slot) used[#used + 1] = bag .. ":" .. slot end
used = {}
env.Fire("LOOT_CLOSED")
suite.check("it tries the next", used[1] == "0:1", used[1])
env.Fire("LOOT_CLOSED")
suite.check("the one that stayed shut is left, the next is tried", used[2] == "0:3", tostring(used[2]))

ns.db.openTest = { result = "blocked" }
used = {}
Opening.tried = {}
env.Fire("LOOT_CLOSED")
suite.check("a blocked test means nothing opens by itself", #used == 0)

suite.check("the probe says what it found", Opening:ProbeText():find("test blocked", 1, true) ~= nil,
    Opening:ProbeText())

-- Leave nothing behind for the next suite.
_G.BlackthornesFarmer, _G.C_TooltipInfo, _G.LOCKED = nil, nil, nil

suite.done()
