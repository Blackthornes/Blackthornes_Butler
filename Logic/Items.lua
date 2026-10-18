-- Blackthornes Butler -- Logic/Items.lua
-- What Butler needs to know about one item: what a vendor pays for it, its
-- kind, and its name, plus money in gold, silver and copper. Where the
-- client has not loaded an item yet, the Forever client's own game tables
-- (Data/ForeverItems.lua) stand in; the live game always wins.
--
-- Every client call is inside a pcall: Forever is a retail engine that hands
-- out secret values in instances, and a missing call must never stop the
-- list from drawing.

local _, ns = ...

local Items = ns.NewModule("Items")

local COPPER_PER_SILVER = 100
local COPPER_PER_GOLD = 100 * 100

--------------------------------------------------------------------------------
-- Client calls
--------------------------------------------------------------------------------

--- The function at a dotted path ("C_Container.GetContainerItemInfo"), or nil.
function Items.Resolve(path)
    local value = _G
    for part in path:gmatch("[^.]+") do
        if type(value) ~= "table" then return nil end
        value = value[part]
    end
    return type(value) == "function" and value or nil
end

--- Call the first of `paths` the client has, inside a pcall. Returns what it
--- returned, or nothing when none is there or it raised.
function Items.Call(paths, ...)
    for _, path in ipairs(paths) do
        local fn = Items.Resolve(path)
        if fn then
            local results = { pcall(fn, ...) }
            if not results[1] then return nil end
            return select(2, unpack(results))
        end
    end
    return nil
end

--------------------------------------------------------------------------------
-- Sell price
--------------------------------------------------------------------------------

-- Kept for the session: what a vendor pays never changes, and asking again
-- for every row on every redraw would be work for nothing. Only a real answer
-- is kept, so an item the client has not loaded yet is asked again later.
local priceMemo = {}

--- Forget what was kept (for tests, whose pretend items change).
function Items:Forget()
    priceMemo = {}
    Items.qualityMemo = {}
end

-- The tooltip line type retail gives "Sell Price:". 11 on every retail build
-- that has the enum.
local function SellPriceLineType()
    local enum = _G.Enum and _G.Enum.TooltipDataLineType
    return (type(enum) == "table" and enum.SellPrice) or 11
end

--- What the item's own tooltip says a vendor pays for one, or nil.
--
-- Forever's server changed some sell prices from Classic's, and only the
-- tooltip has the new one (Tradeskills found it, 2026-10-03: a wand whose
-- tooltip says 1c while the item info says 15s 35c). So the tooltip wins.
function Items.TooltipSellPrice(itemID)
    local get = Items.Resolve("C_TooltipInfo.GetItemByID")
    if not (get and itemID) then return nil end

    local ok, data = pcall(get, itemID)
    if not ok or type(data) ~= "table" or type(data.lines) ~= "table" then return nil end

    local sellType = SellPriceLineType()
    for _, line in ipairs(data.lines) do
        if type(line) == "table" then
            local price, kind = line.price, line.type
            if type(line.args) == "table" then
                for _, arg in ipairs(line.args) do
                    if type(arg) == "table" then
                        if arg.field == "type" and kind == nil then kind = arg.intVal end
                        if arg.field == "price" and price == nil then price = arg.intVal end
                    end
                end
            end
            local same = pcall(function() return kind == sellType end) and kind == sellType
            if same and type(price) == "number" and price >= 0 then
                return price
            end
        end
    end
    return nil
end

--- What a vendor pays for one, in copper: 0 when nothing, nil while the
--- client has not loaded the item yet.
function Items:SellPrice(itemID)
    if not itemID then return nil end
    local known = priceMemo[itemID]
    if known ~= nil then return known end

    local name, _, _, _, _, _, _, _, _, _, sellPrice =
        Items.Call({ "C_Item.GetItemInfo", "GetItemInfo" }, itemID)
    if not name then
        -- Until the client loads it, the Forever client's own table says
        -- (Data/ForeverItems.lua). Not kept: the live answer replaces it
        -- once GET_ITEM_INFO_RECEIVED says the item is here.
        Items:RequestLoad(itemID)
        return Items.TableSellPrice(itemID)
    end

    local fromTooltip = Items.TooltipSellPrice(itemID)
    if fromTooltip then sellPrice = fromTooltip end
    if type(sellPrice) ~= "number" then sellPrice = Items.TableSellPrice(itemID) or 0 end

    priceMemo[itemID] = sellPrice
    return sellPrice
