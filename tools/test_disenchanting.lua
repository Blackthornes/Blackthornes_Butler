-- Items bought to disenchant, and the Disenchant button.
--
-- What must hold:
--   1. An item Tradeskills marks bought to disenchant goes under Disenchant,
--      even when the auction house pays more, and heads that group.
--   2. A character that can't disenchant mails it to the enchanter; with no
--      enchanter it waits under Look at it. An upgrade still says Keep.
--   3. The Disenchant button aims at one slot just before the click, bought
--      items first, and only at rows judged Disenchant; nothing stays aimed.
--   4. Never in combat, and never without the spell.
--   5. The right-click menu marks and unmarks through Tradeskills.

local env = dofile(lfs_cwd .. "/tools/testenv.lua")
local suite = env.NewSuite("disenchanting")

local ns = env.Load()
env.FakeBags({
    { bag = 0, slot = 1, id = 502, name = "Ridge Cleaver", quality = 2, price = 400 },
    { bag = 0, slot = 2, id = 501, name = "Dire Wand", quality = 2, price = 300, count = 1 },
    { bag = 0, slot = 3, id = 501, name = "Dire Wand", quality = 2, price = 300, count = 1 },
    { bag = 0, slot = 4, id = 503, name = "Linen Cloth", quality = 1, price = 13, count = 20 },
})
env.Enable(ns)

local Verdicts, Disenchanting, UI = ns.Verdicts, ns.Disenchanting, ns.UI

local function Find(name)
    for _, group in ipairs(Verdicts:Groups()) do
        for _, row in ipairs(group.rows) do
            if row.name == name then return row end
        end
    end
end

