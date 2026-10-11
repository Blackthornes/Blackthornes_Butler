-- Blackthornes Butler -- Logic/Errands.lua
-- At a mailbox and at the bank (the owner said start, 2026-10-11).
--
-- At a mailbox, Fill mail fills the game's own Send Mail page with the
-- Mail group for one character, through Tradeskills (its QueueMail:Fill,
-- which its Mail panel uses too):
--
--   _G.BlackthornesTS.Butler:FillMail(name, items, money)   -- true, or false and why
--
-- `money` is the gold fund's top-up for that character (Logic/Funds.lua),
-- put in the mail's gold boxes; gold alone is a mail too.
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
        if type(to) == "string" and to ~= "" and not self:IsMe(to) then
            local recipient = byName[to]
            if not recipient then
                recipient = { to = to, items = {}, byID = {}, count = 0, upgrades = {} }
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
            -- An alt's upgrade is written down once the mail goes, so a
            -- copy left behind isn't offered again (Verdicts:UpgradesMailed).
            if row.upgrade then
                recipient.upgrades[#recipient.upgrades + 1] = { itemID = row.itemID, count = count }
            end
        end
    end
    -- Gold from the fund (Logic/Funds.lua) rides with that character's
    -- items, or goes as a mail of its own.
    if ns.Funds and self.mailOpen then
        for _, entry in ipairs((ns.Funds:Plan())) do
            if not self:IsMe(entry.to) then
                local recipient = byName[entry.to]
                if not recipient then
                    recipient = { to = entry.to, items = {}, byID = {}, count = 0 }
                    byName[entry.to] = recipient
                    list[#list + 1] = recipient
                end
                recipient.money = entry.amount
            end
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

--- Is a Holdings entry the character playing, under any of its records?
--- Tradeskills marks its own (`isCurrent`) and any old record of it
--- (`playing`, its Characters:IsPlaying).
local function Mine(entry)
    return type(entry) == "table" and (entry.isCurrent == true or entry.playing == true)
end
Errands.Mine = Mine

--- Tradeskills' Holdings and the entry for the character playing, or nil.
--- The entry is the first `isCurrent` one (Tradeskills lists it first).
local function Holdings()
    local butler = Errands.Tradeskills("Holdings")
    if not butler then return nil end
    local ok, list = pcall(butler.Holdings, butler)
    if not ok or type(list) ~= "table" then return nil end
    local me
    for _, entry in ipairs(list) do
        if not me and type(entry) == "table" and entry.isCurrent == true then me = entry end
    end
    return list, me
end

--- Tradeskills' Holdings and the character playing's entry (the gold fund
--- reads it), or nil without Tradeskills.
function Errands:Holdings()
    return Holdings()
end

--- Every character's name on this realm and side, the one playing too,
--- kept until Verdicts.version moves (the window opening, a choice made).
local namesCache, namesVersion, myName, myNames

local function Fold(text)
    if type(text) ~= "string" then return nil end
    text = text:gsub("^%s+", ""):gsub("%s+$", ""):gsub("%s+", " ")
    if text == "" then return nil end
    return text:lower()
end

--- Every way the character playing is named, folded: each name and short
--- name of every record of it, and its first name alone, which can't tell
--- it from another of that first name, so is never mailed. The game's own
--- first name too, so the guard holds without Tradeskills.
local function MyNames(list)
    local names = {}
    local function Add(text)
        local folded = Fold(text)
        if not folded then return end
        names[folded] = true
        names[folded:match("^(%S+)")] = true
    end
    for _, entry in ipairs(list or {}) do
        if Mine(entry) then
            Add(Text(entry.short))
            Add(Text(entry.name))
        end
    end
    local ok, first = pcall(Items.Call, { "UnitName" }, "player")
    if ok then pcall(Add, first) end
    return names
end

local function AllNames()
    local version = ns.Verdicts and ns.Verdicts.version
    if namesCache and namesVersion == version then return namesCache, myName, myNames end
    local names = {}
    local list, me = Holdings()
    myName = me and (Text(me.short) or Text(me.name)) or nil
    myNames = MyNames(list)
    local realm = me and Text(me.realm)
    local faction = me and Text(me.faction)
    for _, entry in ipairs(list or {}) do
        local name = type(entry) == "table" and (Text(entry.short) or Text(entry.name))
        if name and (not realm or not Text(entry.realm) or Text(entry.realm) == realm)
            and (not faction or not Text(entry.faction) or Text(entry.faction) == faction) then
            names[#names + 1] = name
        end
    end
    namesCache, namesVersion = names, version
    return names, myName, myNames
end

--- The full name Tradeskills gives a character, by its key (the GUID
--- Equipment names it by), when it is on this realm and side and is not
--- the character playing; nil otherwise. Read with the names above, once
--- per Verdicts.version.
local byKeyCache, byKeyVersion
function Errands:NameOf(key)
    if type(key) ~= "string" or key == "" then return nil end
    local version = ns.Verdicts and ns.Verdicts.version
    if not byKeyCache or byKeyVersion ~= version then
        byKeyCache, byKeyVersion = {}, version
        local list, me = Holdings()
        local realm = me and Text(me.realm)
        local faction = me and Text(me.faction)
        for _, entry in ipairs(list or {}) do
            local name = type(entry) == "table" and (Text(entry.short) or Text(entry.name))
            local entryKey = type(entry) == "table" and Text(entry.key)
            if name and entryKey and not Mine(entry)
                and (not realm or not Text(entry.realm) or Text(entry.realm) == realm)
                and (not faction or not Text(entry.faction) or Text(entry.faction) == faction) then
                byKeyCache[entryKey] = name
            end
        end
    end
    return byKeyCache[key]
end

--- The name Tradeskills gives the character playing (as Always mail and
--- mailTo name characters), or nil without Tradeskills. Read with the
--- names above, once per Verdicts.version.
function Errands:PlayingName()
    local _, name = AllNames()
    return name
end

--- Is this name the character playing? The one test every mail, gold
--- top-up, learned habit and Log out asks (2026-10-11: a player was told to
--- mail to, and log out for, the character they were on). Its full name,
--- the name of any old record of it, or its first name alone, without
--- regard to case or spacing; "Name-Realm" counts by its name. nil and
--- anything that is not a name are not.
function Errands:IsMe(name)
    if type(name) ~= "string" then return false end
    local folded = Fold(name:match("^(.-)%-[^%-%s]+$") or name)
    if not folded then return false end
    local _, _, mine = AllNames()
    return (mine or {})[folded] == true
end

--- The full name for a character name saved in an old short form: "Ana
--- S." or the first name alone ("Ana", from before last names were read).
--- Names are never shortened now (the owner's rule, 2026-10-11), but an
--- Always mail choice made before keeps what was saved. The one character
--- the short form fits answers. A first name alone that fits several
--- answers the character playing when it is one of them, as Tradeskills
--- reads it (its old name-realm records filed them all as one), so it is
--- never mailed to itself (the owner found Fill mail aimed at the
--- character he was on, 2026-10-11). Anything else is as given.
function Errands:FullName(name)
    if type(name) ~= "string" then return name end
    local prefix
    local first, initial = name:match("^(%S+) (%S+)%.$")
    if first then
        prefix = first .. " " .. initial
    elseif name:match("^%S+$") then
        prefix = name .. " "
    else
        return name
    end
    local names, me = AllNames()
    local found, several, mine
    for _, full in ipairs(names) do
        if full ~= name and full:sub(1, #prefix) == prefix then
            if found and found ~= full then several = true end
            found = found or full
            if full == me then mine = true end
        end
    end
    if several then
        return (not first and mine) and me or name
    end
    return found or name
end

function Errands:Characters()
    local list, me = Holdings()
    if not list then return {} end
    local realm = me and Text(me.realm)
    local faction = me and Text(me.faction)

    local names, seen = {}, {}
    for _, entry in ipairs(list) do
        local short = type(entry) == "table" and (Text(entry.short) or Text(entry.name))
        if short and not Mine(entry) and not self:IsMe(short) and not seen[short]
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
    -- Ask the other addons afresh: an alt's queue may have changed since
    -- the window last asked, and the click must send what it wants now.
    ns.Verdicts:Changed(true)
    local recipient = self:NextRecipient()
    if not recipient then return false, "Nothing left to mail." end

    -- The last guard before the mail is filled: never the character playing.
    if self:IsMe(recipient.to) then return false, "That's the character you're on." end

    local items = {}
    for _, item in ipairs(recipient.items) do items[#items + 1] = { itemID = item.itemID, count = item.count } end

    local ok, started, why, fullName = pcall(butler.FillMail, butler, recipient.to, items, recipient.money)
    if not ok then return false, "Tradeskills could not fill the mail." end
    if started ~= true then
        return false, type(why) == "string" and ("Couldn't fill it: %s."):format(why) or "Couldn't fill it."
    end
    self.filled[recipient.to] = true
    self.sending = recipient.to
    self.sendingUpgrades = recipient.upgrades
    if recipient.money and ns.Funds then ns.Funds:Filled(recipient.to, recipient.money) end
    self:Update()
    -- The full name the mail went to, when Tradeskills says it: the short
    -- one ("Ana S.") read as a typo in chat.
    local to = type(fullName) == "string" and fullName ~= "" and fullName or recipient.to
    return true, ("Filled a mail to %s: check it, then press Send."):format(to)
end

--- The mail Butler filled went (MAIL_SEND_SUCCESS): fill the next one
--- straight away, so a run of mail is one Send a character (the owner,
--- 2026-10-11: the addons should do the work). Only while the window is up
--- at the mailbox, out of combat, with "Fill the next mail" on; a mail the
--- player sent by hand fills nothing. The player still presses each Send.
function Errands:Sent()
    local was = self.sending
    self.sending = nil
    local upgrades = self.sendingUpgrades
    self.sendingUpgrades = nil
    if was and upgrades then ns.Verdicts:UpgradesMailed(was, upgrades) end
    if not was or not self.mailOpen or ns.db.fillNext == false then return end
    if not (ns.UI and ns.UI:IsShown()) then return end
    -- The bags say what left them a moment after the mail goes.
    C_Timer.After(Errands.NEXT_DELAY, function()
        if not Errands.mailOpen or InCombat() then return end
        Bags:Fresh(function()
            if not Errands.mailOpen or Errands.sending then return end
            if not Errands:NextRecipient() then
                ns.Print("Sent. That's all the mail for now.")
                return
            end
            local ok, message = Errands:FillMail()
            if message then ns.Print(ok and ("Sent. " .. message) or message) end
        end)
    end)
end

Errands.NEXT_DELAY = 0.5

--- The mail did not go: it can be filled again.
function Errands:SendFailed()
    if self.sending then self.filled[self.sending] = nil end
    self.sending = nil
    self.sendingUpgrades = nil
    self:Update()
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
        self.sending = nil
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
        self.sending = nil
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
    ns.RegisterEvent(self, "MAIL_SEND_SUCCESS", function() Errands:Sent() end)
    ns.RegisterEvent(self, "MAIL_FAILED", function() Errands:SendFailed() end)
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

ns.RegisterCommand("fillnext", "turn filling the next mail after each Send on or off", function()
    ns.db.fillNext = ns.db.fillNext == false
    ns.Print(ns.db.fillNext and "after each Send, Butler fills the next mail."
        or "Butler fills a mail only when you click Fill mail.")
end)

ns.RegisterCommand("bank", "turn the Butler window coming up at the bank on or off", function()
    ns.db.openAtBank = not ns.db.openAtBank
    ns.Print(ns.db.openAtBank and "the Butler window comes up at the bank when there is something to move."
        or "the Butler window no longer comes up at the bank by itself.")
end)
