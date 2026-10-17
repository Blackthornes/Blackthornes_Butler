-- The Order page: the player can move Butler's rules and turn them off.
-- The usual order gives the usual verdicts, a moved rule changes what
-- Butler says, the guards hold in any order, bad saved orders are mended,
-- and the board's drag, Undo and Set Default save what they show.

local env = dofile(lfs_cwd .. "/tools/testenv.lua")
local suite = env.NewSuite("ruleorder")

local ns = env.Load()
env.FakeBags({
    { bag = 0, slot = 1, id = 801, name = "Ruined Pelt", quality = 0, price = 12 },
    { bag = 0, slot = 2, id = 802, name = "Tattered Belt", quality = 0, price = 20, class = 4, equipLoc = "INVTYPE_WAIST" },
})
env.Enable(ns)

local Verdicts, UI = ns.Verdicts, ns.UI

-- A Farmer goal wants the pelt; Equipment calls the belt an upgrade to wear now.
_G.BlackthornesFarmer = { Butler = { Advise = function(_, id)
    if id == 801 then return { goal = "Ruined Pelt", have = 1, target = 5, need = 4 } end
end } }
_G.BlackthornesEquipment = { Butler = { Advise = function(_, link)
    if tostring(link):find("802", 1, true) then return { upgrade = "now" } end
end } }

local function Find(name)
    UI:Hide()
    UI:Show()
    for _, group in ipairs(Verdicts:Groups()) do
        for _, row in ipairs(group.rows) do
            if row.name == name then return row end
        end
    end
end

