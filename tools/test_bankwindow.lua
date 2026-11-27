-- The Butler Bank window (Butler idea 8, 2026-11-26): at a banker, the
-- bank in the Butler Bags style. On with Use Butler Bags. The squares are
-- the game's template on Forever's bank tabs; bag -1, which answers with
-- items the game never shows, is left out. The game's bank goes under the
-- veil, never hidden, and comes back when the window closes.

local env = dofile(lfs_cwd .. "/tools/testenv.lua")
local suite = env.NewSuite("bankwindow")

local ns = env.Load()
local fake = env.FakeBags({})
_G.hooksecurefunc = function(a, b, c)
    local owner, name, fn = _G, a, b
    if type(a) == "table" then owner, name, fn = a, b, c end
    local before = owner[name]
    owner[name] = function(...)
        local result = before and before(...)
        fn(...)
        return result
    end
end
_G.ToggleAllBags, _G.OpenAllBags, _G.CloseAllBags = function() end, function() end, function() end
env.Enable(ns)

-- Forever's bank: tabs from bag 6. Tab 6 has 8 slots with three items;
-- bag -1 answers with a key the game never shows.
_G.Enum = { BagIndex = { Bank = -1, CharacterBankTab_1 = 6, CharacterBankTab_6 = 11 } }
fake.bags[-1], fake.bags[6] = {}, {}
fake.Put({ bag = -1, slot = 1, id = 5000, name = "Old Key", quality = 1, price = 0 })
fake.Put({ bag = 6, slot = 1, id = 2589, name = "Linen Cloth", quality = 1, price = 13, count = 20, class = 7 })
fake.Put({ bag = 6, slot = 2, id = 2592, name = "Wool Cloth", quality = 1, price = 33, count = 5, class = 7 })
fake.Put({ bag = 6, slot = 4, id = 1201, name = "Iron Sword", quality = 1, price = 300, class = 2 })
local slotsOf = _G.C_Container.GetContainerNumSlots
_G.C_Container.GetContainerNumSlots = function(bag)
    if bag == -1 then return 32 elseif bag == 6 then return 8 end
    return slotsOf(bag)
end
_G.BankFrame = env.Stub({ _shown = true })

local BankWindow, Errands = ns.BankWindow, ns.Errands

local function Square(bag, slot)
    for i = 1, 40 do
        local button = _G["BlackthornesButlerBankItem" .. i]
        if button and button.bfrBag == bag and button.bfrSlot == slot then return button end
    end
    return nil
end

-- Butler's bank leaves bag -1 out once the client has tabs.
local ids = Errands.BankBagIDs()
suite.check("the bank starts at the first tab", ids[1] == 6, table.concat(ids, ","))
local hasMinus = false
for _, bag in ipairs(ids) do if bag == -1 then hasMinus = true end end
suite.check("bag -1 is left out", not hasMinus)

-- Off with Butler Bags.
Errands.bankOpen = true
BankWindow:BankOpened()
suite.check("off while Butler Bags is off", not BankWindow:IsShown())
suite.check("the game's bank is left alone", not ns.Veil:Covers(_G.BankFrame))

-- Butler Bags on is not enough: it has its own box, off unless ticked.
ns.HandleSlash("bags on")
BankWindow:BankOpened()
suite.check("off until its own box is ticked", not BankWindow:IsShown())
suite.check("nothing saved for it yet", ns.db.bankWindow == nil)

-- Ticked at the bank, it opens there and then.
BankWindow:SetOn(true)
suite.check("ticking it saves it", ns.db.bankWindow == true)
suite.check("it opens at a banker", BankWindow:IsShown())
suite.check("the game's bank goes under the veil", ns.Veil:Covers(_G.BankFrame))
suite.check("and is never hidden", _G.BankFrame:IsShown())
suite.check("a square for each tab slot", Square(6, 1) and Square(6, 8))
suite.check("none for bag -1", Square(-1, 1) == nil)
suite.check("the square is shown", Square(6, 1):IsShown())
suite.check("it carries its slot", Square(6, 2).bfrSlot == 2)

