-- Blackthornes Butler -- UI/Trash.lua
-- A small gold can on the item worth the least, while the bags are full
-- (the owner asked 2026-10-13: "a small can icon for the lowest value
-- item", for a player who wants to throw something away).
--
-- What it picks: only what Butler would sell, auction or disenchant anyway,
-- with a price, in a bag that takes anything (a herb in the herb bag frees
-- no room). Never a quest item, gear an upgrade or an alt wants, goal or
-- craft material, pet food, anything under Keep, Mail, Bank, Wait or Look
-- at it, and never an item Butler has no price for. The stack worth the
-- least in all (Butler's own worth, the verdict's `unit`, times the stack)
-- gets the can.
--
-- Nothing is ever deleted by Butler. A click on the can picks the item up
-- and says so; the player drops it outside the bags and the game's own box
-- asks before anything is destroyed, or clicks its slot to put it back.
--
-- The can is Butler's own button on UIParent, anchored to the game's item
-- button (Equipment's way of finding them: retail's EnumerateValidItems
-- and GetBagID, else classic's ContainerFrame<n>Item<m>). Nothing is
-- written on a game frame: the bag windows' UpdateItems, OnShow and OnHide
-- are only hooked. It hides in combat and at a vendor, where Butler's Sell
-- button is the better way to make room.
--
-- Smooth play: bag events only mark it stale; one look follows 0.2 s after
-- the burst, only while a bag window is open, and the bags are read (and
-- judged) only once they are nearly full.

local _, ns = ...
local L = ns.L

local Trash = ns.NewModule("Trash")

-- Shows at this many free slots or fewer: when the backpack number turns
-- red (UI/FreeSpace.lua).
Trash.FREE = 3
Trash.SETTLE = 0.2
Trash.ART = [[Interface\AddOns\Blackthornes_Butler\Media\Trash\TrashCan]]
-- The can's side, as a share of the item button's.
Trash.SHARE = 0.45

-- The verdicts an item can be thrown away from.
Trash.FROM = { sell = true, auction = true, disenchant = true }

local MAX_FRAMES = 13
local MAX_BUTTONS = 36

local function Field(object, key)
    if type(object) ~= "table" then return nil end
    local ok, value = pcall(function() return object[key] end)
    if ok then return value end
    return nil
end

local function Ask(object, method, ...)
    local fn = Field(object, method)
    if type(fn) ~= "function" then return nil end
    local ok, value = pcall(fn, object, ...)
    if ok then return value end
    return nil
end

local function InCombat()
    local fn = rawget(_G, "InCombatLockdown")
    return type(fn) == "function" and fn() and true or false
end

function Trash:Enabled()
    return ns.db ~= nil and ns.db.trashCan ~= false
end

--- Turn the can on or off (Settings and /bbutler trash).
function Trash:SetEnabled(on)
    ns.db.trashCan = on and true or false
    if on then self:Changed() else self:Hide() end
end

--------------------------------------------------------------------------------
-- The game's bag windows
--------------------------------------------------------------------------------

--- The bag windows this client has, open or not.
function Trash:Frames()
    local frames = {}
    local combined = rawget(_G, "ContainerFrameCombinedBags")
    if type(combined) == "table" then frames[#frames + 1] = combined end
    local count = tonumber(rawget(_G, "NUM_CONTAINER_FRAMES")) or MAX_FRAMES
    for i = 1, count do
        local frame = rawget(_G, "ContainerFrame" .. i)
        if type(frame) == "table" then frames[#frames + 1] = frame end
    end
    return frames
end

function Trash:ShownFrames()
    local shown = {}
    for _, frame in ipairs(self:Frames()) do
        if Ask(frame, "IsShown") then shown[#shown + 1] = frame end
    end
    return shown
end

--- The item buttons in one bag window.
function Trash:Buttons(frame)
    local buttons = {}
    local enumerate = Field(frame, "EnumerateValidItems")
    if type(enumerate) == "function" then
        local ok = pcall(function()
            for _, button in enumerate(frame) do buttons[#buttons + 1] = button end
        end)
        if ok and #buttons > 0 then return buttons end
        buttons = {}
    end
    local name = Ask(frame, "GetName")
    if type(name) == "string" then
        for i = 1, MAX_BUTTONS do
            local button = rawget(_G, name .. "Item" .. i)
            if type(button) ~= "table" then break end
            buttons[#buttons + 1] = button
        end
    end
    return buttons
end

--- The shown item button for a bag slot, or nil.
function Trash:FindButton(frames, bag, slot)
    for _, frame in ipairs(frames) do
        for _, button in ipairs(self:Buttons(frame)) do
            local buttonBag = Ask(button, "GetBagID")
            if type(buttonBag) ~= "number" then buttonBag = Ask(Ask(button, "GetParent") or frame, "GetID") end
            if buttonBag == bag and Ask(button, "GetID") == slot and Ask(button, "IsVisible") then
                return button
            end
        end
    end
    return nil
end

--- Hear the bag windows open, close and redraw: hooks only, once each.
function Trash:InstallHooks()
    self.hooked = self.hooked or {}
    local hook = rawget(_G, "hooksecurefunc")
    for _, frame in ipairs(self:Frames()) do
        if not self.hooked[frame] then
            self.hooked[frame] = true
            if type(hook) == "function" and type(Field(frame, "UpdateItems")) == "function" then
                pcall(hook, frame, "UpdateItems", function() Trash:Changed() end)
            end
            if type(Field(frame, "HookScript")) == "function" then
                pcall(frame.HookScript, frame, "OnShow", function() Trash:Changed() end)
                pcall(frame.HookScript, frame, "OnHide", function() Trash:Changed() end)
            end
        end
    end
    if type(hook) == "function" and not self.hookedUpdate and type(rawget(_G, "ContainerFrame_Update")) == "function" then
        self.hookedUpdate = pcall(hook, "ContainerFrame_Update", function() Trash:Changed() end)
    end
end

--------------------------------------------------------------------------------
-- What to throw away
--------------------------------------------------------------------------------

--- The stack worth the least that may be thrown away: { entry, row, worth,
--- unit }, or nil. `bags` is the set of bag IDs that take anything.
function Trash:Pick(bags)
    local best
    for _, group in ipairs(ns.Verdicts:Groups()) do
        if self.FROM[group.verdict] then
            for _, row in ipairs(group.rows) do
                local unit = tonumber(row.unit)
                if unit and unit > 0 then
                    for _, entry in ipairs(row.slots) do
                        if not entry.locked and not entry.quest and (not bags or bags[entry.bag]) then
                            local worth = unit * (entry.count or 1)
                            if not best or worth < best.worth
                                or (worth == best.worth and (entry.bag < best.entry.bag
                                    or (entry.bag == best.entry.bag and entry.slot < best.entry.slot))) then
                                best = { entry = entry, row = row, worth = worth, unit = unit }
                            end
                        end
                    end
                end
            end
        end
    end
    return best
end

--------------------------------------------------------------------------------
-- The can
--------------------------------------------------------------------------------

function Trash:Can()
    if self.can then return self.can end
    local can = CreateFrame("Button", "BlackthornesButlerTrashCan", UIParent)
    can:SetSize(16, 16)
    can:Hide()
    local icon = can:CreateTexture(nil, "OVERLAY")
    icon:SetAllPoints(can)
    icon:SetTexture(self.ART)
    can.icon = icon
    can:SetScript("OnClick", function() Trash:Take() end)
    can:SetScript("OnEnter", function(owner) Trash:ShowTooltip(owner) end)
    can:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    self.can = can
    return can
end

function Trash:Hide()
    self.pick = nil
    if self.can then self.can:Hide() end
end

--- Lay the can on the picked item's button.
function Trash:Place(frames, bags)
    self.waiting = false
    if self.stale then return self:Changed() end
    local pick = self:Pick(bags)
    local button = pick and self:FindButton(frames, pick.entry.bag, pick.entry.slot)
    if not button then return self:Hide() end

    local can = self:Can()
    self.pick = pick
    local size = (Ask(button, "GetWidth") or 37) * self.SHARE
    can:SetSize(size, size)
    local scale = (Ask(button, "GetEffectiveScale") or 1) / (Ask(UIParent, "GetEffectiveScale") or 1)
    if scale > 0 then can:SetScale(scale) end
    local strata = Ask(button, "GetFrameStrata")
    if type(strata) == "string" then can:SetFrameStrata(strata) end
    can:SetFrameLevel((Ask(button, "GetFrameLevel") or 1) + 10)
    can:ClearAllPoints()
    can:SetPoint("TOPRIGHT", button, "TOPRIGHT", 1, 1)
    can:Show()
end

--- Look again once the burst is over, if a bag window is open.
function Trash:Changed()
    self.stale = true
    if self.settling or self.waiting then return end
    if not self:Enabled() or InCombat() or self.atVendor then return self:Hide() end
    self.settling = true
    C_Timer.After(self.SETTLE, function()
        Trash.settling = false
        Trash:Refresh()
    end)
end

function Trash:Refresh()
    self.stale = false
    if not self:Enabled() or InCombat() or self.atVendor then return self:Hide() end
    -- While the cursor holds something (the item the can picked up, say),
    -- the can waits rather than jump to the next item.
    local cursor = rawget(_G, "GetCursorInfo")
    if type(cursor) == "function" and cursor() then return self:Hide() end
    local frames = self:ShownFrames()
    if #frames == 0 then return self:Hide() end
    local read = ns.FreeSpace and ns.FreeSpace.Read()
    if not read or read.free > self.FREE then return self:Hide() end

    local bags = {}
    for _, entry in ipairs(read.bags) do bags[entry.bag] = true end
    self.free = read.free
    self.waiting = true
    ns.Bags:Fresh(function() Trash:Place(frames, bags) end)
end

function Trash:ShowTooltip(owner)
    local pick = self.pick
    if not (pick and GameTooltip) then return end
    pcall(function()
        GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
        GameTooltip:AddLine(L["Throw away to make room"], 1, 0.82, 0)
        local row, count = pick.row, pick.entry.count or 1
        local name = row.name or L.Format("item %s", tostring(pick.entry.itemID))
        if count > 1 then name = L.Format("%s x%d", name, count) end
        GameTooltip:AddLine(name, 1, 1, 1)
        GameTooltip:AddLine(L.Format("Worth %s in all, the least in your bags",
            ns.Items.FormatMoney(pick.worth)), 1, 1, 1, true)
        if type(row.reason) == "string" and row.reason ~= "" then
            GameTooltip:AddLine(row.reason, 0.8, 0.8, 0.8, true)
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L["Click to pick it up. Drop it outside your bags and the game asks before it is destroyed."],
            0.2, 1, 0.2, true)
        GameTooltip:Show()
    end)
end

--- The click: pick the item up, after making sure it is still there.
--- Butler never deletes it; the game's own box asks when it is dropped.
function Trash:Take()
    local pick = self.pick
    if not pick or InCombat() then return false end
    local entry = pick.entry
    local now = ns.Bags.ReadSlot(entry.bag, entry.slot)
    if not now or now.key ~= entry.key then
        self:Changed()
        return false
    end
    local cursor = rawget(_G, "GetCursorInfo")
    if type(cursor) == "function" and cursor() then
        ns.Print(L["Your cursor is already holding something. Put it down first."])
        return false
    end
    ns.Items.Call({ "C_Container.PickupContainerItem", "PickupContainerItem" }, entry.bag, entry.slot)
    if GameTooltip then GameTooltip:Hide() end
    ns.Print(L.Format("%s is on your cursor. Drop it outside your bags and the game will ask before it is destroyed, or click its bag slot to put it back.",
        pick.row.link or pick.row.name or "?"))
    return true
end

--- One line for /bbutler probe.
function Trash:ProbeText()
    local frames = #self:Frames()
    local state = self.can and self.can:IsShown() and "showing" or "hidden"
    return ("%d bag windows, can %s%s"):format(frames, state, self:Enabled() and "" or ", turned off")
end

function Trash:OnEnable()
    ns.RegisterEvent(self, "BAG_UPDATE_DELAYED", function() Trash:Changed() end)
    ns.RegisterEvent(self, "BAG_CONTAINER_UPDATE", function() Trash:Changed() end)
    ns.RegisterEvent(self, "PLAYER_ENTERING_WORLD", function()
        Trash:InstallHooks()
        Trash:Changed()
    end)
    ns.RegisterEvent(self, "CURSOR_CHANGED", function() Trash:Changed() end)
    ns.RegisterEvent(self, "PLAYER_REGEN_DISABLED", function() Trash:Hide() end)
    ns.RegisterEvent(self, "PLAYER_REGEN_ENABLED", function() Trash:Changed() end)
    ns.RegisterEvent(self, "MERCHANT_SHOW", function()
        Trash.atVendor = true
        Trash:Hide()
    end)
    ns.RegisterEvent(self, "MERCHANT_CLOSED", function()
        Trash.atVendor = false
        Trash:Changed()
    end)
end

ns.RegisterCommand("trash", L["show or hide the trash can on the item worth the least when your bags are full"], function()
    Trash:SetEnabled(not Trash:Enabled())
    ns.Print(Trash:Enabled() and L["the trash can shows on the item worth the least when your bags are full."]
        or L["the trash can no longer shows when your bags are full."])
end)
