-- Blackthornes Butler -- Logic/ListRules.lua
-- Butler's rules for the player's Tradeskills lists (the owner said build
-- it, 2026-10-19, from a mockup): each list can mail what is on it to one
-- of the player's characters (Mail To) and keep some of each on every
-- character (Keep Here). Tradeskills only holds the lists (its
-- Butler:Lists(), read through BankAlt:Lists()); Butler does the work.
--
-- Saved account wide by the list's id, so a rename keeps them, never
-- renamed:
--   listRules = { [list id] = { mailTo = full name, keep = count } }
-- A list with neither has no entry, so nobody's setup changes until a rule
-- is set.
--
-- An item on two lists follows the first one on Tradeskills' Lists view
-- that has a rule here. Keep Here joins the keep Butler and Tradeskills
-- share (KeepHere:Effective): the bigger number wins. Mail To is the rule
-- "Your Lists" in Verdicts (STEPS.lists), right after the Always mail list;
-- once the item reaches that character it stays there, as with Always mail.

local _, ns = ...

local ListRules = ns.NewModule("ListRules")

-- The most Keep Here takes, as Keep on This Character.
ListRules.MOST = 9999

local function Text(value)
    if type(value) == "string" and value ~= "" then return value end
    return nil
end

local function Clean(count)
    count = math.floor(tonumber(count) or 0)
    return math.max(0, math.min(ListRules.MOST, count))
end

local function Saved()
    if not ns.db then return nil end
    if type(ns.db.listRules) ~= "table" then ns.db.listRules = {} end
    return ns.db.listRules
end

--- The player's lists from Tradeskills: { { name, id, items } } in their
--- order, empty without Tradeskills.
function ListRules:Lists()
    return ns.BankAlt and ns.BankAlt:Lists() or {}
end

--- A list's rules here: { mailTo, keep }, a fresh table, empty for none.
function ListRules:Get(id)
    local saved = ns.db and ns.db.listRules
    local rule = type(saved) == "table" and id ~= nil and saved[id]
    if type(rule) ~= "table" then return {} end
    local keep = Clean(rule.keep)
    return { mailTo = Text(rule.mailTo), keep = keep > 0 and keep or nil }
end

local function Changed()
    ListRules.lookup = nil
    if ns.Verdicts then ns.Verdicts:Changed(true) end
    if ns.SettingsUI and ns.SettingsUI.Refresh then ns.SettingsUI:Refresh() end
end

--- Set Mail To (a full name, or nil for nobody) on the list with this id.
function ListRules:SetMailTo(id, name)
    local saved = id ~= nil and Saved()
    if not saved then return false end
    local rule = type(saved[id]) == "table" and saved[id] or {}
    rule.mailTo = Text(name)
    saved[id] = (rule.mailTo or rule.keep) and rule or nil
    Changed()
    return true
end

--- Set Keep Here (0 takes it off) on the list with this id.
function ListRules:SetKeep(id, count)
    local saved = id ~= nil and Saved()
    if not saved then return false end
    local rule = type(saved[id]) == "table" and saved[id] or {}
    count = Clean(count)
    rule.keep = count > 0 and count or nil
    saved[id] = (rule.mailTo or rule.keep) and rule or nil
    Changed()
    return true
end

--- The list an item follows: the first on the Lists view holding it with a
--- rule here. { name, id, mailTo, keep }, or nil.
function ListRules:For(itemID)
    itemID = tonumber(itemID)
    if not itemID then return nil end
    local lists = self:Lists()
    local saved = ns.db and ns.db.listRules
    if self.lookup == nil or self.lookupLists ~= lists or self.lookupSaved ~= saved then
        local lookup = {}
        if type(saved) == "table" and next(saved) ~= nil then
            for _, list in ipairs(lists) do
                local rule = list.id ~= nil and self:Get(list.id) or {}
                if rule.mailTo or rule.keep then
                    local entry = { name = list.name, id = list.id, mailTo = rule.mailTo, keep = rule.keep }
                    for id in pairs(type(list.items) == "table" and list.items or {}) do
                        id = tonumber(id)
                        if id and lookup[id] == nil then lookup[id] = entry end
                    end
                end
            end
        end
        self.lookup, self.lookupLists, self.lookupSaved = lookup, lists, saved
    end
    return self.lookup[itemID]
end

--- Keep Here for an item: how many, and the list's name; or nil.
function ListRules:Keep(itemID)
    local entry = self:For(itemID)
    if entry and entry.keep then return entry.keep, entry.name end
    return nil
end
