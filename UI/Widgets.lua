-- Blackthornes Butler -- UI/Widgets.lua
-- The controls the windows need: a button, a checkbox, a stepper and a search
-- box, with the small tweens that make them feel alive. Farmer's Widgets.lua,
-- trimmed to those, so the pages feel the same under the mouse.

local _, ns = ...

local Widgets = {}
ns.Widgets = Widgets

local Theme = ns.Theme

--------------------------------------------------------------------------------
-- Motion
--
-- Small tweens for the windows and controls: a button easing into its hover
-- colour, a window fading up as it opens. Off means every tween lands at its
-- end at once.
--
-- One OnUpdate on one small frame, shown only while something is moving, so
-- an idle window costs nothing per frame. A tween that errors is dropped
-- rather than raised: a hover colour must never break a click.
--------------------------------------------------------------------------------

local Motion = {}
ns.Motion = Motion

Motion.tweens = {}

--- "full", "subtle" or "off". Farmer has a setting for this; Butler has
--- nothing busy enough to need one yet, so it is always full.
function Motion.Level()
    return "full"
end

function Motion.EaseOut(p)
    return 1 - (1 - p) ^ 3
end

--- Overshoots a touch and settles, for things that should feel like they
--- landed.
function Motion.EaseOutBack(p)
    local c = 1.4
    return 1 + (c + 1) * (p - 1) ^ 3 + c * (p - 1) ^ 2
end

function Motion.Lerp(from, to, p)
    return from + (to - from) * p
end

--- Two palette colours mixed, `p` of the way from `a` to `b`.
function Motion.Mix(a, b, p, alphaA, alphaB)
    local r1, g1, b1, a1 = Theme.Unpack(a, alphaA)
    local r2, g2, b2, a2 = Theme.Unpack(b, alphaB)
    return r1 + (r2 - r1) * p, g1 + (g2 - g1) * p, b1 + (b2 - b1) * p, a1 + (a2 - a1) * p
end

function Motion:Driver()
    if self.driver then return self.driver end

    local driver = CreateFrame("Frame", nil, UIParent)
    driver:SetScript("OnUpdate", function(_, elapsed) Motion:Step(elapsed) end)
    driver:Hide()

    self.driver = driver
    return driver
end

local function Finish(tween)
    pcall(tween.apply, 1)
    if tween.done then pcall(tween.done) end
end

