-- Butler's pages in the one Blackthornes window (UI/ButlerTabs.lua, the
-- owner said build it, 2026-10-30).
--
-- What must hold:
--   1. On unless unticked; unticked, the Butler window opens in its own
--      place.
--   2. Ticked, opening Butler opens the one window on Butler, with the
--      Butler window laid into its area, bare of its own rim and grip.
--   3. Settings opens in the same area; one tab up at a time.
--   4. The secure buttons still dock inside the Butler window.
--   Swapping addons on the rail keeps the one window up.
--   5. Closing the one window gives the pages back their own place.
--   6. "One Window:" on the General page writes every save.
--   9. Up on another addon at a vendor, the one window turns to Butler
--      when "Vendors" is ticked and the Butler Bar is off, every visit, and
--      goes back to that addon as the vendor closes.

local env = dofile(lfs_cwd .. "/tools/testenv.lua")
local suite = env.NewSuite("onewindow")

_G.BlackthornesWindow = nil
local ns = env.Load()
local UI, SettingsUI, Tabs, SW = ns.UI, ns.SettingsUI, ns.ButlerTabs, ns.SharedWindow

ns.MinimapButton.button = env.Stub()
ns.MinimapButton:JoinShared()
local hub = _G.BlackthornesWindow
suite.check("Butler joins with its pages", hub.entries.butler and hub.entries.butler.host == Tabs.host)
suite.check("the one window is Butler's own copy", Tabs.One() == SW)

-- 1.
ns.db.oneWindow = nil
suite.check("on unless unticked", SW.On())
ns.db.oneWindow = false
UI:Show("bags")
suite.check("off: the Butler window opens by itself", UI.frame:IsShown() and not Tabs:Hosted())
suite.check("in its own place", UI.frame:GetParent() ~= (hub.frame and hub.frame.area))
UI:Hide()

-- 2.
SW.SetOn(true)
UI:Show("bags")
local area = hub.frame and hub.frame.area
suite.check("on: the one window opens", hub.frame and hub.frame:IsShown())
suite.check("on Butler", hub.current == hub.entries.butler and ns.db.oneWindowPick == "butler")
suite.check("Butler's pages are in it", Tabs:Hosted() and UI.frame:GetParent() == area)
suite.check("the Butler window shows", UI.frame:IsShown())
suite.check("without its own rim", UI.trim and not UI.trim:IsShown())
suite.check("or its own size grip", UI.sizeGrip and not UI.sizeGrip:IsShown())

-- 3.
Tabs:Open("settings")
suite.check("Settings is in the same area", SettingsUI.frame:GetParent() == area and SettingsUI.frame:IsShown())
suite.check("and the bags stepped aside", not UI.frame:IsShown())
suite.check("one tab up", Tabs:Current() == "settings")

-- Show Descriptions makes the pages taller: the one window keeps its
-- height and the page scrolls (2026-11-18: a tall Settings page stretched
-- Butler off the bottom of the screen). Only Settings' width still counts.
-- On the client Settings fills the area, so its own size only says how big
-- the area is; the stand-in frame is made to answer the same way.
do
    local frame = SettingsUI.frame
    local getW, getH = frame.GetWidth, frame.GetHeight
    frame.GetWidth = function() return area:GetWidth() end
    frame.GetHeight = function() return area:GetHeight() end
    -- The stand-in area follows the one window, as the client's anchors do.
    local areaH = area.GetHeight
    area.GetHeight = function() return hub.frame:GetHeight() - 60 end
    hub.frame:SetHeight(SW.HEIGHT)
    Tabs:Grow()
    local oneBefore = hub.frame:GetHeight()
    suite.check("Butler's own height, well short of the screen", oneBefore < SW.Room(hub.frame), oneBefore)
    SettingsUI.pages:ShowDescriptions(true)
    local need = SettingsUI.pages.need
    suite.check("descriptions on: the pages say how tall they are", type(need) == "table" and need[2] > 0)
    suite.check("Settings asks only for its width", Tabs.needs.settings and Tabs.needs.settings[1] == need[1]
        and Tabs.needs.settings[2] == nil)
    suite.check("and the one window keeps its height", hub.frame:GetHeight() == oneBefore,
        oneBefore, hub.frame:GetHeight())
    suite.check("never taller than the screen", hub.frame:GetHeight() <= SW.Room(hub.frame))
    SettingsUI.pages:ShowDescriptions(false)
    frame.GetWidth, frame.GetHeight = getW, getH
    area.GetHeight = areaH
