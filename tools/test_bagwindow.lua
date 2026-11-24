-- The Bags window: Butler's own bag window, in the house look, laid out by
-- what Butler says to do with each item (the owner said build it,
-- 2026-10-19).
--
-- What must hold:
--   1. Off unless ticked: nothing hooked, nothing veiled, nothing saved.
--   2. Turned on, the game's bags are veiled (see-through), never hidden.
--   3. Opening the bags opens it; a toggle flips it once a frame.
--   4. What To Do groups by Butler's verdicts; Item Type by kind; One Grid
--      is every slot in bag order, empty ones too, with each bag that
--      takes only some things on rows of its own.
--   4b. By Bag gives each carried bag its own section, in bag bar order,
--      its slots in order with empty ones, its name and free slots.
--   5. Search and the chips dim what does not match.
--   6. Settings and /bbutler bags set the same saved values.
--   7. Turned off, the veil comes off and the window goes.
--   8. Full bags: the trash can and its red glow sit on the cheapest
--      stack's square in this window, never on the game's veiled bags.
--   9. The foot shows this character's gold, then every character's.

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
suite.check("it covers the game's bags", BagWindow:Covering())

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

-- Empty slots always show (the owner, 2026-11-01): What To Do and Item
-- Type end with them, One Grid keeps its gaps, and an old saved choice is
-- left in the save, unread.
do
    local function Last(list) return list[#list] end
    ns.db.bagEmptySlots = { todo = false, type = false, grid = false }
    local last = Last(BagView:Sections("todo"))
    suite.check("What To Do ends with EMPTY SLOTS", last.key == "empty" and last.label == "EMPTY SLOTS")
    suite.check("holding only the empty slots", last.places[1] and last.places[1].entry == nil)
    suite.check("Item Type ends with them too", Last(BagView:Sections("type")).key == "empty")
    local grid = BagView:Sections("grid")
    suite.check("One Grid keeps every slot, gaps and all", grid[1] and #grid[1].places == 16)
    suite.check("the old saved choice is kept, not read", type(ns.db.bagEmptySlots) == "table"
        and ns.db.bagEmptySlots.grid == false)
    suite.check("there is no tick box for it", BagView.SetShowsEmpty == nil and BagView.ShowsEmpty == nil)
    ns.db.bagEmptySlots = nil
end

-- A bag that takes only some things (a mining bag) gets rows of its own,
-- so what Sort puts in it is not lost in the middle of the grid.
do
    local read = ns.FreeSpace.Read
    local slots = ns.BagView.AllSlots
    ns.FreeSpace.Read = function() return { free = 0, total = 0, bags = {}, special = { { bag = 1 } } } end
    ns.BagView.AllSlots = function()
        return { { bag = 0, slot = 1 }, { bag = 0, slot = 2 }, { bag = 1, slot = 1, entry = { itemID = 2901 } },
            { bag = 1, slot = 2 }, { bag = 2, slot = 1 } }
    end
    local split = BagView:Sections("grid")
    suite.check("a mining bag starts its own rows", #split == 2 and split[2].key == "grid:1")
    suite.check("the bags that take anything stay together", split[1] and #split[1].places == 3
        and split[1].places[3].bag == 2)
    suite.check("with what is in the mining bag", split[2] and split[2].places[1].entry.itemID == 2901)
    -- EMPTY SLOTS counts only the bags that take anything, so it matches
    -- the foot's "N free"; the mining bag's empty slot sits on its own row
    -- under it (a player saw 5 against 2 free, 2026-11-01).
    local empty, extra
    for _, section in ipairs(BagView:Sections("todo")) do
        if section.key == "empty" then empty = section end
        if section.key == "empty:1" then extra = section end
    end
    suite.check("EMPTY SLOTS counts the bags that take anything", empty and #empty.places == 3)
    suite.check("the mining bag's empty slot sits on its own row", extra and #extra.places == 1
        and extra.places[1].bag == 1 and extra.label == nil)
    ns.FreeSpace.Read, ns.BagView.AllSlots = read, slots
end

-- 4b. By Bag (the owner, 2026-11-08): each bag on its own.
do
    local slots = ns.BagView.AllSlots
    ns.BagView.AllSlots = function()
        return { { bag = 0, slot = 1, entry = { itemID = 801 } }, { bag = 0, slot = 2 },
            { bag = 1, slot = 1 }, { bag = 1, slot = 2, entry = { itemID = 2901 } }, { bag = 1, slot = 3 } }
    end
    local bags = BagView:Sections("bag")
    suite.check("By Bag makes a section a bag", #bags == 2 and bags[1].bag == 0 and bags[2].bag == 1)
    suite.check("each bag has a name heading", type(bags[1].label) == "string" and bags[1].label ~= "")
    suite.check("the backpack has its icon", bags[1].icon ~= nil)
    suite.check("slots stay in the game's order, empty ones too", #bags[2].places == 3
        and bags[2].places[1].entry == nil and bags[2].places[2].entry.itemID == 2901)
    suite.check("free slots are counted per bag", bags[1].free == 1 and bags[2].free == 2)
    suite.check("no EMPTY SLOTS group under By Bag", bags[#bags].key ~= "empty")
    ns.BagView.AllSlots = slots
    suite.check("By Bag is the fourth choice", BagView.GROUPS[4] == "bag" and BagView.GROUP_WORDS.bag == "By Bag")
    local before = ns.db.bagGroupBy
    BagView:SetGroupBy("bag")
    suite.check("By Bag is saved", ns.db.bagGroupBy == "bag" and BagView:GroupBy() == "bag")
    ns.db.bagGroupBy = before
end

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

-- 8. The trash can on this window's squares.
do
    local freeSlots = _G.C_Container.GetContainerNumFreeSlots
    _G.C_Container.GetContainerNumFreeSlots = function() return 0, 0 end
    BagWindow:Changed(true); EndFrame()
    local Trash = ns.Trash
    local square = BagWindow:ButtonFor(0, 1)
    suite.check("the cheapest stack has a square", square ~= nil)
    suite.check("full bags show the can", Trash.can ~= nil and Trash.can:IsShown())
    suite.check("on that square", Trash.can and Trash.can:GetParent() == square and square ~= nil)
    suite.check("the red glow lies round it too", Trash.glow ~= nil and Trash.glow:IsShown()
        and Trash.glow:GetParent() == square)
    BagWindow:SetTab("bank"); EndFrame()
    suite.check("the Bank tab has no squares for it", BagWindow:ButtonFor(0, 1) == nil)
    suite.check("so the can goes", not Trash.can:IsShown())
    BagWindow:SetTab("bags"); EndFrame()
    suite.check("and comes back on Your bags", Trash.can:IsShown() and Trash.can:GetParent() == square)
    _G.C_Container.GetContainerNumFreeSlots = freeSlots
    BagWindow:Changed(true); EndFrame()
    suite.check("a free slot puts it away", not Trash.can:IsShown())
end

-- 7. Off again.
ns.HandleSlash("bags off"); EndFrame()
suite.check("/bbutler bags off turns it off", not BagWindow:On() and ns.db.bagWindow == false)
suite.check("the veil comes off the game's bags", not ns.Veil:Covers(_G.ContainerFrameCombinedBags))
suite.check("and the window goes", not BagWindow:IsShown())
_G.OpenAllBags(); EndFrame()
suite.check("opening the bags leaves it closed", not BagWindow:IsShown())

-- Sort plays the game's own bag sort sound, by ID, then sorts.
do
    local played, sorted, saveSort, savePlay = {}, false, nil, _G.PlaySound
    _G.C_Container = _G.C_Container or {}
    saveSort = _G.C_Container.SortBags
    _G.C_Container.SortBags = function() sorted = true end
    _G.PlaySound = function(id, channel) played[#played + 1] = { id, channel } end
    BagWindow:Sort()
    suite.check("Sort plays the game's bag sort sound", #played == 1 and played[1][1] == 73933)
    suite.check("on the sound effects channel, as the game's button", played[1] and played[1][2] == nil)
    suite.check("and sorts the bags", sorted)
    _G.SOUNDKIT = { UI_BAG_SORTING_01 = 5555 }
    suite.check("the client's own sound name wins", BagWindow.SortSound() == 5555)
    _G.SOUNDKIT = nil
    _G.C_Container.SortBags, _G.PlaySound = saveSort, savePlay
end

-- The coin is for vendor items only, never for auction items.
do
    local saveJudge, saveAsk = ns.Verdicts.VerdictOf, ns.Sisters.AskAll
    local verdictFor = {}
    ns.Verdicts.VerdictOf = function(_, entry) return verdictFor[entry.itemID] end
    ns.Sisters.AskAll = function() return {} end
    ns.Verdicts.version = (ns.Verdicts.version or 0) + 1
    verdictFor[9001], verdictFor[9002] = "sell", "auction"
    local vendorItem = ns.BagView:Marks({ itemID = 9001, bag = 0, slot = 30, count = 1 })
    local auctionItem = ns.BagView:Marks({ itemID = 9002, bag = 0, slot = 31, count = 1 })
    suite.check("a vendor item gets the coin", vendorItem.vendor == true)
    suite.check("an auction item gets no coin", auctionItem.vendor == false)
    suite.check("the To Sell chip still finds both", vendorItem.sell and auctionItem.sell)
    ns.Verdicts.VerdictOf, ns.Sisters.AskAll = saveJudge, saveAsk
    ns.Verdicts.version = ns.Verdicts.version + 1
end

-- 9. The foot: this character's gold first, then every character's.
do
    local saveMoney, saveHoldings = _G.GetMoney, ns.Errands.Holdings
    _G.GetMoney = function() return 864050 end
    ns.Errands.Holdings = function()
        return { { isCurrent = true, gold = 1 }, { gold = 1000000 } }
    end
    BagWindow:UpdateFoot()
    local mine = BagWindow.myGoldLabel:GetText() or ""
    local all = BagWindow.goldLabel:GetText() or ""
    suite.check("the foot says this character's gold", mine:find("Gold: ", 1, true) == 1)
    suite.check("from the purse now", BagView.MyGold() == 864050)
    -- 86 gold 40 silver 50 copper, as the game's bag shows it: coin icons,
    -- no leading zeros, no "g", "s" or "c" letters.
    suite.check("the gold shows with the game's coin icons",
        mine:find("86|TInterface\\MoneyFrame\\UI-GoldIcon", 1, true) ~= nil
        and mine:find("40|TInterface\\MoneyFrame\\UI-SilverIcon", 1, true) ~= nil
        and mine:find("50|TInterface\\MoneyFrame\\UI-CopperIcon", 1, true) ~= nil)
    suite.check("with no coin letters", not mine:find("|cffffd700g|r", 1, true))
    suite.check("and no leading zeros", ns.Items.FormatCoins(180797):find("18|T", 1, true) == 1
        and ns.Items.FormatCoins(180797):find("  7|T", 1, true) ~= nil
        and ns.Items.FormatCoins(5):find("^5|T") ~= nil)
    suite.check("and every character's after it", all:find("All characters: ", 1, true) == 1)
    suite.check("adding the purse to the others", BagView.Gold() == 1864050)
    ns.Errands.Holdings = function() return nil end
    BagWindow:UpdateFoot()
    suite.check("without Tradeskills this character's gold still shows",
        (BagWindow.myGoldLabel:GetText() or "") ~= "" and (BagWindow.goldLabel:GetText() or "") == "")
    _G.GetMoney, ns.Errands.Holdings = saveMoney, saveHoldings
    BagWindow:UpdateFoot()
end

-- 10. The chips never run under "Group By:": they stop short of it and
--     wrap onto a row of their own, and the well moves down to match
--     (a player's screenshot, 2026-11-01: "For My Goals" covered it).
do
    local places, rows = BagWindow.ChipPlaces({ 50, 40, 60, 50 }, 18, 300, 502)
    suite.check("short chips sit on one row", rows == 1 and places[4].row == 1)
    places, rows = BagWindow.ChipPlaces({ 90, 80, 120, 110 }, 18, 300, 502)
    local fits = true
    for i, p in ipairs(places) do
        local w = ({ 90, 80, 120, 110 })[i]
        local edge = p.row == 1 and 300 or 502
        if p.x + w > edge then fits = false end
    end
    suite.check("long chips wrap before the label", rows == 2 and fits)
    suite.check("the wrapped row starts at the left", places[3].row == 2 and places[3].x == 18)
    places, rows = BagWindow.ChipPlaces({ 400 }, 18, 300, 502)
    suite.check("a chip wider than the room still gets a place", rows == 1 and places[1].x == 18)
    suite.check("the well sits under every chip row",
        BagWindow.wellTop == 82 + ((BagWindow.chipRows or 1) - 1) * BagWindow.CHIP_ROW)
end

-- The probe line is read without raising.
suite.check("the probe says what it found", type(BagWindow:ProbeText()) == "string")

-- The game's split box and other pop-ups sit in DIALOG: the window stays
-- under them, so splitting a stack in it shows the split box on top.
do
    local frame = BagWindow:Build()
    suite.check("the window sits under the game's pop-ups", frame:GetFrameStrata() == "HIGH")
end

-- In a fight (a player's report, 2026-11-15: Butler Bags wouldn't open in
-- combat). The window is readied before any fight, the game's guarded code
-- shows and hides it once it is guarded, and addon code never tries.
do
    BagWindow:SetOn(true)
    EndFrame()
    local frame = BagWindow:Build()
    local wraps = {}
    _G.SecureHandlerWrapScript = function(game, script, header, body)
        wraps[#wraps + 1] = { game = game, script = script, header = header, body = body }
    end
    BagWindow.secured, BagWindow.header = nil, nil

    -- Readied while out of a fight: wrapped on the game's bag windows.
    _G.InCombatLockdown = function() return true end
    BagWindow:Secure()
    suite.check("in a fight readying waits", BagWindow.secureWaiting == true and #wraps == 0)
    _G.InCombatLockdown = function() return false end
    env.Fire("PLAYER_REGEN_ENABLED")
    EndFrame()
    suite.check("readied once the fight ends", BagWindow.secured == true and not BagWindow.secureWaiting)
    local shows, hides = 0, 0
    for _, w in ipairs(wraps) do
        if w.script == "OnShow" then shows = shows + 1 end
        if w.script == "OnHide" then hides = hides + 1 end
    end
    suite.check("the game's bag windows carry show and hide lines", shows >= 1 and shows == hides)
    suite.check("the lines run only in a fight",
        wraps[1] and wraps[1].body:find("PlayerInCombat", 1, true) ~= nil)
    suite.check("the lines never touch the game's own windows",
        wraps[1] and not wraps[1].body:find("self:Hide", 1, true) and not wraps[1].body:find("self:Show", 1, true))

    -- Guarded and in a fight: addon code leaves it to the game.
    BagWindow:Hide()
    EndFrame()
    local calls = 0
    local realShow, realHide = frame.Show, frame.Hide
    frame.Show = function(f) calls = calls + 1; return realShow(f) end
    frame.Hide = function(f) calls = calls + 1; return realHide(f) end
    frame.IsProtected = function() return true end
    _G.InCombatLockdown = function() return true end
    suite.check("guarded in a fight counts as locked", BagWindow:Locked() == true)
    BagWindow:Show()
    BagWindow:Hide()
    _G.ToggleAllBags()
    EndFrame()
    suite.check("locked, addon code never shows or hides it", calls == 0)

    -- Not guarded: the ordinary Show still works in a fight.
    frame.IsProtected = function() return false end
    _G.ContainerFrameCombinedBags._shown = true
    _G.OpenAllBags()
    EndFrame()
    suite.check("not guarded, it opens in a fight with the game's bags", frame:IsShown())
    _G.ContainerFrameCombinedBags._shown = false
    _G.CloseAllBags()
    EndFrame()
    suite.check("and closes with them", not frame:IsShown())

    -- Shown by anyone, it draws itself.
    local drew = 0
    local realDraw = BagWindow.Draw
    BagWindow.Draw = function(...) drew = drew + 1; return realDraw(...) end
    _G.InCombatLockdown = function() return false end
    frame:Show()
    local onShow = frame:GetScript("OnShow")
    if onShow then onShow(frame) end
    suite.check("shown by the game's lines, it still draws", drew >= 1)

    frame.Show, frame.Hide, frame.IsProtected, BagWindow.Draw = realShow, realHide, nil, realDraw
    _G.SecureHandlerWrapScript, _G.InCombatLockdown = nil, nil
    _G.ContainerFrameCombinedBags._shown = true
    BagWindow:Hide()
    BagWindow:SetOn(false)
    EndFrame()
end

-- It opens full in a fight (a player's report, 2026-11-21: in combat the
-- window opened empty, so no potion could be used from it). Its squares are
-- laid out while it is closed, out of a fight, so they are in place.
do
    BagWindow:SetOn(true)
    EndFrame()
    BagWindow:Hide()
    EndFrame()
    local frame = BagWindow:Build()
    local function Unplace()
        for _, place in ipairs(ns.BagView.AllSlots()) do
            local square = BagWindow.SquareAt(place.bag, place.slot)
            if square then square._point = nil end
        end
    end
    local function Placed()
        local square = BagWindow.SquareAt(0, 2)
        return square ~= nil and type(rawget(square, "_point")) == "table" and square:IsShown()
    end

    -- Readied at login and never opened: laid out all the same.
    BagWindow.secured, BagWindow.header, BagWindow.prepared = nil, nil, nil
    Unplace()
    BagWindow:Secure()
    EndFrame()
    suite.check("readied before a fight, its squares are laid out while closed", Placed())
    suite.check("laid out while closed, it stays closed", not frame:IsShown())

    -- The bags change while it is closed: laid out again a little later.
    Unplace()
    BagWindow:Changed()
    EndFrame()
    suite.check("a change while closed lays it out again", Placed())

    -- A fight starts before that: laid out as it starts.
    Unplace()
    BagWindow:Changed()
    env.Fire("PLAYER_REGEN_DISABLED")
    suite.check("a fight starting lays out what waited", Placed())
    EndFrame()

    -- In a fight and closed: nothing is laid out, it waits for the end.
    Unplace()
    _G.InCombatLockdown = function() return true end
    BagWindow:Changed()
    EndFrame()
    suite.check("closed in a fight, nothing moves", not Placed() and BagWindow.layoutWaiting == true)
    _G.InCombatLockdown = function() return false end
    env.Fire("PLAYER_REGEN_ENABLED")
    EndFrame()
    suite.check("and it is laid out once the fight ends", Placed())

    -- Not guarded, it lays out in a fight too, so new loot finds its place.
    _G.InCombatLockdown = function() return true end
    frame.IsProtected = function() return false end
    Unplace()
    BagWindow:Show()
    local onShow = frame:GetScript("OnShow")
    if onShow then onShow(frame) end
    EndFrame()
    suite.check("not guarded, it lays out in a fight", frame:IsShown() and Placed())

    -- Guarded, its squares keep still in a fight.
    local groupedBy = ns.BagView:GroupBy()
    ns.BagView:SetGroupBy("bag")
    BagWindow:Draw()
    frame.IsProtected = function() return true end
    Unplace()
    BagWindow:Draw()
    suite.check("guarded, its squares keep still in a fight", not Placed())
    -- Its headings stay up too: a redraw in a fight hid every one and,
    -- with the squares kept still, never showed them again.
    local heading = BagWindow.HeadingAt(1)
    suite.check("guarded, its headings stay up in a fight", heading ~= nil and heading:IsShown())
    -- The squares can't be hidden in a fight, so another tab's list would
    -- be drawn over them: it stays on Your bags until the fight ends.
    BagWindow:SetTab("bank")
    suite.check("guarded, it stays on Your bags in a fight", BagWindow.tab == "bags")
    ns.BagView:SetGroupBy(groupedBy)
    frame.IsProtected = nil
    _G.InCombatLockdown = function() return false end
    env.Fire("PLAYER_REGEN_ENABLED")
    EndFrame()

    -- Closed on the Bank tab, it is back on Your bags, laid out.
    BagWindow:SetTab("bank")
    Unplace()
    BagWindow:Hide()
    local onHide = frame:GetScript("OnHide")
    if onHide then onHide(frame) end
    EndFrame()
    suite.check("closed on another tab, it opens on Your bags next", BagWindow.tab == "bags" and Placed())

    -- The game's click reads the bag from the holder; nothing is written on
    -- the square when the holder already gives it.
    suite.check("the bag the click reads is known",
        BagWindow.ReadsBag({ GetBagID = function() return 3 end }) == 3
        and BagWindow.ReadsBag({ GetBagID = function() error("no bag") end }) == nil
        and BagWindow.ReadsBag({}) == nil)

    _G.InCombatLockdown = nil
    BagWindow:SetOn(false)
    EndFrame()
end

-- Suites share one Lua state: take the game's bag calls away again.
_G.hooksecurefunc, _G.ToggleAllBags, _G.OpenAllBags, _G.CloseAllBags = nil, nil, nil, nil
_G.ContainerFrameCombinedBags = nil

suite.done()
