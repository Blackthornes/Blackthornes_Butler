-- Blackthornes Butler -- Logic/Errands.lua
-- At a mailbox and at the bank (the owner said start, 2026-10-11).
--
-- At a mailbox, Fill mail fills the game's own Send Mail page with the
-- Mail group for one character, through Tradeskills (its QueueMail:Fill,
-- which its Mail panel uses too):
--
--   _G.BlackthornesTS.Butler:FillMail(name, items)   -- true, or false and why
--
-- The player presses Send. Nothing is ever sent from here, the mail frame
-- is never hooked, moved, shown or hidden, and each click fills the next
-- character's mail. The Mail group only exists with Tradeskills loaded,
-- since it is Tradeskills that says who needs what, and who the player's
-- characters are for the Always mail list (Errands:Characters).
--
-- Butler takes over the mailbox (the owner picked it, 2026-10-11): it
-- comes up at every mailbox, and while its window is up there Tradeskills'
-- own mail panel steps aside, told through
--
--   _G.BlackthornesTS.Butler:Mailbox(covered)        -- true while Butler's window is up
--
-- Closing Butler's window brings Tradeskills' panel back.
--
-- At the bank, Move to bank puts the Bank group (the player's Always bank
-- list) into the bank, and Take from bank brings out what this character's
-- own queued crafts still want from it:
--
--   _G.BlackthornesTS.Butler:FromBank()              -- { [itemID] = count }
--
-- Both move whole stacks with C_Container.UseContainerItem, which the
-- selling test found works from addon code on Forever, one a step, each
-- slot read again just before it moves. A stack that does not move means
-- the bank or the bags are full, and the run stops there.
--
-- Smooth play: nothing here runs on a timer or reads the bank except for
-- a click; the bags are Butler's own coalesced read (Logic/Bags.lua).

local _, ns = ...

local Errands = ns.NewModule("Errands")

local Items = ns.Items
local Bags = ns.Bags

-- Seconds between one stack and the next, so the game has moved the last.
Errands.STEP = 0.2

local function InCombat()
    return type(InCombatLockdown) == "function" and InCombatLockdown() and true or false
end

--- Tradeskills' Butler table when it is loaded and has `method`.
function Errands.Tradeskills(method)
    local global = rawget(_G, "BlackthornesTS")
    if type(global) ~= "table" then return nil end
    local butler = rawget(global, "Butler")
    if type(butler) ~= "table" or type(butler[method]) ~= "function" then return nil end
    return butler
end

--------------------------------------------------------------------------------
-- The mailbox
--------------------------------------------------------------------------------