end
-- Gold goals gone: the room they took goes back, never below the one
-- window's own height (2026-11-16).
do
    local getH = area.GetHeight
    local _, base = SW.BaseSize()
    local _, needH = Tabs:Size()
    hub.frame:SetHeight(base + 300)
    area.GetHeight = function() return needH + 300 end
    Tabs:Grow()
    suite.check("a page that needs less gives the room back", hub.frame:GetHeight() == base)
    hub.frame:SetHeight(base + 300)
    area.GetHeight = function() return needH + 100 end
    Tabs:Grow()
    suite.check("only as much as it no longer needs", hub.frame:GetHeight() == base + 200)
    area.GetHeight = getH
    hub.frame:SetHeight(base)
end
-- Settings never asks for more than its two columns: the page names wrap
-- to a second line instead. Its long name row made Butler stretch the one
-- window wider than every other addon, past the screen in Russian
-- (2026-11-18).
do
    local twoColumns = 2 * SettingsUI.COLUMN_WIDTH + SettingsUI.COLUMN_GAP + 2 * SettingsUI.PADDING
    local needW = Tabs.needs.settings and Tabs.needs.settings[1]
    suite.check("Settings asks no wider than its two columns", needW and needW <= twoColumns, needW, twoColumns)
end
-- Wider than a page needs: the width goes back too, never below the one
-- window's own.
do
    local getW = area.GetWidth
    local base = SW.BaseSize()
    local needW = Tabs:Size()
    hub.frame:SetWidth(base + 300)
    area.GetWidth = function() return needW + 300 end
    Tabs:Grow()
    suite.check("a page that needs less width gives it back", hub.frame:GetWidth() == base, hub.frame:GetWidth(), base)
    area.GetWidth = getW
    hub.frame:SetWidth(base)
end
Tabs:Open("all")
suite.check("All Characters back in the area", UI.frame:IsShown() and UI.view == "all"
    and UI.frame:GetParent() == area)

-- 4.
local button = env.Stub()
suite.check("a secure button docks in the Butler window", UI:Dock(button) and button:GetParent() == UI.frame)
UI:Undock()
suite.check("and goes back to UIParent for a fight", button:GetParent() == UIParent)

