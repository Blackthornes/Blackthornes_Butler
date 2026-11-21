-- Butler keeps its size when a list in Settings grows long (the owner,
-- 2026-11-18: "Butler still stretches the window off the bottom of the
-- screen when it has a long list of items").
--
-- Every Butler tab shares one size (UI/ButlerTabs.lua). Settings used to
-- ask for the height of its fullest page, capped only at the screen less
-- 160, so a long Keep Across list (or a long rule list) made every tab
-- nearly as tall as the screen. In the one window that height went on top
-- of the window's own plate and buttons, and Butler's tabs hung off the
-- bottom of the screen. Now Settings keeps the Butler window's height and
-- its pages scroll; only its width still counts.
--
-- What must hold:
--   1. On its own: a long list in Settings leaves every tab's height alone.
--   2. In the one window: a long list leaves the one window's height alone.
--   3. No tab ever asks for more than the Butler window plus its gold goals.
--   4. In the one window, Butler's tabs hanging under it stay on screen.

local env = dofile(lfs_cwd .. "/tools/testenv.lua")
local suite = env.NewSuite("staysonscreen")

_G.BlackthornesWindow = nil
local ns = env.Load()
local UI, SettingsUI, Tabs, SW = ns.UI, ns.SettingsUI, ns.ButlerTabs, ns.SharedWindow

-- A 4K screen at a large interface scale: about 1000 units tall, as on the
-- owner's screenshot (the one window ran 895 of them).
_G.UIParent._height = 995

local MOST = Tabs.HEIGHT + ns.UI.GOALS_MAX_EXTRA

-- A long Keep Across list in Settings.
local function LongList()
    for i = 1, 60 do ns.KeepAcross:Set(3000 + i, 5) end
    SettingsUI:SyncKeepAcross()
end
local function NoList()
    for i = 1, 60 do ns.KeepAcross:Set(3000 + i, 0) end
    SettingsUI:SyncKeepAcross()
end

-- 1. On its own.
ns.db.oneWindow = false
UI:Show("bags")
Tabs:Open("settings")
suite.check("Settings is up on its own", SettingsUI.frame:IsShown() and not Tabs:Hosted())
local _, before = Tabs:Size()
local settingsBefore = SettingsUI.frame:GetHeight()
LongList()
suite.check("the list is long", SettingsUI.pages:TallestColumn() > 1000, SettingsUI.pages:TallestColumn())
local _, after = Tabs:Size()
suite.check("a long list leaves the shared height alone", after == before, before, after)
suite.check("Settings keeps its height", SettingsUI.frame:GetHeight() == settingsBefore,
    settingsBefore, SettingsUI.frame:GetHeight())
suite.check("never taller than Butler with its gold goals", after <= MOST, after, MOST)
Tabs:Open("bags")
suite.check("Your Bags keeps its height too", UI.frame:GetHeight() == before, UI.frame:GetHeight(), before)
-- Settings still says how wide it needs to be.
suite.check("Settings still asks for its width", Tabs.needs.settings and Tabs.needs.settings[1] ~= nil)
NoList()
UI:Hide()

-- 2. In the one window. The stand-in area follows the one window, less its
-- plate and buttons, as the client's anchors would.
ns.MinimapButton.button = env.Stub()
ns.MinimapButton:JoinShared()
local hub = _G.BlackthornesWindow
SW.SetOn(true)
UI:Show("bags")
local one = hub.frame
local area = one.area
local CHROME = 60
area.GetHeight = function() return one:GetHeight() - CHROME end
-- The one window's own clamp, kept so a test can read it back.
one.SetClampRectInsets = function(self, l, r, t, b) self._clamp = { l, r, t, b } end
one.GetClampRectInsets = function(self)
    local c = self._clamp or { 0, 0, 0, 0 }
    return c[1], c[2], c[3], c[4]
end
Tabs:Grow()
suite.check("Butler is in the one window", Tabs:Hosted() and UI.frame:GetParent() == area)
Tabs:Open("settings")
local oneBefore = one:GetHeight()
LongList()
Tabs:Grow()
suite.check("a long list leaves the one window's height alone", one:GetHeight() == oneBefore,
    oneBefore, one:GetHeight())
suite.check("the one window is far from the screen's height", one:GetHeight() <= MOST + CHROME,
    one:GetHeight(), MOST + CHROME)
Tabs:Open("bags")
Tabs:Grow()
suite.check("same height on Your Bags", one:GetHeight() == oneBefore, oneBefore, one:GetHeight())

-- 3. Nothing asks past the most, whatever a window says.
Tabs:Need("test", nil, 5000)
local _, asked = Tabs:Size()
suite.check("no tab grows past Butler with its gold goals", asked <= MOST, asked, MOST)
Tabs.needs.test = nil
Tabs:FitAll()

-- 4. The tabs hang under the one window; its clamp holds them on screen,
-- and goes back as Butler leaves.
local onHide = one:GetScript("OnHide")
one:Hide()
if onHide then onHide(one) end
suite.check("Butler left the one window", not Tabs:Hosted())
one._clamp = { -10, 10, 20, -8 }
UI:Show("bags")
suite.check("back in the one window", Tabs:Hosted())
local _, _, _, bottom = one:GetClampRectInsets()
suite.check("the one window keeps Butler's tabs on screen", bottom <= -Tabs.REACH, bottom)
one:Hide()
onHide = one:GetScript("OnHide")
if onHide then onHide(one) end
local l, r, t, b = one:GetClampRectInsets()
suite.check("and gives its own clamp back as Butler leaves", l == -10 and r == 10 and t == 20 and b == -8, l, r, t, b)

NoList()
suite.done()
