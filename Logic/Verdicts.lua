-- Blackthornes Butler -- Logic/Verdicts.lua
-- One verdict for every item in the bags, and the reason for it.
--
-- Phase 1 of the plan: Butler on its own, with no other Blackthornes addon
-- asked yet. The first rule that applies wins, and keeping always beats
-- selling:
--
--   1. On the player's Always keep list       Keep
--   2. A quest item, or one that starts one   Keep
--   3. A vendor won't buy it                  Keep
--   4. On the player's Always sell list       Sell
--   5. Its price has not loaded yet           Look at it
--   6. Grey (worth vendor only)               Sell
--   7. Anything else                          Look at it
--
-- "Look at it" is never sold for the player. Phase 2 asks the other four
-- addons before step 6 (an upgrade, a goal, a craft, pet food) and turns
-- most "Look at it" rows into Keep, Auction or Disenchant.
--
-- The Always keep and Always sell lists are the player's own choices,
-- account wide, by item ID: BlackthornesButlerDB.alwaysKeep and .alwaysSell
-- ([itemID] = true). Never rename them.

local _, ns = ...

local Verdicts = ns.NewModule("Verdicts")

local Items = ns.Items

-- The order the groups show in: what to do first at the top.
Verdicts.ORDER = { "sell", "look", "keep" }

Verdicts.LABELS = {
    sell = "Sell",
    look = "Look at it",
    keep = "Keep",
}

-- Moves whenever a judgement could change (a choice made, an item loaded),
-- so kept answers and the drawn list are known to be stale.
Verdicts.version = 0

-- [link] = { verdict, reason, unit }, for Verdicts.version.
local memo, memoVersion = {}, 0

--------------------------------------------------------------------------------
-- The player's own choices
--------------------------------------------------------------------------------

local function List(name)
    if not ns.db then return {} end
    if type(ns.db[name]) ~= "table" then ns.db[name] = {} end
    return ns.db[name]
end

--- "keep", "sell" or nil: what the player said about this item.
function Verdicts:Choice(itemID)
    if not itemID then return nil end
    if List("alwaysKeep")[itemID] then return "keep" end
    if List("alwaysSell")[itemID] then return "sell" end
    return nil
end

--- Put an item on the Always keep or Always sell list, or take it off both
--- (`choice` nil) so Butler decides again.
function Verdicts:SetChoice(itemID, choice)
    if not itemID then return end
    List("alwaysKeep")[itemID] = (choice == "keep") or nil
    List("alwaysSell")[itemID] = (choice == "sell") or nil
    self:Changed(true)
end

--------------------------------------------------------------------------------
-- Judging
--------------------------------------------------------------------------------

local function Each(unit)
    if not unit or unit <= 0 then return "" end
    return "Vendor " .. Items.FormatMoney(unit) .. " each"
end

--- The verdict for one carried item, why, and what a vendor pays for one.
--- `entry` is a slot from Bags (itemID, link, quality, noValue, quest).
function Verdicts:Judge(entry)
    if memoVersion ~= self.version then
        memo, memoVersion = {}, self.version
    end
    local key = entry.link or entry.itemID
    local known = memo[key]
    if known then return known[1], known[2], known[3] end

    local verdict, reason, unit, final = self:Decide(entry)
    -- An answer that waits on the client loading the item is asked again.
    if final then memo[key] = { verdict, reason, unit } end
    return verdict, reason, unit
end

--- The rules above, in order. The fourth return says whether the answer
--- will hold (false while the price is still loading).
function Verdicts:Decide(entry)
    local itemID = entry.itemID
    local choice = self:Choice(itemID)

    if choice == "keep" then
        return "keep", "On your Always keep list", nil, true
    end

    if entry.quest == "starts" then
        return "keep", "Starts a quest", nil, true
    elseif entry.quest == "item" then
        return "keep", "Quest item", nil, true
    end

    if entry.noValue then
        return "keep", "Vendors won't buy it", nil, true
    end

    local unit = Items:SellPrice(itemID)
    if unit == 0 then
        return "keep", "Vendors won't buy it", 0, true
    end

    if choice == "sell" then
        return "sell", "On your Always sell list", unit, unit ~= nil
    end

    if unit == nil then
        return "look", "Still loading from the game", nil, false
    end

    if entry.quality == 0 then
        return "sell", "Grey, vendor only", unit, true
    end

    -- Short enough for the row; the tooltip says right-click decides it.
    return "look", Each(unit), unit, true
end

--------------------------------------------------------------------------------
-- Groups
--------------------------------------------------------------------------------

