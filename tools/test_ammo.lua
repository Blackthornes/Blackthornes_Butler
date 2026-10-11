-- Filling a hunter's quiver or ammo pouch at a vendor (the owner asked
-- 2026-10-11: "with the best ammo you can use, for the weapon type you're
-- using and pouch type you have on").
--
-- What must hold:
--   1. Only a hunter, only at a vendor that sells ammo for the weapon on.
--   2. The best ammo the hunter can use: most damage, never above its level.
--   3. As many as fill the quiver: whole lots that fit its empty slots and
--      the room left in its stacks of the same ammo.
--   4. Nothing is bought without the Fill click; then one lot at a time.
--   5. Never more than the purse holds; the gold fund is for mail only.
--   6. A gun with a quiver on (or no ammo bag) says so and buys nothing.
--   7. The hunter's own ammo is kept out of Sell.

local env = dofile(lfs_cwd .. "/tools/testenv.lua")
local suite = env.NewSuite("ammo")

local ns = env.Load()
local fake = env.FakeBags({
    { bag = 0, slot = 1, id = 2512, name = "Rough Arrow", quality = 1, price = 1, count = 40 },
})
fake.money = 5 * 10000

-- Item classes: bow 2/2, gun 2/3; arrows 6/2, bullets 6/3.
local CLASS = {
    [2504] = { 2, 2 }, [2508] = { 2, 3 },
    [2512] = { 6, 2 }, [2515] = { 6, 2 }, [3030] = { 6, 2 }, [2516] = { 6, 3 }, [4400] = { 15, 0 },
}
local MIN_LEVEL = { [2512] = 1, [2515] = 10, [3030] = 25, [2516] = 1 }
local NAMES = { [2512] = "Rough Arrow", [2515] = "Sharp Arrow", [3030] = "Razor Arrow",
    [2516] = "Light Shot", [4400] = "Shiny Token" }

C_Item.GetItemInfoInstant = function(id)
    local class = CLASS[id] or { 15, 0 }
    return id, "Misc", "Misc", "", 134400, class[1], class[2]
end
local itemInfo = C_Item.GetItemInfo
C_Item.GetItemInfo = function(id)
    if MIN_LEVEL[id] then
        return NAMES[id], "link", 1, MIN_LEVEL[id] + 5, MIN_LEVEL[id], "Projectile", "Arrow", 200, "", 134400, 1
    end
    return itemInfo(id)
end

-- A quiver of 4 slots in bag 1, one holding 150 Sharp Arrows.
local family = 1
fake.bags[1][2] = { bag = 1, slot = 2, id = 2515, name = "Sharp Arrow", quality = 1, price = 1, count = 150 }
fake.info[2515] = fake.bags[1][2]
local numSlots = C_Container.GetContainerNumSlots
C_Container.GetContainerNumSlots = function(bag)
    if bag == 1 then return 4 end
    return numSlots(bag)
end
C_Container.GetContainerNumFreeSlots = function(bag)
    if bag == 1 then return 3, family end
    return 0, 0
end
C_Container.GetBagName = function(bag) return bag == 1 and "Light Quiver" or nil end

-- The hunter, level 20, with a bow.
local class, ranged = "HUNTER", 2504
_G.UnitClass = function() return "Hunter", class end
_G.UnitLevel = function() return 20 end
_G.GetInventoryItemID = function(_, slot) return slot == 18 and ranged or nil end

-- The vendor: lots of 200; Razor Arrows are above level 20; a token item.
local vendor = {
    { id = 2512, price = 10, dps = 2 },
    { id = 2515, price = 100, dps = 4.5 },
    { id = 3030, price = 400, dps = 7 },
    { id = 2516, price = 10, dps = 2 },
    { id = 4400, price = 0, extended = true },
}
local bought = {}
_G.GetMerchantNumItems = function() return #vendor end
_G.GetMerchantItemLink = function(i)
    local item = vendor[i]
    return item and ("|cffffffff|Hitem:%d::|h[%s]|h|r"):format(item.id, NAMES[item.id])
