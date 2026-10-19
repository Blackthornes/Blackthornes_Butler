-- The Bags window: Butler's own bag window, in the house look, laid out by
-- what Butler says to do with each item (the owner said build it,
-- 2026-10-19).
--
-- What must hold:
--   1. Off unless ticked: nothing hooked, nothing veiled, nothing saved.
--   2. Turned on, the game's bags are veiled (see-through), never hidden.
--   3. Opening the bags opens it; a toggle flips it once a frame.
--   4. What To Do groups by Butler's verdicts; Item Type by kind; One Grid
--      is every slot in bag order, empty ones too.
--   5. Search and the chips dim what does not match.
--   6. Settings and /bbutler bags set the same saved values.
--   7. Turned off, the veil comes off and the window goes.

local env = dofile(lfs_cwd .. "/tools/testenv.lua")
local suite = env.NewSuite("bagwindow")

local ns = env.Load()
env.FakeBags({
    { bag = 0, slot = 1, id = 801, name = "Broken Fang", quality = 0, price = 12, count = 3 },
    { bag = 0, slot = 2, id = 802, name = "Linen Cloth", quality = 1, price = 13, count = 20, class = 7 },
    { bag = 0, slot = 3, id = 803, name = "Old Letter", quality = 1, price = 1, quest = "item" },
    { bag = 0, slot = 5, id = 804, name = "Iron Sword", quality = 1, price = 300, class = 2, equipLoc = "INVTYPE_WEAPON" },
})

-- A post-hook, as the game's hooksecurefunc runs one.
_G.hooksecurefunc = function(a, b, c)
    local owner, name, fn = _G, a, b
    if type(a) == "table" then owner, name, fn = a, b, c end
    local before = owner[name]
    owner[name] = function(...)
        local result = before(...)
        fn(...)
        return result
    end
end
_G.ToggleAllBags = function() end
_G.OpenAllBags = function() end
_G.CloseAllBags = function() end

-- The game's combined bag window, shown.
_G.ContainerFrameCombinedBags = env.Stub({ _shown = true })

env.Enable(ns)

