-- Set Up Butler (UI/QuickSetup.lua): three choices on first open
-- (the owner said build it, 2026-11-26, from a mockup). What must hold:
--   1. On a new account the card comes up the first time Butler opens,
--      and never again, even when Later or Confirm was not pressed.
--   2. It starts from what is saved, so Confirm with nothing touched
--      changes nothing.
--   3. Confirm writes the bank alt, Tradeskills' disenchanter, Open Butler
--      At and the Butler bar; Later writes nothing.
--   4. A player who set any of the choices before never sees it.
--   5. Never the character playing; never in a fight.
--   6. Without a Tradeskills that takes the name, the disenchanter has
--      nothing to pick and nothing is sent.

local env = dofile(lfs_cwd .. "/tools/testenv.lua")
local suite = env.NewSuite("quicksetup")

local typed
local function FakeTradeskills()
    typed = nil
    _G.BlackthornesTS = { Butler = {
        Advise = function() return nil end,
        Disenchanter = function() return typed end,
        SetDisenchanter = function(_, name) typed = name return true end,
    } }
end

local function Fresh()
    FakeTradeskills()
    local ns = env.Load()
    env.Enable(ns)
    ns.db.quickSetupShown = nil
    ns.Errands.Characters = function() return { "Ana Stone", "Mira Vale" } end
    local realIsMe = ns.Errands.IsMe
    ns.Errands.IsMe = function(self, name) return name == "Bo Reed" or realIsMe(self, name) end
    return ns
end

-- 1.
local ns = Fresh()
local Setup, UI = ns.QuickSetup, ns.UI
suite.check("wanted on a new account", Setup:Wanted())
UI:Show()
suite.check("comes up when Butler opens", Setup:IsShown())
suite.check("marked as shown at once", ns.db.quickSetupShown == true)
Setup:Hide()
UI:Hide()
UI:Show()
suite.check("never comes back", not Setup:IsShown())

-- 2.
ns = Fresh()
Setup = ns.QuickSetup
Setup:Show()
suite.check("bank alt starts at None", Setup.bankAlt:GetValue() == "")
suite.check("lists None and the characters", #Setup.bankAlt.options == 3
    and Setup.bankAlt.options[2].text == "Ana Stone")
suite.check("places start as saved", Setup.atVendor:GetChecked() and Setup.atMailbox:GetChecked()
    and Setup.atBank:GetChecked() and not Setup.bar:GetChecked())
Setup:Confirm()
suite.check("nothing touched: no bank alt", ns.db.bankAlt == nil)
suite.check("nothing touched: no disenchanter", typed == nil)
suite.check("nothing touched: places as they were", ns.db.openAtVendor == true
    and ns.db.openAtMailbox == true and ns.db.openAtBank == true and ns.db.placeBar == false)
suite.check("Confirm closes it", not Setup:IsShown())

-- 3.
ns = Fresh()
Setup = ns.QuickSetup
Setup:Show()
Setup.bankAlt:SetValue("Ana Stone")
Setup.disenchanter:SetValue("Mira Vale")
Setup.atBank:SetChecked(false)
Setup.bar:SetChecked(true)
Setup:Confirm()
suite.check("bank alt written", ns.db.bankAlt == "Ana Stone", tostring(ns.db.bankAlt))
suite.check("disenchanter sent to Tradeskills", typed == "Mira Vale", tostring(typed))
suite.check("bank unticked", ns.db.openAtBank == false and ns.db.openAtVendor == true)
suite.check("the bar ticked", ns.db.placeBar == true)

ns = Fresh()
Setup = ns.QuickSetup
Setup:Show()
Setup.bankAlt:SetValue("Ana Stone")
Setup.bar:SetChecked(true)
Setup:Later()
suite.check("Later writes nothing", ns.db.bankAlt == nil and ns.db.placeBar == false)
suite.check("Later closes it for good", not Setup:IsShown() and ns.db.quickSetupShown == true)

-- 4.
ns = Fresh()
ns.db.bankAlt = "Ana Stone"
suite.check("a bank alt set: not wanted", not ns.QuickSetup:Wanted())
ns = Fresh()
ns.db.bankAltKindTo = { cloth = "Mira Vale" }
suite.check("a kind sent to someone: not wanted", not ns.QuickSetup:Wanted())
ns = Fresh()
ns.db.openAtMailbox = false
suite.check("a place unticked: not wanted", not ns.QuickSetup:Wanted())
ns = Fresh()
ns.db.placeBar = true
suite.check("the bar ticked: not wanted", not ns.QuickSetup:Wanted())
ns = Fresh()
typed = "Mira Vale"
suite.check("a disenchanter typed in Tradeskills: not wanted", not ns.QuickSetup:Wanted())
ns.UI:Show()
suite.check("and it does not come up", not ns.QuickSetup:IsShown())

-- 5.
ns = Fresh()
Setup = ns.QuickSetup
Setup:Show()
Setup.bankAlt.options[#Setup.bankAlt.options + 1] = { text = "Bo Reed", value = "Bo Reed" }
Setup.bankAlt:SetValue("Bo Reed")
Setup.disenchanter:SetValue("Bo Reed")
Setup:Confirm()
suite.check("the one playing is never the bank alt", ns.db.bankAlt == nil)
suite.check("nor the disenchanter", typed == nil)

ns = Fresh()
_G.InCombatLockdown = function() return true end
suite.check("never in a fight", not ns.QuickSetup:Wanted())
ns.UI:Show()
suite.check("so it waits", not ns.QuickSetup:IsShown() and not ns.db.quickSetupShown)
_G.InCombatLockdown = nil

-- 6.
ns = Fresh()
_G.BlackthornesTS.Butler.SetDisenchanter = nil
Setup = ns.QuickSetup
Setup:Show()
suite.check("no Tradeskills call: nothing to pick", not Setup.disenchanter:IsShown())
Setup.disenchanter:SetValue("Mira Vale")
Setup:Confirm()
suite.check("and nothing sent", typed == nil)
_G.BlackthornesTS = nil

ns = Fresh()
_G.BlackthornesTS = nil
suite.check("no Tradeskills at all: still wanted", ns.QuickSetup:Wanted())
ns.QuickSetup:Show()
suite.check("it shows", ns.QuickSetup:IsShown())

-- German loads every word.
local de = env.Load("deDE")
env.Enable(de)
de.db.quickSetupShown = nil
de.QuickSetup:Show()
suite.check("German title", de.L["Set Up Butler"] == "Butler einrichten")

suite.done()
