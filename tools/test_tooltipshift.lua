-- Off, Shift or Always for Butler's two tooltip lines, Who has it and
-- Butler on tooltips (UI/TooltipShift.lua).
--
-- What must hold:
--   1. Nobody's settings change: on reads as Always, off as Off, and nothing
--      is written for a player who never picks.
--   2. On Shift, a line waits while Shift is up and shows while it is down.
--   3. "Hold Shift for more." goes on once, after Butler's verdict, which
--      stays the last of Butler's own lines.
--   4. A Shift press redraws the tooltip and the lines come back.
--   5. The Settings steppers write the same settings the tick boxes did.

local env = dofile(lfs_cwd .. "/tools/testenv.lua")
local suite = env.NewSuite("tooltipshift")

local ns = env.Load()
env.FakeBags({
    { bag = 0, slot = 1, id = 701, name = "Broken Fang", quality = 0, price = 125 },
})

local postCalls = {}
_G.Enum = { TooltipDataType = { Item = 0 } }
_G.TooltipDataProcessor = {
    AddTooltipPostCall = function(kind, fn) postCalls[#postCalls + 1] = { kind = kind, fn = fn } end,
}
local function Double(self, left, right) self._lines[#self._lines + 1] = left .. " | " .. right end
_G.GameTooltip.AddDoubleLine = Double
_G.BlackthornesTS = { Butler = { Holdings = function()
    return {
        { key = "Player-1", name = "Ana Stone", isCurrent = true, playing = true,
            bags = { [701] = 1 }, bank = {}, mail = {} },
        { key = "Player-2", name = "Bob Wither", bags = { [701] = 5 }, bank = {}, mail = {} },
    }
end } }

local shiftDown = false
_G.IsShiftKeyDown = function() return shiftDown end

env.Enable(ns)
env.Fire("PLAYER_ENTERING_WORLD")
local Shift = ns.TooltipShift
suite.check("both lines are hooked", #postCalls == 2 and ns.VerdictTip.installed == "post call")
suite.check("both keys are listed", Shift.KEYS[1] == "whoHas" and Shift.KEYS[2] == "verdictTip")

local button = env.Stub({ GetBagID = function() return 0 end, GetID = function() return 1 end })
local function Clear(tooltip)
    tooltip._lines = {}
    local cleared = tooltip:GetScript("OnTooltipCleared")
    if cleared then cleared(tooltip) end
end
local function Hover()
    Clear(GameTooltip)
    GameTooltip.GetOwner = function() return button end
    for _, call in ipairs(postCalls) do call.fn(GameTooltip, { id = 701 }) end
    return GameTooltip._lines
end
local HINT = "Hold Shift for more."
local function Find(lines, text)
    for i, line in ipairs(lines) do
        if tostring(line):find(text, 1, true) then return i end
    end
    return nil
end
local function Count(lines, text)
    local n = 0
    for _, line in ipairs(lines) do
        if line == text then n = n + 1 end
    end
    return n
end

-- 1.
suite.check("an on line reads as Always", Shift:Mode(ns.db.whoHas ~= false, "whoHas") == Shift.ALWAYS
    and Shift:Mode(ns.db.verdictTip ~= false, "verdictTip") == Shift.ALWAYS)
suite.check("an off line reads as Off", Shift:Mode(false, "whoHas") == Shift.OFF)
local lines = Hover()
suite.check("as before, both lines show and no hint", Find(lines, "Your characters have") and
    (lines[#lines] or ""):find("^Butler:") and Count(lines, HINT) == 0, table.concat(lines, " / "))

ns.HandleSlash("settings")
local controls = ns.SettingsUI.controls
suite.check("the steppers show Always", controls.whoHas:GetValue() == Shift.ALWAYS
    and controls.verdictTip:GetValue() == Shift.ALWAYS and controls.whoHas.text:GetText() == "Always")
suite.check("nothing is written for a player who never picks", ns.db.tooltipShift == nil)

-- 2 and 3. Who has it on Shift.
controls.whoHas.minus:GetScript("OnClick")(controls.whoHas.minus)
suite.check("one step down is Shift, and it is kept", ns.db.tooltipShift and ns.db.tooltipShift.whoHas == true
    and ns.db.whoHas == true and controls.whoHas.text:GetText() == "Shift")
lines = Hover()
suite.check("with Shift up Who has it waits", Find(lines, "Your characters have") == nil, table.concat(lines, " / "))
suite.check("the verdict still shows", Find(lines, "Butler: Sell") ~= nil)
suite.check("and the hint comes after it, once", lines[#lines] == HINT and Count(lines, HINT) == 1
    and Find(lines, "Butler: Sell") == #lines - 1, table.concat(lines, " / "))

-- Both on Shift: the hint still goes on once.
controls.verdictTip.minus:GetScript("OnClick")(controls.verdictTip.minus)
lines = Hover()
suite.check("both on Shift: only the hint", #lines == 1 and lines[1] == HINT, table.concat(lines, " / "))

-- 4. Shift goes down: the tooltip is drawn again, and the lines come back.
local refreshed = 0
GameTooltip.RefreshData = function()
    refreshed = refreshed + 1
    Hover()
end
GameTooltip:Show()
shiftDown = true
Shift.shared.OnModifier("RSHIFT")
lines = GameTooltip._lines
suite.check("Shift down redraws the tooltip", refreshed == 1)
suite.check("with both lines and no hint", Find(lines, "Your characters have")
    and (lines[#lines] or ""):find("^Butler: Sell") and Count(lines, HINT) == 0, table.concat(lines, " / "))
shiftDown = false

-- In the second after login, before the verdict's hook is in, Who has it
-- on Shift adds the hint itself.
ns.VerdictTip.installed = nil
controls.verdictTip.plus:GetScript("OnClick")(controls.verdictTip.plus)
Clear(GameTooltip)
postCalls[1].fn(GameTooltip, { id = 701 })
suite.check("without the verdict's hook, Who has it adds the hint", GameTooltip._lines[1] == HINT
    and #GameTooltip._lines == 1, table.concat(GameTooltip._lines, " / "))
ns.VerdictTip.installed = "post call"

-- 5. Off and back to Always.
controls.whoHas.minus:GetScript("OnClick")(controls.whoHas.minus)
suite.check("Off turns Who has it off", ns.db.whoHas == false and controls.whoHas.text:GetText() == "Off")
lines = Hover()
suite.check("and it shows nothing, no hint", Find(lines, "Your characters have") == nil and Count(lines, HINT) == 0)
controls.whoHas.plus:GetScript("OnClick")(controls.whoHas.plus)
controls.whoHas.plus:GetScript("OnClick")(controls.whoHas.plus)
suite.check("Always turns it on and forgets Shift", ns.db.whoHas == true and ns.db.tooltipShift.whoHas == nil)
refreshed = 0
Shift.shared.OnModifier("LSHIFT")
suite.check("with nothing on Shift, Shift redraws nothing", refreshed == 0)

-- The page shows what is saved; the commands are as they were.
ns.HandleSlash("whohas")
ns.SettingsUI:Refresh()
suite.check("/bbutler whohas still turns it off, and Settings shows Off", ns.db.whoHas == false
    and controls.whoHas:GetValue() == Shift.OFF)
ns.db.tooltipShift.verdictTip = true
ns.SettingsUI:Refresh()
suite.check("Refresh shows Shift from the save", controls.verdictTip:GetValue() == Shift.SHIFT)

suite.done()
