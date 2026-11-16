-- Butler's marks on the game's own bag squares (UI/BagMarks.lua): off
-- unless ticked, our own frames only, and a square is repainted only when
-- its mark changed.

local env = dofile(lfs_cwd .. "/tools/testenv.lua")
local suite = env.NewSuite("bagmarks")

local ns = env.Load()
env.FakeBags({
    { bag = 0, slot = 1, id = 701, name = "Broken Fang", quality = 0, price = 10 },
    { bag = 0, slot = 2, id = 702, name = "Ruined Pelt", quality = 0, price = 5 },
    { bag = 0, slot = 3, id = 300, name = "Linen Cloth", quality = 1, price = 13 },
})

local buttons = {}
for slot = 1, 4 do
    buttons[slot] = env.Stub({
        GetBagID = function() return 0 end,
        GetID = function() return slot end,
        IsVisible = function() return true end,
    })
end
local bagWindow = env.Stub({ _shown = false })
bagWindow.EnumerateValidItems = function()
    local i = 0
    return function()
        i = i + 1
        if buttons[i] then return i, buttons[i] end
    end
end
_G.NUM_CONTAINER_FRAMES = 0
_G.ContainerFrameCombinedBags = bagWindow

env.Enable(ns)
ns.db.bagWindow = false
local Marks = ns.BagMarks
env.Fire("PLAYER_ENTERING_WORLD")

local function MarkOn(slot)
    local overlay = Marks.overlays[buttons[slot]]
    return overlay ~= nil and overlay.mark:IsShown()
end

-- Off unless ticked.
suite.check("off unless ticked", Marks:IsOn() == false and ns.db.bagMarks == false)
bagWindow._shown = true
Marks:Refresh()
suite.check("off, nothing is laid on the game's squares", next(Marks.overlays) == nil)
suite.check("and the bags are not read for it", not Marks.looking)

-- On, with the game's bags open.
Marks:SetOn(true)
suite.check("on, junk wears the sell mark", MarkOn(1) and MarkOn(2))
suite.check("which is the vendor's coin", Marks.kinds[buttons[1]] == "vendor", tostring(Marks.kinds[buttons[1]]))
suite.check("cloth to keep wears none", not MarkOn(3))
suite.check("nor an empty square", not MarkOn(4))
suite.check("each mark is on our own frame over the square",
    Marks.overlays[buttons[1]]:GetParent() == buttons[1] and Marks.overlays[buttons[1]] ~= buttons[1])
suite.check("the bags count as looked at", ns.Bags:Wanted() == true)

-- Nothing moved: nothing is repainted.
suite.check("a second look repaints nothing", Marks:Paint({ bagWindow }) == 0)

-- One verdict moves: only that square is repainted.
-- (The verdicts tell the marks themselves.)
ns.Verdicts:SetChoice(701, "keep")
suite.check("a kept item loses its mark", not MarkOn(1))
suite.check("only that square was repainted", Marks.painted == 1, Marks.painted)
suite.check("the other keeps its mark", MarkOn(2))

-- The bag window shuts: the marks go and nothing looks any more.
bagWindow._shown = false
Marks:Refresh()
suite.check("with the bags shut nothing is marked", not MarkOn(2) and not Marks.looking)

-- Butler Bags standing in for the game's draws its own marks.
bagWindow._shown = true
Marks:Refresh()
suite.check("open again, marked again", MarkOn(2))
ns.db.bagWindow = true
Marks:Refresh()
suite.check("no marks while Butler Bags covers the game's", not MarkOn(2))
ns.db.bagWindow = false

-- In a fight no new frame is made on a square.
local lockdown = InCombatLockdown
InCombatLockdown = function() return true end
Marks.overlays[buttons[2]] = nil
Marks.kinds[buttons[2]] = nil
Marks:Refresh()
suite.check("no frame is made in a fight", Marks.overlays[buttons[2]] == nil)
InCombatLockdown = lockdown
env.Fire("PLAYER_REGEN_ENABLED")
suite.check("it comes once the fight is over", MarkOn(2))

-- Unticked: every mark goes.
Marks:SetOn(false)
suite.check("unticked, the marks go", not MarkOn(2) and ns.db.bagMarks == false)

-- The Settings tick.
ns.HandleSlash("settings")
local box = ns.SettingsUI.controls.bagMarks
suite.check("Settings has the tick, unticked", box ~= nil and not box:GetChecked())

suite.done()
