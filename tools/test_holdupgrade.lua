-- Holding an upgrade back from a character (the owner asked 2026-10-12:
-- "an action that lets me choose not to mail to someone as an upgrade").
--
-- What must hold:
--   1. Right-click on a Mail upgrade row offers both ways, named in full.
--   2. "Don't mail this" moves that item to its next verdict, and Fill mail
--      leaves it out.
--   3. "Never mail upgrades" does it for every upgrade to that character.
--   4. Settings shows both and undoes them; so does the command.
--   5. Nothing else is deleted: the player's lists stay as they were.

local env = dofile(lfs_cwd .. "/tools/testenv.lua")
local suite = env.NewSuite("holdupgrade")

local ns = env.Load()
env.FakeBags({
    { bag = 0, slot = 1, id = 405, name = "Phoenix Gloves", quality = 2, price = 100 },
    { bag = 0, slot = 2, id = 406, name = "Copper Band", quality = 2, price = 50 },
})

local filled = {}
_G.BlackthornesTS = { Butler = {
    Advise = function() return { auction = 0 } end,
    FillMail = function(_, name, items)
        filled[#filled + 1] = { name = name, items = items }
        return true
    end,
    Holdings = function()
        return {
            { key = "me", short = "Me Here", realm = "R", faction = "Horde", isCurrent = true },
            { key = "bob", short = "Bob Stone", realm = "R", faction = "Horde" },
        }
    end,
    Mailbox = function() end,
} }
_G.BlackthornesEquipment = { Butler = { Advise = function()
    return { alt = { key = "bob", gain = 14 } }
end } }
env.Enable(ns)
local Verdicts, UI = ns.Verdicts, ns.UI

local function Rows(verdict)
    local group = Verdicts:Group(verdict)
    local byID = {}
    for _, row in ipairs(group and group.rows or {}) do byID[row.itemID] = row end
    return byID
end

ns.db.alwaysKeep = { [999] = true }
UI:Show("bags")
Verdicts:Changed(true)
local mail = Rows("mail")
suite.check("both go to the alt at first", mail[405] and mail[406])

-- 1.
UI:ShowMenu(mail[405])
local menu = UI.menu
suite.check("the menu offers Don't mail this, by full name",
    menu.hold:IsShown() and menu.hold.label:GetText() == "Don't mail this to Bob Stone",
    menu.hold.label:GetText())
suite.check("and Never mail upgrades",
    menu.holdAll:IsShown() and menu.holdAll.label:GetText() == "Never mail upgrades to Bob Stone")
suite.check("the menu fits them", menu:GetWidth() >= menu.holdAll:GetWidth())

-- 2.
menu.hold:GetScript("OnClick")(menu.hold)
suite.check("it is remembered for that item and character", ns.db.noUpgradeMail[405]["Bob Stone"] == true)
mail = Rows("mail")
suite.check("the gloves leave Mail", mail[405] == nil)
suite.check("and get their next verdict", Verdicts:VerdictOf(ns.Bags.ReadSlot(0, 1)) ~= "mail")
suite.check("the ring still goes", mail[406] ~= nil)
env.Fire("MAIL_SHOW")
UI.mailButton:GetScript("OnClick")(UI.mailButton)
local sent = {}
for _, item in ipairs(filled[1] and filled[1].items or {}) do sent[item.itemID] = true end
suite.check("Fill mail leaves the gloves out", not sent[405] and sent[406])
env.Fire("MAIL_CLOSED")

-- A row that is no upgrade gets neither.
local sell = Rows("sell")[405] or Rows("keep")[405] or Rows("bank")[405]
if sell then
    UI:ShowMenu(sell)
    suite.check("a row that is no upgrade offers neither", not menu.hold:IsShown() and not menu.holdAll:IsShown())
end
UI:HideMenu()

-- 3.
UI:ShowMenu(Rows("mail")[406])
menu.holdAll:GetScript("OnClick")(menu.holdAll)
suite.check("never mail upgrades is remembered", ns.db.noUpgradesFor["Bob Stone"] == true)
suite.check("no upgrade goes to them now", Rows("mail")[406] == nil)

-- 4. Settings.
ns.HandleSlash("settings")
local controls = ns.SettingsUI.controls
suite.check("Settings picks the character", controls.heldPick:GetName() == "Bob Stone")
suite.check("with Mail them upgrades unticked", not controls.heldAll:GetChecked())
suite.check("and one item held back", controls.heldItems.label:GetText() == "Undo 1",
    controls.heldItems.label:GetText())
controls.heldAll:GetScript("OnClick")(controls.heldAll)
suite.check("ticking it mails upgrades again", ns.db.noUpgradesFor["Bob Stone"] == nil)
suite.check("so the ring goes", Rows("mail")[406] ~= nil)
controls.heldItems:GetScript("OnClick")(controls.heldItems)
suite.check("Undo lets the gloves go again", ns.db.noUpgradeMail[405] == nil and Rows("mail")[405] ~= nil)
suite.check("and the button says none are left", controls.heldItems.label:GetText() == "None")

-- The command.
Verdicts:HoldUpgrade(405, "Bob Stone", true)
Verdicts:HoldAllUpgrades("Bob Stone", true)
suite.check("the command lists them", pcall(ns.HandleSlash, "upgrademail"))
ns.HandleSlash("upgrademail undo Bob Stone")
suite.check("the command undoes both", ns.db.noUpgradesFor["Bob Stone"] == nil and ns.db.noUpgradeMail[405] == nil)

-- 5.
suite.check("the player's lists are untouched", ns.db.alwaysKeep[999] == true)

_G.BlackthornesEquipment = nil
_G.BlackthornesTS = nil
suite.done()
