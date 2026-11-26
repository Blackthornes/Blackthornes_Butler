-- Blackthornes Butler -- Logic/Kinds.lua
-- One rule for a whole kind of item (a player asked, the owner said build
-- it, 2026-11-26): Crates and Lockboxes, Writs, Mage Scrolls, Recipes I
-- Know and Pet Food, each Keep, Sell, Bank or As Butler Says, on the Keep
-- page under YOUR LISTS.
--
-- Saved account wide as kindRules = { [kind] = "keep" | "sell" | "bank" }
-- (never rename it); a kind with no entry is As Butler Says, so nothing
-- changes until the player picks. A mark on one item (an Always list) or a
-- number kept here wins over a kind: Verdicts' "kinds" step skips them.
--
-- How a kind is told, from what the client gives (each read in a pcall):
--   crates   the item's tooltip says it opens (ITEM_OPENABLE) or is
--            locked (LOCKED), or the bag slot says it has loot
--   writs    the name holds "Writ" (Craftsman's Writs and the sealed ones
--            mobs drop); checked before crates, since a sealed writ opens
--   scrolls  a consumable (class 0) only a Mage can use (the tooltip's
--            "Classes: Mage" line, ITEM_CLASSES_ALLOWED)
--   recipes  a recipe (class 9) whose tooltip says it is known already
--            (ITEM_SPELL_KNOWN)
--   petFood  Blackthornes Pets says the pet eats it
-- None of these is seen on Forever yet: /bbutler probe has a "kinds" line.

local _, ns = ...
local L = ns.L

local Kinds = ns.NewModule("Kinds")

local Items = ns.Items

Kinds.LIST = { "crates", "writs", "scrolls", "recipes", "petFood" }
Kinds.LABELS = {
    crates = L["Crates and Lockboxes"],
    writs = L["Writs"],
    scrolls = L["Mage Scrolls"],
    recipes = L["Recipes I Know"],
    petFood = L["Pet Food"],
}
-- The same, as Settings rows on the Keep page.
Kinds.ROW_LABELS = {
    crates = L["Crates and Lockboxes:"],
    writs = L["Writs:"],
    scrolls = L["Mage Scrolls:"],
    recipes = L["Recipes I Know:"],
    petFood = L["Pet Food:"],
}
-- What a kind's rule can say; nil is As Butler Says.
Kinds.CHOICES = { "keep", "sell", "bank" }
local CHOICE = { keep = true, sell = true, bank = true }

local CONSUMABLE, RECIPE = 0, 9

local function Rules()
    if not ns.db then return nil end
    if type(ns.db.kindRules) ~= "table" then return nil end
    return ns.db.kindRules
end

--- What the player picked for a kind: "keep", "sell", "bank" or nil.
function Kinds:Rule(kind)
    local rules = Rules()
    local choice = rules and rules[kind]
    return CHOICE[choice] and choice or nil
end

--- Set a kind's rule (nil for As Butler Says).
function Kinds:SetRule(kind, choice)
    if not (ns.db and self.LABELS[kind]) then return end
    if choice ~= nil and not CHOICE[choice] then return end
    if type(ns.db.kindRules) ~= "table" then ns.db.kindRules = {} end
    ns.db.kindRules[kind] = choice
    if next(ns.db.kindRules) == nil then ns.db.kindRules = nil end
    if ns.Verdicts then ns.Verdicts:Changed(true) end
end

--- True while any kind has a rule.
function Kinds:AnyOn()
    for _, kind in ipairs(self.LIST) do
        if self:Rule(kind) then return true end
    end
    return false
end

