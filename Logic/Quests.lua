-- Blackthornes Butler -- Logic/Quests.lua
-- Items for your quests (a player asked, the owner said build it,
-- 2026-10-14: "Gooey Spider Legs, Murloc Eyes, whatever. If I have a quest
-- for it, it'd be great to easily buy it from the AH").
--
-- Reads the open quests' "collect N" objectives and works out, for each
-- item, how many the quests still want. Two things follow:
--
--   * Verdicts keep every item an open quest collects ("Westfall Stew
--     needs 5 more"), so Sell never takes them while the quest is open.
--   * Jobs leads with a "For your quests" line naming what is still to
--     find that can be traded. At the auction house, its Search button
--     hands the list to Tradeskills, which looks them all up:
--
--       _G.BlackthornesTS.Butler:SearchAuctions(items)   -- true and "all" or "one", or false and why
--
-- The quest log gives the item's name and the counts, never its ID, so the
-- ID comes from Data/QuestItems.lua (Classic's quests, tradeable items
-- only), else from an item in the bags or the client with that name. An
-- item that can't be traded (bind on pickup, a quest item) is kept but
-- never offered to buy.
--
-- Nothing is saved. "Items for your quests" (questItems, account wide, on
-- unless unticked, never rename it) and /bbutler quests [on|off].
--
-- Smooth play: quest events come in bursts (every loot of a quest item
-- moves the log), so they only mark the log stale; one read follows
-- SETTLE seconds after the last, and the verdicts are judged again only
-- when what the quests want changed. Every client value is read inside a
-- pcall.

local _, ns = ...
local L = ns.L

local Quests = ns.NewModule("Quests")

local Items = ns.Items

Quests.SETTLE = 0.5

-- Moves whenever what the quests want changed.
Quests.version = 0

Quests.stale = true
Quests.auctionOpen = false

-- { [itemID] = { itemID, need, want, have, quests = { title, ... }, trade } }
Quests.byItem = {}
Quests.signature = ""

function Quests:IsOn()
    return not (ns.db and ns.db.questItems == false)
end

--------------------------------------------------------------------------------
-- Reading the quest log
--------------------------------------------------------------------------------

local function Number(value)
    local ok, n = pcall(tonumber, value)
    if ok and n and n == n then return math.floor(n) end
    return nil
end

local function Plain(value)
    local ok, text = pcall(function()
        if type(value) ~= "string" then return nil end
        local clean = value:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
        clean = clean:gsub("^%s+", ""):gsub("%s+$", "")
        if clean == "" then return nil end
        return clean
    end)
    return ok and text or nil
end

--- An objective's text as the item's name and its counts: "Murloc Eye:
--- 3/8" (Classic's way) or "3/8 Murloc Eye" (retail's).
function Quests.ParseObjective(text)
    text = Plain(text)
    if not text then return nil end
    local name, have, want = text:match("^(.-)%s*:%s*(%d+)%s*/%s*(%d+)$")
    if not name then
        have, want, name = text:match("^(%d+)%s*/%s*(%d+)%s+(.+)$")
    end
    if not name then return text end
    name = name:gsub("%s+$", "")
    if name == "" then return nil end
    return name, tonumber(have), tonumber(want)
end

local function Field(t, key)
    local ok, value = pcall(function() return t[key] end)
    return ok and value or nil
end

--- One quest's item objectives, retail's way: { { name, have, want, done } }.
local function ObjectivesByID(questID)
    local list = Items.Call({ "C_QuestLog.GetQuestObjectives" }, questID)
    if type(list) ~= "table" then return nil end
    local found = {}
    for _, objective in ipairs(list) do
        if type(objective) == "table" and Field(objective, "type") == "item" then
            local name, have, want = Quests.ParseObjective(Field(objective, "text"))
            have = Number(Field(objective, "numFulfilled")) or have
            want = Number(Field(objective, "numRequired")) or want
            if name then
                found[#found + 1] = { name = name, have = have or 0, want = want or 1,
                    done = Field(objective, "finished") == true }
            end
        end
    end
    return found
end

--- One quest's item objectives, Classic's way, by log index.
local function ObjectivesByIndex(index)
    local count = Number(Items.Call({ "GetNumQuestLeaderBoards" }, index)) or 0
    local found = {}
    for objective = 1, count do
        local text, kind, done = Items.Call({ "GetQuestLogLeaderBoard" }, objective, index)
        if kind == "item" then
            local name, have, want = Quests.ParseObjective(text)
            if name then
                found[#found + 1] = { name = name, have = have or 0, want = want or 1, done = done == true or done == 1 }
            end
        end
    end
    return found
end

--- Every quest in the log with an item to collect:
--- { { questID, title, objectives } }.
function Quests.ReadLog()
    local quests = {}
    if Items.Resolve("C_QuestLog.GetNumQuestLogEntries") and Items.Resolve("C_QuestLog.GetInfo") then
        local count = Number(Items.Call({ "C_QuestLog.GetNumQuestLogEntries" })) or 0
        for index = 1, count do
            local info = Items.Call({ "C_QuestLog.GetInfo" }, index)
            if type(info) == "table" and Field(info, "isHeader") ~= true then
                local questID = Number(Field(info, "questID"))
                local objectives = questID and ObjectivesByID(questID)
                if objectives and #objectives > 0 then
                    quests[#quests + 1] = { questID = questID, title = Plain(Field(info, "title")) or "",
                        objectives = objectives }
                end
            end
        end
        return quests
    end
    local count = Number(Items.Call({ "GetNumQuestLogEntries" })) or 0
    for index = 1, count do
        local title, _, _, isHeader, _, _, _, questID = Items.Call({ "GetQuestLogTitle" }, index)
        if not isHeader and Plain(title) then
            local objectives = ObjectivesByIndex(index)
            if #objectives > 0 then
                quests[#quests + 1] = { questID = Number(questID), title = Plain(title), objectives = objectives }
            end
        end
    end
    return quests
end

--------------------------------------------------------------------------------
-- From a name to an item
--------------------------------------------------------------------------------

local function Lower(text)
    local ok, lower = pcall(string.lower, text)
    return ok and lower or nil
end

local function NameOf(itemID)
    local name = Items.Call({ "C_Item.GetItemNameByID", "GetItemInfo" }, itemID)
    if type(name) == "string" and name ~= "" then return name end
    return nil
end

--- The item an objective names: the quest's own items from the data
--- first, then one in the bags, then the client's answer for the name.
--- nil while nothing knows it yet (its item is asked for, and the log is
--- read again when it comes).
function Quests:Resolve(questID, name, onlyItem)
    local wanted = Lower(name)
    local ids = questID and ns.QUEST_ITEMS and ns.QUEST_ITEMS[questID]
    if ids then
        local unknown = false
        for _, itemID in ipairs(ids) do
            local known = NameOf(itemID)
            if known then
                if Lower(known) == wanted then return itemID, true end
            else
                unknown = true
                Items:RequestLoad(itemID)
            end
        end
        -- One item to collect and one in the data: it is that one.
        if onlyItem and #ids == 1 then return ids[1], true end
        if unknown then self.waiting = true end
    end
    for _, entry in pairs(ns.Bags and ns.Bags.slots or {}) do
        local known = Items.NameFromLink(entry.link)
        if known and Lower(known) == wanted then return entry.itemID, nil end
    end
    local itemID = Items.Call({ "C_Item.GetItemInfoInstant", "GetItemInfoInstant" }, name)
    if type(itemID) == "number" then return itemID, nil end
    return nil
end

--- Can it go on the auction house? true from the data (tradeable only);
--- else by how it binds, which needs the item loaded (nil until then).
function Quests.Tradeable(itemID, fromData)
    if fromData then return true end
    if Items.IsQuestClass(itemID) then return false end
    local results = { Items.Call({ "C_Item.GetItemInfo", "GetItemInfo" }, itemID) }
    local bind = tonumber(results[14])
    if not results[1] or bind == nil then
        Items:RequestLoad(itemID)
        return nil
    end
    return bind ~= 1 and bind ~= 4
end

--------------------------------------------------------------------------------
-- What the quests want
--------------------------------------------------------------------------------

--- Read the log again and lay it out by item. Moves Quests.version, and
--- has the verdicts judged again, only when something changed.
function Quests:Read()
    self.stale = false
    self.waiting = false
    local byItem, unnamed = {}, false
    if self:IsOn() then
        for _, quest in ipairs(Quests.ReadLog()) do
            local only = #quest.objectives == 1
            for _, objective in ipairs(quest.objectives) do
                local itemID, fromData = self:Resolve(quest.questID, objective.name, only)
                -- Named by nothing yet: the bags may name it once read.
                if not itemID then unnamed = true end
                if itemID then
                    local item = byItem[itemID]
                    if not item then
                        item = { itemID = itemID, need = 0, want = 0, have = 0, quests = {} }
                        byItem[itemID] = item
                    end
                    item.want = item.want + objective.want
                    if not objective.done then
                        item.need = item.need + math.max(0, objective.want - objective.have)
                    end
                    item.quests[#item.quests + 1] = quest.title
                    if item.trade == nil or fromData then item.trade = Quests.Tradeable(itemID, fromData) end
                end
            end
        end
    end
    local parts = {}
    for itemID, item in pairs(byItem) do
        parts[#parts + 1] = ("%d:%d:%d:%s"):format(itemID, item.need, item.want, tostring(item.trade))
    end
    table.sort(parts)
    local signature = table.concat(parts, ",")
    self.byItem = byItem
    self.unnamedAt = unnamed and (ns.Bags and ns.Bags.version or 0) or nil
    if signature ~= self.signature then
        self.signature = signature
        self.version = self.version + 1
        return true
    end
    return false
end

local function Fresh()
    -- An objective nothing could name is looked at again once the bags
    -- were read again, since an item carried names it.
    local bags = ns.Bags and ns.Bags.version or 0
    if Quests.stale or (Quests.unnamedAt and Quests.unnamedAt ~= bags) then
        -- Read in the middle of judging: items judged before it are judged
        -- again once this pass is over, if what the quests want moved.
        if Quests:Read() and not Quests.announcing and C_Timer and C_Timer.After then
            Quests.announcing = true
            C_Timer.After(0, function()
                Quests.announcing = false
                Quests:Announce()
            end)
        end
    end
    return Quests.byItem
end

--- What the open quests want of an item, or nil when none collects it.
function Quests:For(itemID)
    if not self:IsOn() then return nil end
    return Fresh()[itemID]
end

--- The Keep reason for an item an open quest collects, or nil.
function Quests:Reason(itemID)
    local item = self:For(itemID)
    if not item then return nil end
    local title = item.quests[1]
    if item.need > 0 then
        if title and title ~= "" then return L.Format("%s needs %d more", title, item.need) end
        return L.Format("Your quest needs %d more", item.need)
    end
    if title and title ~= "" then return L.Format("For %s", title) end
    return L["For a quest you're on"]
end

--- What is still to find that can be bought: { { itemID, count, quests } },
--- most needed first.
function Quests:ToBuy()
    local list = {}
    if not self:IsOn() then return list end
    for itemID, item in pairs(Fresh()) do
        if item.need > 0 and item.trade then
            list[#list + 1] = { itemID = itemID, count = item.need, quests = item.quests }
        end
    end
    table.sort(list, function(a, b)
        if a.count ~= b.count then return a.count > b.count end
        return a.itemID < b.itemID
    end)
    return list
end

--- The Jobs line, or nil with nothing to buy.
function Quests:Step()
    local items = self:ToBuy()
    if #items == 0 then return nil end
    return { kind = "quest", items = items, ready = true }
end

--------------------------------------------------------------------------------
-- Search at the auction house
--------------------------------------------------------------------------------

local function Tradeskills(method)
    local global = rawget(_G, "BlackthornesTS")
    if type(global) ~= "table" then return nil end
    local butler = rawget(global, "Butler")
    if type(butler) ~= "table" or type(butler[method]) ~= "function" then return nil end
    return butler
end

--- Does the line get a Search button? At the auction house, with Tradeskills.
function Quests.CanSearch()
    return Quests.auctionOpen and Tradeskills("SearchAuctions") ~= nil
end

local function ListKey(items)
    local parts = {}
    for _, item in ipairs(items) do parts[#parts + 1] = item.itemID end
    return table.concat(parts, ",")
end

--- Where a one at a time search is up to: 2 of 5 means the next click
--- looks up the second. nil when the next click looks up them all.
function Quests:SearchPlace(items)
    local place = self.searching
    if place and place.key == ListKey(items) and place.pos <= #items then return place.pos, #items end
    return nil
end

--- The Search click: every item at once where the game allows it, else
--- one a click, the button reading "Next 2/5".
function Quests:Search(items)
    local ts = Tradeskills("SearchAuctions")
    if not ts then
        ns.Print(L["searching the auction house from here needs Blackthornes Tradeskills."])
        return false
    end
    if not (items and #items > 0) then return false end
    local key = ListKey(items)
    local place = self.searching
    local from = (place and place.key == key and place.pos <= #items) and place.pos or 1
    local send = {}
    for index = from, #items do
        send[#send + 1] = { itemID = items[index].itemID, count = items[index].count }
    end
    local ok, done, how = pcall(ts.SearchAuctions, ts, send)
    if not ok then
        ns.Print(L["couldn't search the auction house."])
        return false
    end
    if not done then
        if type(how) == "string" and how ~= "" then ns.Print(how) end
        return false
    end
    if how == "one" and from < #items then
        self.searching = { key = key, pos = from + 1 }
    else
        self.searching = nil
    end
    return true
end

--------------------------------------------------------------------------------
-- Commands and events
--------------------------------------------------------------------------------

function Quests:Report()
    if not self:IsOn() then
        ns.Print(L["Items for your quests is off. /bbutler quests on turns it back on."])
        return
    end
    self:Read()
    local any = false
    for itemID, item in pairs(self.byItem) do
        any = true
        local name = NameOf(itemID)
        name = name and Items:ColorName(name, itemID) or L.Format("Item %s", tostring(itemID))
        local line = item.need > 0 and L.Format("%s: %d more for %s", name, item.need, table.concat(item.quests, ", "))
            or L.Format("%s: you have enough for %s", name, table.concat(item.quests, ", "))
        if item.need > 0 and item.trade == false then
            line = line .. " " .. L["(can't be bought)"]
        end
        ns.PrintRaw("   " .. line)
    end
    if not any then ns.Print(L["none of your open quests asks you to collect an item."]) end
end

--- After the log settled: read it, and if what it wants moved, have the
--- items judged again and the window redrawn.
function Quests:Settle()
    self.settling = false
    self:Read()
    self:Announce()
end

-- The version the verdicts were last judged again for.
Quests.announced = 0

--- Have the items judged again, once for each change in what the quests want.
function Quests:Announce()
    if self.version == self.announced then return end
    self.announced = self.version
    if ns.Verdicts then ns.Verdicts:Changed() end
end

function Quests:Stale()
    self.stale = true
    if self.settling then return end
    self.settling = true
    if C_Timer and C_Timer.After then
        C_Timer.After(Quests.SETTLE, function() Quests:Settle() end)
    else
        self:Settle()
    end
end

--- Items the log was waiting on came in (Items:Loaded).
function Quests:ItemsArrived()
    if self.waiting then self:Stale() end
end

function Quests:SetOn(on)
    ns.db.questItems = on and true or false
    self:Stale()
end

local function AuctionHouse(open)
    if Quests.auctionOpen == open then return end
    Quests.auctionOpen = open
    if not open then Quests.searching = nil end
    if ns.UI and ns.UI.IsShown and ns.UI:IsShown() then ns.UI:Refresh(true) end
end

function Quests:OnEnable()
    for _, event in ipairs({ "QUEST_LOG_UPDATE", "QUEST_ACCEPTED", "QUEST_REMOVED", "QUEST_TURNED_IN" }) do
        ns.RegisterEvent(self, event, function() Quests:Stale() end)
    end
    ns.RegisterEvent(self, "AUCTION_HOUSE_SHOW", function() AuctionHouse(true) end)
    ns.RegisterEvent(self, "AUCTION_HOUSE_CLOSED", function() AuctionHouse(false) end)
end

function Quests:ProbeText()
    local retail = Items.Resolve("C_QuestLog.GetQuestObjectives") ~= nil
    local classic = Items.Resolve("GetQuestLogLeaderBoard") ~= nil
    local count = 0
    for _ in pairs(self.byItem) do count = count + 1 end
    return ("GetQuestObjectives %s, GetQuestLogLeaderBoard %s, items from quests %d, Tradeskills search %s"):format(
        retail and "found" or "missing", classic and "found" or "missing", count,
        Tradeskills("SearchAuctions") and "yes" or "no")
end

ns.RegisterCommand("quests", L["list what your open quests still need, or turn the quest line on or off"], function(arg)
    arg = (arg or ""):lower()
    if arg == "on" or arg == "off" then
        Quests:SetOn(arg == "on")
        ns.Print(arg == "on" and L["Butler keeps and lists the items your open quests collect."]
            or L["Butler no longer keeps or lists the items your quests collect."])
        return
    end
    Quests:Report()
end)
