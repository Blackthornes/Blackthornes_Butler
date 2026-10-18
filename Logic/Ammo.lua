-- Blackthornes Butler -- Logic/Ammo.lua
-- Filling a hunter's quiver or ammo pouch at a vendor (the owner asked
-- 2026-10-11: "butler should request filling your ammo pouch on a hunter at
-- a vendor that can do it, with the best ammo you can use, for the weapon
-- type you're using and pouch type you have on").
--
-- At a vendor that sells ammo for the bow, crossbow or gun the hunter has
-- on, the Butler window shows an Ammo row first: the best ammo that vendor
-- has which the hunter can use (most damage, read from the item's tooltip,
-- else the highest item level), how many fill the quiver or pouch and what
-- it costs, with a Fill button. Nothing is bought without that click.
--
-- What is never done:
--   * Buy arrows for a gun or bullets for a bow, or fill a quiver with
--     bullets: when the bag on doesn't match the weapon, the row says so
--     and has no button.
--   * Buy more than the quiver or pouch holds: only whole lots the vendor
--     sells that fit its empty slots and the room left in stacks of the
--     same ammo.
--   * Spend gold the character doesn't have: with less it buys what the
--     purse allows, and says so. The gold fund's amount (Logic/Funds.lua)
--     is only for mailing gold to alts, never for spending (the owner,
--     2026-10-11), so it plays no part here.
--
-- Ammo for the weapon the hunter has on is also kept out of Sell
-- (Verdicts:Decide asks Ammo:Keeps), since a vendor would always "pay
-- most" for it.
--
-- Smooth play: the vendor's list is read only while the window shows at a
-- vendor, again only when the bags, the purse, the gear or the vendor's
-- list moved (Ammo:Offer's key). A Fill click buys one lot every
-- Ammo.GAP seconds, so the game keeps up.

local _, ns = ...
local L = ns.L

local Ammo = ns.NewModule("Ammo")

local Items = ns.Items

-- Item classes the client numbers the same on every build.
local WEAPON_CLASS = 2
local PROJECTILE_CLASS = 6
local ARROW, BULLET = 2, 3

-- Ranged weapons and the ammo each fires.
Ammo.WEAPONS = {
    [2] = { word = "bow", ammo = "arrow" },
    [18] = { word = "crossbow", ammo = "arrow" },
    [3] = { word = "gun", ammo = "bullet" },
}
local AMMO_SUBCLASS = { arrow = ARROW, bullet = BULLET }

-- The bags made for each (their bag family: 1 holds arrows, 2 bullets).
-- `word` is the internal name; `label` is what the player reads.
Ammo.BAGS = {
    arrow = { family = 1, word = "quiver", label = L["quiver"] },
    bullet = { family = 2, word = "ammo pouch", label = L["ammo pouch"] },
}

-- The player's words for each weapon and bag, one whole sentence a key, so
-- German can give each its own grammar. Keyed by the internal words above.
local KEEPS = {
    bow = L["Ammo for your bow"],
    crossbow = L["Ammo for your crossbow"],
    gun = L["Ammo for your gun"],
}
local NO_BAG = {
    bow = L["Put on a quiver to fill it with these"],
    crossbow = L["Put on a quiver to fill it with these"],
    gun = L["Put on an ammo pouch to fill it with these"],
}
local MISMATCH = {
    bow = L["Your bow needs a quiver, not an ammo pouch"],
    crossbow = L["Your crossbow needs a quiver, not an ammo pouch"],
    gun = L["Your gun needs an ammo pouch, not a quiver"],
}

-- The ranged slot, then the main hand (a client that moved ranged weapons
-- there).
local SLOTS = { 18, 16 }

-- Between one lot bought and the next.
Ammo.GAP = 0.2

-- Moves when the gear or the vendor's list did.
Ammo.version = 0

local function Call(paths, ...)
    return Items.Call(paths, ...)
end

local function InCombat()
    return type(InCombatLockdown) == "function" and InCombatLockdown() and true or false
end

local function Purse()
    if type(GetMoney) ~= "function" then return nil end
    local ok, money = pcall(function() return tonumber(GetMoney()) end)
    return ok and money or nil
end

local function IDFromLink(link)
    if type(link) ~= "string" then return nil end
    local ok, id = pcall(function() return tonumber(link:match("item:(%d+)")) end)
    return ok and id or nil
end

--- Is the character playing a hunter?
function Ammo.IsHunter()
    if type(UnitClass) ~= "function" then return false end
    local ok, _, class = pcall(UnitClass, "player")
    return ok and class == "HUNTER"
end

local function Level()
    if type(UnitLevel) ~= "function" then return nil end
    local ok, level = pcall(UnitLevel, "player")
    return ok and tonumber(level) or nil
end

local function ClassOf(itemID)
    local _, _, _, _, _, classID, subclassID = Call({ "C_Item.GetItemInfoInstant", "GetItemInfoInstant" }, itemID)
    return tonumber(classID), tonumber(subclassID)
end

--------------------------------------------------------------------------------
-- What the hunter has on
--------------------------------------------------------------------------------

--- The ranged weapon on: { word = "bow", ammo = "arrow", itemID }, or nil.
--- Kept until the gear changes.
function Ammo:Weapon()
    if self.weaponRead then return self.weapon end
    self.weaponRead = true
    self.weapon = nil
    if not self.IsHunter() then return nil end
    for _, slot in ipairs(SLOTS) do
        local id = tonumber((Call({ "GetInventoryItemID" }, "player", slot)))
        if id then
            local classID, subclassID = ClassOf(id)
            local kind = classID == WEAPON_CLASS and self.WEAPONS[subclassID]
            if kind then
                self.weapon = { word = kind.word, ammo = kind.ammo, itemID = id }
                break
            end
        end
    end
    return self.weapon
end

--- The quiver or ammo pouch on: { bag, holds = "arrow" | "bullet", word,
--- name }, or nil.
function Ammo:Bag()
    local last = tonumber(_G.NUM_BAG_SLOTS) or 4
    for bag = 1, last do
        local _, family = Call({ "C_Container.GetContainerNumFreeSlots", "GetContainerNumFreeSlots" }, bag)
        local ok, read = pcall(function() return tonumber(family) + 0 end)
        family = (ok and type(read) == "number" and read) or Items.TableBagFamily(bag) or 0
        for holds, kind in pairs(self.BAGS) do
            if math.floor(family / kind.family) % 2 == 1 then
                local name = Call({ "C_Container.GetBagName", "GetBagName" }, bag)
                return { bag = bag, holds = holds, word = kind.word, label = kind.label, name = type(name) == "string" and name or nil }
            end
        end
    end
    return nil
end

--- Ammo the hunter's weapon fires, kept out of Sell: the reason, or nil.
function Ammo:Keeps(itemID)
    local weapon = self:Weapon()
    if not weapon then return nil end
    local classID, subclassID = ClassOf(itemID)
    if classID == PROJECTILE_CLASS and subclassID == AMMO_SUBCLASS[weapon.ammo] then
        return KEEPS[weapon.word]
    end
    return nil
end

--- How many of `itemID` fit in the ammo bag: its empty slots and the room
--- left in its stacks of the same ammo. Read live (a quiver is a few slots).
function Ammo.Room(bag, itemID, stack)
    local slots = tonumber((Call({ "C_Container.GetContainerNumSlots", "GetContainerNumSlots" }, bag))) or 0
    local room = 0
    for slot = 1, slots do
        local entry = ns.Bags.ReadSlot(bag, slot)
        if not entry then
            room = room + stack
        elseif entry.itemID == itemID then
            room = room + math.max(0, stack - entry.count)
        end
    end
    return room
end

--------------------------------------------------------------------------------
-- What the vendor sells
--------------------------------------------------------------------------------

--- One of the vendor's items: { name, icon, price (copper a lot), perBuy,
--- available (-1 for no limit), usable, purchasable, extended }, or nil.
function Ammo.MerchantItem(index)
    local info = Call({ "C_MerchantFrame.GetItemInfo" }, index)
    if type(info) == "table" then
        local ok, item = pcall(function()
            return {
                name = info.name, icon = info.texture, price = tonumber(info.price),
                perBuy = tonumber(info.stackCount) or 1, available = tonumber(info.numAvailable) or -1,
                usable = info.isUsable ~= false, purchasable = info.isPurchasable ~= false,
                extended = info.hasExtendedCost and true or false,
            }
        end)
        if ok then return item end
    end
    local name, icon, price, perBuy, available, purchasable, usable, extended =
        Call({ "GetMerchantItemInfo" }, index)
    if not name then return nil end
    return {
        name = name, icon = icon, price = tonumber(price), perBuy = tonumber(perBuy) or 1,
        available = tonumber(available) or -1, usable = usable ~= false,
        purchasable = purchasable ~= false, extended = extended and true or false,
    }
