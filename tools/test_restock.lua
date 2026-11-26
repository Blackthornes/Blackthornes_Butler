-- The restock list (the owner said "build 1-10", 2026-11-26, from the
-- mockup butler-improve-2-restock): what this character always carries.
--
-- What must hold:
--   1. An empty list is off: no RESTOCK group, no Restock button.
--   2. A line is saved by GUID, with a copy in the character's own save;
--      nothing is written when the GUID can't be read. 0 takes it off.
--   3. A low line shows under RESTOCK with how many are short.
--   4. "Food for my level" counts food (not drink) that fits the level,
--      in any language, by the spell it casts.
--   5. At a vendor who sells it: "Buy N" on the row and "Restock N" on the
--      Butler Bar; nothing is bought without a click; then just enough.
--   6. A kind buys the vendor's best food that counts, never above the level.
--   7. Restocked items are kept up to their count (never under Sell).
--   8. Settings lists the lines with KEEP and HAVE, and adds by drop or kind.

local env = dofile(lfs_cwd .. "/tools/testenv.lua")
local suite = env.NewSuite("restock")

local ns = env.Load()
local fake = env.FakeBags({
    { bag = 0, slot = 1, id = 117, name = "Tough Jerky", count = 6, price = 1, stack = 20, class = 0, subclass = 5 },
    { bag = 0, slot = 2, id = 159, name = "Refreshing Spring Water", count = 20, price = 1, stack = 20, class = 0, subclass = 5 },
    { bag = 0, slot = 3, id = 929, name = "Healing Potion", count = 1, price = 100, stack = 5, class = 0, subclass = 1 },
    { bag = 0, slot = 4, id = 2589, name = "Linen Cloth", count = 4, price = 1, stack = 20, class = 7 },
})
fake.money = 10 * 10000
local GUID = "Player-1-0000AAAA"
local guid = GUID
_G.UnitGUID = function(unit) if unit == "player" then return guid end end
_G.UnitName = function() return "Ana Thornfield" end
local level = 10
_G.UnitLevel = function() return level end

-- Food casts "Food", drink casts "Drink" (in German, "Essen" and "Trinken").
local SPELL = { [433] = "Food", [430] = "Drink" }
_G.C_Spell = { GetSpellName = function(id) return SPELL[id] end }
local CASTS = { [117] = 433, [2287] = 433, [3770] = 433, [4592] = 433, [159] = 430, [1179] = 430 }
C_Item.GetItemSpell = function(id) return CASTS[id] and SPELL[CASTS[id]], CASTS[id] end
local NEEDS = { [117] = 1, [2287] = 5, [3770] = 15, [4592] = 5, [159] = 1, [1179] = 5 }
local NAMES = { [117] = "Tough Jerky", [2287] = "Haunch of Meat", [3770] = "Mutton Chop",
    [4592] = "Longjaw Mud Snapper", [929] = "Healing Potion", [159] = "Refreshing Spring Water",
    [1179] = "Ice Cold Milk" }
local itemInfo = C_Item.GetItemInfo
C_Item.GetItemInfo = function(id)
    if NEEDS[id] then
        return NAMES[id], "link", 1, NEEDS[id] + 5, NEEDS[id], "Consumable", "Food & Drink", 20, "", 134400, 1
    end
    return itemInfo(id)
end
local instant = C_Item.GetItemInfoInstant
C_Item.GetItemInfoInstant = function(id)
    if NEEDS[id] then return id, "Consumable", "Food & Drink", "", 134400, 0, 5 end
    return instant(id)
end
C_Item.GetItemFamily = function() return 0 end
C_Item.GetItemIconByID = function() return 134400 end

-- The vendor: Haunch of Meat (level 5), Mutton Chop (15), Mud Snapper (5,
-- dearer), milk, and potions in lots of one.
local vendor = {
    { id = 2287, price = 25 }, { id = 3770, price = 100 }, { id = 4592, price = 40 },
    { id = 1179, price = 25 }, { id = 929, price = 400 },
}
_G.GetMerchantNumItems = function() return #vendor end
_G.GetMerchantItemLink = function(i)
    local item = vendor[i]
    return item and ("|cffffffff|Hitem:%d::|h[%s]|h|r"):format(item.id, NAMES[item.id])
