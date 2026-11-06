-- Blackthornes Butler -- UI/ThrowAway.lua
-- The Throw Away button: a gold plaque under the open bag window that throws
-- away the item the trash can is on (a player asked on Discord, the owner
-- said build it from a mockup, 2026-11-06). For a player whose bags are full
-- while an NPC tries to hand them a quest item, so they don't have to hunt
-- for the can among their icons.
--
-- It shows only while the trash can shows a pick (UI/Trash.lua, `Trash.pick`
-- from `Trash:Pick` or `Trash:Merge`), so the same rules hold: only what
-- Butler would sell, auction or disenchant anyway, never a quest item, a
-- locked slot, a keep, a mail, a bank item, an upgrade, goal or craft
-- material or pet food. Like the can it hides in a fight, at a vendor and
-- while the cursor holds something.
--
-- Two clicks, never one. The first turns it red, "Click Again", for
-- `ARMED` seconds (moving off it lets go too). The second reads the slot
-- again (its key must match), picks the item up, checks the cursor holds
-- that very item and then destroys it (DeleteCursorItem), the way
-- SwapWhenFull:Take does. A green or better item is never destroyed here:
-- the plaque says Pick Up and a click picks it up, so the game's own box
-- asks before it goes (Trash:Take). Two short stacks that fit together say
-- Stack These, and one click joins them (Trash:Take as well).
--
-- Butler's own button on UIParent, placed by screen position under the
-- bag window that shows (Butler Bags, else the game's combined bag, else
-- its first bag). Nothing is written on a game frame. Off unless ticked:
-- "Throw Away Button:" on the General page (`throwAwayButton`, account
-- wide, never rename it).

local _, ns = ...
local L = ns.L

local ThrowAway = ns.NewModule("ThrowAway")

-- How long the red Click Again waits for the second click.
ThrowAway.ARMED = 3
-- The gap between the bag window's bottom edge and the plaque.
ThrowAway.GAP = 6
-- Green, the first quality Butler never throws away itself.
ThrowAway.KEEP_FROM = 2
-- The red of the armed plaque.
ThrowAway.RED = { 1, 0.35, 0.3 }

local function Global(name, ...)
    local fn = rawget(_G, name)
    if type(fn) ~= "function" then return nil end
    local ok, a, b = pcall(fn, ...)
    if ok then return a, b end
    return nil
end

local function Ask(object, method, ...)
    if type(object) ~= "table" then return nil end
    local ok, fn = pcall(function() return object[method] end)
    if not ok or type(fn) ~= "function" then return nil end
    local ok2, value = pcall(fn, object, ...)
    if ok2 then return value end
    return nil
end

local function InCombat()
    return Global("InCombatLockdown") and true or false
end

local function CursorHolds()
    return Global("GetCursorInfo") ~= nil
end

local function Now()
    return Global("GetTime") or 0
end

function ThrowAway:Enabled()
    return ns.db ~= nil and ns.db.throwAwayButton == true
end

--- Turn the button on or off (Settings).
function ThrowAway:SetEnabled(on)
    ns.db.throwAwayButton = on and true or false
    if on and ns.Trash then ns.Trash:Changed() end
    self:Update()
end

--------------------------------------------------------------------------------
-- What the trash can picked
--------------------------------------------------------------------------------

--- "throw", "pickup" (green or better) or "merge", for a trash can pick.
function ThrowAway.Mode(pick)
    if not pick then return nil end
    if pick.merge then return "merge" end
    local entry = pick.entry
    local quality = tonumber(entry.quality)
    if not quality and ns.Items.Quality then
        quality = tonumber(ns.Items:Quality(entry.itemID))
    end
    if quality and quality >= ThrowAway.KEEP_FROM then return "pickup" end
    return "throw"
end

--- The item's name in its quality colour, with "x3" for a stack.
function ThrowAway.Name(pick)
    local entry = pick.entry
    local name = (pick.row and pick.row.name) or ns.Items.NameFromLink(entry.link)
        or L.Format("item %s", tostring(entry.itemID))
    name = ns.Items:ColorName(name, entry.itemID, entry.quality)
    local count = entry.count or 1
    if count > 1 then name = L.Format("%s x%d", name, count) end
    return name
end

--- The plaque's two lines for a pick, armed or not.
function ThrowAway.Lines(pick, armed)
    local mode = ThrowAway.Mode(pick)
    local name = ThrowAway.Name(pick)
    if mode == "merge" then
        return L.Format("Stack These %s", name), L["Nothing is thrown away"]
    end
    local worth = ns.Items.FormatMoney(pick.worth or 0)
    if mode == "pickup" then
        return L.Format("Pick Up %s", name), L.Format("Worth %s. The game asks before it goes.", worth)
    end
    if armed then
        return L["Click Again"], L.Format("To throw away %s", name)
    end
    return L.Format("Throw Away %s", name), L.Format("Worth %s, the least in your bags", worth)
