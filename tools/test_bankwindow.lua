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

-- The close gem gives the game's bank back.
BankWindow:Close()
suite.check("closed", not BankWindow:IsShown())
suite.check("the game's bank comes back", not ns.Veil:Covers(_G.BankFrame))

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

-- In a fight it does not open.
Errands.bankOpen = true
_G.InCombatLockdown = function() return true end
BankWindow:BankOpened()
suite.check("not in a fight", not BankWindow:IsShown())
_G.InCombatLockdown = nil
_G.Enum = nil

suite.done()