local function Moved(id, before)
    local order = {}
    for _, have in ipairs(Verdicts.DEFAULT_ORDER) do
        if have ~= id then order[#order + 1] = have end
    end
    for i, have in ipairs(order) do
        if have == before then table.insert(order, i, id) return order end
    end
end

-- The usual order.
suite.check("starts in the usual order", Verdicts:IsDefaultOrder())
suite.check("nothing saved for the usual order", ns.db.ruleOrder == nil)
local pelt = Find("Ruined Pelt")
suite.check("usual order: the goal keeps a grey", pelt.verdict == "keep", pelt.verdict)
local belt = Find("Tattered Belt")
suite.check("usual order: an upgrade stays", belt.verdict == "keep", belt.verdict)

-- Greys asked before goals: the grey is sold.
Verdicts:SetOrder(Moved("greys", "goals"))
suite.check("a moved order is saved", type(ns.db.ruleOrder) == "table" and not Verdicts:IsDefaultOrder())
pelt = Find("Ruined Pelt")
suite.check("greys first: the grey sells", pelt.verdict == "sell", pelt.verdict)

-- But an upgrade to wear now is never sold, wherever greys sit.
Verdicts:SetOrder(Moved("greys", "keepList"))
belt = Find("Tattered Belt")
suite.check("greys at the top still keep an upgrade", belt.verdict ~= "sell", belt.verdict)

-- Back to the usual order, then the goals rule turned off.
Verdicts:SetDefault()
suite.check("Set Default clears the saved order", ns.db.ruleOrder == nil and Verdicts:IsDefaultOrder())
Verdicts:SetRuleOn("goals", false)
suite.check("a rule turned off is saved", ns.db.rulesOff and ns.db.rulesOff.goals == true)
suite.check("and reads as off", not Verdicts:RuleOn("goals"))
pelt = Find("Ruined Pelt")
suite.check("goals off: the grey sells", pelt.verdict == "sell", pelt.verdict)
Verdicts:SetRuleOn("goals", true)
suite.check("turned on again leaves nothing saved", ns.db.rulesOff == nil or next(ns.db.rulesOff) == nil)
suite.check("goals on: kept again", Find("Ruined Pelt").verdict == "keep")

-- A rule with its own switch writes that switch, not rulesOff.
Verdicts:SetRuleOn("altUpgrades", true)
suite.check("alt upgrades has its own switch", Verdicts:AltUpgradesOn())
Verdicts:SetRuleOn("altUpgrades", false)
suite.check("and turns it off", not Verdicts:AltUpgradesOn())
suite.check("rulesOff left alone", ns.db.rulesOff == nil or ns.db.rulesOff.altUpgrades == nil)

-- A bad saved order is mended: unknown and repeated ids go, missing ones
-- come back after the rule they follow in the usual order.
ns.db.ruleOrder = { "greys", "bogus", "greys", "keepList", 7 }
local order = Verdicts:Order()
suite.check("mended order is whole", #order == #Verdicts.DEFAULT_ORDER, #order)
local seen, clean = {}, true
for _, id in ipairs(order) do
    if seen[id] or not Verdicts.STEPS[id] then clean = false end
    seen[id] = true
end
suite.check("no repeats or unknown rules", clean)
local at = {}
for i, id in ipairs(order) do at[id] = i end
suite.check("the player's own picks keep their order", at.greys == 1 and at.greys < at.keepList,
    tostring(order[1]) .. " " .. tostring(order[2]))
suite.check("a missing rule after a moved one follows it", at.bankAlt == at.greys + 1)
suite.check("a missing rule follows its usual neighbour", at.mailList == at.bankList + 1)
suite.check("the saved table itself is untouched", ns.db.ruleOrder[2] == "bogus")
Verdicts:SetDefault()

-- The board: open the Order page and drag a rule.
local SettingsUI, RuleOrderUI = ns.SettingsUI, ns.RuleOrderUI
SettingsUI:Show()
suite.check("the board is built", RuleOrderUI.board ~= nil and RuleOrderUI.rows.greys ~= nil)
local board = RuleOrderUI.board
board._left, board._top = 0, 600

local cursor = { 0, 0 }
_G.GetCursorPosition = function() return cursor[1], cursor[2] end
local function Point(x, y) cursor[1], cursor[2] = x, 600 - y end

-- Pick up Greys (slot 20) and drop it on slot 1.
local row = RuleOrderUI.rows.greys
Point(row.x + 10, row.y + 10)
RuleOrderUI:PickUp(row)
local tx, ty = RuleOrderUI:SlotAt(1)
Point(tx + 10, ty + 10)
RuleOrderUI:Follow()
suite.check("the dragged row follows the cursor", math.abs(row.x - tx) < 1 and math.abs(row.y - ty) < 1)
suite.check("the others make room", RuleOrderUI.order[1] == "greys")
suite.check("nothing saved mid-drag", Verdicts:IsDefaultOrder())
RuleOrderUI:LetGo()
suite.check("letting go saves it", Verdicts:Order()[1] == "greys")
suite.check("and Butler follows it", Find("Ruined Pelt").verdict == "sell")

-- The rows ease into place over a few frames, then the board stops.
for _ = 1, 200 do
    if not RuleOrderUI:Step(0.016) then break end
end
suite.check("the rows land", not RuleOrderUI:Step(0.016))

RuleOrderUI:Undo()
suite.check("Undo Move puts it back", Verdicts:IsDefaultOrder())

RuleOrderUI:Toggle("petFood", false)
suite.check("the tick box turns a rule off", not Verdicts:RuleOn("petFood"))
RuleOrderUI:Undo()
suite.check("Undo turns it back on", Verdicts:RuleOn("petFood"))

Verdicts:SetOrder(Moved("sellList", "keepList"))
RuleOrderUI:Refresh()
suite.check("Set Default can be pressed", RuleOrderUI:CanSetDefault())
RuleOrderUI:SetDefault()
suite.check("Set Default puts the usual order back", Verdicts:IsDefaultOrder())

-- A drag the window closes on ends there.
Point(row.x + 10, row.y + 10)
RuleOrderUI:PickUp(RuleOrderUI.rows.goals)
board:GetScript("OnHide")()
suite.check("closing mid-drag lets go", RuleOrderUI.drag == nil)

-- /bbutler order default.
Verdicts:SetOrder(Moved("greys", "goals"))
SlashCmdList.BLACKTHORNESBUTLER("order default")
suite.check("the command puts the usual order back", Verdicts:IsDefaultOrder())
suite.check("and says so", env.ChatText():find("usual order again", 1, true) ~= nil)

_G.BlackthornesFarmer, _G.BlackthornesEquipment = nil, nil
suite.done()