-- Item Type, in Butler Bags' order: weapons, trade goods, then the empty
-- slots.
local sections = BankWindow:Sections(BankWindow.Slots())
suite.check("weapons first", sections[1].key == "weapons", sections[1].key)
suite.check("trade goods next", sections[2].key == "trade" and #sections[2].places == 2, sections[2] and sections[2].key)
suite.check("empty slots last", sections[3].key == "empty" and sections[3].free == 5, sections[3] and sections[3].free)
suite.check("the foot counts the free slots", BankWindow.freeLabel:GetText():find("5", 1, true), BankWindow.freeLabel:GetText())

-- Bag Slots along the foot match the game's bank: the bag bought in the
-- first slot, then a lock for each of the other seven.
_G.C_Container.ContainerIDToInventoryID = function(bag)
    if bag >= 7 and bag <= 14 then return 80 + bag end
    return nil
end
_G.GetInventoryItemTexture = function(_, slot) return slot == 87 and 133639 or nil end
_G.C_Container.GetContainerNumSlots = function(bag)
    if bag == -1 then return 32 elseif bag == 6 then return 8 elseif bag == 7 then return 4 end
    return slotsOf(bag)
end
local bagSlots = BankWindow.BagSlots()
suite.check("eight bag slots after the bank itself", #bagSlots == 8, #bagSlots)
suite.check("the first holds the bag bought", bagSlots[1].bag == 7 and bagSlots[1].bought and bagSlots[1].icon == 133639)
suite.check("the rest are not bought", not bagSlots[2].bought and not bagSlots[8].bought)
BankWindow:Draw()
suite.check("the bought bag's slots are read too", Square(7, 4) ~= nil)
suite.check("the foot counts every free slot", BankWindow.freeLabel:GetText():find("9", 1, true), BankWindow.freeLabel:GetText())

-- Twelve bag slots and Game Bank share the foot: the slots shrink so the
-- last one ends before the button (seen in game 2026-11-26, the locks ran
-- over the button's words).
_G.C_Container.ContainerIDToInventoryID = function(bag)
    if bag >= 7 and bag <= 18 then return 80 + bag end
    return nil
end
BankWindow:Draw()
local swapLeft = 480 - 18 - BankWindow.swapButton:GetWidth()
local label = ns.Theme.TextWidth("small", ns.L["Bag Slots:"])
suite.check("twelve bag slots in the foot", #BankWindow.BagSlots() == 12, #BankWindow.BagSlots())
suite.check("the bag slots end before Game Bank", 18 + BankWindow.footEnd <= swapLeft - 6,
    tostring(18 + BankWindow.footEnd) .. " vs " .. tostring(swapLeft))
suite.check("the bag slots start after their label", BankWindow.footStart >= label + 4)
suite.check("the bag slots stay a size to see", BankWindow.footIcon >= 12, BankWindow.footIcon)
-- With a long German label, they still fit.
local oldLabel = ns.L["Bag Slots:"]
ns.L["Bag Slots:"] = "Taschenplätze im Bankfach:"
BankWindow:Draw()
suite.check("a long label still leaves the button clear", 18 + BankWindow.footEnd <= swapLeft - 6,
    tostring(18 + BankWindow.footEnd) .. " vs " .. tostring(swapLeft))
ns.L["Bag Slots:"] = oldLabel
_G.C_Container.ContainerIDToInventoryID = nil
_G.C_Container.GetContainerNumSlots = function(bag)
    if bag == -1 then return 32 elseif bag == 6 then return 8 end
    return slotsOf(bag)
end
BankWindow:Draw()

-- One Grid: one section, every slot.
BankWindow.groupIndex = 2
sections = BankWindow:Sections(BankWindow.Slots())
suite.check("One Grid is one section", #sections == 1 and #sections[1].places == 8)
BankWindow.groupIndex = 1

-- Search dims what does not match.
BankWindow.search:SetText("Wool")
BankWindow:Draw()
suite.check("a match stays lit", Square(6, 2):GetAlpha() ~= 0.25)
suite.check("the rest go dim", Square(6, 1)._alpha == 0.25 or Square(6, 1):GetAlpha() == 0.25)
BankWindow.search:SetText("")

-- Take for Crafts shows on trade goods when something is wanted.
Errands.WantedCount = function() return 3 end
local took = 0
Errands.TakeFromBank = function() took = took + 1 return true end
BankWindow:Draw()
suite.check("Take for Crafts shows", BankWindow.takeButton and BankWindow.takeButton:IsShown())
suite.check("with the count", BankWindow.takeButton.label:GetText() == "Take for Crafts 3", BankWindow.takeButton.label:GetText())
BankWindow.takeButton:GetScript("OnClick")(BankWindow.takeButton, "LeftButton")
suite.check("a click takes from the bank", took == 1)
Errands.WantedCount = function() return 0 end
BankWindow:Draw()
suite.check("and hides when nothing is wanted", not BankWindow.takeButton:IsShown())

-- Nothing moves without a click.
suite.check("drawing moved nothing", #fake.used == 0)

-- Game Bank swaps to the game's bank, still open; Butler Bank swaps back.
BankWindow.swapButton:GetScript("OnClick")(BankWindow.swapButton, "LeftButton")
suite.check("Game Bank hides Butler's window", not BankWindow:IsShown())
suite.check("and shows the game's bank", not ns.Veil:Covers(_G.BankFrame))
suite.check("with a Butler Bank button under it", BankWindow.backButton and BankWindow.backButton:IsShown())
suite.check("the bank stays open", Errands.bankOpen)
BankWindow.backButton:GetScript("OnClick")(BankWindow.backButton, "LeftButton")
suite.check("Butler Bank swaps back", BankWindow:IsShown() and ns.Veil:Covers(_G.BankFrame))
suite.check("and its button goes", not BankWindow.backButton:IsShown())
BankWindow:SwapToGame()
Errands:Left("bank")
suite.check("leaving the banker takes the button away", not BankWindow.backButton:IsShown())
Errands.bankOpen = true
BankWindow:BankOpened()

-- The close gem shuts the bank, as the game's own close does.
local shut = 0
_G.C_Bank = { CloseBankFrame = function() shut = shut + 1 end }
BankWindow:Close()
suite.check("closed", not BankWindow:IsShown())
suite.check("the bank is shut too", shut == 1)
suite.check("the game's bank is not left veiled", not ns.Veil:Covers(_G.BankFrame))
_G.C_Bank = nil
local cleared
_G.C_PlayerInteractionManager = { ClearInteraction = function(kind) cleared = kind end }
_G.Enum.PlayerInteractionType = { Banker = 8 }
suite.check("without that call the interaction is cleared", BankWindow.CloseBank() and cleared == 8)
_G.C_PlayerInteractionManager = nil
suite.check("with neither it says so", BankWindow.CloseBank() == false)

-- Leaving the banker closes it.
BankWindow:BankOpened()
suite.check("open again", BankWindow:IsShown())
Errands:Left("bank")
suite.check("leaving the banker closes it", not BankWindow:IsShown())
suite.check("and uncovers the game's bank", not ns.Veil:Covers(_G.BankFrame))

-- Unticking it closes it and gives the game's bank back.
BankWindow:BankOpened()
BankWindow:SetOn(false)
suite.check("unticking closes it", not BankWindow:IsShown() and not ns.Veil:Covers(_G.BankFrame))
suite.check("and forgets it", ns.db.bankWindow == nil)
BankWindow:SetOn(true)
BankWindow:Close()

-- Sort: One Grid only, in Group By's old spot; it sorts the real bank.
do
    local sorted, played, savePlay = 0, {}, _G.PlaySound
    _G.C_Container.SortBankBags = function() sorted = sorted + 1 end
    _G.PlaySound = function(id) played[#played + 1] = id end
    BankWindow:BankOpened()
    BankWindow.groupIndex = 1
    BankWindow:Draw()
    suite.check("no Sort in Item Type", not BankWindow.sortButton:IsShown())
    BankWindow.groupIndex = 2
    BankWindow:Draw()
    suite.check("Sort shows in One Grid", BankWindow.sortButton:IsShown())
    BankWindow.sortButton:GetScript("OnClick")(BankWindow.sortButton)
    suite.check("a click sorts the bank", sorted == 1)
    suite.check("with the game's bag sort sound", played[1] == 73933)
    ns.db.muteSounds = true
    local saveMuted = ns.Muted
    ns.Muted = function() return true end
    BankWindow:Sort()
    suite.check("Mute All Sounds keeps it quiet", sorted == 2 and #played == 1)
    ns.Muted = saveMuted
    ns.db.muteSounds = nil
    _G.InCombatLockdown = function() return true end
    BankWindow:Sort()
    suite.check("nothing in a fight", sorted == 2)
    BankWindow:UpdateSort()
    suite.check("and the button greys", BankWindow.sortButton.IsEnabled == nil or not BankWindow.sortButton:IsEnabled())
    _G.InCombatLockdown = nil
    BankWindow:UpdateSort()
    _G.C_Container.SortBankBags = nil
    BankWindow:Draw()
    suite.check("hidden where the client can't sort the bank", not BankWindow.sortButton:IsShown())
    suite.check("the search box stays clear of Group By",
        59 + BankWindow.search:GetWidth() <= 480 - 32 - BankWindow.sortButton:GetWidth() - 6 - BankWindow.groupStepper:GetWidth())
    BankWindow.groupIndex = 1
    _G.PlaySound = savePlay
    BankWindow:Close()
end

-- In a fight it does not open.
Errands.bankOpen = true
_G.InCombatLockdown = function() return true end
BankWindow:BankOpened()
suite.check("not in a fight", not BankWindow:IsShown())
_G.InCombatLockdown = nil
_G.Enum = nil

suite.done()
