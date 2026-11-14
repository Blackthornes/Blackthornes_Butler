-- The keyring with Butler Bags on (a player's report, 2026-11-14: the
-- keyring didn't open or show). Butler Bags doesn't show the keyring, so:
--   1. The game's window holding the keyring is never veiled.
--   2. A game bag window veiled as a bag and reused for the keyring gets
--      its veil lifted when it shows.
--   3. Opening the keyring never opens or closes Butler's window.
--   4. Other bags still go under the veil as before.

local env = dofile(lfs_cwd .. "/tools/testenv.lua")
local suite = env.NewSuite("bagkeyring")

local ns = env.Load()
env.FakeBags({})

_G.hooksecurefunc = function(a, b, c)
    local owner, name, fn = _G, a, b
    if type(a) == "table" then owner, name, fn = a, b, c end
    local before = owner[name]
    owner[name] = function(...)
        local result = before(...)
        fn(...)
        return result
    end
end
_G.ToggleBag = function() end
_G.ToggleAllBags = function() end

local KEYRING = -2
local bagFrame = env.Stub({ _shown = true, _id = 1 })
function bagFrame:GetID() return self._id end
local keyFrame = env.Stub({ _shown = false, _id = KEYRING })
function keyFrame:GetID() return self._id end
_G.ContainerFrame1 = bagFrame
_G.ContainerFrame2 = keyFrame

env.Enable(ns)

local queued = {}
_G.C_Timer.After = function(_, fn) queued[#queued + 1] = fn end
local function EndFrame()
    while #queued > 0 do
        local now = queued
        queued = {}
        for _, fn in ipairs(now) do fn() end
    end
end

local BagWindow = ns.BagWindow
suite.check("the keyring is bag -2", BagWindow.KeyringID() == KEYRING)
suite.check("a frame holding it is known", BagWindow.HoldsKeyring(keyFrame))
suite.check("a bag's frame is not", not BagWindow.HoldsKeyring(bagFrame))

ns.HandleSlash("bags on"); EndFrame()
suite.check("other bags go under the veil", ns.Veil:Covers(bagFrame))
BagWindow:Hide()

-- 1 and 3. Opening the keyring.
_G.ToggleBag(KEYRING)
keyFrame:Show()
local onShow = keyFrame:GetScript("OnShow")
if onShow then onShow(keyFrame) end
EndFrame()
suite.check("the keyring window is never veiled", not ns.Veil:Covers(keyFrame))
suite.check("and Butler's window stays closed", not BagWindow:IsShown())
BagWindow:CoverGame()
suite.check("covering again leaves the keyring alone", not ns.Veil:Covers(keyFrame))

_G.ToggleBag(0); EndFrame()
suite.check("another bag's toggle still opens Butler's window", BagWindow:IsShown())

-- 2. A bag window reused for the keyring.
suite.check("the bag window is veiled", ns.Veil:Covers(bagFrame))
bagFrame._id = KEYRING
local reshow = bagFrame:GetScript("OnShow")
if reshow then reshow(bagFrame) end
suite.check("shown again holding the keyring, its veil comes off", not ns.Veil:Covers(bagFrame))

ns.HandleSlash("bags off"); EndFrame()

_G.hooksecurefunc, _G.ToggleBag, _G.ToggleAllBags = nil, nil, nil
_G.ContainerFrame1, _G.ContainerFrame2 = nil, nil

suite.done()
