-- Butler's voice (the owner asked 2026-10-11): Moroes's "You rang?" when the
-- player opens the window and "Now, where was I?" when they close it.
--
-- What must hold:
--   1. Opened or closed by the player: the line plays, as dialogue.
--   2. Never while a vendor, mailbox, bank or other NPC is open, and never
--      when the window opens or closes by itself.
--   3. A line waits a few minutes before it is said again.
--   4. "Butler's voice" in Settings turns it off.

local env = dofile(lfs_cwd .. "/tools/testenv.lua")
local suite = env.NewSuite("voice")

local ns = env.Load()
local UI = ns.UI

-- As in the game: a new frame starts shown, and Hide on a shown frame runs
-- its OnHide (a player heard both lines on the first open, 2026-10-11).
local createFrame = _G.CreateFrame
_G.CreateFrame = function(...)
    local frame = createFrame(...)
    frame._shown = true
    function frame:Hide()
        local was = self._shown
        self._shown = false
        local onHide = self._scripts and self._scripts.OnHide
        if was and onHide then onHide(self) end
    end
    return frame
end

local played, now, npc = {}, 1000, false
_G.PlaySoundFile = function(id, channel) played[#played + 1] = { id = id, channel = channel } end
_G.GetTime = function() return now end
_G.UnitExists = function(unit) return unit == "npc" and npc end

local function Close() UI.frame:Hide() end
local function Last() return played[#played] end

-- 1.
UI:Toggle()
suite.check("opening it says \"You rang?\" and only that", #played == 1 and Last().id == 555818 and Last().channel == "Dialog",
    #played)
UI:Toggle()
suite.check("closing it says \"Now, where was I?\"", #played == 2 and Last().id == 555814)

-- 3.
now = now + 30
UI:Toggle()
Close()
suite.check("not again a moment later", #played == 2, #played)
now = now + UI.VOICE_GAP
UI:Toggle()
suite.check("again once a few minutes pass", #played == 3)
Close()
suite.check("both lines", #played == 4)

-- 2. A vendor opens the window and closes it: nothing.
now = now + UI.VOICE_GAP
ns.Selling.merchantOpen = true
UI:AtVendor()
suite.check("the window came up at the vendor", UI:IsShown())
suite.check("but said nothing over the vendor", #played == 4)
ns.Selling.merchantOpen = false
UI:LeftVendor()
suite.check("nor when it closed by itself", #played == 4)

-- Opened by hand at a vendor, or while talking to any NPC: nothing.
ns.Selling.merchantOpen = true
UI:Toggle()
Close()
suite.check("never at a vendor, even by hand", #played == 4)
ns.Selling.merchantOpen = false
npc = true
UI:Toggle()
Close()
suite.check("nor while any NPC is talking", #played == 4)
npc = false

-- A window that opens by itself (UI:Show) says nothing.
UI:Show()
suite.check("opening by itself says nothing", #played == 4)
Close()
suite.check("closed by hand, it answers", #played == 5)

-- 4.
now = now + UI.VOICE_GAP
ns.db.voice = false
UI:Toggle()
Close()
suite.check("the setting turns it off", #played == 5)
ns.db.voice = true

_G.PlaySoundFile, _G.GetTime, _G.UnitExists = nil, nil, nil
_G.CreateFrame = createFrame
suite.done()