-- From here timers wait for the end of the frame, as the game's do, so a
-- burst of bag calls settles once.
local queued = {}
_G.C_Timer.After = function(_, fn) queued[#queued + 1] = fn end
local function EndFrame()
    while #queued > 0 do
        local now = queued
        queued = {}
        for _, fn in ipairs(now) do fn() end
    end
end

local BagWindow, BagView = ns.BagWindow, ns.BagView

-- 1. Off unless ticked.
suite.check("it starts off", not BagWindow:On())
suite.check("nothing is saved for it yet", ns.db.bagWindow == nil)
_G.OpenAllBags(); EndFrame()
suite.check("opening the bags does nothing while it is off", not BagWindow:IsShown())
suite.check("the game's bags are left alone", not ns.Veil:Covers(_G.ContainerFrameCombinedBags))

-- 2. On: the game's bags are veiled, never hidden.
ns.HandleSlash("bags on"); EndFrame()
suite.check("/bbutler bags on turns it on", BagWindow:On() and ns.db.bagWindow == true)
suite.check("and says so", env.ChatText():find("Butler Bags is on.", 1, true) ~= nil)
suite.check("the game's bags go under the veil", ns.Veil:Covers(_G.ContainerFrameCombinedBags))
suite.check("but are never hidden", _G.ContainerFrameCombinedBags:IsShown())
suite.check("the trash can stands down while it covers the bags", BagWindow:Covering())

-- 3. Opening and toggling.
_G.OpenAllBags(); EndFrame()
suite.check("opening the bags opens it", BagWindow:IsShown())
_G.ToggleAllBags(); EndFrame()
suite.check("a toggle closes it", not BagWindow:IsShown())
_G.ToggleAllBags(); EndFrame()
suite.check("and opens it again", BagWindow:IsShown())
_G.CloseAllBags(); EndFrame()
suite.check("closing the bags closes it", not BagWindow:IsShown())
BagWindow:Show(); EndFrame()

-- 4. Grouping.
ns.Bags:Scan(); EndFrame()
local sections = BagView:Sections("todo")
suite.check("What To Do has sections", #sections > 0)
local sellSection
for _, section in ipairs(sections) do
    if section.verdict == "sell" then sellSection = section end
end
suite.check("the grey goes under Sell", sellSection ~= nil and sellSection.places[1].entry.itemID == 801)
suite.check("with what the group is worth", sellSection and sellSection.worth and sellSection.worth > 0)

local byType = {}
for _, section in ipairs(BagView:Sections("type")) do byType[section.key] = section end
suite.check("Item Type puts the quest item under QUEST", byType.quest and byType.quest.places[1].entry.itemID == 803)
suite.check("the cloth under TRADE GOODS", byType.trade and byType.trade.places[1].entry.itemID == 802)
suite.check("the sword under WEAPONS", byType.weapons and byType.weapons.places[1].entry.itemID == 804)

local grid = BagView:Sections("grid")
suite.check("One Grid is one section", #grid == 1)
suite.check("holding every slot, empty ones too", grid[1] and #grid[1].places == 16)
suite.check("in bag order", grid[1] and grid[1].places[4].entry == nil and grid[1].places[5].entry.itemID == 804)

-- 5. Search.
suite.check("search finds by name", BagView.Matches("Linen Cloth", 802, "linen"))
suite.check("in any case", BagView.Matches("Linen Cloth", 802, BagView.Fold("  LINEN ")))
suite.check("or by item ID", BagView.Matches("Linen Cloth", 802, "802"))
suite.check("and skips what does not match", not BagView.Matches("Linen Cloth", 802, "sword"))

-- 6. Settings and the command set the same values.
BagView:SetGroupBy("grid")
suite.check("Group By is saved", ns.db.bagGroupBy == "grid")
BagView:SetGroupBy("nonsense")
suite.check("a word it does not know falls back", BagView:GroupBy() == "todo" or BagView:GroupBy() == "grid")
BagView:SetItemSize("large")
suite.check("Item Size is saved", ns.db.bagItemSize == "large" and BagView:Pixels() > 37)
BagView:SetItemLevelOn(false)
suite.check("Item Level on Gear can be turned off", ns.db.bagItemLevel == false and not BagView:ItemLevelOn())
BagView:SetNewGlowOn(false)
suite.check("New Item Glow can be turned off", ns.db.bagNewGlow == false and not BagView:NewGlowOn())

ns.SettingsUI:Show()
local controls = ns.SettingsUI.controls
suite.check("Settings has the Use Butler Bags box", controls.bagWindow ~= nil)
suite.check("and it shows what is saved", controls.bagWindow:GetChecked() == true)

-- Every way of laying it out draws without a fault, in each tab.
for _, groupBy in ipairs({ "todo", "type", "grid" }) do
    BagView:SetGroupBy(groupBy)
    BagWindow:Changed(true); EndFrame()
end
suite.check("the window still shows after redrawing", BagWindow:IsShown())
BagWindow:SetTab("bank"); EndFrame()
suite.check("the Bank tab draws", BagWindow.tab == "bank")
BagWindow:SetTab("everyone"); EndFrame()
suite.check("the Everyone tab draws", BagWindow.tab == "everyone")
BagWindow:SetTab("bags"); EndFrame()

-- 7. Off again.
ns.HandleSlash("bags off"); EndFrame()
suite.check("/bbutler bags off turns it off", not BagWindow:On() and ns.db.bagWindow == false)
suite.check("the veil comes off the game's bags", not ns.Veil:Covers(_G.ContainerFrameCombinedBags))
suite.check("and the window goes", not BagWindow:IsShown())
_G.OpenAllBags(); EndFrame()
suite.check("opening the bags leaves it closed", not BagWindow:IsShown())

-- The probe line is read without raising.
suite.check("the probe says what it found", type(BagWindow:ProbeText()) == "string")

-- Suites share one Lua state: take the game's bag calls away again.
_G.hooksecurefunc, _G.ToggleAllBags, _G.OpenAllBags, _G.CloseAllBags = nil, nil, nil, nil
_G.ContainerFrameCombinedBags = nil

suite.done()
