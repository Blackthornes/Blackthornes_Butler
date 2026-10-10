-- Blackthornes Butler -- UI/Minimap.lua
-- The minimap button.
--
-- Pets', which is Equipment's, which is Farmer's, which is Tradeskills', so
-- the five behave
-- the same: drag it round the ring, click it to open, right-click for
-- settings. The orbit radius comes from the minimap's real size rather than
-- an assumed one, because a fixed radius only clears the ring on a default
-- 140px minimap.
--
-- A left-click opens the Butler window, a right-click the settings.

local _, ns = ...

local MinimapButton = ns.NewModule("MinimapButton")

local Theme = ns.Theme

-- Further round than Tradeskills' 170 degrees, Farmer's 200, Equipment's
-- 230 and Pets' 260, so the five buttons do not start stacked on one another.
local DEFAULT_ANGLE = math.rad(290)
local ICON = [[Interface\Icons\INV_Misc_Bag_08]]

--- What a left-click does: the main window once there is one, the settings
--- page until then.
function MinimapButton:Open()
    if ns.UI and ns.UI.Toggle then
        ns.UI:Toggle()
    elseif ns.SettingsUI then
        ns.SettingsUI:Toggle()
    end
end

function MinimapButton:Build()
    if self.button or not Minimap then return self.button end

    local button = CreateFrame("Button", "BlackthornesButlerMinimapButton", Minimap)
    button:SetSize(31, 31)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetSize(20, 20)
    background:SetPoint("CENTER")
    background:SetColorTexture(Theme.Unpack("window"))

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetSize(18, 18)
    icon:SetPoint("CENTER")
    icon:SetTexture(ICON)
    icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)

    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetSize(53, 53)
    border:SetPoint("TOPLEFT")
    border:SetTexture([[Interface\Minimap\MiniMap-TrackingBorder]])

    -- The game's own round glow under the mouse, as every minimap button has.
    if button.SetHighlightTexture then
        pcall(button.SetHighlightTexture, button,
            [[Interface\Minimap\UI-Minimap-ZoomButton-Highlight]], "ADD")
    end

    -- The icon swells a little under the mouse and dips when pressed.
    local function IconSize(size)
        icon:SetSize(size, size)
    end
    button:SetScript("OnMouseDown", function() IconSize(16) end)
    button:SetScript("OnMouseUp", function()
        local target = 18 + 2 * ns.Motion:Value(button, "hover")
        ns.Motion:Run(button, "press", 0.2, function(p) IconSize(16 + (target - 16) * p) end,
            { ease = ns.Motion.EaseOutBack })
    end)

    local function GetOrbitRadius()
        local size = Minimap:GetWidth()
        if not size or size <= 0 then size = 140 end

        -- Centre the button on the ring, where other minimap buttons sit:
        -- 5 pixels past the map's edge. A saved minimapGap is kept but no
        -- longer read; its 16 pixels left the button floating off the ring.
        return (size / 2) + 5
    end

    local function UpdatePosition(angle)
        local radius = GetOrbitRadius()

        button:ClearAllPoints()
        button:SetPoint("CENTER", Minimap, "CENTER",
            math.cos(angle) * radius, math.sin(angle) * radius)
    end

    button.UpdatePosition = UpdatePosition
    UpdatePosition((ns.db and ns.db.minimapAngle) or DEFAULT_ANGLE)

    button:SetMovable(true)
    button:RegisterForDrag("LeftButton")

    button:SetScript("OnDragStart", function(self)
        self.dragging = true
        self:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local cx, cy = GetCursorPosition()
            -- The minimap's own scale: its centre is in its units, and a
            -- resized minimap is not at UIParent's.
            local scale = Minimap:GetEffectiveScale()

            local newAngle = math.atan2((cy / scale) - my, (cx / scale) - mx)
            UpdatePosition(newAngle)

            if ns.db then ns.db.minimapAngle = newAngle end
        end)
    end)

    button:SetScript("OnDragStop", function(self)
        self.dragging = false
        self:SetScript("OnUpdate", nil)
    end)

    button:SetScript("OnClick", function(_, mouseButton)
        if mouseButton == "RightButton" and ns.SettingsUI then
            ns.SettingsUI:Toggle()
        else
            MinimapButton:Open()
        end
    end)

    button:SetScript("OnEnter", function(self)
        ns.Motion:Blend(self, "hover", 1, 0.12, function(v) IconSize(18 + 2 * v) end)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("Blackthornes Butler")
        -- Which version is installed, so a player can say when reporting.
        GameTooltip:AddLine(ns.VersionLabel(), 0.5, 0.5, 0.5)

        if ns.UI and ns.UI.Toggle then
            GameTooltip:AddLine("Click to open", 0.7, 0.7, 0.7)
            GameTooltip:AddLine("Right-click for settings", 0.7, 0.7, 0.7)
        else
            GameTooltip:AddLine("Click for settings", 0.7, 0.7, 0.7)
        end
        GameTooltip:AddLine("Drag to move it round the minimap", 0.5, 0.5, 0.5)
        GameTooltip:Show()
    end)

    button:SetScript("OnLeave", function(self)
        ns.Motion:Blend(self, "hover", 0, 0.18, function(v) IconSize(18 + 2 * v) end)
        GameTooltip:Hide()
    end)

    self.button = button
    self.lastMinimapWidth = Minimap:GetWidth()

    self:ApplyVisibility()
    return button
end

--- Re-seat the button at its stored angle, using the current radius.
function MinimapButton:Reposition()
    local button = self.button
    if not button or not button.UpdatePosition then return end

    button.UpdatePosition((ns.db and ns.db.minimapAngle) or DEFAULT_ANGLE)
    self.lastMinimapWidth = Minimap and Minimap:GetWidth()
end

function MinimapButton:ApplyVisibility()
    local button = self.button
    if not button then return end

    if ns.db and ns.db.minimapHidden then
        button:Hide()
    else
        button:Show()
    end
end

--- Show or hide the button. Returns true when it ends up visible.
function MinimapButton:Toggle()
    if ns.db then
        ns.db.minimapHidden = not ns.db.minimapHidden
    end

    self:ApplyVisibility()
    return not (ns.db and ns.db.minimapHidden)
end

function MinimapButton:OnEnable()
    self:Build()

    -- The minimap's final size is not always settled at login, and other addons
    -- resize it afterwards, so re-seat the button once things have calmed down.
    if C_Timer and C_Timer.After then
        C_Timer.After(1, function() MinimapButton:Reposition() end)
    end

    -- Cheap enough to check, and catches a minimap resized at any point.
    if C_Timer and C_Timer.NewTicker then
        self.ticker = C_Timer.NewTicker(5, function()
            if Minimap and MinimapButton.lastMinimapWidth ~= Minimap:GetWidth() then
                MinimapButton:Reposition()
            end
        end)
    end
end

ns.RegisterCommand("minimap", "show or hide the minimap button", function()
    if MinimapButton:Toggle() then
        ns.Print("minimap button shown.")
    else
        ns.Print("minimap button hidden. /bbutler minimap brings it back.")
    end
end)
