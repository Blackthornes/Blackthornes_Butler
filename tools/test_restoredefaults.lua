-- Butler Settings: Set Default (the owner said build it, 2026-11-23).
--
-- What matters: every saved value a Settings control writes goes back to how
-- it started, nothing else does (no data, no window spots, none of the ALL
-- ADDONS choices the five addons share), and it takes two clicks.

local env = dofile(lfs_cwd .. "/tools/testenv.lua")
local suite = env.NewSuite("restoredefaults")

local ns = env.Load()

local SettingsUI = ns.SettingsUI

for _, module in ipairs(ns.moduleOrder) do
    if module.OnEnable then module:OnEnable() end
end

SettingsUI:Show()
local controls = SettingsUI.controls

--------------------------------------------------------------------------------
-- Poke every control and see which saved keys it writes.
--------------------------------------------------------------------------------

local function Flat(value, depth)
    if type(value) ~= "table" then return tostring(value) end
    if (depth or 0) > 3 then return "{...}" end
    local keys = {}
    for key in pairs(value) do keys[#keys + 1] = tostring(key) end
    table.sort(keys)
    local out = {}
    for _, key in ipairs(keys) do
        out[#out + 1] = key .. "=" .. Flat(value[key], (depth or 0) + 1)
    end
    return "{" .. table.concat(out, ",") .. "}"
end

-- Account keys as they are, character keys as "char.<key>".
local function Snapshot()
    local copy = {}
    for key, value in pairs(ns.db) do copy[key] = Flat(value) end
    for key, value in pairs(ns.charDB or {}) do copy["char." .. tostring(key)] = Flat(value) end
    return copy
end

local function Changed(before)
    local after, keys = Snapshot(), {}
    for key, value in pairs(after) do
        if before[key] ~= value then keys[key] = true end
    end
    for key in pairs(before) do
        if after[key] == nil then keys[key] = true end
    end
    return keys
end

-- Buttons run commands (open a window, put a window back); only the boxes,
-- drop-downs and steppers hold a setting.
local function Poke(control)
    if type(control) ~= "table" then return false end
    if rawget(control, "Pick") and rawget(control, "options") then
        local now = control.GetValue and control:GetValue()
        for _, option in ipairs(control.options) do
            if option.value ~= now then control:Pick(option.value) return true end
        end
        return false
    end
    -- A stepper: one step along, or one back at the top.
    if rawget(control, "SetValue") and rawget(control, "GetValue") and not rawget(control, "options")
        and not rawget(control, "SetChecked") and not rawget(control, "Toggle") then
        local now = tonumber(control:GetValue()) or 0
        control:SetValue(now + 1)
        if tonumber(control:GetValue()) == now then control:SetValue(now - 1) end
        return true
    end
    if rawget(control, "SetChecked") and control.GetScript and control:GetScript("OnClick") then
        control:GetScript("OnClick")(control)
        return true
    end
    return false
end

local written = {}
local names = {}
for name in pairs(controls) do
    if name ~= "restoreDefaults" then names[#names + 1] = name end
end
table.sort(names)
-- Twice round: a box greyed out until another is ticked takes a click the
-- second time.
for _ = 1, 2 do for _, name in ipairs(names) do
    local before = Snapshot()
    local ok = pcall(Poke, controls[name])
    if ok then
        for key in pairs(Changed(before)) do
            written[key] = written[key] or name
        end
    end
end end

-- Written by a control but kept on purpose: the ALL ADDONS choices (shared
-- by all five), window spots moved by a size change, and data.
local KEPT = {
    textSize = true, windowStyle = true, windowEffects = true, effects = true,
    effectsLevel = true, muteSounds = true, muteSoundsAt = true, minimapButton = true,
    minimapButtonAt = true, oneWindow = true, oneWindowAt = true,
    oneWindowPick = true, lookChoices = true, sisterNote = true,
    point = true, relativePoint = true, x = true, y = true,
}

local listed = {}
for _, key in ipairs(SettingsUI.SETTING_KEYS) do listed[key] = true end
for _, key in ipairs(SettingsUI.CHAR_SETTING_KEYS or {}) do listed["char." .. key] = true end
local missing = {}
for key, name in pairs(written) do
    if not listed[key] and not KEPT[key] then missing[#missing + 1] = key .. " (" .. name .. ")" end
end
table.sort(missing)
suite.check("every key a Settings control writes is put back", #missing == 0, table.concat(missing, ", "))
for key in pairs(KEPT) do
    suite.check("a kept key is never put back: " .. key, not listed[key])
end

--------------------------------------------------------------------------------
-- Two clicks, then everything back, data and shared choices kept
--------------------------------------------------------------------------------

ns.db.textSize = "large"
ns.db.muteSounds = true
ns.db.someSavedData = { [123] = 4 }


local reloads = 0
_G.ReloadUI = function() reloads = reloads + 1 end

local button = controls.restoreDefaults
suite.check("the Set Default button is on the page", button ~= nil)
button:GetScript("OnClick")(button)
suite.check("the first click asks to confirm", button.armed == true and button.label:GetText() == "Confirm",
    button.label:GetText())
suite.check("and changes nothing yet", reloads == 0 and ns.db.settingsRestored == nil)

local function Skip(key) return listed[key] or key == "settingsRestored" end
local before = {}
for key, value in pairs(Snapshot()) do
    if not Skip(key) then before[key] = value end
end

button:GetScript("OnClick")(button)
for _, key in ipairs(SettingsUI.SETTING_KEYS) do
    if Flat(ns.db[key]) ~= Flat(ns.DEFAULTS[key]) then
        suite.check("back to how it started: " .. key, false, tostring(ns.db[key]))
    end
end
for _, key in ipairs(SettingsUI.CHAR_SETTING_KEYS or {}) do
    if Flat(ns.charDB[key]) ~= Flat((ns.CHAR_DEFAULTS or {})[key]) then
        suite.check("back to how it started: char." .. key, false, tostring(ns.charDB[key]))
    end
end
suite.check("the game reloads once", reloads == 1, reloads)
suite.check("the button is back to Set Default", button.armed == false
    and button.label:GetText() == "Set Default")


local changed = {}
local now = Snapshot()
for key, value in pairs(before) do
    if now[key] ~= value then changed[#changed + 1] = key end
end
for key in pairs(now) do
    if before[key] == nil and not Skip(key) then changed[#changed + 1] = key end
end
table.sort(changed)
suite.check("nothing else changed", #changed == 0, table.concat(changed, ", "))
suite.check("text size and Mute All Sounds stay", ns.db.textSize == "large" and ns.db.muteSounds == true)
suite.check("data stays", ns.db.someSavedData and ns.db.someSavedData[123] == 4)

-- After the reload: said once.
local said = {}
local print_ = ns.Print
ns.Print = function(text) said[#said + 1] = text end
SettingsUI:SayRestored()
SettingsUI:SayRestored()
ns.Print = print_
suite.check("chat says it once after the reload", #said == 1
    and said[1] == "Every Butler setting is back to how it started.", table.concat(said, " | "))
suite.check("and forgets it said so", ns.db.settingsRestored == nil)

suite.done()
