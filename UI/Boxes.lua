-- Blackthornes Butler -- UI/Boxes.lua
-- The small boxes (Buy More, Bags Full, Keep Across Characters) used to
-- share one spot, so two up at once sat on top of each other. Each signs up
-- here: it can be dragged, it remembers where it was dropped
-- (SharedWindow.KeepSpot, windowSpots[key]), and one that would open on
-- another opens beside it.
--
--   ns.Boxes.Add(frame, key)   -- once, as the box is built
--   ns.Boxes.Kept(key)         -- true once the player has dragged it
--   ns.Boxes.Settle(frame, key) -- after the box is placed and shown

local ADDON, ns = ...

local Boxes = {}
ns.Boxes = Boxes

Boxes.GAP = 10

local boxes = {}

function Boxes.Add(frame, key)
    if type(frame) ~= "table" or type(key) ~= "string" then return end
    for _, box in ipairs(boxes) do
        if box.frame == frame then return end
    end
    boxes[#boxes + 1] = { frame = frame, key = key }
    pcall(function()
        frame:SetMovable(true)
        frame:RegisterForDrag("LeftButton")
        frame:SetScript("OnDragStart", frame.StartMoving)
        frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    end)
    local shared = ns.SharedWindow
    if shared and shared.KeepSpot then shared.KeepSpot(frame, key) end
end

--- Has the player dropped this box somewhere? Then it opens there.
function Boxes.Kept(key)
    local spots = ns.db and ns.db.windowSpots
    local spot = type(spots) == "table" and spots[key]
    return type(spot) == "table" and type(spot.x) == "number" and type(spot.y) == "number"
end

-- A frame's edges in screen pixels, or nil while the client won't say.
local function Edges(frame)
    local ok, left, right, top, bottom, scale = pcall(function()
        return frame:GetLeft(), frame:GetRight(), frame:GetTop(), frame:GetBottom(), frame:GetEffectiveScale()
    end)
    if not ok then return nil end
    for _, value in ipairs({ left, right, top, bottom }) do
        if type(value) ~= "number" then return nil end
    end
    if type(scale) ~= "number" or scale <= 0 then scale = 1 end
    return { left = left * scale, right = right * scale, top = top * scale, bottom = bottom * scale, scale = scale }
end

local function Overlap(a, b)
    return a.left < b.right and b.left < a.right and a.bottom < b.top and b.bottom < a.top
end

local function ScreenWidth()
    local ok, right, scale = pcall(function() return UIParent:GetRight(), UIParent:GetEffectiveScale() end)
    if ok and type(right) == "number" then
        return right * (type(scale) == "number" and scale > 0 and scale or 1)
    end
    return nil
end

--- A box just placed by itself: if it sits on another box that is up, it
--- moves beside that one, to the right when there is room, else the left.
--- One the player has dragged stays where it was dropped.
function Boxes.Settle(frame, key)
    if Boxes.Kept(key) then return false end
    local mine = Edges(frame)
    if not mine then return false end
    for _, box in ipairs(boxes) do
        local other = box.frame
        local okShown, shown = pcall(other.IsShown, other)
        if other ~= frame and okShown and shown then
            local theirs = Edges(other)
            if theirs and Overlap(mine, theirs) then
                local width = mine.right - mine.left
                local screen = ScreenWidth()
                local left = theirs.right + Boxes.GAP
                if screen and left + width > screen and theirs.left - Boxes.GAP - width >= 0 then
                    left = theirs.left - Boxes.GAP - width
                end
                frame:ClearAllPoints()
                frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left / mine.scale, theirs.top / mine.scale)
                return true
            end
        end
    end
    return false
end