--- Run `apply(p)` with p going 0 to 1 over `duration` seconds.
--
-- `owner` and `slot` name the tween: a new one for the same owner and slot
-- replaces the old, so hovering on and off quickly never leaves two fighting.
-- opts: delay (seconds before it starts), done (called at the end), ease
-- (a function of p; EaseOut unless given, false for linear).
function Motion:Run(owner, slot, duration, apply, opts)
    opts = opts or {}

    self:Stop(owner, slot)

    local tween = { owner = owner, slot = slot, duration = duration or 0.2,
        apply = apply, done = opts.done, age = -(opts.delay or 0) }

    local ease = opts.ease
    if ease == nil then ease = Motion.EaseOut end
    tween.ease = ease or nil

    if self.Level() == "off" or tween.duration <= 0 then
        Finish(tween)
        return
    end

    -- Drawn at its start now, so nothing flashes at its end for a frame
    -- before the first step.
    pcall(apply, 0)

    self.tweens[#self.tweens + 1] = tween
    self:Driver():Show()
end

--- Stop a running tween where it is. `finish` lands it at its end first.
function Motion:Stop(owner, slot, finish)
    for index = #self.tweens, 1, -1 do
        local tween = self.tweens[index]
        if tween.owner == owner and (slot == nil or tween.slot == slot) then
            table.remove(self.tweens, index)
            if finish then Finish(tween) end
        end
    end
end

--- Whether a tween is running for this owner (and slot, when given).
function Motion:Running(owner, slot)
    for _, tween in ipairs(self.tweens) do
        if tween.owner == owner and (slot == nil or tween.slot == slot) then return true end
    end
    return false
end

--- Land every running tween at its end. For the tests, and for a window
--- being hidden mid-animation.
function Motion:FinishAll()
    local tweens = self.tweens
    self.tweens = {}
    for _, tween in ipairs(tweens) do Finish(tween) end
    if self.driver then self.driver:Hide() end
end

function Motion:Step(elapsed)
    elapsed = tonumber(elapsed) or 0

    local live = {}
    local tweens = self.tweens
    self.tweens = live

    for _, tween in ipairs(tweens) do
        tween.age = tween.age + elapsed

        if tween.age >= 0 then
            local p = math.min(1, tween.age / tween.duration)
            local eased = tween.ease and tween.ease(p) or p
            local ok = pcall(tween.apply, eased)

            if not ok or p >= 1 then
                if ok and tween.done then pcall(tween.done) end
            else
                live[#live + 1] = tween
            end
        else
            live[#live + 1] = tween
        end
    end

    -- Tweens started from inside an apply or done landed in `live` already.
    if #self.tweens == 0 and self.driver then self.driver:Hide() end
end

--- Ease a number kept on `owner` toward `target`, calling `apply(value)` as
--- it goes. Starts from wherever the last one left it, so a hover that is
--- undone halfway turns round smoothly instead of jumping.
function Motion:Blend(owner, slot, target, duration, apply)
    local from = self:Value(owner, slot)
    if from == target and not self:Running(owner, slot) then
        apply(target)
        return
    end

    self:Run(owner, slot, duration, function(p)
        local value = from + (target - from) * p
        self:SetValue(owner, slot, value)
        apply(value)
    end, { ease = false })
end

-- Blended values, kept here rather than as fields on the frames so they never
-- collide with a frame's own keys.
Motion.values = setmetatable({}, { __mode = "k" })

--- Where Blend last left `owner`'s `slot`: 0 until it has moved.
function Motion:Value(owner, slot)
    local values = self.values[owner]
    return values and values[slot] or 0
end

function Motion:SetValue(owner, slot, value)
    local values = self.values[owner]
    if not values then
        values = {}
        self.values[owner] = values
    end
    values[slot] = value
end

--- Fade a window up as it opens: from clear, and a few pixels low.
--
-- Only the alpha and one point's offset move, so the window's saved spot is
-- never touched: the last step puts back exactly the point it started with.
function Motion:Open(frame, rise)
    if not frame then return end

    local level = self.Level()
    if level == "off" then
        frame:SetAlpha(1)
        return
    end

    rise = level == "full" and (rise or 8) or 0

    local point, relativeTo, relativePoint, x, y = frame:GetPoint(1)
    local canMove = rise ~= 0 and point ~= nil and type(x) == "number" and type(y) == "number"

    self:Run(frame, "open", level == "full" and 0.2 or 0.12, function(p)
        frame:SetAlpha(p)
        if canMove then
            frame:SetPoint(point, relativeTo, relativePoint, x, y - rise * (1 - p))
        end
    end)
end

--------------------------------------------------------------------------------
-- Button
--------------------------------------------------------------------------------

local HOVER_TIME = 0.12

--- A button in the house style.
--
-- opts: width, height; primary (solid gold with dark lettering, for the one
-- button on a screen that does the main thing); danger (lights red under
-- the mouse, for a close button); labelKey (the label's resting colour);
-- baseColor ({ r, g, b, a }, a resting face of its own); name and template,
-- for a button built on one of the game's templates (a secure action button,
-- say, which must then be given no onClick).
--
-- Titanforged (2026-10-04, as Tradeskills'): every button is raised metal,
-- a dark face in a gold edge with a gold label, lit and glowing under the
-- mouse. The primary one is solid gold, so it stands out at a glance.
function Widgets.CreateButton(parent, text, onClick, opts)
    opts = opts or {}

    local button = CreateFrame("Button", opts.name, parent, opts.template)
    button:SetSize(opts.width or 80, opts.height or 22)

    -- Dark lettering only on a gold face: a primary button given its own
    -- dark face (opts.baseColor) keeps a gold label, or its text would be
    -- dark on dark and the button would read as an empty box.
    -- The Blizzard window style has no gold face: every button wears the
    -- game's red with a gold label (UI/BlizzardLook.lua). A client missing
    -- that art keeps the house face, so the label is picked to suit it.
    local Look = ns.BlizzardLook
    local blizzard = Look and Look.DressesButtons()
    local goldFace = opts.primary and not opts.baseColor and not blizzard

    local baseKey = goldFace and "accent" or "row"
    local hotFill = goldFace and "accentHi" or opts.danger and "rowHover" or "rowActive"
    local edgeKey = goldFace and "accentHi" or "metal"
    local hotEdge = (opts.danger and "loss") or "accentHi"
    local defaultLabel = goldFace and "ink" or "gilt"
    local defaultHot = goldFace and "ink" or { 1, 0.953, 0.784 }
    local labelKey = opts.labelKey or defaultLabel
    local labelHot = opts.labelKey or defaultHot

    button.background = Theme.Fill(button, baseKey)
    -- Kept on the button, so the Blizzard style leaves a face of its own be.
    button.baseColor = opts.baseColor
    if opts.baseColor then
        button.background:SetColorTexture(unpack(opts.baseColor))
    end
    Theme.Border(button, edgeKey)
    button.sheen = Theme.TopSheen(button, 0.10)
    if Theme.Bevel then button.bevel = { Theme.Bevel(button) } end

    -- Every button glows round its edge under the mouse; the primary one
    -- glows a little even at rest. A button with a face of its own keeps to
    -- its own look.
    local haloRest = goldFace and 0.12 or 0
    if Theme.Halo and not opts.baseColor then
        Theme.Halo(button, 5, haloRest, opts.danger and "loss" or "accent")
    end

    button.label = Theme.CreateLabel(button, "small", labelKey, "CENTER")
    button.label:SetPoint("CENTER")
    button.label:SetText(text)

    -- Never narrower than its text: the game's font runs wider than a width
    -- picked by eye.
    local function Fit(value)
        button:SetWidth(math.max(opts.width or 80, Theme.TextWidth("small", value) + 12))
    end
    Fit(text)

    --- A palette key or an { r, g, b } colour, as four numbers.
    local function Color(value)
        if type(value) == "table" then return value[1], value[2], value[3], value[4] or 1 end
        return Theme.Unpack(value)
    end

    local function Blend(a, b, p)
        local r1, g1, b1, a1 = Color(a)
        local r2, g2, b2, a2 = Color(b)
        return r1 + (r2 - r1) * p, g1 + (g2 - g1) * p, b1 + (b2 - b1) * p, a1 + (a2 - a1) * p
    end

    --- How lit the button is: 0 at rest, 1 under the mouse.
    local function Light(p)
        local face = opts.baseColor or baseKey
        local hot = opts.baseColor and "rowHover" or hotFill
        button.background:SetColorTexture(Blend(face, hot, p))

        local r, g, b, a = Motion.Mix(edgeKey, hotEdge, p)
        for _, edge in ipairs(button.borderTextures or {}) do
            edge:SetColorTexture(r, g, b, a)
        end

        if opts.danger then
            button.label:SetTextColor(Blend(labelKey, "loss", p))
        else
            button.label:SetTextColor(Blend(labelKey, labelHot, p))
        end

        if rawget(button, "haloTextures") then
            Theme.SetHalo(button, haloRest + (0.4 - haloRest) * p)
        end
    end
    button.Light = Light

    button:SetScript("OnEnter", function(self)
        Motion:Blend(self, "hover", 1, HOVER_TIME, Light)
    end)

    button:SetScript("OnLeave", function(self)
        Motion:Blend(self, "hover", 0, HOVER_TIME * 1.5, Light)
    end)

    -- The label dips a pixel while held, so a click feels pressed. Wherever
    -- the label was put (a caller may have moved it beside an icon), it
    -- goes back to exactly there.
    button:SetScript("OnMouseDown", function(self)
        -- Held, for the Blizzard style's pressed art.
        self.held = true
        local point, relativeTo, relativePoint, x, y = self.label:GetPoint(1)
        if not (point and type(x) == "number" and type(y) == "number") then return end

        self.restPoint = { point, relativeTo, relativePoint, x, y }
        self.label:SetPoint(point, relativeTo, relativePoint, x, y - 1)
    end)

    button:SetScript("OnMouseUp", function(self)
        self.held = nil
        local rest = rawget(self, "restPoint")
        if not rest then return end

        self.restPoint = nil
        self.label:SetPoint(rest[1], rest[2], rest[3], rest[4], rest[5])
    end)

    if onClick then
        button:SetScript("OnClick", function(self, mouseButton)
            onClick(self, mouseButton)
        end)
    end

    function button:SetText(value)
        self.label:SetText(value)
        Fit(value)
    end

    --- The label's resting colour, for a button whose text means something
    --- (an upgrade in green, say), which it keeps under the mouse. No key
    --- puts back the house colour.
    function button:SetLabelColor(key)
        labelKey = key or defaultLabel
        labelHot = key or defaultHot
        Light(Motion:Value(self, "hover"))
    end

    if blizzard then Look.Button(button) end

    return button
end

--------------------------------------------------------------------------------
-- Checkbox
--------------------------------------------------------------------------------

--- A square toggle with its label beside it. Ported from the tradeskills addon
--- so the two settings pages feel the same under the mouse.
function Widgets.CreateCheckbox(parent, text, onToggle, initial)
    local checkbox = CreateFrame("Button", nil, parent)
    checkbox:SetHeight(18)

    local box = CreateFrame("Frame", nil, checkbox)
    box:SetSize(14, 14)
    box:SetPoint("LEFT")
    -- A small dark well in a gold edge, glowing when ticked (Titanforged).
    box.background = Theme.Fill(box, "well")
    Theme.Border(box, "metal")
    if Theme.Halo then Theme.Halo(box, 4, 0) end

    local tick = box:CreateTexture(nil, "OVERLAY")
    tick:SetPoint("CENTER")
    tick:SetSize(8, 8)
    tick:SetColorTexture(Theme.Unpack("accentHi"))

    local label = Theme.CreateLabel(checkbox, "small", "text")
    label:SetPoint("LEFT", box, "RIGHT", 6, 0)
    label:SetText(text)

    checkbox.label = label
    checkbox.tick = tick
    -- Measured as the game draws it, so the label is never cut short.
    checkbox:SetWidth(math.max(Theme.TextWidth("small", text), label:GetStringWidth() or 60) + 24)
    checkbox.checked = initial and true or false
    checkbox.disabled = false

    --- The box's edge and glow: lit gold when ticked, gold under the mouse,
    --- dim metal otherwise.
    local function PaintBox(hovered)
        local checked = checkbox.checked
        tick:SetShown(checked)
        Theme.SetBorderColor(box, checked and "accentHi" or hovered and "accent" or "metal")
        if rawget(box, "haloTextures") then
            Theme.SetHalo(box, checked and not checkbox.disabled and 0.3 or hovered and 0.15 or 0)
        end
    end
    PaintBox(false)

    function checkbox:SetChecked(value)
        self.checked = value and true or false
        PaintBox(false)
    end

    function checkbox:GetChecked()
        return self.checked
    end

    --- A disabled box keeps showing its state but ignores clicks, for a
    --- setting this client cannot honour.
    function checkbox:SetDisabled(disabled)
        self.disabled = disabled and true or false
        label:SetTextColor(Theme.Unpack(self.disabled and "dim" or "text"))
        -- In the Blizzard style the house tick stays out of sight.
        if not rawget(self, "blizzard") then tick:SetAlpha(self.disabled and 0.4 or 1) end
        PaintBox(false)
    end

    checkbox:SetScript("OnClick", function(self)
        if self.disabled then return end
        self:SetChecked(not self.checked)

        -- Ticking pops the mark in from small, a touch past size and back.
        if self.checked then
            Motion:Run(self, "tick", 0.22, function(p)
                local size = math.max(1, 8 * p)
                tick:SetSize(size, size)
            end, { ease = Motion.EaseOutBack })
        end

        if onToggle then onToggle(self.checked) end
    end)

    checkbox:SetScript("OnEnter", function(self)
        if not self.disabled then
            label:SetTextColor(Theme.Unpack("accent"))
            PaintBox(true)
        end
    end)

    checkbox:SetScript("OnLeave", function(self)
        label:SetTextColor(Theme.Unpack(self.disabled and "dim" or "text"))
        PaintBox(false)
    end)

    if ns.BlizzardLook and ns.BlizzardLook.Checkbox(checkbox, box, tick) then
        checkbox.blizzard = true
    end

    return checkbox
end

--------------------------------------------------------------------------------
-- Stepper
--------------------------------------------------------------------------------

--- [-] value [+], for a number with a small sensible range such as a scale.
--
-- Chosen over a slider: a slider on this client needs a thumb texture and a
-- drag to land on a round number, and a stepper only ever holds values from
-- its own list of steps.
--
-- @param opts
--   min, max, step  the range, in the stored unit
--   format          function(value) -> text shown between the buttons
--   onChange        function(value)
function Widgets.CreateStepper(parent, opts)
    opts = opts or {}

    local stepper = CreateFrame("Frame", nil, parent)
    stepper:SetSize(118, 20)

    local minus = Widgets.CreateButton(stepper, "-", nil, { width = 22, height = 20 })
    minus:SetPoint("LEFT")

    local plus = Widgets.CreateButton(stepper, "+", nil, { width = 22, height = 20 })
    plus:SetPoint("RIGHT")

    local well = Theme.CreatePanel(stepper, "panel", "border")
    well:SetPoint("LEFT", minus, "RIGHT", 4, 0)
    well:SetPoint("RIGHT", plus, "LEFT", -4, 0)
    well:SetHeight(20)
    -- Sunk between its buttons (Titanforged).
    if Theme.Recess then Theme.Recess(well) end

    local text = Theme.CreateLabel(well, "small", "text", "CENTER")
    text:SetPoint("CENTER")

    stepper.minus = minus
    stepper.plus = plus
    stepper.text = text

    local step = opts.step or 1
    local low = opts.min or 0
    local high = opts.max or 100

    local function Clamp(value)
        -- Snapped to a whole number of steps, so repeated presses never drift
        -- to 0.8999999 and show a value that is not on the list.
        value = low + math.floor((value - low) / step + 0.5) * step
        return math.max(low, math.min(high, value))
    end

    function stepper:SetValue(value, silent)
        self.value = Clamp(tonumber(value) or low)
        text:SetText(opts.format and opts.format(self.value) or tostring(self.value))

        -- Dim at the end of the range; the house gold otherwise.
        minus:SetLabelColor(self.value <= low and "dim" or nil)
        plus:SetLabelColor(self.value >= high and "dim" or nil)

        if not silent and opts.onChange then opts.onChange(self.value) end
    end

    function stepper:GetValue()
        return self.value
    end

    local function Nudge(direction)
        local wanted = Clamp((stepper.value or low) + direction * step)
        if wanted ~= stepper.value then stepper:SetValue(wanted) end
    end

    minus:SetScript("OnClick", function() Nudge(-1) end)
    plus:SetScript("OnClick", function() Nudge(1) end)

    stepper:SetValue(opts.value or low, true)
    return stepper
end

--------------------------------------------------------------------------------
-- Search box
--
-- Farmer's, for Find a setting.
--------------------------------------------------------------------------------

--- Whether the mouse is on `frame` and the frame is on screen. Read in a
--- pcall, as every client value is; a client that cannot say answers no.
local function UnderMouse(frame)
    local ok, over = pcall(function() return frame:IsVisible() and frame:IsMouseOver() end)
    return ok and over and true or false
end

--- An edit box with placeholder text.
--
-- onChange fires on every keystroke so results follow typing; onAccept fires on
-- Enter. Escape clears focus rather than the text, because losing what you
-- typed on a mis-key is worse than an extra keystroke.
--
-- opts.plain leaves out the magnifier and the clear button, for a small box
-- that is not a search: the room they keep is most of a narrow box.
function Widgets.CreateSearchBox(parent, placeholder, onChange, onAccept, opts)
    opts = opts or {}
    local inset = opts.plain and 6 or 26

    local holder = Theme.CreatePanel(parent, "row", "border")
    holder:SetHeight(24)

    -- Sunk into the window, and glowing gold while it has the keyboard
    -- (Titanforged, as Tradeskills' search box).
    if Theme.Recess then Theme.Recess(holder) end
    if Theme.Halo then Theme.Halo(holder, 6, 0) end

    -- The game's own magnifier, so the box reads as search at a glance.
    local icon = holder:CreateTexture(nil, "ARTWORK")
    icon:SetSize(14, 14)
    icon:SetPoint("LEFT", 7, 0)
    icon:SetTexture([[Interface\Common\UI-Searchbox-Icon]])
    icon:SetVertexColor(Theme.Unpack("muted"))
    icon:SetShown(not opts.plain)
    holder.icon = icon

    local box = CreateFrame("EditBox", nil, holder)
    box:SetPoint("TOPLEFT", inset, 0)
    box:SetPoint("BOTTOMRIGHT", -inset, 0)
    box:SetAutoFocus(false)
    box:SetFont(Theme.FONT, Theme.sizes.normal, "")
    box:SetTextColor(Theme.Unpack("text"))
    box:SetMaxLetters(80)

    local hint = Theme.CreateLabel(holder, "normal", "dim")
    hint:SetPoint("LEFT", inset, 0)
    hint:SetText(placeholder or "")

    -- Clears what you typed in one click, and only shows when there is
    -- something to clear.
    local clear = CreateFrame("Button", nil, holder)
    clear:SetSize(20, 20)
    clear:SetPoint("RIGHT", -3, 0)
    local cross = Theme.CreateLabel(clear, "normal", "muted", "CENTER")
    cross:SetPoint("CENTER", 0, 0)
    cross:SetText("x")
    clear:Hide()
    holder.clear = clear

    local function UpdateHint()
        local empty = box:GetText() == ""
        hint:SetShown(empty)
        clear:SetShown(not empty and not opts.plain)
    end

    --- The edge and the magnifier, from how far the mouse and the keyboard
    --- have each eased in: the edge lifts under the mouse and turns gold
    --- while the box has the keyboard, and the keyboard's gold wins.
    local function Paint()
        local hover = Motion:Value(holder, "hover")
        local focus = Motion:Value(holder, "focus")

        local r1, g1, b1 = Motion.Mix("border", "borderLit", hover)
        local r2, g2, b2 = Theme.Unpack("accent")
        local r, g, b = r1 + (r2 - r1) * focus, g1 + (g2 - g1) * focus, b1 + (b2 - b1) * focus
        for _, edge in ipairs(holder.borderTextures or {}) do
            edge:SetColorTexture(r, g, b, 1 - 0.2 * focus)
        end
        if rawget(holder, "haloTextures") then Theme.SetHalo(holder, 0.3 * focus) end

        icon:SetVertexColor(Motion.Mix("muted", "accent", math.max(focus, hover * 0.4)))
    end

    --- The mouse came onto part of the box or left it. Lit while it is
    --- anywhere on the box: going from the margin onto the text, or onto
    --- the x, is a leave and an enter of their own.
    local function Hover()
        local over = UnderMouse(holder)
        Motion:Blend(holder, "hover", over and 1 or 0, over and 0.12 or 0.18, Paint)
    end

    holder:EnableMouse(true)
    holder:SetScript("OnEnter", Hover)
    holder:SetScript("OnLeave", Hover)
    box:SetScript("OnEnter", Hover)
    box:SetScript("OnLeave", Hover)
    -- The margin answers the mouse now, so a click there (on the
    -- magnifier, say) gives the box the keyboard rather than nothing.
    holder:SetScript("OnMouseDown", function() box:SetFocus() end)

    -- The x lifts to the text colour under the mouse, eased like the rest.
    local function LightCross(p)
        cross:SetTextColor(Motion.Mix("muted", "text", p))
    end
    clear:SetScript("OnEnter", function(self)
        Motion:Blend(self, "hover", 1, 0.12, LightCross)
        Hover()
    end)
    clear:SetScript("OnLeave", function(self)
        Motion:Blend(self, "hover", 0, 0.18, LightCross)
        Hover()
    end)

    -- Hidden under the mouse (its window closing, or the x going with the
    -- text it cleared), no leave may come: let go, or it shows again lit.
    local function LetGo(frame, apply)
        Motion:Stop(frame, "hover")
        Motion:SetValue(frame, "hover", 0)
        apply(0)
    end
    holder:SetScript("OnHide", function() LetGo(holder, Paint) end)
    clear:SetScript("OnHide", function() LetGo(clear, LightCross) end)

    box:SetScript("OnEditFocusGained", function()
        Motion:Blend(holder, "focus", 1, 0.15, Paint)
    end)

    box:SetScript("OnEditFocusLost", function()
        Motion:Blend(holder, "focus", 0, 0.2, Paint)
    end)

    box:SetScript("OnTextChanged", function(self, userInput)
        UpdateHint()
        if userInput and onChange then
            onChange(self:GetText())
        end
    end)

    box:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
        if onAccept then onAccept(self:GetText()) end
    end)

    box:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)

    clear:SetScript("OnClick", function()
        box:SetText("")
        UpdateHint()
        if onChange then onChange("") end
        box:SetFocus()
    end)

    holder.editBox = box

    function holder:SetText(value)
        box:SetText(value or "")
        UpdateHint()
    end

    function holder:GetText()
        return box:GetText()
    end

    function holder:SetFocus()
        box:SetFocus()
    end

    function holder:ClearFocus()
        box:ClearFocus()
    end

    UpdateHint()
    return holder
end
