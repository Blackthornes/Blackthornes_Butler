-- The Titanforged window frame (picked 2026-10-04), outside WoW.
-- Ported from Tradeskills' test of the same name.
--
-- What must hold:
--   1. A dressed window gets its rim, four corner gems turned to their
--      corners, the name on a plate wide enough for it, the portrait with
--      the emblem, and a close gem that closes.
--   2. Its art comes from this addon's own Media\Frame folder.
--   3. The light round the portrait runs once as the window opens and goes
--      out; with the effects off it never shows.
--   4. The glint runs along the top edge and comes round again while the
--      window shows, never with effects Subtle or Off, and stops when the
--      window hides.
--   5. Every kind of button keeps its label readable on its own face, at
--      rest and under the mouse. Tradeskills' first bug with this look was
--      dark lettering on a dark face: buttons that read as empty boxes.

local ns = {}

-- Tests share one Lua state, so the globals replaced here are put back.
local saved = { CreateFrame = CreateFrame, UIParent = UIParent, CreateColor = CreateColor,
    GameTooltip = GameTooltip }

local function Region(parent)
    local region = { shown = true, parent = parent, scripts = {}, points = {}, alpha = 1,
        width = 0, height = 0, events = {}, children = {} }

    region.Show = function(self)
        local was = self.shown
        self.shown = true
        if not was and self.scripts.OnShow then self.scripts.OnShow(self) end
    end
    region.Hide = function(self)
        local was = self.shown
        self.shown = false
        if was and self.scripts.OnHide then self.scripts.OnHide(self) end
    end
    region.SetShown = function(self, on) if on then self:Show() else self:Hide() end end
    region.IsShown = function(self) return self.shown end
    region.IsVisible = function(self) return self.shown end
    region.SetAlpha = function(self, a) self.alpha = a end
    region.GetAlpha = function(self) return self.alpha end
    region.SetWidth = function(self, w) self.width = w end
    region.SetHeight = function(self, h) self.height = h end
    region.GetWidth = function(self) return self.width end
    region.GetHeight = function(self) return self.height end
    region.SetSize = function(self, w, h) self.width, self.height = w, h end
    region.SetColorTexture = function(self, r, g, b, a) self.color = { r, g, b, a or 1 } end
    region.SetGradient = function(self, orientation, from, to)
        self.gradient = { orientation, from, to }
    end
    region.SetTextColor = function(self, r, g, b, a) self.textColor = { r, g, b, a } end
    region.SetText = function(self, text) self.text = text end
    region.GetText = function(self) return self.text end
    region.GetStringWidth = function(self) return #(self.text or "") * 6 end
    region.SetScript = function(self, name, fn) self.scripts[name] = fn end
    region.GetScript = function(self, name) return self.scripts[name] end
    region.HookScript = function(self, name, fn)
        local old = self.scripts[name]
        self.scripts[name] = function(...)
            if old then old(...) end
            fn(...)
        end
    end

    -- As the game does: the short forms fill in the parent and the same
    -- point, and setting a point the region already has moves that one.
    region.SetPoint = function(self, point, a, b, c, d)
        local relativeTo, relativePoint, x, y
        if a == nil or type(a) == "number" then
            relativeTo, relativePoint, x, y = self.parent, point, a or 0, b or 0
        elseif type(b) == "string" then
            relativeTo, relativePoint, x, y = a, b, c or 0, d or 0
        else
            relativeTo, relativePoint, x, y = a, point, b or 0, c or 0
        end

        local anchor = { point, relativeTo, relativePoint, x, y }
        for index, existing in ipairs(self.points) do
            if existing[1] == point then
                self.points[index] = anchor
                return
            end
        end
        self.points[#self.points + 1] = anchor
    end
    region.ClearAllPoints = function(self) self.points = {} end
    region.GetNumPoints = function(self) return #self.points end
    region.GetPoint = function(self, index)
        local p = self.points[index or 1]
        if not p then return nil end
        return p[1], p[2], p[3], p[4], p[5]
    end
    region.IsMouseOver = function(self) return self.mouseOver == true end
    region.RegisterEvent = function(self, event) self.events[event] = true end
    region.UnregisterEvent = function(self, event) self.events[event] = nil end
    region.CreateTexture = function(self) return Region(self) end
    region.CreateFontString = function(self) return Region(self) end
    region.GetParent = function(self) return self.parent end
    region.GetMinMaxValues = function(self) return self.min or 0, self.max or 0 end
    region.SetMinMaxValues = function(self, lo, hi) self.min, self.max = lo, hi end
    region.GetValue = function(self) return self.value or 0 end
    region.SetValue = function(self, v) self.value = v end
    region.SetTexture = function(self, path) self.texture = path end
    region.SetTexCoord = function(self, ...) self.coords = { ... } end
    region.SetRotation = function(self, radians) self.rotation = radians end
    region.SetBlendMode = function(self, mode) self.blend = mode end
    region.SetFrameLevel = function(self, level) self.level = level end
    region.GetFrameLevel = function(self) return self.level or 1 end

    -- Any other method does nothing. Fields read as nil, as on a real frame,
    -- so a button no one disabled is not taken for a disabled one.
    return setmetatable(region, { __index = function(_, key)
        if type(key) == "string" and key:match("^%u") then return function() end end
    end })
end

-- Frames remember their children, so a test can find the ones a widget keeps
-- to itself (a menu's entries).
CreateFrame = function(_, _, parent)
    local frame = Region(parent)
    if type(parent) == "table" and rawget(parent, "children") then
        parent.children[#parent.children + 1] = frame
    end
    return frame
end
UIParent = Region()
CreateColor = function(r, g, b, a) return { r = r, g = g, b = b, a = a } end
GameTooltip = Region()

local function Load(path)
    local chunk = assert(loadfile(lfs_cwd .. path))
    chunk("Blackthornes_Butler", ns)
end

Load("/UI/Theme.lua")
Load("/UI/Widgets.lua")
Load("/UI/Titanforged.lua")

local Theme, Widgets, Motion, Titanforged = ns.Theme, ns.Widgets, ns.Motion, ns.Titanforged

-- Pets has no Window effects setting yet; the tests set the level by hand.
local fullLevel = Motion.Level
local function SetLevel(level)
    Motion.Level = level and function() return level end or fullLevel
end

local passed, failed = 0, 0

local function check(label, got, want)
    local ok = got == want
    if ok then passed = passed + 1 else failed = failed + 1 end
    print(string.format("  %-58s %-10s %s", label, tostring(got), ok and "ok" or
        ("WRONG, wanted " .. tostring(want))))
end

print("")
print("dressing a window")

local window = Region()
window:SetSize(520, 360)
local closed = false
local trim = Titanforged:Dress(window, {
    title = "Blackthornes Butler", portrait = true,
    close = function() closed = true end,
})

check("the trim is kept on the window", window.titan, trim)
check("four corner gems", #trim.corners, 4)
check("from this addon's art", trim.corners[1].texture, [[Interface\AddOns\Blackthornes_Butler\Media\Frame\Corner]])
check("the top left one unturned", trim.corners[1].coords[1] == 0 and trim.corners[1].coords[2] == 1, true)
check("the top right one turned to face it", trim.corners[2].coords[1] == 1 and trim.corners[2].coords[2] == 0, true)
check("the bottom right one upside down too", trim.corners[3].coords[3] == 1 and trim.corners[3].coords[4] == 0, true)
check("the name on the plate", trim.plate.label.text, "Blackthornes Butler")
check("which is wide enough for it", trim.plate.width >= #"Blackthornes Butler" * 6 + 30, true)
check("sat on the top edge", trim.plate.points[1][3], "TOP")
check("a portrait", trim.portrait ~= nil, true)
check("its light starts out", trim.portrait.sweep.alpha, 0)
check("drawn added, as light", trim.portrait.sweep.blend, "ADD")
check("the trim sits above the window's contents", trim.level, 21)

trim.plate:SetTitle("A much longer name for the plate to hold")
check("a longer name widens the plate",
    trim.plate.width >= #"A much longer name for the plate to hold" * 6 + 30, true)
trim.plate:SetTitle("Blackthornes Butler")

trim.closeButton.scripts.OnClick(trim.closeButton)
check("the close gem closes", closed, true)
trim.closeButton.scripts.OnEnter(trim.closeButton)
Motion:Step(1)
check("and glows red under the mouse", trim.closeButton.glow.alpha > 0.7, true)
trim.closeButton.scripts.OnLeave(trim.closeButton)
Motion:Step(1)

local left, right, top = Titanforged.Reach(trim)
check("it reaches out past the top left for the portrait", left == 20 and top == 20, true)
check("and a little past the right for the gem", right > 3, true)

local plated = Titanforged:Dress(Region(), { title = "Blackthornes Butler", close = function() end })
check("a window can have the plate without the portrait", plated.portrait == nil and plated.plate ~= nil, true)
local _, _, platedTop = Titanforged.Reach(plated)
check("and then reaches up by half the plate", platedTop, 15)

local plain = Titanforged:Dress(Region())
check("a bare frame gets no plate", plain.plate, nil)
check("or portrait", plain.portrait, nil)
local pl, _, pt = Titanforged.Reach(plain)
check("so it reaches out only by its corners", pl == 3 and pt == 3, true)

print("")
print("opening")

Titanforged:Opened(window)
Motion:Step(0.1)
check("the light runs round the portrait", trim.portrait.sweep.alpha > 0, true)
check("turning as it goes", trim.portrait.sweep.rotation < 0, true)
Motion:Step(2)
check("and goes out when it has been round", trim.portrait.sweep.alpha, 0)

SetLevel("off")
Titanforged:Opened(window)
check("with effects off it never shows", trim.portrait.sweep.alpha, 0)
check("and nothing is left running", Motion:Running(trim.portrait.sweep), false)
SetLevel(nil)

print("")
print("the glint")

window.shown = true
Titanforged:StartGlint(window, 0)
Motion:Step(0.8)
check("it runs along the top edge", trim.glint.alpha > 0.5, true)
local _, _, _, x = trim.glint:GetPoint(1)
check("about halfway along at halfway", x > 150 and x < 400, true)
Motion:Step(1)
check("then it is gone", trim.glint.alpha, 0)
check("and another is on its way", Motion:Running(trim.glint, "glint"), true)

Titanforged:StopGlint(window)
check("hidden, the window stops it", Motion:Running(trim.glint, "glint"), false)

SetLevel("subtle")
Titanforged:StartGlint(window, 0)
check("with effects subtle there is none", Motion:Running(trim.glint, "glint"), false)
SetLevel(nil)

Titanforged:StartGlint(window, 0)
window.shown = false
Motion:Step(2)
check("one finishing on a hidden window sends no other", Motion:Running(trim.glint, "glint"), false)

print("")
print("buttons stay readable")

local function Same(color, key)
    local want = type(key) == "table" and key or Theme.colors[key]
    if not (color and want) then return false end
    for i = 1, 3 do
        if math.abs(color[i] - want[i]) > 0.01 then return false end
    end
    return true
end

local function Luminance(c)
    local function lin(v) v = v or 0; return v <= 0.03928 and v / 12.92 or ((v + 0.055) / 1.055) ^ 2.4 end
    return 0.2126 * lin(c[1]) + 0.7152 * lin(c[2]) + 0.0722 * lin(c[3])
end
local function Contrast(a, b)
    local la, lb = Luminance(a), Luminance(b)
    if la < lb then la, lb = lb, la end
    return (la + 0.05) / (lb + 0.05)
end

local kinds = {
    { "a plain button", {}, 4.5 },
    { "a primary button", { primary = true }, 4.5 },
    -- Red on dark metal reads as a warning first; it only needs to stand out.
    { "a danger button", { danger = true }, 3.5 },
    { "a primary button with its own dark face", { primary = true, baseColor = { 0.06, 0.07, 0.09, 1 } }, 4.5 },
    -- The Feed buttons: secure, built on the game's template, primary.
    { "a secure Feed button", { primary = true, template = "SecureActionButtonTemplate" }, 4.5 },
}
for _, kind in ipairs(kinds) do
    local b = Widgets.CreateButton(Region(), "Feed", nil, kind[2])
    check(kind[1] .. " is readable at rest",
        Contrast(b.label.textColor, b.background.color) >= kind[3], true)
    b.scripts.OnEnter(b)
    Motion:Step(1)
    check(kind[1] .. " is readable under the mouse",
        Contrast(b.label.textColor, b.background.color) >= kind[3], true)
    b.scripts.OnLeave(b)
    Motion:Step(1)
end

local primary = Widgets.CreateButton(Region(), "Feed", nil, { primary = true })
check("a primary button is solid gold", Same(primary.background.color, "accent"), true)
check("with dark lettering", Same(primary.label.textColor, "ink"), true)
check("and glows a little at rest", primary.haloTextures[1].shown, true)
primary.scripts.OnEnter(primary)
Motion:Step(1)
check("it lights up under the mouse", Same(primary.background.color, "accentHi"), true)
primary.scripts.OnLeave(primary)
Motion:Step(1)
check("and goes back to rest", Same(primary.background.color, "accent"), true)

local darkFace = Widgets.CreateButton(Region(), "Feed", nil, { primary = true, baseColor = { 0.06, 0.07, 0.09, 1 } })
check("a primary button with a dark face keeps a gold label", Same(darkFace.label.textColor, "gilt"), true)

local plainButton = Widgets.CreateButton(Region(), "Settings", nil, {})
check("a plain button wears a gold label", Same(plainButton.label.textColor, "gilt"), true)
check("in a dim metal edge", Same(plainButton.borderTextures[1].color, "metal"), true)
check("and no glow at rest", plainButton.haloTextures[1].shown, false)
plainButton.scripts.OnEnter(plainButton)
Motion:Step(1)
check("its edge lights gold under the mouse", Same(plainButton.borderTextures[1].color, "accentHi"), true)
check("and it glows", plainButton.haloTextures[1].shown, true)
plainButton:SetLabelColor("good")
check("a label given a colour keeps it under the mouse", Same(plainButton.label.textColor, "good"), true)
plainButton.scripts.OnLeave(plainButton)
Motion:Step(1)
plainButton:SetLabelColor(nil)
check("and no colour puts the gold back", Same(plainButton.label.textColor, "gilt"), true)

local stepper = Widgets.CreateStepper(Region(), { min = 1, max = 3, value = 1 })
check("a stepper at its lowest dims its minus", Same(stepper.minus.label.textColor, "dim"), true)
check("and leaves its plus gold", Same(stepper.plus.label.textColor, "gilt"), true)
stepper.minus.scripts.OnEnter(stepper.minus)
Motion:Step(1)
check("the dim minus stays dim under the mouse", Same(stepper.minus.label.textColor, "dim"), true)
stepper.minus.scripts.OnLeave(stepper.minus)
Motion:Step(1)
stepper.plus.scripts.OnClick(stepper.plus)
check("a step up still counts", stepper:GetValue(), 2)
check("and lights the minus again", Same(stepper.minus.label.textColor, "gilt"), true)

local box = Widgets.CreateCheckbox(Region(), "Show it", nil, false)
local boxFrame = box.children[1]
check("a checkbox rests in dim metal", Same(boxFrame.borderTextures[1].color, "metal"), true)
box.scripts.OnClick(box)
check("ticked, its edge lights gold", Same(boxFrame.borderTextures[1].color, "accentHi"), true)
check("and it glows", boxFrame.haloTextures[1].shown, true)

Motion:FinishAll()

for key, value in pairs(saved) do _G[key] = value end

print("")
print(("%d passed, %d failed"):format(passed, failed))
assert(failed == 0, "titanforged checks failed")
