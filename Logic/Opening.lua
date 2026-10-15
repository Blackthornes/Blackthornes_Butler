-- Blackthornes Butler -- Logic/Opening.lua
-- The Open button: one click opens the next clam, sack or lockbox in the
-- bags (the owner asked 2026-10-15: "just the button with hover text that
-- say Open").
--
-- What counts: a bag slot the client says has loot in it
-- (C_Container.GetContainerItemInfo's hasLoot). Left alone, so nothing kept
-- on purpose is used up:
--   * anything on the Always keep, bank or mail list, or kept from a buyback;
--   * quest items, and anything an open quest collects;
--   * anything a Farmer goal or a craft in Tradeskills' queue still needs,
--     on this character or another one;
--   * a lockbox still locked (its tooltip says so), and a slot the game has
--     locked while it moves.
--
-- Addon code may not use an item, but the player's own click on a secure
-- button may, as the Sell button does. So this is a secure button, aimed at
-- one slot ("/use bag slot") just before the click runs and emptied after.
-- At a vendor, bank, mailbox, auction house or trade a /use would sell,
-- bank, attach or trade the item, so the button hides there.
--
-- Like the other secure buttons it sits inside the window out of combat
-- (UI:Dock), at its foot left of the Sell, errand and Disenchant buttons,
-- and goes as a fight starts, so the window stays free to move and close.
--
-- Opening after loot (`autoOpen`, off unless ticked) opens the next one by
-- itself each time a loot window closes, out of combat and away from any
-- NPC, but only once /bbutler opentest found the game lets addon code open
-- an item (`openTest`, as `sellTest` is for selling). One it tried that
-- did not open is left for the session. Never rename `openButton`,
-- `autoOpen` or `openTest`.

local _, ns = ...
local L = ns.L

local Opening = ns.NewModule("Opening")

local Bags = ns.Bags
local Items = ns.Items

Opening.SIZE = 28
-- Between it and the buttons to its right.
local GAP = 6
-- After a loot window closes, how long before the next one opens by itself.
Opening.AUTO_DELAY = 0.4
-- How long the test waits for a loot window.
Opening.TEST_WAIT = 1.5

-- Items tried by Open after loot that stayed shut, for this session.
Opening.tried = {}

local function InCombat()
    return type(InCombatLockdown) == "function" and InCombatLockdown() and true or false
end

--------------------------------------------------------------------------------
-- Settings
--------------------------------------------------------------------------------

function Opening:IsOn()
    return ns.db ~= nil and ns.db.openButton ~= false
end

function Opening:SetOn(on)
    ns.db.openButton = on and true or false
    if ns.UI and ns.UI.frame then ns.UI:FootRoom() end
end

function Opening:AutoOn()
    return ns.db ~= nil and ns.db.autoOpen == true
end

function Opening:SetAuto(on)
    ns.db.autoOpen = on and true or false
end

--- "works", "blocked" or nil (not tested).
function Opening:TestResult()
    local test = ns.db and ns.db.openTest
    return type(test) == "table" and test.result or nil
end

--------------------------------------------------------------------------------
-- What to open
--------------------------------------------------------------------------------

--- Is a slot's item kept on purpose? Then it is never opened.
function Opening:Kept(entry)
    local itemID = entry.itemID
    local Verdicts, Sisters = ns.Verdicts, ns.Sisters
    if Verdicts:InSet(itemID) then return true end
    if Verdicts:Choice(itemID) then
        -- Always keep, bank or mail: the player has plans for it. Always
        -- sell is no reason to keep it shut.
        local choice = Verdicts:Choice(itemID)
        if choice ~= "sell" then return true end
    end
    if ns.Learning and ns.Learning:Get(itemID) == "keep" then return true end
    if entry.quest then return true end
    if ns.Quests and ns.Quests:Reason(itemID) then return true end

    local goal = Sisters.Number(Sisters:Ask("farmer", entry), "need")
    if goal and goal > 0 then return true end
    local ts = Sisters:Ask("ts", entry)
    local need = Sisters.Number(ts, "need")
    if need and need > 0 then return true end
    local share = Sisters.Number(ts, "mailCount")
    if share and share > 0 then return true end
    return false
end

--- Does the slot's tooltip say the lockbox is still locked?
function Opening.LockedBox(bag, slot)
    local tip = rawget(_G, "C_TooltipInfo")
    if type(tip) ~= "table" or type(tip.GetBagItem) ~= "function" then return false end
    local word = rawget(_G, "LOCKED") or "Locked"
    local ok, locked = pcall(function()
        local data = tip.GetBagItem(bag, slot)
        for _, line in ipairs(data and data.lines or {}) do
            if line.leftText == word then return true end
        end
        return false
    end)
    return ok and locked == true
end

--- May this slot be opened now? `entry` as Bags reads it.
function Opening:Openable(entry)
    if not (entry and entry.loot and entry.itemID) or entry.locked then return false end
    if self:Kept(entry) then return false end
    return not Opening.LockedBox(entry.bag, entry.slot)
end

--- The slots to open, by the last read of the bags, in bag order, and how
--- many items that is. Kept until the bags or the verdicts move.
function Opening:Queue()
    local key = Bags.version .. ":" .. tostring(ns.Verdicts.version)
    if self.queueKey == key and self.queue then return self.queue, self.total end

    local queue, total = {}, 0
    for _, entry in pairs(Bags.slots) do
        if entry.loot and not entry.locked and self:Openable(entry) then
            queue[#queue + 1] = entry
            total = total + (entry.count or 1)
        end
    end
    table.sort(queue, function(a, b)
        if a.bag ~= b.bag then return a.bag < b.bag end
        return a.slot < b.slot
    end)
    self.queue, self.total, self.queueKey = queue, total, key
    return queue, total
end

--- The next slot that still holds something to open, read again now, or nil.
--- `skipTried` leaves out what Open after loot tried and could not open.
function Opening:Next(skipTried)
    for _, item in ipairs((self:Queue())) do
        local entry = Bags.ReadSlot(item.bag, item.slot)
        if entry and entry.itemID == item.itemID and not (skipTried and Opening.tried[entry.itemID]) then
            entry.quest = Bags.ReadQuest(item.bag, item.slot, item.itemID)
            if self:Openable(entry) then return entry end
        end
    end
end

--- At a vendor, bank, mailbox, auction house or trade, a /use does
--- something else with the item.
function Opening.Busy()
    if ns.UI and ns.UI.AtAnNPC and ns.UI.AtAnNPC() then return true end
    local trade = rawget(_G, "TradeFrame")
    if trade then
        local ok, shown = pcall(trade.IsShown, trade)
        if ok and shown then return true end
    end
    return false
end

--------------------------------------------------------------------------------
-- The button
--------------------------------------------------------------------------------

local function Clear(button)
    button:SetAttribute("type", nil)
    button:SetAttribute("macrotext", nil)
end

function Opening:Create()
    if self.button then return self.button end

    -- Icon only: the next item's own icon, how many are left in the corner
    -- like a stack, and "Open" under the mouse.
    local button = ns.Widgets.CreateButton(UIParent, "", nil, {
        name = "BlackthornesButlerOpen", template = "SecureActionButtonTemplate",
        width = Opening.SIZE, height = Opening.SIZE,
    })
    button:Hide()
    button:SetFrameStrata("DIALOG")
    button:RegisterForClicks("AnyUp")
    button:SetAttribute("useOnKeyDown", false)

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", 2, -2)
    icon:SetPoint("BOTTOMRIGHT", -2, 2)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    button.icon = icon

    local count = ns.Theme.CreateLabel(button, "small", "text", "RIGHT")
    count:SetPoint("BOTTOMRIGHT", -2, 2)
    button.count = count

    button:HookScript("OnEnter", function(frame)
        GameTooltip:SetOwner(frame, "ANCHOR_TOP")
        GameTooltip:SetText(L["Open"], 1, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    button:HookScript("OnLeave", function() GameTooltip:Hide() end)

    -- Last look before the secure action runs: aimed at the next slot that
    -- may still be opened, or at nothing.
    button:SetScript("PreClick", function(frame)
        if InCombat() then return end
        local item = not Opening.Busy() and Opening:Next() or nil
        if not item then
            Clear(frame)
            return
        end
        frame:SetAttribute("type", "macro")
        frame:SetAttribute("macrotext", ("/use %d %d"):format(item.bag, item.slot))
    end)

    -- Nothing is left aimed at a slot between clicks.
    button:SetScript("PostClick", function(frame)
        if not InCombat() then Clear(frame) end
    end)

    self.button = button
    return button
end

--- Show it when there is something to open, left of `room` (how wide the
--- buttons at the foot are, 0 for none).
-- @return how wide it is when shown, else 0
function Opening:Update(room)
    if self.fighting or InCombat() then return 0 end

    local window = ns.UI and ns.UI.frame
    local show = window and self:IsOn() and ns.UI:IsShown() and not ns.UI.dragging
        and ns.UI.view ~= "all" and not Opening.Busy()
    local button = self.button
    if not show then
        if button then button:Hide() end
        return 0
    end

    local queue, total = self:Queue()
    if total == 0 then
        if button then button:Hide() end
        return 0
    end

    button = self:Create()
    if not ns.UI:Dock(button) then
        button:Hide()
        return 0
    end
    button.icon:SetTexture(queue[1].icon or 134400)
    button.count:SetText(total > 1 and tostring(total) or "")

    button:ClearAllPoints()
    local inset = ns.UI.SELL_INSET_X + ((room or 0) > 0 and room + GAP or 0)
    button:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -inset, ns.UI.SELL_INSET_Y - 2)
    button:Show()
    return Opening.SIZE
end

--------------------------------------------------------------------------------
-- The test, and opening after loot
--------------------------------------------------------------------------------

local function Use()
    return Items.Resolve("C_Container.UseContainerItem")
end

--- Open the next one from addon code, to see whether the game allows it.
--- What it finds is kept in openTest.
function Opening:Test()
    if InCombat() then
        ns.Print(L["not in a fight. Try again after it."])
        return
    end
    if Opening.Busy() then
        ns.Print(L["step away from vendors, the bank and the mailbox first, or the test would sell, bank or mail the item."])
        return
    end
    local use = Use()
    if not use then
        ns.Print(L["this version of the game has no C_Container.UseContainerItem."])
        return
    end

    Bags:Scan(function()
        local item = Opening:Next()
        if not item then
            ns.Print(L["no clam, sack or lockbox in your bags to test with. Carry one and try again."])
            return
        end

        ns.Print(L.Format("trying to open %s from addon code...", item.link or L["an item"]))
        Opening.testLoot = false
        Opening.testing = true
        local called, err = pcall(use, item.bag, item.slot)

        C_Timer.After(Opening.TEST_WAIT, function()
            Opening.testing = false
            local still = Bags.ReadSlot(item.bag, item.slot)
            local used = not (still and still.itemID == item.itemID and (still.count or 1) == (item.count or 1))
            local works = called and (Opening.testLoot or used) and true or false

            ns.db.openTest = { at = time(), result = works and "works" or "blocked",
                error = (not called and err) and tostring(err):sub(1, 120) or nil }

            if works then
                ns.Print(L["|cff4fd18bopening from Butler works|r: tick Open after loot in Settings and Butler opens them as you loot."])
            else
                ns.Print(L.Format("|cffe5604fopening from Butler is blocked|r (%s). The Open button still works.",
                    not called and L["the game refused the call"] or L["nothing opened"]))
            end
        end)
    end)
end

--- A loot window closed: check what the last try did, then open the next.
function Opening:LootClosed()
    local last = self.last
    self.last = nil
    if last then
        local still = Bags.ReadSlot(last.bag, last.slot)
        if still and still.itemID == last.itemID and (still.count or 1) >= (last.count or 1) then
            -- It stayed shut, or its loot was left in it: not again by itself.
            Opening.tried[last.itemID] = true
        end
    end
    if not (self:AutoOn() and self:TestResult() == "works") then return end

    C_Timer.After(Opening.AUTO_DELAY, function() Opening:OpenNext() end)
end

--- Open the next one by itself, when that is allowed now.
function Opening:OpenNext()
    if not (self:AutoOn() and self:TestResult() == "works") then return false end
    if InCombat() or Opening.Busy() or self.lootOpen then return false end
    local space = ns.FreeSpace and ns.FreeSpace.Read and ns.FreeSpace.Read()
    if space and space.free < 1 then return false end
    local use = Use()
    if not use then return false end

    Bags:Fresh(function()
        if InCombat() or Opening.Busy() or Opening.lootOpen then return end
        local item = Opening:Next(true)
        if not item then return end
        Opening.last = { bag = item.bag, slot = item.slot, itemID = item.itemID, count = item.count }
        if not pcall(use, item.bag, item.slot) then
            Opening.tried[item.itemID] = true
            Opening.last = nil
        end
    end)
    return true
end

--- One line for /bbutler probe.
function Opening:ProbeText()
    local _, total = self:Queue()
    local button = self.button
    local test = self:TestResult()
    return ("to open %d, button %s, %s, test %s, after loot %s"):format(total or 0,
        button and (button:IsShown() and "shown" or "hidden") or "not made",
        self:IsOn() and "on" or "off", test or "not run", self:AutoOn() and "on" or "off")
end

--------------------------------------------------------------------------------
-- Events
--------------------------------------------------------------------------------

function Opening:OnEnable()
    ns.RegisterEvent(self, "PLAYER_REGEN_DISABLED", function()
        Opening.fighting = true
        local button = Opening.button
        if button then
            button:Hide()
            Clear(button)
        end
    end)
    ns.RegisterEvent(self, "PLAYER_REGEN_ENABLED", function()
        Opening.fighting = false
        if ns.UI and ns.UI.FootRoom and ns.UI.frame then ns.UI:FootRoom() end
    end)
    ns.RegisterEvent(self, "LOOT_OPENED", function()
        Opening.lootOpen = true
        if Opening.testing then Opening.testLoot = true end
    end)
    ns.RegisterEvent(self, "LOOT_CLOSED", function()
        Opening.lootOpen = false
        Opening:LootClosed()
    end)
end

ns.RegisterCommand("openbutton", L["show or hide the Open button for clams, sacks and lockboxes"], function(arg)
    arg = (arg or ""):lower()
    local on = arg == "on" or (arg ~= "off" and not Opening:IsOn())
    Opening:SetOn(on)
    ns.Print(on and L["the Open button shows while you carry a clam, sack or lockbox."]
        or L["the Open button is hidden."])
end)

ns.RegisterCommand("opentest", L["open one clam, sack or lockbox from addon code, to test whether Butler may open them as you loot"],
    function() Opening:Test() end)

ns.RegisterCommand("autoopen", L["open clams, sacks and lockboxes by themselves after you loot, once the test says it works"], function(arg)
    arg = (arg or ""):lower()
    local on = arg == "on" or (arg ~= "off" and not Opening:AutoOn())
    Opening:SetAuto(on)
    if on and Opening:TestResult() ~= "works" then
        ns.Print(L["Butler opens them after you loot once /bbutler opentest says it can."])
    else
        ns.Print(on and L["Butler opens clams, sacks and lockboxes after you loot."]
            or L["Butler no longer opens anything by itself."])
    end
end)
