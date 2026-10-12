-- Blackthornes Butler -- Logic/Disenchanting.lua
-- The Disenchant button: casts Disenchant on the next item under Disenchant,
-- one cast a click (the owner asked, 2026-10-11).
--
-- Items bought on the auction house to disenchant (Tradeskills marks them,
-- its Logic/DisenchantBuys.lua) head the Disenchant group, so they go first.
--
-- Addon code may not cast a spell, but the player's own click on a secure
-- button may. So, as Tradeskills' Disenchant button does, this is a secure
-- button set to cast Disenchant, aimed at one bag slot through the
-- template's own target-bag and target-slot attributes just before the
-- click runs. Never a "/use bag slot" macro: when the cast did not start,
-- that would equip the item, and equipping binds it.
--
-- Rules:
--   * Every disenchant is the player's own click: nothing is cast for them.
--   * Only rows judged Disenchant are offered, and every slot is read again
--     just before the click: it must still hold that item, unlocked, and
--     still be judged Disenchant, or nothing is cast.
--   * Never in combat: the button hides as combat starts (its aim emptied
--     while that can still be done) and comes back when it ends.
--
-- Like the Sell button, it is parented to UIParent and placed over the
-- window's foot by screen position, left of the Sell or errand buttons, so
-- the window stays free to move and close in combat. It shows only while
-- the window is up on Your bags, not moving, and the character knows
-- Disenchant. It never touches a Blizzard frame.

local _, ns = ...
local L = ns.L

local Disenchanting = ns.NewModule("Disenchanting")

local Bags = ns.Bags

Disenchanting.SPELL = 13262

local BUTTON_WIDTH = 150
local BUTTON_HEIGHT = 24
-- Between it and the buttons to its right.
local GAP = 6

local function InCombat()
    return type(InCombatLockdown) == "function" and InCombatLockdown() and true or false
end

--- Does the character playing know Disenchant? nil when the client won't say.
function Disenchanting:Knows()
    for _, name in ipairs({ "IsPlayerSpell", "IsSpellKnown" }) do
        local fn = rawget(_G, name)
        if type(fn) == "function" then
            local ok, known = pcall(fn, self.SPELL)
            if ok and type(known) == "boolean" then return known end
        end
    end
    return nil
end

--------------------------------------------------------------------------------
-- What to disenchant
--------------------------------------------------------------------------------

--- The Disenchant group's slots, in the order they go (bought first, as the
--- group sorts them): each { bag, slot, itemID, name }, and how many items
--- that is in all.
function Disenchanting:Queue()
    local queue, total = {}, 0
    local group = ns.Verdicts:Group("disenchant")
    if not group then return queue, total end
    for _, row in ipairs(group.rows) do
        for _, entry in ipairs(row.slots) do
            if not entry.locked then
                queue[#queue + 1] = { bag = entry.bag, slot = entry.slot, itemID = entry.itemID,
                    name = row.name, bought = row.bought }
                total = total + (entry.count or 1)
            end
        end
    end
    return queue, total
end

--- Is this slot still the item, unlocked and judged Disenchant?
local function StillDisenchant(item)
    if not Bags.Holds(item.bag, item.slot, item.itemID) then return false end
    local entry = Bags.ReadSlot(item.bag, item.slot)
    if not entry then return false end
    entry.quest = Bags.ReadQuest(item.bag, item.slot, item.itemID)
    return ns.Verdicts:VerdictOf(entry) == "disenchant"
end

--- The next item to disenchant that the bags still hold, or nil.
function Disenchanting:Next()
    for _, item in ipairs((self:Queue())) do
        if StillDisenchant(item) then return item end
    end
end

--------------------------------------------------------------------------------
-- The button
--------------------------------------------------------------------------------

local function Clear(button)
    button:SetAttribute("type", nil)
    button:SetAttribute("target-bag", nil)
    button:SetAttribute("target-slot", nil)
end