end

--------------------------------------------------------------------------------
-- The plaque
--------------------------------------------------------------------------------

function ThrowAway:Button()
    if self.button then return self.button end
    local button = ns.Plaque.Create(UIParent, { name = "BlackthornesButlerThrowAway" })
    pcall(button.SetFrameStrata, button, "HIGH")
    pcall(button.RegisterForClicks, button, "LeftButtonUp")
    button:Hide()

    -- The red wash over the glass while it waits for Click Again.
    local red = button:CreateTexture(nil, "BACKGROUND", nil, 4)
    red:SetPoint("TOPLEFT", ns.Plaque.RIM, -ns.Plaque.RIM)
    red:SetPoint("BOTTOMRIGHT", -ns.Plaque.RIM, ns.Plaque.RIM)
    red:SetColorTexture(0.55, 0.06, 0.04, 0.55)
    red:Hide()
    button.red = red

    -- The plaque's own hover light, with the red kept on the first line
    -- while armed, and the tooltip.
    local function Light(p)
        button.Light(p)
        if ThrowAway.armed then button.first:SetTextColor(unpack(ThrowAway.RED)) end
    end
    button:SetScript("OnEnter", function(owner)
        local Motion = ns.Motion
        if Motion and Motion.Blend then Motion:Blend(owner, "hover", 1, 0.12, Light) else Light(1) end
        ThrowAway:ShowTooltip(owner)
    end)
    button:SetScript("OnLeave", function(owner)
        local Motion = ns.Motion
        if Motion and Motion.Blend then Motion:Blend(owner, "hover", 0, 0.18, Light) else Light(0) end
        if GameTooltip then GameTooltip:Hide() end
        ThrowAway:Disarm()
    end)
    button:SetScript("OnClick", function() ThrowAway:Click() end)
    self.button = button
    return button
end

--- The bag window the plaque sits under, or nil.
function ThrowAway:Anchor()
    local Bags = ns.BagWindow
    if Bags and Bags:Covering() then
        local frame = Bags.frame
        if frame and Ask(frame, "IsShown") then return frame end
        return nil
    end
    local combined = rawget(_G, "ContainerFrameCombinedBags")
    if Ask(combined, "IsShown") then return combined end
    local first = rawget(_G, "ContainerFrame1")
    if Ask(first, "IsShown") then return first end
    for _, frame in ipairs(ns.Trash:ShownFrames()) do return frame end
    return nil
end

--- Lay the plaque under `frame` by screen position, in UIParent's units.
function ThrowAway:Place(button, frame)
    local left, bottom = Ask(frame, "GetLeft"), Ask(frame, "GetBottom")
    if type(left) ~= "number" or type(bottom) ~= "number" then return false end
    local scale = tonumber(Ask(frame, "GetEffectiveScale")) or 1
    local parent = tonumber(Ask(UIParent, "GetEffectiveScale")) or 1
    local x = left * scale / parent
    local y = bottom * scale / parent - self.GAP
    -- Never off the bottom of the screen: tuck it over the window instead.
    local height = tonumber(Ask(button, "GetHeight")) or ns.Plaque.HEIGHT
    if y - height < 0 then y = height end
    button:ClearAllPoints()
    button:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y)
    return true
end

function ThrowAway:Hide()
    self:Disarm(true)
    self.pick = nil
    if self.button then self.button:Hide() end
end

--- Show or hide the plaque for what the trash can shows now. Called by
--- Trash:Place and Trash:Hide, and by its own events.
function ThrowAway:Update()
    local Trash = ns.Trash
    local pick = Trash and Trash.pick
    if not self:Enabled() or not pick or InCombat() or (Trash and Trash.atVendor) or CursorHolds()
        or not (Trash.can and Trash.can:IsShown()) then
        return self:Hide()
    end
    local frame = self:Anchor()
    if not frame then return self:Hide() end
    if self.pick ~= pick then self:Disarm(true) end
    self.pick = pick

    local button = self:Button()
    button:SetIcon(ns.Items.Call({ "C_Item.GetItemIconByID", "GetItemIcon" }, pick.entry.itemID))
    self:Paint()
    if not self:Place(button, frame) then return self:Hide() end
    button:Show()
    button:SetGlowing(true)
end

--- Set the words and colours for the pick, armed or not.
function ThrowAway:Paint()
    local button, pick = self.button, self.pick
    if not (button and pick) then return end
    local first, second = self.Lines(pick, self.armed)
    button:SetLines(first, second)
    button.red:SetShown(self.armed and true or false)
    if self.armed then
        button.first:SetTextColor(unpack(self.RED))
    else
        button.first:SetTextColor(unpack(ns.Plaque.FIRST))
    end
end

function ThrowAway:Disarm(quiet)
    if not self.armed then return end
    self.armed = nil
    if not quiet then self:Paint() end
    if self.button then self.button.red:Hide() end