end
_G.GetMerchantItemMaxStack = function() return 20 end
_G.C_MerchantFrame = { GetItemInfo = function(i)
    local item = vendor[i]
    return item and { name = NAMES[item.id], texture = 1, price = item.price, stackCount = 1,
        numAvailable = -1, isPurchasable = true, isUsable = true, hasExtendedCost = false }
end }
local calls = {}
_G.BuyMerchantItem = function(i, quantity)
    calls[#calls + 1] = { id = vendor[i].id, quantity = quantity or 1 }
    fake.money = fake.money - vendor[i].price * (quantity or 1)
    for slot = 1, fake.numSlots do
        if not fake.bags[0][slot] then
            fake.Put({ bag = 0, slot = slot, id = vendor[i].id, name = NAMES[vendor[i].id], quality = 1,
                price = 1, count = quantity or 1, stack = 20, class = 0, subclass = 5 })
            break
        end
    end
end

env.Enable(ns)
local Restock, UI = ns.Restock, ns.UI

local function Scan()
    ns.Bags:Scan()
    Restock.lowKey, Restock.offerKey = nil, nil
end
Scan()

local function Group(lines, verdict)
    for index, line in ipairs(lines) do
        if line.type == "header" and line.group.verdict == verdict then return line, index end
    end
    return nil
end

-- 1. Off until a line is added.
suite.check("an empty list is off", not Restock:IsOn())
suite.check("no RESTOCK group", Group(UI:Lines(), "restock") == nil)

-- 2. Saved by GUID, a copy in the character's own save.
suite.check("a line is added", Restock:Add("food"))
suite.check("a kind starts at 20", Restock:Count("food") == 20, Restock:Count("food"))
Restock:Set(929, 5)
Restock:Add("water")
local record = ns.db.restock[GUID]
suite.check("saved by GUID with the character's name", record and record.name == "Ana Thornfield"
    and #record.lines == 3)
suite.check("in the order added", record.lines[1].item == "food" and record.lines[2].item == 929)
suite.check("copied to the character's own save", #ns.charDB.restock == 3)
guid = nil
suite.check("not sure who's playing: writes nothing", Restock:Set(2589, 10) == false
    and #record.lines == 3)
suite.check("and reads the character's own copy", #Restock:MyLines() == 3)
guid = GUID

-- 4. Food for my level.
suite.check("jerky is food", Restock.KindOf(117) == "food")
suite.check("water is drink", Restock.KindOf(159) == "water")
suite.check("a potion is neither", Restock.KindOf(929) == nil)
suite.check("6 jerky count at level 10", Restock:Have("food") == 6, Restock:Have("food"))
suite.check("20 water count", Restock:Have("water") == 20)
level = 30
Restock.lowKey = nil
suite.check("at 30, level 1 jerky no longer counts", Restock:Have("food") == 0)
level = 10

-- 3. Low lines.
Scan()
local low = Restock:Low()
suite.check("food and potions are low, water is not", #low == 2 and low[1].item == "food"
    and low[1].need == 14 and low[2].item == 929 and low[2].need == 4)
local lines = UI:Lines()
local header, at = Group(lines, "restock")
suite.check("a RESTOCK group in the window", header ~= nil and header.group.count == 2)
local row = CreateFrame("Button")
UI.CreateRow(row)
UI.UpdateRow(row, lines[at + 2])
suite.check("away from a vendor: how many are short", env.Plain(row.name:GetText()) == "4 Healing Potion"
    and row.reason:GetText() == "You have 1 of 5." and not row.action:IsShown(), env.Plain(row.name:GetText()))

-- 7. Kept up to their count.
local verdict = ns.Verdicts:Decide(ns.Bags.ReadSlot(0, 1))
suite.check("food on the list is kept", verdict == "keep", verdict)
suite.check("kept up to the count", ns.KeepHere:Effective(929) == 5 and ns.KeepHere:Effective(117) == 20)

-- 5. At a vendor.
env.Fire("MERCHANT_SHOW")
Scan()
local offer = Restock:Offer()
suite.check("the vendor sells both", offer and offer.rows[1].plan and offer.rows[2].plan)
-- 6. The best food that counts: Haunch of Meat (level 5, cheaper than the
-- snapper), not Mutton Chop (level 15).
suite.check("the best food for the level", offer.rows[1].plan.item.itemID == 2287,
    offer.rows[1].plan.item.itemID)
suite.check("just enough", offer.rows[1].plan.count == 14 and offer.rows[2].plan.count == 4)
suite.check("adds up for Restock", offer.count == 18 and offer.cost == 14 * 25 + 4 * 400, offer.cost)
lines = UI:Lines()
header, at = Group(lines, "restock")
UI.UpdateRow(row, lines[at + 1])
suite.check("the row says Buy 14", env.Plain(row.name:GetText()) == "Buy 14 Haunch of Meat"
    and row.action:IsShown() and row.action.label:GetText() == "Buy 14", env.Plain(row.name:GetText()))
suite.check("with the cost", row.reason:GetText():find("This vendor sells it.", 1, true) ~= nil)

local Bar = ns.PlaceBar
ns.db.placeBar = true
Bar.place = "vendor"
_G.MerchantFrame = env.Stub({ _shown = true })
_G.MerchantFrame.IsShown = function() return true end
UI:Hide()
Bar:Refresh()
suite.check("Restock 18 on the Butler Bar", Bar.restock and Bar.restock:IsShown()
    and Bar.restock.label:GetText() == "Restock 18", Bar.restock and Bar.restock.label:GetText())

suite.check("nothing bought without a click", #calls == 0)
Restock:Buy(929)
suite.check("one row's Buy buys only that line", #calls == 1 and calls[1].id == 929 and calls[1].quantity == 4,
    calls[1] and calls[1].id)
Scan()
suite.check("potions no longer low", #Restock:Low() == 1)
Restock:Buy()
suite.check("Restock buys the food", #calls == 2 and calls[2].id == 2287 and calls[2].quantity == 14)
Scan()
suite.check("nothing low now", #Restock:Low() == 0)
suite.check("so no RESTOCK group", Group(UI:Lines(), "restock") == nil)
Bar:Refresh()
suite.check("and no Restock button", not Bar.restock:IsShown())
env.Fire("MERCHANT_CLOSED")

-- 2. 0 takes a line off.
Restock:Set(929, 0)
suite.check("0 takes it off", Restock:Count(929) == nil and #ns.charDB.restock == 2)

-- 8. Settings.
ns.SettingsUI:Show()
local list = ns.SettingsUI.controls.restockList
suite.check("Settings lists each line", list.rows[1]:IsShown() and list.rows[2]:IsShown()
    and list.rows[1].name:GetText() == "Food for my level")
suite.check("with HAVE", list.rows[1].have:GetText() == "20", list.rows[1].have:GetText())
_G.GetCursorInfo = function() return "item", 2589 end
_G.ClearCursor = function() _G.GetCursorInfo = function() return nil end end
ns.RestockList:AddClicked()
suite.check("dropping an item adds it", Restock:Count(2589) == 20 and list.rows[3]:IsShown())
Restock:Set("water", 0)
local offered
local open = ns.RowMenu.Open
ns.RowMenu.Open = function(_, menu) offered = menu end
ns.RestockList:AddClicked()
ns.RowMenu.Open = open
suite.check("with nothing held, the kinds not on it yet", offered and #offered == 1
    and offered[1].text == "Water for my level")
offered[1].run()
suite.check("and picking one adds it", Restock:Count("water") == 20)
list.rows[1].keep:SetText("0")
list.rows[1].keep.editBox:GetScript("OnEnterPressed")(list.rows[1].keep.editBox)
suite.check("typing 0 takes a line off", Restock:Count("food") == nil, Restock:Count("food"))

suite.done()
