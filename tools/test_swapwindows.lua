-- The swap gem on Butler's windows and the one window (UI/SharedWindow.lua
-- AddSwap and Swap, ButlerTabs' tab, show and hide; the owner said build
-- it, 2026-11-19).
--
-- What must hold:
--   1. The Butler window and Settings carry a join gem; the one window a
--      split gem.
--   2. Split from the one window on All Characters: the one window closes
--      and Butler opens on its own on All Characters; the One Window box
--      reads unticked.
--   3. Join from the own Settings window: the one window opens on Butler,
--      still on Settings, and the box reads ticked.

local env = dofile(lfs_cwd .. "/tools/testenv.lua")
local suite = env.NewSuite("swapwindows")

_G.BlackthornesWindow = nil
local ns = env.Load()
local UI, SettingsUI, Tabs, SW = ns.UI, ns.SettingsUI, ns.ButlerTabs, ns.SharedWindow

ns.MinimapButton.button = env.Stub()
ns.MinimapButton:JoinShared()
local hub = _G.BlackthornesWindow

-- The game runs a frame's OnHide as it hides; the fake game does not.
local function HidesLikeTheGame(frame)
    local hide = frame.Hide
    frame.Hide = function(self)
        local was = self:IsShown()
        hide(self)
        local onHide = was and self:GetScript("OnHide")
        if onHide then onHide(self) end
    end
end

local function Gem(frame) return frame and rawget(frame, "blackthornesSwap") end

-- 1.
SW.SetOn(true)
Tabs:Open("all")
HidesLikeTheGame(hub.frame)
local oneGem = Gem(hub.frame)
suite.check("the one window has the split gem", oneGem and rawget(oneGem, "join") == false)
SettingsUI:Build()
for _, window in ipairs({ UI, SettingsUI }) do
    local gem = Gem(window.frame)
    suite.check("each window has the join gem", gem and rawget(gem, "join") == true
        and rawget(gem, "swapKey") == "butler")
end
suite.check("on All Characters in the one window", Tabs:Hosted() and Tabs:Current() == "all")

-- 2.
oneGem:GetScript("OnClick")(oneGem)
suite.check("split: the choice is off", not SW.On() and ns.db.oneWindow == false)
suite.check("the one window closed", not hub.frame:IsShown())
suite.check("Butler opens on its own", not Tabs:Hosted() and UI.frame:IsShown()
    and UI.frame:GetParent() ~= hub.frame.area)
suite.check("on the same tab", Tabs:Current() == "all")
Tabs:Open("settings")
SettingsUI:Refresh()
suite.check("the One Window box reads unticked", SettingsUI.controls.oneWindow:GetChecked() == false)

-- 3.
suite.check("Settings is up on its own", Tabs:Current() == "settings" and not Tabs:Hosted())
local settingsGem = Gem(SettingsUI.frame)
settingsGem:GetScript("OnClick")(settingsGem)
suite.check("join: the choice is on", SW.On() and ns.db.oneWindow == true)
suite.check("the one window opens on Butler", hub.frame:IsShown() and hub.current == hub.entries.butler)
suite.check("still on Settings, inside it", Tabs:Hosted() and Tabs:Current() == "settings"
    and SettingsUI.frame:GetParent() == hub.frame.area)
SettingsUI:Refresh()
suite.check("the One Window box reads ticked", SettingsUI.controls.oneWindow:GetChecked() == true)

SW.SetOn(false)
_G.BlackthornesWindow = nil
suite.done()