-- A window built for the first time hides itself before it is laid in
-- (a player's report, 2026-10-30: picking another addon on the rail once
-- turned the one window into that addon's own window).
local fresh = { GetParent = function() return UIParent end }
Tabs:Closed(fresh)
suite.check("a window not yet laid in hiding keeps the one window", hub.frame:IsShown() and Tabs:Hosted())

-- Swapping to another addon on the rail hands Butler's pages back without
-- closing the one window, so Butler never falls back to its own window.
local entered, left = 0, 0
SW:Join({ key = "farmer", order = 1, name = "Farmer", db = function() return {} end,
    host = { enter = function() entered = entered + 1 end, leave = function() left = left + 1 end } })
SW.Pick("farmer")
suite.check("swapping keeps the one window up", hub.frame:IsShown() and hub.current == hub.entries.farmer)
suite.check("the other addon moved in", entered == 1)
suite.check("Butler's pages went home, hidden", not Tabs:Hosted() and UI.frame:GetParent() == UIParent
    and not UI.frame:IsShown() and not SettingsUI.frame:IsShown())
SW.Pick("butler")
suite.check("back on Butler in the same window", hub.frame:IsShown() and hub.current == hub.entries.butler
    and Tabs:Hosted() and left == 1)
suite.check("a Butler tab is in the area", (UI.frame:GetParent() == hub.frame.area and UI.frame:IsShown())
    or (SettingsUI.frame:GetParent() == hub.frame.area and SettingsUI.frame:IsShown()))
hub.entries.farmer = nil

-- 5.
ns.db.windowLeft, ns.db.windowTop = 300, 650
hub.frame:Hide()
local onHide = hub.frame:GetScript("OnHide")
if onHide then onHide(hub.frame) end
suite.check("closing it lets Butler go", not Tabs:Hosted() and hub.current == nil)
suite.check("the Butler window is back on its own", UI.frame:GetParent() == UIParent and not UI.frame:IsShown())
suite.check("with its rim", UI.trim:IsShown() and UI.sizeGrip:IsShown())
suite.check("Settings too", SettingsUI.frame:GetParent() == UIParent)
local width = Tabs:Size()
suite.check("at the shared size", UI.frame:GetWidth() == width, UI.frame:GetWidth(), width)

-- 6.
local other = {}
SW:Join({ key = "pets", order = 3, name = "Pets", db = function() return other end })
SettingsUI:Show()
suite.check("Settings opens in the one window", Tabs:Hosted() and SettingsUI.frame:GetParent() == hub.frame.area)
SettingsUI.controls.oneWindow:SetChecked(false)
SettingsUI:SetOneWindow(false)
local onHideAgain = hub.frame:GetScript("OnHide")
if onHideAgain then onHideAgain(hub.frame) end
suite.check("unticked in every save", ns.db.oneWindow == false and other.oneWindow == false)
SettingsUI:Show()
suite.check("Settings opens on its own again", not Tabs:Hosted() and SettingsUI.frame:GetParent() == UIParent
    and SettingsUI.frame:IsShown())
SettingsUI:SetOneWindow(true)
suite.check("ticked again in every save", ns.db.oneWindow == true and other.oneWindow == true)
suite.check("and Settings moves into the one window", Tabs:Hosted() and SettingsUI.frame:GetParent() == hub.frame.area)

-- 7. Window Position's Set Default while hosted leaves the window where it is
-- (a player's report, 2026-10-31: it pulled the page out of the one window).
rawset(SettingsUI.frame, "_point", nil)
ns.db.windowLeft, ns.db.windowTop = 5, 600
SettingsUI:ResetPositions()
suite.check("Set Default keeps Settings in the one window", Tabs:Hosted()
    and SettingsUI.frame:GetParent() == hub.frame.area and rawget(SettingsUI.frame, "_point") == nil)
suite.check("Set Default forgets Butler's own place", ns.db.windowLeft == nil and ns.db.windowTop == nil)

-- 8. At a vendor (a player saw the window open as a vendor closed,
-- 2026-11-01). The bags are read first, so the vendor may be gone by the
-- time Butler would come up: then it doesn't.
hub.frame:Hide()
local onHideVendor = hub.frame:GetScript("OnHide")
if onHideVendor then onHideVendor(hub.frame) end
ns.db.openAtVendor = true
ns.Selling.merchantOpen = false
UI:AtVendor()
suite.check("the vendor closed before the bags were read: Butler stays shut",
    not hub.frame:IsShown() and not Tabs:Hosted() and not UI.openedByVendor)
ns.Selling.merchantOpen = true
UI:AtVendor()
suite.check("at the vendor, Butler comes up in the one window", Tabs:Hosted() and UI.openedByVendor)
Tabs:Open("settings")
suite.check("Settings is the tab up", Tabs:Current() == "settings" and not UI.frame:IsShown())
ns.Selling.merchantOpen = false
UI:LeftVendor()
suite.check("leaving the vendor on Settings closes the one window too",
    not hub.frame:IsShown() and not UI.openedByVendor)
if onHideVendor then onHideVendor(hub.frame) end

-- 9. Up on another addon at a vendor (a player saw Farmer there instead of
-- Butler on the second visit, 2026-11-17).
SW:Join({ key = "farmer", order = 1, name = "Farmer", db = function() return {} end,
    host = { enter = function() end, leave = function() end } })
suite.check("Butler wants the vendor while Vendors is ticked",
    Tabs.host.wants("vendor") == true and not Tabs.host.wants("mail"))
-- Walking to the vendor takes a while (the game's clock).
local clock, getTime = 100, rawget(_G, "GetTime")
_G.GetTime = function() return clock end
SW.Open("farmer")
for visit = 1, 2 do
    clock = clock + 30
    ns.Selling.merchantOpen = true
    SW.Arrived("vendor")
    suite.check("visit " .. visit .. ": the one window turns to Butler",
        hub.current == hub.entries.butler and Tabs:Hosted())
    UI:AtVendor()
    suite.check("visit " .. visit .. ": Butler's own open changes nothing", hub.current == hub.entries.butler)
    ns.Selling.merchantOpen = false
    UI:LeftVendor()
    SW.Left("vendor")
    suite.check("visit " .. visit .. ": back on Farmer as the vendor closes",
        hub.frame:IsShown() and hub.current == hub.entries.farmer and not Tabs:Hosted())
end
ns.db.openAtVendor = false
clock = clock + 30
SW.Arrived("vendor")
suite.check("Vendors unticked: it stays on Farmer", hub.current == hub.entries.farmer)
SW.Left("vendor")
ns.db.openAtVendor = true
if ns.PlaceBar then
    local isOn = ns.PlaceBar.IsOn
    ns.PlaceBar.IsOn = function() return true end
    suite.check("the Butler Bar comes up instead: no turn", not Tabs.host.wants("vendor"))
    ns.PlaceBar.IsOn = isOn
end
hub.frame:Hide()
hub.entries.farmer = nil
_G.GetTime = getTime

_G.BlackthornesWindow = nil
suite.done()