--- Who the Mail group goes to: a list of { to, items = { { itemID, count } },
--- count }, most items first. A row from Tradeskills' queue carries how many
--- the alt needs; one for the enchanter goes whole.
function Errands:Recipients()
    local byName, list = {}, {}
    local group = ns.Verdicts:Group("mail")
    for _, row in ipairs(group and group.rows or {}) do
        local to = row.mailTo
        if type(to) == "string" and to ~= "" then
            local recipient = byName[to]
            if not recipient then
                recipient = { to = to, items = {}, byID = {}, count = 0 }
                byName[to] = recipient
                list[#list + 1] = recipient
            end
            local count = row.count
            if type(row.mailCount) == "number" and row.mailCount > 0 then
                count = math.min(count, row.mailCount)
            end
            local item = recipient.byID[row.itemID]
            if item then
                item.count = item.count + count
            else
                item = { itemID = row.itemID, count = count }
                recipient.byID[row.itemID] = item
                recipient.items[#recipient.items + 1] = item
            end
            recipient.count = recipient.count + count
        end
    end
    table.sort(list, function(a, b)
        if #a.items ~= #b.items then return #a.items > #b.items end
        return a.to < b.to
    end)
    return list
end

--- The player's other characters an item can be mailed to: short names,
--- same realm and faction as the character playing, from Tradeskills'
--- record of them. Empty without Tradeskills.
local function Text(value)
    return type(value) == "string" and value ~= "" and value or nil
end

--- Tradeskills' Holdings and the entry for the character playing, or nil.
local function Holdings()
    local butler = Errands.Tradeskills("Holdings")
    if not butler then return nil end
    local ok, list = pcall(butler.Holdings, butler)
    if not ok or type(list) ~= "table" then return nil end
    local me
    for _, entry in ipairs(list) do
        if type(entry) == "table" and entry.isCurrent == true then me = entry end
    end
    return list, me
end

--- The short name Tradeskills gives the character playing (as Always mail
--- and mailTo name characters), or nil without Tradeskills.
function Errands:PlayingName()
    local _, me = Holdings()
    return me and (Text(me.short) or Text(me.name)) or nil
end

function Errands:Characters()
    local list, me = Holdings()
    if not list then return {} end
    local realm = me and Text(me.realm)
    local faction = me and Text(me.faction)

    local names, seen = {}, {}
    for _, entry in ipairs(list) do
        local short = type(entry) == "table" and (Text(entry.short) or Text(entry.name))
        if short and entry.isCurrent ~= true and not seen[short]
            and (not realm or not Text(entry.realm) or Text(entry.realm) == realm)
            and (not faction or not Text(entry.faction) or Text(entry.faction) == faction) then
            seen[short] = true
            names[#names + 1] = short
        end
    end
    table.sort(names)
    return names
end

--- Tell Tradeskills whether Butler's window covers the mailbox now, so its
--- mail panel steps aside or comes back. Only said when it changes.
--- `shown` is the window's state when the caller knows it (its OnHide).
function Errands:TellTradeskills(shown)
    if shown == nil then shown = ns.UI ~= nil and ns.UI:IsShown() == true end
    local covered = self.mailOpen == true and shown == true
    if covered == self.covered then return end
    self.covered = covered
    local butler = Errands.Tradeskills("Mailbox")
    if butler then pcall(butler.Mailbox, butler, covered) end
end

--- The next character to fill a mail for on this visit, or nil.
function Errands:NextRecipient()
    for _, recipient in ipairs(self:Recipients()) do
        if not self.filled[recipient.to] then return recipient end
    end
    return nil
end

Errands.filled = {}

--- Fill the Send Mail page for the next character. Returns true when it
--- started, or false and why.
function Errands:FillMail()
    if not self.mailOpen then return false, "Open a mailbox first." end
    if InCombat() then return false, "Not in combat." end
    local butler = Errands.Tradeskills("FillMail")
    if not butler then return false, "Filling mail needs Blackthornes Tradeskills." end
    local recipient = self:NextRecipient()
    if not recipient then return false, "Nothing left to mail." end

    local items = {}
    for _, item in ipairs(recipient.items) do items[#items + 1] = { itemID = item.itemID, count = item.count } end

    local ok, started, why, fullName = pcall(butler.FillMail, butler, recipient.to, items)
    if not ok then return false, "Tradeskills could not fill the mail." end
    if started ~= true then
        return false, type(why) == "string" and ("Couldn't fill it: %s."):format(why) or "Couldn't fill it."
    end
    self.filled[recipient.to] = true
    self:Update()
    -- The full name the mail went to, when Tradeskills says it: the short
    -- one ("Ana S.") read as a typo in chat.
    local to = type(fullName) == "string" and fullName ~= "" and fullName or recipient.to
    return true, ("Filled a mail to %s: check it, then press Send."):format(to)
end

--------------------------------------------------------------------------------
-- The bank
--------------------------------------------------------------------------------

--- The bank's containers: the bank itself, the reagent bank and the bank
--- bag slots, on clients that have each.
function Errands.BankBagIDs()
    local index = _G.Enum and _G.Enum.BagIndex
    local ids, seen = {}, {}
    local function Add(id)
        if type(id) == "number" and not seen[id] then
            seen[id] = true
            ids[#ids + 1] = id
        end
    end
    Add(type(index) == "table" and index.Bank or -1)
    if type(index) == "table" then Add(index.Reagentbank or index.ReagentBank) end
    local first = type(index) == "table" and index.BankBag_1 or ((tonumber(_G.NUM_BAG_SLOTS) or 4) + 1)
    local count = tonumber(_G.NUM_BANKBAGSLOTS) or 7
    for bag = first, first + count - 1 do Add(bag) end
    return ids
end

local function NumSlots(bag)
    return tonumber(Items.Call({ "C_Container.GetContainerNumSlots", "GetContainerNumSlots" }, bag)) or 0
end

--- The Bank group's carried slots: { bag, slot, itemID } in bag order.
function Errands:ToBank()
    local slots = {}
    local group = ns.Verdicts:Group("bank")
    for _, row in ipairs(group and group.rows or {}) do
        for _, entry in ipairs(row.slots) do
            if not entry.locked then
                slots[#slots + 1] = { bag = entry.bag, slot = entry.slot, itemID = entry.itemID }
            end
        end
    end
    table.sort(slots, function(a, b)
        if a.bag ~= b.bag then return a.bag < b.bag end
        return a.slot < b.slot
    end)
    return slots
end

--- What this character's queued crafts want from its bank, per Tradeskills:
--- { [itemID] = count }, empty without it.
function Errands:BankWants()
    local butler = Errands.Tradeskills("FromBank")
    if not butler then return {} end
    local ok, wants = pcall(butler.FromBank, butler)
    if not ok or type(wants) ~= "table" then return {} end
    local clean = {}
    for itemID, count in pairs(wants) do
        if type(itemID) == "number" and type(count) == "number" and count > 0 then
            clean[itemID] = math.floor(count)
        end
    end
    return clean
end

--- How many things Take from bank would bring out: the number of items
--- wanted, counted once each.
function Errands:WantedCount()
    local count = 0
    for _ in pairs(self:BankWants()) do count = count + 1 end
    return count
end

--- The bank stacks to take for what is wanted: smallest first, until each
--- item's count is covered. Read now, while the bank is open.
function Errands:FromBankSlots()
    local wants = self:BankWants()
    if not next(wants) then return {} end

    local stacks = {}
    for _, bag in ipairs(Errands.BankBagIDs()) do
        for slot = 1, NumSlots(bag) do
            local entry = Bags.ReadSlot(bag, slot)
            if entry and wants[entry.itemID] and not entry.locked then
                stacks[#stacks + 1] = entry
            end
        end
    end
    table.sort(stacks, function(a, b)
        if a.count ~= b.count then return a.count < b.count end
        if a.bag ~= b.bag then return a.bag < b.bag end
        return a.slot < b.slot
    end)

    local left, slots = {}, {}
    for itemID, count in pairs(wants) do left[itemID] = count end
    for _, entry in ipairs(stacks) do
        if left[entry.itemID] > 0 then
            slots[#slots + 1] = { bag = entry.bag, slot = entry.slot, itemID = entry.itemID }
            left[entry.itemID] = left[entry.itemID] - entry.count
        end
    end
    return slots
end

--- Move `slots` one at a time with UseContainerItem while the bank stays
--- open. `full` is said when a stack does not move.
function Errands:Move(slots, done, full)
    if self.moving then return false, "Still moving the last ones." end
    if not self.bankOpen then return false, "Open your bank first." end
    if InCombat() then return false, "Not in combat." end
    if #slots == 0 then return false, "Nothing to move." end
    if not Items.Resolve("C_Container.UseContainerItem") then return false, "This game can't move items for Butler." end

    self.moving = true
    local index, moved = 0, 0

    local function Finish(message)
        Errands.moving = false
        Bags:Changed()
        Errands:Update()
        if message then ns.Print(message) end
        if done then done(moved) end
    end

    local function Next()
        if not Errands.bankOpen or InCombat() then return Finish() end
        index = index + 1
        local step = slots[index]
        if not step then return Finish(("moved %d %s."):format(moved, moved == 1 and "stack" or "stacks")) end

        if not Bags.Holds(step.bag, step.slot, step.itemID) then return Next() end
        Items.Call({ "C_Container.UseContainerItem" }, step.bag, step.slot)

        C_Timer.After(Errands.STEP, function()
            -- Still there, unlocked: nowhere for it to go.
            if Bags.Holds(step.bag, step.slot, step.itemID) then
                return Finish(("moved %d, then %s"):format(moved, full))
            end
            moved = moved + 1
            Next()
        end)
    end

    Next()
    return true
end

function Errands:MoveToBank()
    return self:Move(self:ToBank(), nil, "the bank is full.")
end

function Errands:TakeFromBank()
    return self:Move(self:FromBankSlots(), nil, "your bags are full.")
end

--------------------------------------------------------------------------------
-- Showing the buttons
--------------------------------------------------------------------------------

--- What the window's foot offers now: { mail = recipient or nil,
--- toBank = count, fromBank = count }. Nothing outside a mailbox or bank.
function Errands:Offers()
    local offers = { toBank = 0, fromBank = 0 }
    if self.mailOpen then offers.mail = self:NextRecipient() end
    if self.bankOpen then
        offers.toBank = #self:ToBank()
        offers.fromBank = self:WantedCount()
    end
    return offers
end

--- Is there anything to do here, so the window is worth opening by itself?
function Errands:HasWork(place)
    local offers = self:Offers()
    if place == "mail" then return offers.mail ~= nil end
    return offers.toBank > 0 or offers.fromBank > 0
end

function Errands:Update()
    if ns.UI then ns.UI:UpdateErrands() end
end

--------------------------------------------------------------------------------
-- Events
--------------------------------------------------------------------------------

function Errands:Arrived(place)
    if place == "mail" then
        self.mailOpen = true
        self.filled = {}
    else
        self.bankOpen = true
    end
    Bags:Fresh(function()
        if ns.UI then ns.UI:AtPlace(place) end
        Errands:Update()
    end)
end

function Errands:Left(place)
    -- Leaving can be said twice (MAIL_CLOSED and the interaction ending).
    if place == "mail" and not self.mailOpen and not (ns.UI and ns.UI.openedFor == "mail") then return end
    if place == "bank" and not self.bankOpen and not (ns.UI and ns.UI.openedFor == "bank") then return end
    if place == "mail" then
        self.mailOpen = false
    else
        self.bankOpen = false
    end
    if ns.UI then ns.UI:LeftPlace(place) end
    self:TellTradeskills()
    self:Update()
end

function Errands:OnEnable()
    ns.RegisterEvent(self, "MAIL_SHOW", function() Errands:Arrived("mail") end)
    ns.RegisterEvent(self, "MAIL_CLOSED", function() Errands:Left("mail") end)
    ns.RegisterEvent(self, "BANKFRAME_OPENED", function() Errands:Arrived("bank") end)
    ns.RegisterEvent(self, "BANKFRAME_CLOSED", function() Errands:Left("bank") end)
    -- Walking away ends the game's interaction with the mailbox or banker;
    -- heard as well in case the client says that and not MAIL_CLOSED (a
    -- player found the window left up after walking off, 2026-10-11).
    ns.RegisterEvent(self, "PLAYER_INTERACTION_MANAGER_FRAME_HIDE", function(_, _, kind)
        local place = Errands.InteractionPlace(kind)
        if place then Errands:Left(place) end
    end)
end

--- "mail" or "bank" for the game's interaction types, else nil.
function Errands.InteractionPlace(kind)
    local types = rawget(_G, "Enum") and rawget(Enum, "PlayerInteractionType")
    local mail = type(types) == "table" and rawget(types, "MailInfo") or 17
    local bank = type(types) == "table" and rawget(types, "Banker") or 8
    if kind == mail then return "mail" end
    if kind == bank then return "bank" end
    return nil
end

--------------------------------------------------------------------------------
-- Commands
--------------------------------------------------------------------------------

ns.RegisterCommand("mailbox", "turn the Butler window coming up at a mailbox on or off", function()
    ns.db.openAtMailbox = not ns.db.openAtMailbox
    ns.Print(ns.db.openAtMailbox and "the Butler window comes up at every mailbox."
        or "the Butler window no longer comes up at a mailbox by itself.")
end)

ns.RegisterCommand("bank", "turn the Butler window coming up at the bank on or off", function()
    ns.db.openAtBank = not ns.db.openAtBank
    ns.Print(ns.db.openAtBank and "the Butler window comes up at the bank when there is something to move."
        or "the Butler window no longer comes up at the bank by itself.")
end)
