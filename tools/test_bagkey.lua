-- The Butler Bags key: a key on the game's Key Bindings page, under
-- Blackthornes Butler, that opens and closes Butler's bag window on its own,
-- whether Use Butler Bags is on or off, so a player can keep another bag
-- addon on the game's bag key.
--
-- What must hold:
--   1. Bindings.xml names the key's button under the Blackthornes Butler
--      header, and both names are set for the Key Bindings page.
--   2. With Use Butler Bags off, the key opens and closes the window, and
--      the game's bags are never veiled, hooked or touched.
--   3. Nothing is built until a key is bound; once one is, the window is
--      readied before any fight and handed to the key's guarded line.
--   4. In a fight readying waits for the fight to end.
--   5. In a fight, once the game guards the window, addon code leaves it to
--      the guarded line; not guarded, the key still works.
--   6. With Use Butler Bags on, the key opens and closes it too.

local env = dofile(lfs_cwd .. "/tools/testenv.lua")
local suite = env.NewSuite("bagkey")

local ns = env.Load()
env.FakeBags({
    { bag = 0, slot = 1, id = 801, name = "Broken Fang", quality = 0, price = 12, count = 3 },
    { bag = 0, slot = 2, id = 802, name = "Linen Cloth", quality = 1, price = 13, count = 20, class = 7 },
})

local hooked = {}
_G.hooksecurefunc = function(name) hooked[#hooked + 1] = name end
_G.ToggleAllBags = function() end
_G.ContainerFrameCombinedBags = env.Stub({ _shown = true })
local bound = nil
_G.GetBindingKey = function(action)
    if action == "CLICK BlackthornesButlerBagsKey:LeftButton" then return bound end
    return nil
end

local BagWindow = ns.BagWindow
local key = _G.BlackthornesButlerBagsKey
local refs = {}
if key then key.SetFrameRef = function(_, name, frame) refs[name] = frame end end

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

local function Press()
    local click = key and key:GetScript("OnClick")
    if click then click(key, "LeftButton", false) end
    EndFrame()
end

-- 1. The Key Bindings page.
do
    local file = io.open(lfs_cwd .. "/Bindings.xml", "r")
    local text = file and file:read("*a") or ""
    if file then file:close() end
    suite.check("Bindings.xml names the key's button",
        text:find('name="CLICK BlackthornesButlerBagsKey:LeftButton"', 1, true) ~= nil)
    suite.check("under the Blackthornes Butler header",
        text:find('header="BLACKTHORNESBUTLER"', 1, true) ~= nil)
    suite.check("the header has its name", _G.BINDING_HEADER_BLACKTHORNESBUTLER == "Blackthornes Butler")
    suite.check("the key has its name",
        _G["BINDING_NAME_CLICK BlackthornesButlerBagsKey:LeftButton"] == "Butler Bags")
    suite.check("the TOC does not list it", (function()
        for _, path in ipairs(env.TocFiles()) do
            if path:find("Bindings") then return false end
        end
        return true
    end)())
    suite.check("the key's button is made as the addon loads", key ~= nil and BagWindow.key == key)
    suite.check("and is never shown", key ~= nil and not key:IsShown())
    local body = key and key:GetAttribute("_onclick") or ""
    suite.check("its guarded line runs only in a fight", body:find("PlayerInCombat", 1, true) ~= nil)
    suite.check("and only on a guarded window", body:find("IsProtected", 1, true) ~= nil)
end

-- 2. Off: the key works on its own and the game's bags are left alone.
suite.check("Use Butler Bags starts off", not BagWindow:On())
suite.check("with no key, nothing is built", BagWindow.frame == nil and not BagWindow.keyReady)
Press()
suite.check("the key opens the window while the box is off", BagWindow:IsShown())
suite.check("the box stays off", not BagWindow:On() and not ns.db.bagWindow)
suite.check("the game's bags are not veiled", not ns.Veil:Covers(_G.ContainerFrameCombinedBags))
suite.check("and are never hidden", _G.ContainerFrameCombinedBags:IsShown())
suite.check("the game's bag calls are not hooked", (function()
    for _, name in ipairs(hooked) do
        if type(name) == "string" and name:find("Bag") then return false end
    end
    return not BagWindow.hooked
end)())
suite.check("nothing says it covers the game's bags", not BagWindow:Covering())
Press()
suite.check("a second press closes it", not BagWindow:IsShown())
suite.check("the game's bags are still left alone", not ns.Veil:Covers(_G.ContainerFrameCombinedBags))

-- 3. A bound key readies the window and hands it to the guarded line.
suite.check("with no key bound, nothing is readied", not BagWindow.keyReady)
bound = "SHIFT-B"
_G.InCombatLockdown = function() return true end
env.Fire("UPDATE_BINDINGS")
EndFrame()
-- 4. In a fight it waits.
suite.check("in a fight readying waits", BagWindow.keyWaiting == true and not BagWindow.keyReady)
_G.InCombatLockdown = function() return false end
env.Fire("PLAYER_REGEN_ENABLED")
EndFrame()
suite.check("readied once the fight ends", BagWindow.keyReady == true and not BagWindow.keyWaiting)
suite.check("the guarded line knows the window", refs.bags ~= nil and refs.bags == BagWindow.frame)
suite.check("readying shows nothing", not BagWindow:IsShown())
suite.check("readying veils nothing", not ns.Veil:Covers(_G.ContainerFrameCombinedBags))

-- 5. In a fight.
do
    local frame = BagWindow.frame
    local calls = 0
    local realShow, realHide = frame.Show, frame.Hide
    frame.Show = function(f) calls = calls + 1; return realShow(f) end
    frame.Hide = function(f) calls = calls + 1; return realHide(f) end
    frame.IsProtected = function() return true end
    _G.InCombatLockdown = function() return true end
    Press()
    suite.check("guarded in a fight, addon code leaves it to the guarded line", calls == 0)

    frame.IsProtected = function() return false end
    Press()
    suite.check("not guarded, the key opens it in a fight", frame:IsShown())
    Press()
    suite.check("and closes it", not frame:IsShown())
    frame.Show, frame.Hide, frame.IsProtected = realShow, realHide, nil
    _G.InCombatLockdown = nil
end

-- 6. On: the key works too.
BagWindow:SetOn(true)
EndFrame()
Press()
suite.check("with the box on, the key opens it", BagWindow:IsShown())
suite.check("and the game's bags go under the veil", ns.Veil:Covers(_G.ContainerFrameCombinedBags))
Press()
suite.check("and closes it", not BagWindow:IsShown())
BagWindow:SetOn(false)
EndFrame()
suite.check("turned off again, the veil comes off", not ns.Veil:Covers(_G.ContainerFrameCombinedBags))

-- Suites share one Lua state.
_G.hooksecurefunc, _G.ToggleAllBags, _G.GetBindingKey = nil, nil, nil
_G.ContainerFrameCombinedBags = nil

suite.done()