--- The bags as groups, in Verdicts.ORDER: { verdict, label, rows, count,
--- worth }, each row one item (stacks of the same link put together) with
--- its slots. Kept until the bags or a verdict change.
function Verdicts:Groups()
    local bagsVersion = ns.Bags.version
    local cache = self.groupCache
    if cache and cache.bags == bagsVersion and cache.verdicts == self.version then
        return cache.groups
    end

    local byVerdict, rowsByKey = {}, {}
    for _, verdict in ipairs(self.ORDER) do
        byVerdict[verdict] = { verdict = verdict, label = self.LABELS[verdict], rows = {}, count = 0, worth = 0 }
    end

    for _, entry in pairs(ns.Bags.slots) do
        local verdict, reason, unit = self:Judge(entry)
        local group = byVerdict[verdict]
        local key = verdict .. "|" .. tostring(entry.link or entry.itemID)
        local row = rowsByKey[key]
        if not row then
            row = {
                type = "item", verdict = verdict, reason = reason, unit = unit,
                itemID = entry.itemID, link = entry.link, icon = entry.icon,
                quality = entry.quality, bound = entry.bound,
                name = Items.NameFromLink(entry.link) or ("item " .. tostring(entry.itemID)),
                count = 0, slots = {},
            }
            rowsByKey[key] = row
            group.rows[#group.rows + 1] = row
        end
        row.count = row.count + entry.count
        row.slots[#row.slots + 1] = entry
        group.count = group.count + 1
    end

    local groups = {}
    for _, verdict in ipairs(self.ORDER) do
        local group = byVerdict[verdict]
        for _, row in ipairs(group.rows) do
            row.worth = (row.unit or 0) * row.count
            group.worth = group.worth + row.worth
            -- Slots in bag order, so a sale goes through the bags as the
            -- player reads them.
            table.sort(row.slots, function(a, b)
                if a.bag ~= b.bag then return a.bag < b.bag end
                return a.slot < b.slot
            end)
        end
        -- Most valuable first, then by name.
        table.sort(group.rows, function(a, b)
            if a.worth ~= b.worth then return a.worth > b.worth end
            return a.name < b.name
        end)
        group.count = #group.rows
        groups[#groups + 1] = group
    end

    self.groupCache = { bags = bagsVersion, verdicts = self.version, groups = groups }
    return groups
end

--- One group by its verdict.
function Verdicts:Group(verdict)
    for _, group in ipairs(self:Groups()) do
        if group.verdict == verdict then return group end
    end
end

--------------------------------------------------------------------------------
-- Change
--------------------------------------------------------------------------------

--- Something a verdict leans on moved (a choice, an item loaded): judge
--- again and redraw what shows. `now` redraws at once, for a click.
function Verdicts:Changed(now)
    self.version = self.version + 1
    self:Redraw(now)
end

--- The bags changed (Bags.version moved).
function Verdicts:BagsChanged()
    self:Redraw(true)
end

function Verdicts:Redraw()
    if ns.UI then ns.UI:Refresh() end
    if ns.Selling then ns.Selling:Update() end
end

--------------------------------------------------------------------------------
-- Commands
--------------------------------------------------------------------------------

local function PrintList(name, title)
    local ids = {}
    for itemID in pairs(List(name)) do ids[#ids + 1] = itemID end
    table.sort(ids)
    if #ids == 0 then
        ns.PrintRaw(("  |c%s%s:|r none"):format(ns.COLORS.muted, title))
        return
    end
    local names = {}
    for _, itemID in ipairs(ids) do
        local itemName, link = Items.Call({ "C_Item.GetItemInfo", "GetItemInfo" }, itemID)
        if not itemName then Items:RequestLoad(itemID) end
        names[#names + 1] = link or itemName or ("item " .. itemID)
    end
    ns.PrintRaw(("  |c%s%s (%d):|r %s"):format(ns.COLORS.muted, title, #ids, table.concat(names, ", ")))
end

ns.RegisterCommand("lists", "show your Always keep and Always sell lists", function()
    ns.Print("your lists (right-click a row in the Butler window to change them)")
    PrintList("alwaysKeep", "Always keep")
    PrintList("alwaysSell", "Always sell")
end)

ns.RegisterCommand("vendor", "turn the Butler window coming up at a vendor on or off", function()
    ns.db.openAtVendor = not ns.db.openAtVendor
    ns.Print(ns.db.openAtVendor and "the Butler window comes up at a vendor when there is something to sell."
        or "the Butler window no longer comes up at a vendor by itself.")
end)

-- Deletes the player's choices, so typed only, with "confirm" (a house
-- rule: no button deletes data).
ns.RegisterCommand("reset", "empty your Always keep and Always sell lists (type: reset confirm)", function(rest)
    if rest ~= "confirm" then
        ns.Print("this empties your Always keep and Always sell lists. To do it, type /bbutler reset confirm")
        return
    end
    ns.db.alwaysKeep, ns.db.alwaysSell = {}, {}
    Verdicts:Changed(true)
    ns.Print("your Always keep and Always sell lists are empty. Butler decides every item again.")
end)
