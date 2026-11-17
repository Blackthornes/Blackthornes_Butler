-- Blackthornes Butler -- Logic/Wishlist.lua
-- Recipes on the wishlist (the owner said build it, 2026-11-17, from a
-- mockup with the words he approved). Tradeskills keeps a wishlist of
-- recipes each character starred. At a vendor or trainer that teaches one,
-- Butler shows a row for each: "Buy a recipe on your wishlist" with Buy, or
-- "Learn a recipe on your wishlist" with Learn. Tradeskills' own card under
-- the window stays hidden while this module is loaded, so there is one note.
--
-- Tradeskills answers, inside a pcall, read only:
--
--   _G.BlackthornesTS.Butler:WishlistHere()
--     -- { { recipeID, name, itemID, price, needs, short, kind = "vendor" or
--     --     "trainer", index } }, or nil
--
-- Butler buys (BuyMerchantItem) or trains (BuyTrainerService) by index
-- itself, one a click, and never changes the wishlist. Without Tradeskills,
-- or with its "Recipe Wishlist:" off, nothing shows.

local _, ns = ...
local L = ns.L or setmetatable({ Format = string.format }, { __index = function(_, key) return key end })

local Wishlist = ns.NewModule("Wishlist")

local Items = ns.Items

-- How long after a vendor or trainer opens the window looks again:
-- Tradeskills reads the vendor's list a moment after it opens.
Wishlist.LOOK_AGAIN = 0.6

Wishlist.key = ""

--- Tradeskills' Butler table when it is loaded and has `method`.
local function Tradeskills(method)
    local global = rawget(_G, "BlackthornesTS")
    if type(global) ~= "table" then return nil end
    local butler = rawget(global, "Butler")
    if type(butler) ~= "table" or type(butler[method]) ~= "function" then return nil end
    return butler
end

local function Whole(value)
    value = tonumber(value)
    if value and value == value and value ~= math.huge and value ~= -math.huge then
        return math.floor(value + 0.5)
    end
    return nil
end

local function Text(value)
    if type(value) ~= "string" or value == "" then return nil end
    return value
end

--- Is a vendor or trainer open?
function Wishlist.Open()
    local vendor = ns.Selling and ns.Selling.merchantOpen
    local trainer = ns.ClassTraining and ns.ClassTraining.trainerOpen
    return vendor == true or trainer == true
end

--- Tradeskills' answer, checked field by field, kept as `Wishlist.list`;
--- empty away from a vendor or trainer, without Tradeskills, or when it
--- raises.
function Wishlist:Read()
    local list = {}
    local ts = Wishlist.Open() and Tradeskills("WishlistHere")
    if ts then
        local ok, answer = pcall(ts.WishlistHere, ts)
        if ok and type(answer) == "table" then
            for _, entry in ipairs(answer) do
                local kind = type(entry) == "table" and entry.kind
                local recipeID = type(entry) == "table" and Whole(entry.recipeID)
                if recipeID and (kind == "vendor" or kind == "trainer") then
                    list[#list + 1] = {
                        recipeID = recipeID, kind = kind,
                        name = Text(entry.name), itemID = Whole(entry.itemID),
                        price = Whole(entry.price), needs = Whole(entry.needs),
                        short = Whole(entry.short), index = Whole(entry.index),
                    }
                end
            end
        end
    end
    self.list = list
    local parts = {}
    for _, entry in ipairs(list) do
        parts[#parts + 1] = ("%s%d:%d:%s"):format(entry.kind, entry.recipeID, entry.index or 0,
            tostring(entry.short))
    end
    self.key = table.concat(parts, ",")
    return list
end

--- One row a recipe, read last by Read (the window's Refresh reads first).
function Wishlist:Rows()
    local rows = {}
    for _, entry in ipairs(self.list or {}) do
        rows[#rows + 1] = { type = "wishlist", entry = entry }
    end
    return rows
end

--- The recipe's name: the recipe item's at a vendor, else Tradeskills'.
function Wishlist.Name(entry)
    if entry.kind == "vendor" and entry.itemID and ns.Jobs and ns.Jobs.ItemName then
        local ok, name = pcall(ns.Jobs.ItemName, entry.itemID, entry.name)
        if ok and Text(name) then return name end
    end
    return entry.name or L.Format("Item %s", tostring(entry.itemID or entry.recipeID))
end

--- The row's title and the words under it: the recipe and its price, or
--- the skill it needs when the character is short of it.
function Wishlist.Text(entry)
    local title = entry.kind == "trainer" and L["Learn a recipe on your wishlist"]
        or L["Buy a recipe on your wishlist"]
    local detail = Wishlist.Name(entry)
    if entry.short then
        detail = detail .. ", " .. L.Format("Learn at %d", entry.short)
    elseif entry.price and entry.price > 0 then
        detail = detail .. ", " .. Items.FormatMoney(entry.price)
    end
    return title, detail
end

--- Does the row get its button? A vendor sells it whatever the skill; a
--- trainer only teaches a line it shows as ready.
function Wishlist.Clickable(entry)
    if not (entry and entry.index) then return false end
    if entry.kind == "trainer" then return entry.short == nil end
    return true
end

--- The button's words.
function Wishlist.ButtonText(entry)
    return entry.kind == "trainer" and L["Learn"] or L["Buy"]
end

local function InCombat()
    return type(InCombatLockdown) == "function" and InCombatLockdown() and true or false
end

--- Buy or Learn, one a click, after checking the place still holds it.
-- @return true when the game was asked
function Wishlist:Click(entry)
    if not Wishlist.Clickable(entry) or InCombat() then return false end
    if entry.kind == "trainer" then
        if not (ns.ClassTraining and ns.ClassTraining.trainerOpen) then return false end
        local ok, name = pcall(GetTrainerServiceInfo, entry.index)
        if not ok or type(name) ~= "string" or (entry.name and name:lower() ~= entry.name:lower()) then
            self:LookAgain()
            return false
        end
        if type(BuyTrainerService) ~= "function" then return false end
        local bought = pcall(BuyTrainerService, entry.index)
        self:LookAgain()
        return bought
    end
    if not (ns.Selling and ns.Selling.merchantOpen) then return false end
    local ok, link = pcall(GetMerchantItemLink, entry.index)
    local itemID = ok and type(link) == "string" and tonumber(link:match("item:(%d+)")) or nil
    if entry.itemID and itemID ~= entry.itemID then
        self:LookAgain()
        return false
    end
    if type(BuyMerchantItem) ~= "function" then return false end
    local bought = pcall(BuyMerchantItem, entry.index, 1)
    self:LookAgain()
    return bought
end

--- Draw the window again a moment from now, once.
function Wishlist:LookAgain()
    if self.looking or not (C_Timer and C_Timer.After) then return end
    self.looking = true
    C_Timer.After(Wishlist.LOOK_AGAIN, function()
        Wishlist.looking = false
        local ui = ns.UI
        if ui and ui.IsShown and ui:IsShown() then ui:Refresh() end
    end)
end

function Wishlist:OnEnable()
    if not ns.RegisterEvent then return end
    for _, event in ipairs({ "MERCHANT_SHOW", "MERCHANT_UPDATE", "TRAINER_SHOW", "TRAINER_UPDATE" }) do
        ns.RegisterEvent(self, event, function() Wishlist:LookAgain() end)
    end
end