local can, enchanter, upgrade = true, nil, false
local marked = { [501] = 2 }
local calls = {}
_G.BlackthornesTS = { Butler = {
    Advise = function(_, id)
        if id == 501 then
            return { auction = 50000, disenchant = 11000, canDisenchant = can, enchanter = enchanter,
                bought = marked[501] }
        end
        if id == 502 then
            return { auction = 100, disenchant = 8500, canDisenchant = can, enchanter = enchanter,
                bought = marked[502] }
        end
        if id == 503 then return { auction = 40 } end
    end,
    SetBoughtToDisenchant = function(_, id, on, count)
        calls[#calls + 1] = { id = id, on = on, count = count }
        marked[id] = on and count or nil
        return true
    end,
} }
_G.BlackthornesEquipment = { Butler = { Advise = function(_, link)
    local id = tonumber(tostring(link):match("item:(%d+)"))
    if upgrade and id == 501 then return { upgrade = "now", gain = 5 } end
end } }

_G.IsPlayerSpell = function(spell) return spell == 13262 end

UI:Show()
UI.frame.GetRight = function() return 800 end
UI.frame.GetBottom = function() return 200 end

-- 1. Bought: Disenchant, though the auction house pays more, and first.
local wand = Find("Dire Wand")
suite.check("bought to disenchant goes under Disenchant", wand.verdict == "disenchant", wand.verdict)
suite.check("whatever the auction house pays", wand.reason:find("Bought to disenchant") ~= nil, wand.reason)
suite.check("and the row knows it was bought", wand.bought == 2)
local group = Verdicts:Group("disenchant")
suite.check("bought heads the group", group.rows[1].name == "Dire Wand", group.rows[1].name)
suite.check("the cleaver is still disenchanted on its worth", Find("Ridge Cleaver").verdict == "disenchant")

-- 3. The button: shown, aimed just before the click, at the bought one.
ns.Selling:Update()
local button = Disenchanting.button
suite.check("the Disenchant button shows", button and button:IsShown())
suite.check("placed by screen position", button._point[2] == UIParent)
-- On the Disenchant line while it is on screen (the owner, 2026-10-12).
local realRows = UI.list.rows
local function Line(verdict, shown)
    return { data = { type = "header", group = { verdict = verdict } },
        IsShown = function() return shown ~= false end,
        GetRight = function() return 700 end, GetTop = function() return 300 end,
        GetBottom = function() return 270 end, GetEffectiveScale = function() return 1 end }
end
UI.list.rows = { Line("sell"), Line("disenchant") }
ns.Selling:Update()
suite.check("it sits on the Disenchant line", button:IsShown() and button._point[1] == "RIGHT"
    and button._point[4] == 700 - UI.LINE_BUTTON_RIGHT and button._point[5] == 285)
UI.list.rows = { Line("disenchant", false) }
ns.Selling:Update()
suite.check("its line out of sight, at the foot", button:IsShown() and button._point[1] == "BOTTOMRIGHT")
UI.list.rows = realRows
ns.Selling:Update()
suite.check("it counts what is left", button.label:GetText() == "Disenchant (3 left)", button.label:GetText())
suite.check("nothing aimed before a click", button:GetAttribute("target-bag") == nil)
button:GetScript("PreClick")(button)
suite.check("a click casts the spell", button:GetAttribute("type") == "spell"
    and button:GetAttribute("spell") == 13262)
suite.check("on the bought item first", button:GetAttribute("target-bag") == 0
    and button:GetAttribute("target-slot") == 2, button:GetAttribute("target-slot"))
button:GetScript("PostClick")(button)
suite.check("nothing left aimed after", button:GetAttribute("type") == nil
    and button:GetAttribute("target-slot") == nil)

-- A slot that changed under the button is skipped.
env.bags.bags[0][2] = { bag = 0, slot = 2, id = 503, name = "Linen Cloth", quality = 1, price = 13 }
button:GetScript("PreClick")(button)
suite.check("a slot holding something else now is skipped", button:GetAttribute("target-slot") == 3,
    button:GetAttribute("target-slot"))
button:GetScript("PostClick")(button)
env.bags.bags[0][2] = { bag = 0, slot = 2, id = 501, name = "Dire Wand", quality = 2, price = 300 }

-- White items are never offered.
for _, item in ipairs((Disenchanting:Queue())) do
    suite.check("only Disenchant rows are offered", item.itemID ~= 503)
end

-- 4. Combat hides it and empties its aim; it comes back after.
button:GetScript("PreClick")(button)
_G.InCombatLockdown = function() return true end
env.Fire("PLAYER_REGEN_DISABLED")
suite.check("hidden in combat", not button:IsShown())
suite.check("with nothing aimed", button:GetAttribute("type") == nil)
_G.InCombatLockdown = nil
env.Fire("PLAYER_REGEN_ENABLED")
suite.check("back after", button:IsShown())

-- Without the spell, no button.
_G.IsPlayerSpell = function() return false end
ns.Selling:Update()
suite.check("no button without Disenchant", not button:IsShown())

-- One check saying no while the spellbook says yes (Forever) still shows it.
_G.IsSpellKnown = function(spell) return spell == 13262 end
ns.Selling:Update()
suite.check("shown when the spellbook knows it", button:IsShown())
_G.IsSpellKnown = nil
_G.IsPlayerSpell = function(spell) return spell == 13262 end

-- 2. A character that can't: mail it to the enchanter, or wait.
can, enchanter = false, "Ana Stoneheart"
Verdicts:Changed(true)
wand = Find("Dire Wand")
suite.check("an alt that can't mails it to the enchanter", wand.verdict == "mail" and wand.mailTo == "Ana Stoneheart",
    wand.verdict)
suite.check("saying it was bought to disenchant", wand.reason == "Bought to disenchant: mail to Ana Stoneheart",
    wand.reason)
suite.check("and the button goes", not button:IsShown())
enchanter = nil
Verdicts:Changed(true)
suite.check("with no enchanter it waits under Look at it", Find("Dire Wand").verdict == "look")
can = true
upgrade = true
Verdicts:Changed(true)
suite.check("an upgrade still says Keep", Find("Dire Wand").verdict == "keep")
upgrade = false

-- 5. The menu marks and unmarks through Tradeskills.
Verdicts:Changed(true)
UI:ShowMenu(Find("Dire Wand"))
suite.check("the menu offers it", UI.menu.bought:IsShown())
suite.check("saying it is marked now", UI.menu.bought.label:GetText() == "Bought to disenchant (now)",
    UI.menu.bought.label:GetText())
UI.menu.bought:GetScript("OnClick")(UI.menu.bought)
suite.check("a click unmarks it", calls[#calls].id == 501 and calls[#calls].on == false)
suite.check("and it is judged again", Find("Dire Wand").bought == nil)
UI:ShowMenu(Find("Ridge Cleaver"))
suite.check("an unmarked one offers to mark", UI.menu.bought.label:GetText() == "Bought to disenchant")
UI.menu.bought:GetScript("OnClick")(UI.menu.bought)
suite.check("marking all that is carried", calls[#calls].id == 502 and calls[#calls].on == true
    and calls[#calls].count == 1)
suite.check("which is then bought", Find("Ridge Cleaver").bought == 1)

-- Without Tradeskills' mark call, the menu leaves it out.
_G.BlackthornesTS.Butler.SetBoughtToDisenchant = nil
UI:ShowMenu(Find("Ridge Cleaver"))
suite.check("no mark button without Tradeskills", not UI.menu.bought:IsShown())

UI:Hide()
_G.BlackthornesTS, _G.BlackthornesEquipment, _G.IsPlayerSpell = nil, nil, nil
suite.done()