end

--- What the Forever client's game tables say a vendor pays for one, or nil
--- when they don't say (Data/ForeverItems.lua). Only a stand-in: the item's
--- tooltip and item info win whenever the client has them.
function Items.TableSellPrice(itemID)
    local data = ns.ForeverItems
    local price = data and data.SELL and itemID and data.SELL[itemID]
    return type(price) == "number" and price or nil
end

--------------------------------------------------------------------------------
-- Bag family
--------------------------------------------------------------------------------

--- The family of the bag in bag slot `bag` (1 to 4) from the Forever
--- client's game tables, by the bag's own item: 1 arrows, 2 bullets, 4 soul
--- shards, 32 herbs and so on, nil for a bag that takes anything or one not
--- known. Only for when the client's own GetContainerNumFreeSlots gives no
--- family (a secret value, a call missing).
function Items.TableBagFamily(bag)
    local data = ns.ForeverItems
    if not (data and data.BAGS and type(bag) == "number" and bag > 0) then return nil end
    local slot = Items.Call({ "C_Container.ContainerIDToInventoryID", "ContainerIDToInventoryID" }, bag)
    if type(slot) ~= "number" then return nil end
    local itemID = Items.Call({ "GetInventoryItemID" }, "player", slot)
    local ok, family = pcall(function() return data.BAGS[tonumber(itemID)] end)
    return ok and type(family) == "number" and family or nil
end

--------------------------------------------------------------------------------
-- Kind
--------------------------------------------------------------------------------

-- Enum.ItemClass.Questitem on retail; 12 on every build.
local QUEST_CLASS = 12

--- The item's class ID, read from what the client always has (no loading).
function Items.ClassID(itemID)
    local _, _, _, _, _, classID = Items.Call({ "C_Item.GetItemInfoInstant", "GetItemInfoInstant" }, itemID)
    return tonumber(classID)
end

function Items.IsQuestClass(itemID)
    return Items.ClassID(itemID) == QUEST_CLASS
end

--- The name inside a link ("|cff...|Hitem:...|h[Linen Cloth]|h|r").
function Items.NameFromLink(link)
    if type(link) ~= "string" then return nil end
    local ok, name = pcall(string.match, link, "|h%[(.-)%]|h")
    return ok and name or nil
end

--------------------------------------------------------------------------------
-- Rarity colour
--------------------------------------------------------------------------------

-- The game's item quality colours, for a client without ITEM_QUALITY_COLORS:
-- Poor grey, Common white, Uncommon green, Rare blue, Epic purple,
-- Legendary orange.
Items.QUALITY_RGB = {
    [0] = { 0.616, 0.616, 0.616 },
    [1] = { 1, 1, 1 },
    [2] = { 0.118, 1, 0 },
    [3] = { 0, 0.439, 0.867 },
    [4] = { 0.639, 0.208, 0.933 },
    [5] = { 1, 0.502, 0 },
}

-- [itemID] = quality, kept for the session once the client says. A miss
-- is not kept, so the item is asked again once it has loaded.
Items.qualityMemo = {}

local function Unit(value)
    value = tonumber(value)
    if value and value == value and value >= 0 and value <= 1 then return value end
    return nil
end

--- The red, green and blue of `quality`, or nil for none: the game's own
--- table first, then its call, then the colours above.
function Items.QualityRGB(quality)
    quality = tonumber(quality)
    if not quality then return nil end
    local colors = rawget(_G, "ITEM_QUALITY_COLORS")
    local ok, r, g, b = pcall(function()
        local color = type(colors) == "table" and colors[quality]
        if type(color) == "table" then return color.r, color.g, color.b end
    end)
    if ok and Unit(r) and Unit(g) and Unit(b) then return r, g, b end
    r, g, b = Items.Call({ "C_Item.GetItemQualityColor", "GetItemQualityColor" }, quality)
    if Unit(r) and Unit(g) and Unit(b) then return r, g, b end
    local fixed = Items.QUALITY_RGB[quality]
    if fixed then return fixed[1], fixed[2], fixed[3] end
    return nil