end

function ThrowAway:Arm()
    self.armed = Now()
    local token = self.armed
    self:Paint()
    if C_Timer and C_Timer.After then
        C_Timer.After(self.ARMED, function()
            if ThrowAway.armed == token then ThrowAway:Disarm() end
        end)
    end
end

--------------------------------------------------------------------------------
-- The clicks
--------------------------------------------------------------------------------

function ThrowAway:Click()
    local pick = self.pick
    if not pick or InCombat() then return false end
    local mode = self.Mode(pick)
    if mode ~= "throw" then
        -- Pick Up or Stack These: the trash can's own click, one click.
        if GameTooltip then GameTooltip:Hide() end
        return ns.Trash:Take()
    end
    if not self.armed or Now() - self.armed > self.ARMED then
        self:Arm()
        if self.button and GameTooltip and Ask(self.button, "IsMouseOver") then self:ShowTooltip(self.button) end
        return false
    end
    return self:Throw()
end

--- The second click: destroy the item, after making sure it is still the
--- one the plaque names and that it is what the cursor holds.
function ThrowAway:Throw()
    local pick = self.pick
    self:Disarm(true)
    if not pick or InCombat() or self.Mode(pick) ~= "throw" then return false end
    if CursorHolds() then
        ns.Print(L["Your cursor is already holding something. Put it down first."])
        return false
    end
    local entry = pick.entry
    local now = ns.Bags.ReadSlot(entry.bag, entry.slot)
    if not now or now.key ~= entry.key then
        ns.Trash:Changed()
        return false
    end
    local names = { "C_Container.PickupContainerItem", "PickupContainerItem" }
    ns.Items.Call(names, entry.bag, entry.slot)
    local kind, itemID = Global("GetCursorInfo")
    if kind ~= "item" or tonumber(itemID) ~= entry.itemID then
        -- Not the item named: put back whatever came up, delete nothing.
        if kind then ns.Items.Call(names, entry.bag, entry.slot) end
        ns.Trash:Changed()
        return false
    end
    Global("DeleteCursorItem")
    if GameTooltip then GameTooltip:Hide() end
    ns.Print(L.Format("Threw away %s.", self.Name(pick)))
    self:Hide()
    ns.Trash:Changed()
    return true
end

function ThrowAway:ShowTooltip(owner)
    local pick = self.pick
    if not (pick and GameTooltip) then return end
    pcall(function()
        GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
        local mode = self.Mode(pick)
        if mode == "merge" then
            GameTooltip:AddLine(L["Stack these to make room"], 1, 0.82, 0)
            GameTooltip:AddLine(self.Name(pick), 1, 1, 1)
            GameTooltip:AddLine(L.Format("It fits on your other stack of %d.", pick.to.count or 1), 1, 1, 1, true)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(L["Click to stack them. Nothing is thrown away."], 0.2, 1, 0.2, true)
            GameTooltip:Show()
            return
        end
        GameTooltip:AddLine(L["Throw away to make room"], 1, 0.82, 0)
        GameTooltip:AddLine(self.Name(pick), 1, 1, 1)
        GameTooltip:AddLine(L.Format("Worth %s in all, the least in your bags",
            ns.Items.FormatMoney(pick.worth or 0)), 1, 1, 1, true)
        local reason = pick.row and pick.row.reason
        if type(reason) == "string" and reason ~= "" then
            GameTooltip:AddLine(reason, 0.8, 0.8, 0.8, true)
        end
        GameTooltip:AddLine(" ")
        if mode == "pickup" then
            GameTooltip:AddLine(L["Click to pick it up. Nothing is thrown away until you say so."],
                0.2, 1, 0.2, true)
        else
            GameTooltip:AddLine(L["Click, then Click Again to throw it away."], 0.2, 1, 0.2, true)
        end
        GameTooltip:Show()
    end)
end

--- One line for /bbutler probe.
function ThrowAway:ProbeText()
    local parts = { self:Enabled() and "on" or "off" }
    parts[#parts + 1] = (self.button and self.button:IsShown()) and "showing" or "hidden"
    if self.pick then parts[#parts + 1] = "mode " .. tostring(self.Mode(self.pick)) end
    parts[#parts + 1] = Global("DeleteCursorItem") == nil and rawget(_G, "DeleteCursorItem") and "can delete"
        or (type(rawget(_G, "DeleteCursorItem")) == "function" and "can delete" or "no DeleteCursorItem")
    return table.concat(parts, "; ")
end

function ThrowAway:OnEnable()
    ns.RegisterEvent(self, "PLAYER_REGEN_DISABLED", function() ThrowAway:Hide() end)
    ns.RegisterEvent(self, "MERCHANT_SHOW", function() ThrowAway:Hide() end)
    ns.RegisterEvent(self, "CURSOR_CHANGED", function() ThrowAway:Update() end)
end
