-- Blackthornes Butler -- UI/BagMarks.lua
-- Butler's marks on the game's own bag squares (the owner said build it,
-- 2026-11-16, from a mockup): the coin, letter, arrow and the rest that
-- Butler Bags draws (UI/BagWindow.lua's ShowMark), on the bags the game
-- draws, so a player who keeps the game's bags sees what Butler thinks.
--
--   * Off unless ticked ("Marks on Bags" beside "Bag Helpers:" on the
--     General page, `bagMarks`).
--   * Nothing of the game's is hidden, moved or changed: each mark is our
--     own texture on our own small frame laid over the square. The frames
--     are made out of combat only.
--   * A square is repainted only when its mark changed. Bag and verdict
--     bursts are coalesced, and nothing runs while no bag window is open
--     or while Butler Bags stands in for the game's.

local _, ns = ...

local BagMarks = ns.NewModule("BagMarks")

BagMarks.SETTLE = 0.15
BagMarks.SIZE = 14

-- [button] = our frame over it, and the kind it shows now.
BagMarks.overlays = setmetatable({}, { __mode = "k" })
BagMarks.kinds = setmetatable({}, { __mode = "k" })

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

local function InFight()
    local fn = rawget(_G, "InCombatLockdown")
    return type(fn) == "function" and fn() and true or false
end

function BagMarks:IsOn()
    return ns.db ~= nil and ns.db.bagMarks == true
end

function BagMarks:SetOn(on)
    if not ns.db then return end
    ns.db.bagMarks = on and true or false
    if on then
        self:InstallHooks()
        self:Changed()
    else
        self:HideAll()
    end
end

--- Every mark goes. The frames stay for next time.
function BagMarks:HideAll()
    self.looking = false
    for button, overlay in pairs(self.overlays) do
        if self.kinds[button] then
            self.kinds[button] = nil
            overlay.mark:Hide()
        end
    end
end

--- Our frame over a square, made once. Nil in a fight until one is over.
function BagMarks:Overlay(button)
    local overlay = self.overlays[button]
    if overlay then return overlay end
    if InFight() then return nil end
    local ok, frame = pcall(CreateFrame, "Frame", nil, button)
    if not ok or type(frame) ~= "table" then return nil end
    frame:SetAllPoints(button)
    frame:SetFrameLevel((tonumber(Ask(button, "GetFrameLevel")) or 1) + 3)
    if frame.EnableMouse then frame:EnableMouse(false) end
    local mark = frame:CreateTexture(nil, "OVERLAY")
    mark:SetSize(BagMarks.SIZE, BagMarks.SIZE)
    mark:SetPoint("TOPRIGHT", -1, -1)
    mark:Hide()
    frame.mark = mark
    self.overlays[button] = frame
    return frame
end

--- The mark a bag slot wears, or nil.
function BagMarks.KindFor(bag, slot)
    local entry = ns.Bags.slots[bag .. ":" .. slot]
    local marks = entry and ns.BagView:Marks(entry)
    if not marks then return nil end
    for _, kind in ipairs(ns.BagWindow.MARK_ORDER) do
        if marks[kind] then return kind end
    end
    return nil
end

--- Paint one square; a square whose mark did not change is left alone.
function BagMarks:PaintButton(button, kind)
    if self.kinds[button] == kind then return false end
    local overlay = self:Overlay(button)
    if not overlay then return false end
    self.kinds[button] = kind
    if kind then
        ns.BagWindow.ShowMark(overlay.mark, kind)
    else
        overlay.mark:Hide()
    end
    return true
end

--- Paint every square of the bag windows shown. Returns how many changed.
function BagMarks:Paint(frames)
    local changed = 0
    for _, frame in ipairs(frames) do
        for _, button in ipairs(ns.Trash:Buttons(frame)) do
            local bag = Ask(button, "GetBagID")
            if type(bag) ~= "number" then bag = Ask(Ask(button, "GetParent") or frame, "GetID") end
            local slot = Ask(button, "GetID")
            local kind
            if type(bag) == "number" and type(slot) == "number" then kind = BagMarks.KindFor(bag, slot) end
            if self:PaintButton(button, kind) then changed = changed + 1 end
        end
    end
    self.painted = changed
    return changed
end

--- The bags, the verdicts or the bag windows moved: once the burst is over.
function BagMarks:Changed()
    if not self:IsOn() or self.settling then return end
    self.settling = true
    C_Timer.After(self.SETTLE, function()
        BagMarks.settling = false
        BagMarks:Refresh()
    end)
end

function BagMarks:Refresh()
    if not self:IsOn() or not ns.Trash then return self:HideAll() end
    -- Butler Bags draws its own marks while it stands in for the game's.
    if ns.BagWindow and ns.BagWindow:Covering() then return self:HideAll() end
    local frames = ns.Trash:ShownFrames()
    if #frames == 0 then return self:HideAll() end
    self.looking = true
    ns.Verdicts:ForgetIfOld()
    ns.Bags:Fresh(function()
        if BagMarks.looking then BagMarks:Paint(ns.Trash:ShownFrames()) end
    end)
end

--- Hear the bag windows open, close and redraw: hooks only, once each.
function BagMarks:InstallHooks()
    if not ns.Trash then return end
    self.hooked = self.hooked or {}
    local hook = rawget(_G, "hooksecurefunc")
    for _, frame in ipairs(ns.Trash:Frames()) do
        if not self.hooked[frame] then
            self.hooked[frame] = true
            if type(hook) == "function" and type(Field(frame, "UpdateItems")) == "function" then
                pcall(hook, frame, "UpdateItems", function() BagMarks:Changed() end)
            end
            if type(Field(frame, "HookScript")) == "function" then
                pcall(frame.HookScript, frame, "OnShow", function() BagMarks:Changed() end)
                pcall(frame.HookScript, frame, "OnHide", function() BagMarks:Changed() end)
            end
        end
    end
end

function BagMarks:OnEnable()
    ns.RegisterEvent(self, "PLAYER_ENTERING_WORLD", function()
        if BagMarks:IsOn() then
            BagMarks:InstallHooks()
            BagMarks:Changed()
        end
    end)
    -- Squares first seen in a fight get their frames once it is over.
    ns.RegisterEvent(self, "PLAYER_REGEN_ENABLED", function() BagMarks:Changed() end)
end