function Disenchanting:Create()
    if self.button then return self.button end

    -- The main action: a gold face with dark ink lettering (the game's red
    -- in the Blizzard style), on the game's secure template, with no
    -- OnClick of its own: the template's is what casts.
    local button = ns.Widgets.CreateButton(UIParent, L["Disenchant"], nil, {
        name = "BlackthornesButlerDisenchant", template = "SecureActionButtonTemplate",
        primary = true, width = BUTTON_WIDTH, height = BUTTON_HEIGHT,
    })
    button:Hide()
    -- Above the window (DIALOG), as the Sell button is.
    button:SetFrameStrata("FULLSCREEN_DIALOG")
    button:SetFrameLevel(10)
    button:RegisterForClicks("AnyUp")
    button:SetAttribute("useOnKeyDown", false)
    button:SetAttribute("spell", self.SPELL)

    button:HookScript("OnEnter", function(frame)
        if frame.tooltipText then
            GameTooltip:SetOwner(frame, "ANCHOR_TOP")
            GameTooltip:SetText(frame.tooltipText, 1, 1, 1, 1, true)
            GameTooltip:Show()
        end
    end)
    button:HookScript("OnLeave", function() GameTooltip:Hide() end)

    -- Last look before the secure action runs: aimed at the next slot that
    -- still holds a Disenchant item, or at nothing.
    button:SetScript("PreClick", function(frame)
        if InCombat() then return end
        local item = Disenchanting:Next()
        if not item then
            Clear(frame)
            ns.Print(L["nothing left to disenchant."])
            return
        end
        frame:SetAttribute("type", "spell")
        frame:SetAttribute("spell", Disenchanting.SPELL)
        frame:SetAttribute("target-bag", item.bag)
        frame:SetAttribute("target-slot", item.slot)
    end)

    -- Nothing is left aimed at a slot between clicks.
    button:SetScript("PostClick", function(frame)
        if not InCombat() then Clear(frame) end
    end)

    self.button = button
    return button
end

--- Words for the button and its tooltip, for what is under Disenchant now.
function Disenchanting:Words()
    local queue, total = self:Queue()
    local first = queue[1]
    local text = total > 0 and L.Format("Disenchant (%d left)", total) or L["Nothing to disenchant"]

    local lines = {}
    if first then
        lines[#lines + 1] = first.bought and L.Format("Next: %s, bought to disenchant.", first.name)
            or L.Format("Next: %s.", first.name)
    end
    lines[#lines + 1] = L["Each click casts Disenchant once, on the next item under Disenchant."]
    lines[#lines + 1] = L["Items you bought to disenchant go first. Never in combat."]
    return text, table.concat(lines, "\n"), total
end

--- Show it when there is something to disenchant here, left of `room`
--- (how wide the Sell or errand buttons at the foot are, 0 for none).
-- @return how wide it is when shown, else 0
function Disenchanting:Update(room)
    if self.fighting or InCombat() then return 0 end

    local window = ns.UI and ns.UI.frame
    local show = window and ns.UI:IsShown() and not ns.UI.dragging and ns.UI.view ~= "all"
        and self:Knows() == true
    local button = self.button
    if not show then
        if button then button:Hide() end
        return 0
    end

    local text, tip, total = self:Words()
    if total == 0 then
        if button then button:Hide() end
        return 0
    end

    button = self:Create()
    button:SetText(text)
    button.tooltipText = tip

    local right, bottom = window:GetRight(), window:GetBottom()
    if not (right and bottom) then
        button:Hide()
        return 0
    end
    -- Drawn at the window's size, so the button's own units are the
    -- window's, as the Sell button's are (Selling:Place).
    local scale = (window:GetEffectiveScale() or 1) / (UIParent:GetEffectiveScale() or 1)
    button:SetScale(scale)
    button:ClearAllPoints()
    local inset = ns.UI.SELL_INSET_X + ((room or 0) > 0 and room + GAP or 0)
    button:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMLEFT", right - inset, bottom + ns.UI.SELL_INSET_Y)
    button:Show()
    return button:GetWidth() or BUTTON_WIDTH
end

--------------------------------------------------------------------------------
-- Events
--------------------------------------------------------------------------------

function Disenchanting:OnEnable()
    -- Fires just before combat locks secure frames, so the button can still
    -- be hidden and its aim emptied.
    ns.RegisterEvent(self, "PLAYER_REGEN_DISABLED", function()
        Disenchanting.fighting = true
        local button = Disenchanting.button
        if button then
            button:Hide()
            Clear(button)
        end
        if ns.UI and ns.UI.FootRoom and ns.UI.frame then ns.UI:FootRoom() end
    end)
    ns.RegisterEvent(self, "PLAYER_REGEN_ENABLED", function()
        Disenchanting.fighting = false
        if ns.UI and ns.UI.FootRoom and ns.UI.frame then ns.UI:FootRoom() end
    end)
end