--- The tooltip's left-hand lines for an item, or nil.
function Kinds.TipLines(entry)
    local data
    local byBag = Items.Resolve("C_TooltipInfo.GetBagItem")
    if byBag and entry.bag and entry.slot then
        local ok, got = pcall(byBag, entry.bag, entry.slot)
        if ok then data = got end
    end
    if type(data) ~= "table" then
        local byID = Items.Resolve("C_TooltipInfo.GetItemByID")
        if not (byID and entry.itemID) then return nil end
        local ok, got = pcall(byID, entry.itemID)
        if not ok then return nil end
        data = got
    end
    if type(data) ~= "table" or type(data.lines) ~= "table" then return nil end
    local texts = {}
    for _, line in ipairs(data.lines) do
        local ok, text = pcall(function() return line.leftText end)
        if ok and type(text) == "string" and text ~= "" then texts[#texts + 1] = text end
    end
    return texts
end

local function Has(texts, wanted)
    if not (texts and type(wanted) == "string" and wanted ~= "") then return false end
    for _, text in ipairs(texts) do
        if text == wanted then return true end
    end
    return false
end

local function Global(name, fallback)
    local value = rawget(_G, name)
    return type(value) == "string" and value or fallback
end

--- "Classes: Mage" in the client's words.
function Kinds.MageLine()
    local names = rawget(_G, "LOCALIZED_CLASS_NAMES_MALE")
    local mage = type(names) == "table" and type(names.MAGE) == "string" and names.MAGE or "Mage"
    local format = Global("ITEM_CLASSES_ALLOWED", "Classes: %s")
    local ok, text = pcall(string.format, format, mage)
    return ok and text or "Classes: Mage"
end

local function IsWrit(name)
    if type(name) ~= "string" then return false end
    -- By the English name only for now: how other clients name writs is
    -- not seen yet.
    return name:find("Writ", 1, true) ~= nil
end

--- The kind of an item in the bags, or nil.
function Kinds:Of(entry)
    if type(entry) ~= "table" or not entry.itemID then return nil end
    local name = Items.NameFromLink(entry.link)
    if IsWrit(name) then return "writs" end
    local classID = Items.ClassID(entry.itemID)
    -- A class this addon never sorts and no rule wants: no tooltip read.
    local texts
    local function Tip()
        if texts == nil then texts = Kinds.TipLines(entry) or false end
        return texts or nil
    end
    if self:Rule("recipes") and classID == RECIPE then
        if Has(Tip(), Global("ITEM_SPELL_KNOWN", "Already known")) then return "recipes" end
        return nil
    end
    if self:Rule("scrolls") and classID == CONSUMABLE then
        if Has(Tip(), Kinds.MageLine()) then return "scrolls" end
    end
    if self:Rule("crates") then
        if entry.openable then return "crates" end
        local tip = Tip()
        if Has(tip, Global("ITEM_OPENABLE", "<Right Click to Open>")) or Has(tip, Global("LOCKED", "Locked")) then
            return "crates"
        end
    end
    if self:Rule("petFood") and ns.Sisters then
        local pets = ns.Sisters:Ask("pets", entry)
        if ns.Sisters.True(pets, "eats") then return "petFood" end
    end
    return nil
end

--- The rule for this item's kind: verdict and reason, or nil.
function Kinds:For(entry)
    if not self:AnyOn() then return nil end
    local kind = self:Of(entry)
    local choice = kind and self:Rule(kind)
    if not choice then return nil end
    return choice, L.Format("Your rule for %s", self.LABELS[kind]), kind
end

--- What /bbutler probe prints: each bag item's kind and how it was told.
function Kinds:ProbeText()
    local found, seen = {}, {}
    local slots = ns.Bags and ns.Bags.slots or {}
    for _, entry in pairs(slots) do
        local name = Items.NameFromLink(entry.link)
        if entry.itemID and not seen[entry.itemID] then
            seen[entry.itemID] = true
            local classID = Items.ClassID(entry.itemID)
            local tip = Kinds.TipLines(entry)
            local tags = {}
            if IsWrit(name) then tags[#tags + 1] = "writ name" end
            if entry.openable then tags[#tags + 1] = "has loot" end
            if Has(tip, Global("ITEM_OPENABLE", "<Right Click to Open>")) then tags[#tags + 1] = "opens" end
            if Has(tip, Global("LOCKED", "Locked")) then tags[#tags + 1] = "locked" end
            if classID == CONSUMABLE and Has(tip, Kinds.MageLine()) then tags[#tags + 1] = "mage only" end
            if classID == RECIPE then
                tags[#tags + 1] = Has(tip, Global("ITEM_SPELL_KNOWN", "Already known")) and "recipe known" or "recipe"
            end
            if #tags > 0 then
                found[#found + 1] = ("%s (class %s: %s)"):format(tostring(name or entry.itemID),
                    tostring(classID), table.concat(tags, ", "))
            end
        end
    end
    local on = {}
    for _, kind in ipairs(self.LIST) do
        local rule = self:Rule(kind)
        if rule then on[#on + 1] = kind .. "=" .. rule end
    end
    return ("rules %s; in bags: %s"):format(#on > 0 and table.concat(on, " ") or "none",
        #found > 0 and table.concat(found, "; ") or "none")
end