end

-- The English lines, kept after the game's own (below) as a fallback.
local DPS_PATTERNS = { "Adds ([%d%.]+) damage per second", "([%d%.]+) damage per second" }

-- A number as the client writes it: "2.5", or "2,5" on a German client.
local NUMBER = "([%d%.,]+)"

--- A Lua pattern that reads the number out of a line the game writes from
--- a format string ("Adds %s damage per second"), or nil. Every other
--- character is matched as it is.
function Ammo.PatternFrom(template)
    if type(template) ~= "string" or template == "" then return nil end
    local parts, pos, found = {}, 1, false
    while true do
        local from, to = template:find("%%[%d%$%.%-]*[sgfd]", pos)
        if not from then break end
        parts[#parts + 1] = template:sub(pos, from - 1):gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0")
        parts[#parts + 1] = NUMBER
        found = true
        pos = to + 1
    end
    if not found then return nil end
    parts[#parts + 1] = template:sub(pos):gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0")
    return table.concat(parts)
end

--- The patterns tried on each tooltip line: the game's own words for the
--- ammo line first (AMMO_DAMAGE_TEMPLATE, in the client's language), then
--- the English ones. Built once.
function Ammo.DamagePatterns()
    if Ammo.patterns then return Ammo.patterns end
    local list = {}
    local ok, template = pcall(rawget, _G, "AMMO_DAMAGE_TEMPLATE")
    local own = ok and Ammo.PatternFrom(template) or nil
    if own then list[1] = own end
    for _, pattern in ipairs(DPS_PATTERNS) do list[#list + 1] = pattern end
    Ammo.patterns = list
    return list
end

--- "2.5" or "2,5" as 2.5, or nil.
function Ammo.ReadNumber(text)
    if type(text) ~= "string" then return nil end
    text = text:gsub("[%.,]+$", "")
    if text:find(",", 1, true) and not text:find(".", 1, true) then
        text = text:gsub(",", ".")
    else
        text = text:gsub(",", "")
    end
    return tonumber(text)
end

--- The damage a second the ammo adds, from the vendor item's tooltip (or
--- the item's), or nil when the client doesn't say.
function Ammo.Damage(index, itemID)
    local data = Call({ "C_TooltipInfo.GetMerchantItem" }, index)
    if type(data) ~= "table" then data = Call({ "C_TooltipInfo.GetItemByID" }, itemID) end
    if type(data) ~= "table" then return nil end
    local ok, dps = pcall(function()
        for _, line in ipairs(data.lines or {}) do
            local text = line.leftText
            if type(text) == "string" then
                for _, pattern in ipairs(Ammo.DamagePatterns()) do
                    local value = Ammo.ReadNumber(text:match(pattern))
                    if value then return value end
                end
            end
        end
    end)
    return ok and dps or nil
end

--- Better ammo first: more damage, then a higher item level, then a
--- higher level to use, then cheaper.
function Ammo.Better(a, b)
    if (a.damage or 0) ~= (b.damage or 0) then return (a.damage or 0) > (b.damage or 0) end
    if (a.itemLevel or 0) ~= (b.itemLevel or 0) then return (a.itemLevel or 0) > (b.itemLevel or 0) end
    if (a.minLevel or 0) ~= (b.minLevel or 0) then return (a.minLevel or 0) > (b.minLevel or 0) end
    return (a.price or 0) / math.max(1, a.perBuy) < (b.price or 0) / math.max(1, b.perBuy)
end

--- The vendor's ammo of `kind` ("arrow", "bullet") the hunter can use,
--- best first.
function Ammo:Choices(kind)
    local list = {}
    local count = tonumber((Call({ "GetMerchantNumItems" }))) or 0
    local level = Level()
    for index = 1, count do
        local itemID = IDFromLink(Call({ "GetMerchantItemLink" }, index))
        local classID, subclassID
        if itemID then classID, subclassID = ClassOf(itemID) end
        if classID == PROJECTILE_CLASS and subclassID == AMMO_SUBCLASS[kind] then
            local item = self.MerchantItem(index)
            if item and item.usable and item.purchasable and not item.extended and item.price
                and item.available ~= 0 then
                local name, _, _, itemLevel, minLevel, _, _, stack = Call({ "C_Item.GetItemInfo", "GetItemInfo" }, itemID)
                if not name then Items:RequestLoad(itemID) end
                minLevel = tonumber(minLevel)
                if not (level and minLevel and minLevel > level) then
                    item.index, item.itemID = index, itemID
                    item.name = item.name or name
                    item.itemLevel, item.minLevel = tonumber(itemLevel), minLevel
                    -- Not loaded yet: count a stack as one lot, which never buys too many.
                    item.stack = math.max(tonumber(stack) or 0, item.perBuy)
                    item.damage = self.Damage(index, itemID)
                    list[#list + 1] = item
                end
            end
        end
    end
    table.sort(list, self.Better)
    return list
end

--------------------------------------------------------------------------------
-- The offer
--------------------------------------------------------------------------------

--- What to offer at this vendor, or nil: { state, ammo (the vendor item),
--- weapon, bag, count, lots, cost, short }. `state` is "fill" (the
--- Fill button), "nobag" (no quiver or pouch on), "mismatch" (the bag on
--- doesn't hold this ammo) or "poor" (the purse can't pay for one lot). Nil when it isn't a hunter, no vendor is open, the vendor sells
--- no ammo the hunter can use, or the bag is full.
function Ammo:Offer()
    if not (ns.Selling and ns.Selling:MerchantOpen()) then return nil end
    local purse = Purse()
    local key = ("%d:%d:%d:%s"):format(self.version, ns.Bags.version, ns.Verdicts.version,
        tostring(purse))
    if self.offerKey == key then return self.offer end
    self.offerKey = key
    self.offer = self:Work(purse)
    return self.offer
end

function Ammo:Work(purse)
    local weapon = self:Weapon()
    if not weapon then return nil end
    local best = self:Choices(weapon.ammo)[1]
    if not best then return nil end

    local offer = { ammo = best, weapon = weapon }
    local bag = self:Bag()
    offer.bag = bag
    if not bag then
        offer.state = "nobag"
        return offer
    end
    if bag.holds ~= weapon.ammo then
        offer.state = "mismatch"
        return offer
    end

    local room = self.Room(bag.bag, best.itemID, best.stack)
    local lots = math.floor(room / best.perBuy)
    if best.available > 0 then lots = math.min(lots, math.floor(best.available)) end
    if lots < 1 then return nil end

    if best.price > 0 then
        local afford = math.max(0, math.floor((purse or 0) / best.price))
        if afford < lots then
            offer.short = true
            offer.full = lots * best.perBuy
            offer.fullCost = lots * best.price
            lots = afford
        end
    end
    if lots < 1 then
        offer.state = "poor"
        return offer
    end
    offer.state = "fill"
    offer.lots = lots
    offer.count = lots * best.perBuy
    offer.cost = lots * best.price
    return offer
end

local function Thousands(number)
    local text = tostring(math.floor(number))
    local done
    repeat
        text, done = text:gsub("^(%d+)(%d%d%d)", "%1,%2")
    until done == 0
    return text
end
Ammo.Thousands = Thousands

--- What the Ammo row says.
function Ammo.Reason(offer)
    local weapon, bag = offer.weapon, offer.bag
    local quiver = bag and bag.holds == "arrow"
    if offer.state == "nobag" then
        return NO_BAG[weapon.word]
    elseif offer.state == "mismatch" then
        return MISMATCH[weapon.word]
    elseif offer.state == "poor" then
        if quiver then
            return L.Format("Room for %s (%s), but not enough gold yet",
                Thousands(offer.full), Items.FormatMoney(offer.fullCost))
        end
        return L.Format("Room for %s (%s), but not enough gold yet",
            Thousands(offer.full), Items.FormatMoney(offer.fullCost))
    end
    local text
    if quiver then
        text = L.Format("Fills your quiver: %s for %s", Thousands(offer.count), Items.FormatMoney(offer.cost))
    else
        text = L.Format("Fills your ammo pouch: %s for %s", Thousands(offer.count), Items.FormatMoney(offer.cost))
    end
    if offer.short then
        text = L.Format("%s, all you can pay for now", text)
    end
    return text
end

--------------------------------------------------------------------------------
-- Buying
--------------------------------------------------------------------------------

--- Fill the quiver or pouch: one lot every Ammo.GAP seconds, each checked
--- again first (the vendor still open, the same item at that place, and
--- gold to pay). Only on the player's click.
function Ammo:Buy()
    if self.buying then return end
    local offer = self:Offer()
    if not (offer and offer.state == "fill") then return end
    local ammo = offer.ammo
    self.buying = true
    -- A run of its own: a vendor closed and opened again before the next
    -- lot must not carry on with the first vendor's list and prices.
    self.run = (self.run or 0) + 1
    local run = self.run
    if ns.UI and ns.UI.Refresh then ns.UI:Refresh(true) end
    local bought, spent = 0, 0

    local function Done()
        Ammo.buying = false
        if bought > 0 then
            local full = bought >= offer.lots and not offer.short
            local amount, name, money = Thousands(bought * ammo.perBuy),
                ammo.name and Items:ColorName(ammo.name, ammo.itemID) or L["ammo"], Items.FormatMoney(spent)
            if not full then
                ns.Print(L.Format("bought %s %s for %s.", amount, name, money))
            elseif offer.bag.holds == "arrow" then
                ns.Print(L.Format("bought %s %s for %s. Your quiver is full.", amount, name, money))
            else
                ns.Print(L.Format("bought %s %s for %s. Your ammo pouch is full.", amount, name, money))
            end
        end
        Ammo.offerKey = nil
        if ns.UI and ns.UI.Refresh then ns.UI:Refresh(true) end
    end

    local function Step()
        if Ammo.run ~= run then return Done() end
        if bought >= offer.lots or not ns.Selling:MerchantOpen(true) or InCombat() then return Done() end
        if IDFromLink(Call({ "GetMerchantItemLink" }, ammo.index)) ~= ammo.itemID then return Done() end
        local purse = Purse()
        if not purse or purse < ammo.price then return Done() end
        local fn = Items.Resolve("BuyMerchantItem")
        if not (fn and pcall(fn, ammo.index)) then return Done() end
        bought = bought + 1
        spent = spent + ammo.price
        C_Timer.After(Ammo.GAP, Step)
    end

    Step()
end

--- One line for /bbutler probe: the weapon and ammo bag Butler sees.
function Ammo:ProbeText()
    if not self.IsHunter() then return "not a hunter" end
    self.weaponRead = false
    local weapon, bag = self:Weapon(), self:Bag()
    local text = weapon and ("%s, fires %ss"):format(weapon.word, weapon.ammo) or "no bow, crossbow or gun found"
    if bag then
        text = ("%s; %s in bag %d holds %ss"):format(text, bag.word, bag.bag, bag.holds)
    else
        text = text .. "; no quiver or ammo pouch found"
    end
    return text
end

--------------------------------------------------------------------------------
-- Events
--------------------------------------------------------------------------------

function Ammo:GearChanged()
    self.weaponRead = false
    self.version = self.version + 1
    if ns.Verdicts then ns.Verdicts:Changed() end
end

function Ammo:VendorChanged()
    self.version = self.version + 1
    if ns.UI and ns.UI.IsShown and ns.UI:IsShown() then ns.UI:Refresh() end
end

function Ammo:OnEnable()
    ns.RegisterEvent(self, "PLAYER_EQUIPMENT_CHANGED", function(_, _, slot)
        if slot == nil or slot == 16 or slot == 18 then Ammo:GearChanged() end
    end)
    ns.RegisterEvent(self, "MERCHANT_SHOW", function() Ammo.version = Ammo.version + 1 end)
    -- The vendor's list changes (stock sold out, an item loaded) in bursts.
    ns.RegisterEvent(self, "MERCHANT_UPDATE", function()
        if Ammo.updating then return end
        Ammo.updating = true
        C_Timer.After(0.2, function()
            Ammo.updating = false
            Ammo:VendorChanged()
        end)
    end)
    ns.RegisterEvent(self, "MERCHANT_CLOSED", function()
        Ammo.offer, Ammo.offerKey = nil, nil
        Ammo.run = (Ammo.run or 0) + 1
    end)
end