end

--- "ffRRGGBB" for `quality`, for a |c colour code, or nil for none.
function Items.QualityHex(quality)
    local r, g, b = Items.QualityRGB(quality)
    if not r then return nil end
    local function Byte(value) return math.floor(value * 255 + 0.5) end
    return ("ff%02x%02x%02x"):format(Byte(r), Byte(g), Byte(b))
end

--- The item's quality (0 Poor to 5 Legendary and up), or nil while the
--- client has not loaded it (it is asked for, and GET_ITEM_INFO_RECEIVED
--- redraws). `known` is a quality already in hand (a bag slot's), which wins.
function Items:Quality(itemID, known)
    known = tonumber(known)
    if known then return known end
    itemID = tonumber(itemID)
    if not itemID then return nil end
    local memo = Items.qualityMemo
    if memo[itemID] then return memo[itemID] end
    local quality = tonumber((Items.Call({ "C_Item.GetItemQualityByID" }, itemID)))
    if not quality then
        local name, _, infoQuality = Items.Call({ "C_Item.GetItemInfo", "GetItemInfo" }, itemID)
        if name then quality = tonumber(infoQuality) end
    end
    if quality then
        memo[itemID] = quality
        return quality
    end
    Items:RequestLoad(itemID)
    return nil
end

--- `name` in the item's rarity colour, "|cff1eff00Truefaith Gloves|r",
--- only the name, so a sentence around it keeps its own colour. The name as
--- it is while the quality isn't known yet, and a link (already coloured
--- by the game) as it is.
function Items:ColorName(name, itemID, known)
    if type(name) ~= "string" or name == "" then return name end
    if name:find("|c", 1, true) or name:find("|H", 1, true) then return name end
    local hex = Items.QualityHex(self:Quality(itemID, known))
    if not hex then return name end
    return ("|c%s%s|r"):format(hex, name)
end

--------------------------------------------------------------------------------
-- Loading
--------------------------------------------------------------------------------

-- Items asked for and not yet answered: GET_ITEM_INFO_RECEIVED says which.
Items.waiting = {}

function Items:RequestLoad(itemID)
    if self.waiting[itemID] then return end
    self.waiting[itemID] = true
    Items.Call({ "C_Item.RequestLoadItemDataByID" }, itemID)
end

-- Answers come one event per item, often dozens together: one call after
-- they stop, 0.2 s later.
function Items:Loaded(itemID)
    if not self.waiting[itemID] then return end
    self.waiting[itemID] = nil
    if self.loadPending then return end
    self.loadPending = true
    C_Timer.After(0.2, function()
        Items.loadPending = false
        if ns.Everyone then ns.Everyone:NamesArrived() end
        if ns.Quests then ns.Quests:ItemsArrived() end
        if ns.Verdicts then ns.Verdicts:Changed() end
    end)
end

function Items:OnEnable()
    ns.RegisterEvent(self, "GET_ITEM_INFO_RECEIVED", function(_, _, itemID)
        Items:Loaded(itemID)
    end)
end

--------------------------------------------------------------------------------
-- Money
--------------------------------------------------------------------------------

local GOLD = "|cffffd700g|r"
local SILVER = "|cffc7c7cfs|r"
local COPPER = "|cffeda55fc|r"

--- Copper as gold, silver and copper, each coin in its own colour, as the
--- other four show money ("1g 05s 00c", "8s 00c", "45c").
function Items.FormatMoney(copper)
    if type(copper) ~= "number" then return "|c" .. ns.COLORS.muted .. "--|r" end
    local amount = math.floor(math.max(0, copper) + 0.5)
    local gold = math.floor(amount / COPPER_PER_GOLD)
    local silver = math.floor((amount % COPPER_PER_GOLD) / COPPER_PER_SILVER)
    local copperPart = amount % COPPER_PER_SILVER

    if gold > 0 then
        return ("%d%s %02d%s %02d%s"):format(gold, GOLD, silver, SILVER, copperPart, COPPER)
    elseif silver > 0 then
        return ("%d%s %02d%s"):format(silver, SILVER, copperPart, COPPER)
    end
    return ("%d%s"):format(copperPart, COPPER)
end