end
_G.C_MerchantFrame = { GetItemInfo = function(i)
    local item = vendor[i]
    return item and { name = NAMES[item.id], texture = 1, price = item.price, stackCount = 200,
        numAvailable = -1, isPurchasable = true, isUsable = true, hasExtendedCost = item.extended or false }
end }
_G.C_TooltipInfo = { GetMerchantItem = function(i)
    local item = vendor[i]
    return { lines = { { leftText = NAMES[item.id] },
        item.dps and { leftText = ("Adds %.1f damage per second"):format(item.dps) } or nil } }
end }
_G.BuyMerchantItem = function(i, quantity)
    bought[#bought + 1] = { index = i, quantity = quantity }
    fake.money = fake.money - vendor[i].price
end

env.Enable(ns)
local Ammo, UI = ns.Ammo, ns.UI

local function Fresh()
    Ammo.offerKey = nil
    Ammo:GearChanged()
    return Ammo:Offer()
end

-- 1. Not at a vendor: nothing.
suite.check("no offer away from a vendor", Ammo:Offer() == nil)

env.Fire("MERCHANT_SHOW")
local offer = Fresh()
suite.check("at a vendor with arrows, an offer", offer ~= nil and offer.state == "fill",
    offer and offer.state)

-- 2. The best the hunter can use.
suite.check("the most damage it can use: Sharp Arrow, not Razor (level 25)",
    offer.ammo.itemID == 2515, offer.ammo.itemID)

-- 3. What fits: 3 empty slots of 200 and 50 more in the stack: 3 lots.
suite.check("whole lots that fit the quiver", offer.lots == 3 and offer.count == 600, offer.count)
suite.check("and their cost", offer.cost == 300, offer.cost)
suite.check("the row says so", Ammo.Reason(offer):find("Fills your quiver: 600 for", 1, true) ~= nil,
    Ammo.Reason(offer))

local lines = UI:Lines()
suite.check("the Ammo row comes first in the window", lines[1].type == "header"
    and lines[1].group.verdict == "ammo" and lines[2].type == "ammo")
local row = CreateFrame("Button")
UI.CreateRow(row)
UI.UpdateRow(row, lines[2])
suite.check("with a Fill button", row.action:IsShown() and row.action.label:GetText() == "Fill")
UI.UpdateRow(row, lines[1])
suite.check("which no other row shows", not row.action:IsShown())

-- 4. Nothing bought until the click; then one lot at a time.
suite.check("nothing bought without a click", #bought == 0)
Ammo:Buy()
suite.check("the click buys 3 lots", #bought == 3 and bought[1].index == 2 and bought[1].quantity == nil, #bought)
suite.check("and says so", env.ChatText():find("bought 600 Sharp Arrow", 1, true) ~= nil)

-- 5. The gold fund is only for mailing gold, never for spending (the
-- owner, 2026-10-11): a purse below it still buys.
fake.money = 50000
bought = {}
ns.Funds:SetMinimum(100000)
offer = Fresh()
suite.check("the gold kept for mail plays no part", offer.state == "fill" and offer.lots == 3 and not offer.short,
    offer and offer.state)
ns.Funds:SetMinimum(nil)
fake.money = 150
offer = Fresh()
suite.check("only what the purse can pay for", offer.state == "fill" and offer.lots == 1 and offer.short)
suite.check("saying why", Ammo.Reason(offer):find("all you can pay for now", 1, true) ~= nil, Ammo.Reason(offer))
fake.money = 50
offer = Fresh()
suite.check("not enough for one lot: no button", offer.state == "poor"
    and Ammo.Reason(offer):find("can't pay for one lot", 1, true) ~= nil, Ammo.Reason(offer))
Ammo:Buy()
suite.check("and nothing bought", #bought == 0)
fake.money = 50000

-- 6. A gun with a quiver on: bullets can't go in it.
ranged = 2508
offer = Fresh()
suite.check("a gun with a quiver: says so", offer.state == "mismatch" and offer.ammo.itemID == 2516
    and Ammo.Reason(offer):find("gun fires bullets, but your quiver", 1, true) ~= nil, offer and Ammo.Reason(offer))
Ammo:Buy()
suite.check("and buys nothing", #bought == 0)
family = 2
offer = Fresh()
suite.check("a gun with an ammo pouch: bullets", offer.state == "fill" and offer.ammo.itemID == 2516)
family = 0
offer = Fresh()
suite.check("no ammo bag: says to put one on", offer.state == "nobag"
    and Ammo.Reason(offer):find("Put on a ammo pouch", 1, true) == nil
    and Ammo.Reason(offer):find("Put on an ammo pouch", 1, true) ~= nil, offer and Ammo.Reason(offer))
family, ranged = 1, 2504
Ammo:GearChanged()

-- 7. The hunter's arrows are kept.
suite.check("arrows for the bow are kept", Ammo:Keeps(2512) == "Ammo for your bow")
suite.check("bullets for a gun it doesn't have are not", Ammo:Keeps(2516) == nil)
local entry = ns.Bags.ReadSlot(0, 1)
local verdict, reason = ns.Verdicts:Decide(entry)
suite.check("so Butler never puts them under Sell", verdict == "keep" and reason == "Ammo for your bow", verdict)
class = "WARRIOR"
offer = Fresh()
suite.check("not a hunter: no offer", offer == nil)
suite.check("and arrows are not kept", Ammo:Keeps(2512) == nil)
class = "HUNTER"

-- A full quiver: nothing to offer.
for slot = 1, 4 do
    fake.bags[1][slot] = { bag = 1, slot = slot, id = 2515, name = "Sharp Arrow", quality = 1, price = 1, count = 200 }
end
suite.check("a full quiver: no offer", Fresh() == nil)

env.Fire("MERCHANT_CLOSED")
suite.check("the vendor gone: no offer", Fresh() == nil)

-- A German client: the damage line is in German, written from the game's
-- own format string, with a decimal comma.
suite.check("English damage line read", Ammo.Damage(2, 2515) == 4.5, Ammo.Damage(2, 2515))
_G.AMMO_DAMAGE_TEMPLATE = "Verursacht zusätzlich %s Schaden pro Sekunde (+%s)."
Ammo.patterns = nil
local germanTip = { lines = { { leftText = "Scharfer Pfeil" },
    { leftText = "Verursacht zusätzlich 4,5 Schaden pro Sekunde (+1)." } } }
local englishTip = _G.C_TooltipInfo.GetMerchantItem
_G.C_TooltipInfo.GetMerchantItem = function() return germanTip end
suite.check("the game's own words for it, decimal comma and all", Ammo.Damage(2, 2515) == 4.5,
    Ammo.Damage(2, 2515))
germanTip.lines[2].leftText = "Verursacht zusätzlich 7 Schaden pro Sekunde (+1)."
suite.check("a whole number too", Ammo.Damage(2, 2515) == 7, Ammo.Damage(2, 2515))
suite.check("magic characters in the game's words are matched as they are",
    ("(+1)."):match(Ammo.PatternFrom("(+%d).")) == "1")
_G.C_TooltipInfo.GetMerchantItem = englishTip
suite.check("English lines still read with the German words first", Ammo.Damage(2, 2515) == 4.5)
_G.AMMO_DAMAGE_TEMPLATE = nil
Ammo.patterns = nil
suite.check("numbers: 2.5, 2,5 and 1,234.5", Ammo.ReadNumber("2.5") == 2.5 and Ammo.ReadNumber("2,5") == 2.5
    and Ammo.ReadNumber("1,234.5") == 1234.5 and Ammo.ReadNumber("3,5.") == 3.5)

suite.done()
