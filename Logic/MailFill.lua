-- Butler's own mail, for players without Blackthornes Tradeskills (a
-- player asked why mailing the bank alt needed it, the owner said build
-- it, 2026-11-22). Two pieces Butler used to borrow from Tradeskills:
--
--   * Your characters. Each character you log in on is written down,
--     account wide, in `myCharacters[guid] = { name, realm, faction }`
--     (never rename it): the whole name, first and last, and nothing else.
--     A GUID or last name the client won't read writes nothing. The name
--     picker and Equipment's alt names read it when Tradeskills is off
--     (`MailFill:Holdings`, the shape of Tradeskills' Holdings, names only).
--   * Filling the Send Mail page (`MailFill:Fill`), a copy of Tradeskills'
--     `QueueMail:Fill`: whole stacks first, part of a stack split into an
--     empty bag slot first and put in once the game shows it there, each
--     attachment counted and one that came out too big taken back out.
--     Errands:FillMail uses Tradeskills' when it is loaded, this otherwise.
--
-- Tested in tools/test_mailfill.lua.

local _, ns = ...
local L = ns.L

local MailFill = ns.NewModule("MailFill")

-- Seconds between one attachment and the next, and how often and how many
-- times a split is looked for in its new bag slot (as Tradeskills has it).
MailFill.ATTACH_STEP = 0.2
MailFill.SPLIT_STEP = 0.1
MailFill.SPLIT_TRIES = 20
-- What sending one mail costs.
MailFill.POSTAGE = 30

local function Call(fn, ...)
    if type(fn) ~= "function" then return false end
    return pcall(fn, ...)
end

--- A plain string the client gave, or nil (empty, not a string, or a
--- value that raises when read).
local function Text(value)
    if type(value) ~= "string" then return nil end
    local ok, copy = pcall(function() return (value:gsub("^%s+", ""):gsub("%s+$", "")) end)
    if not ok or copy == "" then return nil end
    return copy
end

local function Global(path)
    local fn = _G
    for part in path:gmatch("[^%.]+") do
        if type(fn) ~= "table" then return nil end
        fn = rawget(fn, part)
    end
    return type(fn) == "function" and fn or nil
end

--------------------------------------------------------------------------------
-- Your characters
--------------------------------------------------------------------------------

local SURNAME_WORDS = { "surname", "secondaryname", "lastname" }

--- The last name in `value` after `first` ("Ana Smith" gives "Smith").
local function After(first, value)
    value = Text(value)
    if not value then return nil end
    local rest = value:match("^" .. first:gsub("%p", "%%%0") .. " (.+)$")
    return Text(rest)
end

--- The character playing's last name, when the client will say it: from a
--- name call that gives first and last, else from a call named for the last
--- name (the same calls Tradeskills' Config:ReadSurname asks).
function MailFill.ReadSurname(first)
    if not first then return nil end
    for _, ask in ipairs({ { "UnitName", "player" }, { "UnitFullName", "player" }, { "GetUnitName", "player", true } }) do
        local results = { Call(Global(ask[1]), ask[2], ask[3]) }
        if results[1] then
            for i = 2, #results do
                local ok, found = pcall(After, first, results[i])
                if ok and found then return found end
            end
        end
    end

    local found = {}
    pcall(function()
        local function Consider(label, name, fn)
            if type(fn) ~= "function" or type(name) ~= "string" then return end
            local lower = name:lower()
            if not (lower:find("^get") or lower:find("^unit")) then return end
            for _, word in ipairs(SURNAME_WORDS) do
                if lower:find(word, 1, true) then
                    found[#found + 1] = { label = label, fn = fn }
                    return
                end
            end
        end
        for name, value in pairs(_G) do Consider(name, name, value) end
        if type(rawget(_G, "C_PlayerInfo")) == "table" then
            for name, value in pairs(C_PlayerInfo) do Consider("C_PlayerInfo." .. name, name, value) end
        end
    end)
    table.sort(found, function(a, b) return a.label < b.label end)
    for _, candidate in ipairs(found) do
        local ok, value = Call(candidate.fn, "player")
        if ok then
            local okAfter, rest = pcall(After, first, value)
            if okAfter and rest then return rest end
            -- A call named for the last name may give it bare.
            local bare = Text(value)
            if bare and bare ~= first and not bare:find("[%s%-]") then return bare end
        end
    end
    return nil
end

local function Saved()
    if not ns.db then return nil end
    if type(ns.db.myCharacters) ~= "table" then ns.db.myCharacters = {} end
    return ns.db.myCharacters
end

--- Write down the character playing: its whole name, realm and side.
--- Nothing when the GUID, first or last name can't be read. A realm the
--- client leaves blank keeps the one written before.
function MailFill:Remember()
    local okGuid, guid = Call(Global("UnitGUID"), "player")
    guid = okGuid and Text(guid) or nil
    if not guid then return false end
    local okFirst, first = Call(Global("UnitName"), "player")
    first = okFirst and Text(first) or nil
    if not first then return false end
    local last = MailFill.ReadSurname(first)
    if not last then return false end
    local saved = Saved()
    if not saved then return false end
    local before = type(saved[guid]) == "table" and saved[guid] or {}
    local okRealm, realm = Call(Global("GetRealmName"))
    local okSide, side = Call(Global("UnitFactionGroup"), "player")
    saved[guid] = {
        name = first .. " " .. last,
        realm = (okRealm and Text(realm)) or Text(before.realm),
        faction = (okSide and Text(side)) or Text(before.faction),
    }
    return true
end

--- Your characters in the shape of Tradeskills' Holdings, names only:
--- { { key, name, short, realm, faction, isCurrent } }, the one playing
--- first, then by name. Nil when none is written down.
function MailFill:Holdings()
    local saved = ns.db and ns.db.myCharacters
    if type(saved) ~= "table" then return nil end
    local okGuid, me = Call(Global("UnitGUID"), "player")
    me = okGuid and Text(me) or nil
    local list = {}
    for guid, record in pairs(saved) do
        local name = type(record) == "table" and Text(record.name)
        if type(guid) == "string" and name then
            list[#list + 1] = {
                key = guid, name = name, short = name,
                realm = Text(record.realm), faction = Text(record.faction),
                isCurrent = me ~= nil and guid == me or nil,
            }
        end
    end
    if #list == 0 then return nil end
    table.sort(list, function(a, b)
        if (a.isCurrent == true) ~= (b.isCurrent == true) then return a.isCurrent == true end
        return a.name < b.name
    end)
    return list
end

function MailFill:OnEnable()
    self:Remember()
    -- The last name can come late on the first login of a character.
    if C_Timer and C_Timer.After then C_Timer.After(5, function() MailFill:Remember() end) end
end

--------------------------------------------------------------------------------
-- Filling the Send Mail page
--------------------------------------------------------------------------------

local function MaxAttachments()
    local max = tonumber(_G.ATTACHMENTS_MAX_SEND)
    if max and max > 0 then return max end
    return 12
end

--- Which mail slots already hold something, and how many.
local function UsedSlots()
    local used, count = {}, 0
    for slot = 1, MaxAttachments() do
        local ok, name = Call(Global("GetSendMailItem"), slot)
        if ok and name ~= nil then
            used[slot] = true
            count = count + 1
        end
    end
    return used, count
end

local function FreeSlot()
    local used = UsedSlots()
    for slot = 1, MaxAttachments() do
        if not used[slot] then return slot end
    end
end

local function AttachedCount(slot)
    local ok, name, _, _, count = Call(Global("GetSendMailItem"), slot)
    if not ok or name == nil then return nil end
    local copied, n = pcall(function() return (count or 1) + 0 end)
    return copied and n or nil
end

local function Container(name)
    return Global("C_Container." .. name) or Global(name)
end

local function NumSlots(bag)
    local ok, slots = Call(Container("GetContainerNumSlots"), bag)
    return ok and tonumber(slots) or 0
end

--- What a bag slot holds: itemID, count, locked, bound, link. nil when empty.
local function SlotHolds(bag, slot)
    local ok, itemID, count, locked, bound, link = Call(function()
        local info = Container("GetContainerItemInfo")(bag, slot)
        if type(info) ~= "table" then return nil end
        local link = type(info.hyperlink) == "string" and info.hyperlink or nil
        return tonumber(info.itemID), tonumber(info.stackCount) or 1, info.isLocked == true,
            info.isBound == true, link
    end)
    if ok then return itemID, count, locked, bound, link end
end

--- Of the stacks of one item, the ones that are `link`: two versions of
--- one item ("of the Monkey" kept, "of the Bear" to mail) share an item ID,
--- and the kept one went in the mail (found 2026-11-28). A link the bags no
--- longer hold still matches when only one version is there; with two, none.
function MailFill.OnlyLink(stacks, link)
    if type(link) ~= "string" or link == "" then return stacks end
    local same, links, kinds = {}, {}, 0
    for _, stack in ipairs(stacks) do
        if stack.link == link then same[#same + 1] = stack end
        local seen = stack.link or ""
        if not links[seen] then links[seen] = true kinds = kinds + 1 end
    end
    if #same > 0 then return same end
    if kinds == 1 then return stacks end
    return {}
end

local function Bags()
    return ns.Bags and ns.Bags.BagIDs and ns.Bags.BagIDs() or { 0, 1, 2, 3, 4 }
end

--- The bag stacks to take for `count` of an item: whole stacks first, the
--- biggest first, and one split for the rest. With `link`, only that
--- version of the item (MailFill.OnlyLink).
--- @return list of { bag, slot, count, split }
function MailFill:PlanStacks(itemID, count, taken, link)
    local stacks = {}
    for _, bag in ipairs(Bags()) do
        for slot = 1, NumSlots(bag) do
            local id, size, locked, bound, slotLink = SlotHolds(bag, slot)
            local key = bag .. ":" .. slot
            if id == itemID and not bound and not locked and not taken[key] then
                stacks[#stacks + 1] = { bag = bag, slot = slot, size = size or 1, key = key, link = slotLink }
            end
        end
    end
    stacks = MailFill.OnlyLink(stacks, link)
    table.sort(stacks, function(a, b)
        if a.size ~= b.size then return a.size > b.size end
        if a.bag ~= b.bag then return a.bag < b.bag end
        return a.slot < b.slot
    end)

    local steps, left = {}, count
    for _, stack in ipairs(stacks) do
        if left <= 0 then break end
        if stack.size <= left then
            steps[#steps + 1] = { bag = stack.bag, slot = stack.slot, count = stack.size }
            taken[stack.key] = true
            left = left - stack.size
        end
    end
    if left > 0 then
        for index = #stacks, 1, -1 do
            local stack = stacks[index]
            if not taken[stack.key] and stack.size > left then
                steps[#steps + 1] = { bag = stack.bag, slot = stack.slot, count = left, split = true }
                taken[stack.key] = true
                break
            end
        end
    end
    return steps
end

--- Do two bag family masks share a bit? Written out, since the tests' Lua
--- has no bit library.
local function SharesFamily(a, b)
    a, b = tonumber(a) or 0, tonumber(b) or 0
    while a > 0 and b > 0 do
        if a % 2 == 1 and b % 2 == 1 then return true end
        a, b = math.floor(a / 2), math.floor(b / 2)
    end
    return false
end

local function ItemFamily(itemID)
    local get = Global("C_Item.GetItemFamily") or Global("GetItemFamily")
    if not (itemID and get) then return 0 end
    local ok, family = pcall(get, itemID)
    return ok and tonumber(family) or 0
end

--- An empty bag slot to split part of a stack into, kept in `reserved`:
--- the stack's own bag first, then an ordinary bag, then a profession bag
--- made for the item.
local function EmptyBagSlot(reserved, from)
    local itemFamily = ItemFamily(from.itemID)
    local function FreeIn(bag)
        for slot = 1, NumSlots(bag) do
            local key = bag .. ":" .. slot
            local ok, info = Call(Container("GetContainerItemInfo"), bag, slot)
            if ok and info == nil and not reserved[key] then
                reserved[key] = true
                return bag, slot
            end
        end
    end
    local function Family(bag)
        local ok, free, family = Call(Container("GetContainerNumFreeSlots"), bag)
        if not ok then return nil, 0 end
        return tonumber(free), tonumber(family) or 0
    end
    local function Takes(bag, sameBag)
        local free, family = Family(bag)
        -- A client that won't count free slots: look for one anyway.
        if free ~= nil and free <= 0 then return false end
        return sameBag or family == 0 or SharesFamily(family, itemFamily)
    end

    if Takes(from.bag, true) then
        local bag, slot = FreeIn(from.bag)
        if bag then return bag, slot end
    end
    for pass = 1, 2 do
        for _, bag in ipairs(Bags()) do
            local _, family = Family(bag)
            if bag ~= from.bag and (pass == 1) == (family == 0) and Takes(bag) then
                local found, slot = FreeIn(bag)
                if found then return found, slot end
            end
        end
    end
end

--- Put `copper` in the Send Mail page's gold boxes. Never with COD ticked,
--- and never more than the purse holds less the postage.
--- @return true, or false and why
function MailFill.PutMoney(copper)
    copper = math.floor(tonumber(copper) or 0)
    if copper <= 0 then return true end
    local cod = _G.SendMailCODButton
    if cod and cod.GetChecked then
        local ok, checked = pcall(cod.GetChecked, cod)
        if ok and checked then return false, L["the mail is set to COD"] end
    end
    local okMoney, purse = Call(Global("GetMoney"))
    purse = okMoney and tonumber(purse) or nil
    if purse and purse < copper + MailFill.POSTAGE then
        return false, L["not enough gold on you"]
    end
    local frame = _G.SendMailMoney
    if not frame then return false, L["the mail has no gold box"] end
    local set = Global("MoneyInputFrame_SetCopper")
    if set and pcall(set, frame, copper) then return true end
    local gold = _G.SendMailMoneyGold or frame.gold
    local silver = _G.SendMailMoneySilver or frame.silver
    local bronze = _G.SendMailMoneyCopper or frame.copper
    if not (gold and silver and bronze) then return false, L["the mail has no gold box"] end
    Call(gold.SetText, gold, tostring(math.floor(copper / 10000)))
    Call(silver.SetText, silver, tostring(math.floor(copper / 100) % 100))
    Call(bronze.SetText, bronze, tostring(copper % 100))
    return true
end

local function HasCursor()
    local has = Global("CursorHasItem")
    local ok, yes = Call(has)
    return ok and yes and true or false
end

local function ClearCursor()
    Call(Global("ClearCursor"))
end

local function MailOpen()
    local frame = _G.SendMailFrame
    if not (frame and frame.IsShown) then return false end
    local ok, shown = pcall(frame.IsShown, frame)
    return ok and shown == true
end

--- What a fill left out, said in chat, since Butler's window covers the
--- mail page.
function MailFill.Done(attached, leftOver)
    if not (leftOver and leftOver > 0) then return end
    if MailFill.splitBlocked then
        ns.Print(L["Free one bag slot to split a stack, then press the button again."])
    else
        ns.Print(L.Format("%d attached; the rest go in the next mail. Press Send.", attached or 0))
    end
end

--- Open the Send Mail page and fill it in: the name, the subject, the gold
--- and as many stacks as one mail holds, one at a time. What doesn't fit
--- stays for the next mail.
--- @param to the whole name for the To box
--- @param items list of { itemID, count }
--- @param money copper, or nil
--- @param onDone function(attached, leftOver), MailFill.Done when nil
--- @return true when it started, or false and why
function MailFill:Fill(to, items, money, onDone)
    onDone = onDone or MailFill.Done
    if self.filling then return false, L["still filling the last mail"] end
    local nameBox = _G.SendMailNameEditBox
    if not nameBox then return false, L["the mailbox is not open"] end

    local list = {}
    for _, item in ipairs(type(items) == "table" and items or {}) do
        local itemID, count = tonumber(item.itemID), tonumber(item.count)
        local link = type(item.link) == "string" and item.link ~= "" and item.link or nil
        if itemID and count and count > 0 then
            list[#list + 1] = { itemID = itemID, count = math.floor(count), link = link }
        end
    end
    money = tonumber(money)
    money = money and money >= 1 and math.floor(money) or nil

    -- The Send Mail tab, by its own click handler where the client has it.
    local tab = _G.MailFrameTab2
    if tab and Global("MailFrameTab_OnClick") then
        Call(Global("MailFrameTab_OnClick"), tab, 2)
    elseif tab and tab.Click then
        Call(tab.Click, tab)
    end

    Call(nameBox.SetText, nameBox, to)
    local subject = _G.SendMailSubjectEditBox
    if subject then
        Call(subject.SetText, subject, #list == 0 and "Gold from Blackthornes Butler" or "From Blackthornes Butler")
    end
    self.splitBlocked = nil

    if money then
        local put, why = MailFill.PutMoney(money)
        if not put then return false, why end
    end

    local _, alreadyIn = UsedSlots()
    local room = MaxAttachments() - alreadyIn
    local steps, taken = {}, {}
    for _, item in ipairs(list) do
        for _, step in ipairs(self:PlanStacks(item.itemID, item.count, taken, item.link)) do
            step.itemID = item.itemID
            steps[#steps + 1] = step
        end
    end
    local leftOver = math.max(0, #steps - room)
    while #steps > room do steps[#steps] = nil end
    if #steps == 0 then
        onDone(0, leftOver)
        return true
    end

    self.filling = true
    local attached, reserved, index = 0, {}, 0
    local Next

    local function Finish()
        MailFill.filling = false
        if HasCursor() then ClearCursor() end
        onDone(attached, leftOver)
    end

    local function Attach(step)
        local slot = FreeSlot()
        if not slot then return Finish() end
        if HasCursor() then ClearCursor() end
        local picked = Call(Container("PickupContainerItem"), step.bag, step.slot)
        if picked and HasCursor() then
            Call(Global("ClickSendMailItemButton"), slot)
            if HasCursor() then
                -- The mail would not take it: put it back and stop.
                ClearCursor()
                leftOver = leftOver + (#steps - index + 1)
                return Finish()
            end
            attached = attached + 1
        end
        C_Timer.After(MailFill.ATTACH_STEP, function()
            -- More in the mail than asked for: never send it.
            local count = AttachedCount(slot)
            if count and count > step.count then
                Call(Global("ClickSendMailItemButton"), slot, true)
                attached = attached - 1
                leftOver = leftOver + 1
            end
            Next()
        end)
    end

    local function SplitThenAttach(step)
        local toBag, toSlot = EmptyBagSlot(reserved, step)
        if not toBag then
            MailFill.splitBlocked = true
            leftOver = leftOver + 1
            return Next()
        end
        if HasCursor() then ClearCursor() end
        Call(Container("SplitContainerItem"), step.bag, step.slot, step.count)
        if not HasCursor() then
            leftOver = leftOver + 1
            return Next()
        end
        Call(Container("PickupContainerItem"), toBag, toSlot)
        if HasCursor() then
            ClearCursor()
            leftOver = leftOver + 1
            return Next()
        end
        local tries = 0
        local function Settled()
            tries = tries + 1
            local itemID, count, locked = SlotHolds(toBag, toSlot)
            if itemID == step.itemID and count == step.count and not locked then
                if not MailOpen() then return Finish() end
                return Attach({ bag = toBag, slot = toSlot, count = step.count, itemID = step.itemID })
            end
            if tries >= MailFill.SPLIT_TRIES or not MailOpen() then
                leftOver = leftOver + 1
                return Next()
            end
            C_Timer.After(MailFill.SPLIT_STEP, Settled)
        end
        C_Timer.After(MailFill.SPLIT_STEP, Settled)
    end

    Next = function()
        index = index + 1
        local step = steps[index]
        if not step or not MailOpen() then return Finish() end
        if step.split then return SplitThenAttach(step) end
        return Attach(step)
    end

    Next()
    return true
end
