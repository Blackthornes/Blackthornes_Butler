-- The settings window.
--
-- What matters is that every way in opens it, that each control changes the
-- same saved value its chat command does, and that the page shows what is
-- saved rather than what it last drew.

local env = dofile(lfs_cwd .. "/tools/testenv.lua")
local suite = env.NewSuite("settings")

local ns = env.Load()

local SettingsUI = ns.SettingsUI

-- A client with retail's Settings API, recording what is registered.
local registered = {}
_G.Settings = {
    RegisterCanvasLayoutCategory = function(panel, name) return { panel = panel, name = name } end,
    RegisterAddOnCategory = function(category) registered[#registered + 1] = category end,
}

for _, module in ipairs(ns.moduleOrder) do
    if module.OnEnable then module:OnEnable() end
end

suite.check("it is listed under the game's AddOns options",
    registered[1] and registered[1].name == "Blackthornes Butler")

-- Ways in.
ns.HandleSlash("settings")
suite.check("/bbutler settings opens it", SettingsUI.frame:IsShown())
ns.HandleSlash("settings")
suite.check("and closes it", not SettingsUI.frame:IsShown())
ns.HandleSlash("options")
suite.check("/bbutler options works too", SettingsUI.frame:IsShown())
suite.check("options is not listed twice in help",
    not (function()
        for _, name in ipairs(ns.commandOrder) do
            if name == "options" or name == "config" then return true end
        end
    end)())

-- The house frame: the plate and close gem, without the portrait.
local trim = SettingsUI.frame.titan
suite.check("settings wears the house frame", trim ~= nil)
suite.check("with the name on the plate", trim and trim.plate.label:GetText() == "Blackthornes Butler")
-- A stub answers any field it lacks with a function, so "no portrait"
-- means no portrait frame.
suite.check("and no portrait", trim and type(trim.portrait) ~= "table")
trim.closeButton:GetScript("OnClick")(trim.closeButton)
suite.check("the close gem closes it", not SettingsUI.frame:IsShown())
SettingsUI:Show()

local controls = SettingsUI.controls

-- The minimap checkbox.
local minimapBox = controls.minimap
suite.check("the minimap box starts ticked", minimapBox:GetChecked())
minimapBox:GetScript("OnClick")(minimapBox)
suite.check("unticking hides the button",
    ns.db.minimapHidden == true and not ns.MinimapButton.button:IsShown())
ns.HandleSlash("minimap")
suite.check("/bbutler minimap ticks it again", minimapBox:GetChecked())

-- Debug.
controls.debug:GetScript("OnClick")(controls.debug)
suite.check("the debug box sets debug", ns.db.debug == true)

-- The pages along the top, as Tradeskills' Settings tab has them: Selling,
-- then General. The plan's others come with the features they hold.
local pages = SettingsUI.pages
suite.check("it opens on the first page", pages.shown == "selling", pages.shown)
suite.check("with the selling rows showing", pages.pages.selling.content:IsShown())
pages:Show("general")
suite.check("General is the second page", pages.shown == "general" and pages.pages.general.content:IsShown())
SettingsUI:Hide()
SettingsUI:Show()
suite.check("it opens again on the page left", pages.shown == "general")

-- Open at a vendor: on unless unticked, saved as the box says.
suite.check("Open at a vendor starts ticked", controls.openAtVendor:GetChecked())
controls.openAtVendor:GetScript("OnClick")(controls.openAtVendor)
suite.check("unticking it saves off", ns.db.openAtVendor == false)
ns.HandleSlash("vendor")
suite.check("/bbutler vendor turns it back on, and the box follows",
    ns.db.openAtVendor == true and controls.openAtVendor:GetChecked())

-- What a setting does is a tooltip until Show descriptions is ticked.
local minimapRow
for _, row in ipairs(pages.pages.general.rows) do
    if row.labelText == "Minimap button" then minimapRow = row end
end
suite.check("descriptions start hidden", ns.db.settingsDescriptions == false
    and not minimapRow.hint:IsShown())
GameTooltip._lines = {}
minimapRow:GetScript("OnEnter")(minimapRow)
suite.check("a row lights under the mouse", minimapRow.hover:IsShown())
suite.check("and says what it does in a tooltip", GameTooltip._lines[1] and
    GameTooltip._lines[1]:find("Butler window") ~= nil)
local before = SettingsUI.frame:GetHeight()
pages.describe:GetScript("OnClick")(pages.describe)
suite.check("Show descriptions is saved", ns.db.settingsDescriptions == true)
suite.check("and puts the words under the rows", minimapRow.hint:IsShown())
suite.check("and the window grows to fit them", SettingsUI.frame:GetHeight() > before)
pages.describe:GetScript("OnClick")(pages.describe)
suite.check("unticked, the window goes back", SettingsUI.frame:GetHeight() == before)

-- Find a setting.
pages.find:SetText("debug")
pages:Search("debug")
local lit = 0
for _, entry in ipairs(pages.searchables) do
    if entry.glow:IsShown() then lit = lit + 1 end
end
suite.check("the search lights only what matches", lit == 1)
pages:Search("")
lit = 0
for _, entry in ipairs(pages.searchables) do
    if entry.glow:IsShown() then lit = lit + 1 end
end
suite.check("an empty search lights nothing", lit == 0)

-- Text size, saved as a word, waits for a reload.
controls.textSize.plus:GetScript("OnClick")(controls.textSize.plus)
suite.check("Text size saves Large", ns.db.textSize == "large")
suite.check("and offers Reload", controls.textSize.reload:IsShown())
suite.check("beside the stepper, inside its column", controls.textSize.reload._point[2] == controls.textSize
    and controls.textSize.reload._point[1] == "LEFT")
controls.textSize.minus:GetScript("OnClick")(controls.textSize.minus)
suite.check("back to Normal needs no reload", ns.db.textSize == "normal"
    and not controls.textSize.reload:IsShown())

-- Sell below: gold, silver and copper boxes, saved when the player leaves
-- a box or presses Enter, not on every key.
local money = controls.sellBelow
pages:Show("selling")
suite.check("Sell below starts empty (off)", money:GetValue() == 0 and ns.db.sellBelow == nil)
money.boxes.silver.editBox:SetText("50")
suite.check("typing alone saves nothing", ns.db.sellBelow == nil)
money.boxes.silver.editBox:GetScript("OnEnterPressed")(money.boxes.silver.editBox)
suite.check("Enter saves it in copper", ns.db.sellBelow == 5000, tostring(ns.db.sellBelow))
money.boxes.gold.editBox:SetText("1")
money.boxes.gold.editBox:GetScript("OnEditFocusLost")(money.boxes.gold.editBox)
suite.check("leaving a box saves it too", ns.db.sellBelow == 15000)
ns.HandleSlash("sellbelow 2s 5c")
suite.check("/bbutler sellbelow fills the boxes", money.boxes.gold:GetText() == ""
    and money.boxes.silver:GetText() == "2" and money.boxes.copper:GetText() == "5")
ns.HandleSlash("sellbelow off")
suite.check("and off empties them", money:GetValue() == 0 and ns.db.sellBelow == nil)

-- Every /bbutler command has a button here.
local ran = {}
local realSlash = ns.HandleSlash
ns.HandleSlash = function(text) ran[#ran + 1] = text end
for _, key in ipairs({ "openWindow", "all", "probe", "help", "sellTest", "lists" }) do
    controls[key]:GetScript("OnClick")(controls[key])
end
ns.HandleSlash = realSlash
suite.check("the command buttons run their commands",
    table.concat(ran, ",") == "window,all,probe,help,selltest,lists", table.concat(ran, ","))

-- Every command has a button or a control here, apart from the one that
-- deletes the player's lists, which stays typed (a house rule).
local covered = { window = true, all = true, probe = true, help = true, selltest = true, lists = true,
    vendor = true, mailbox = true, bank = true, minimap = true, settings = true, reset = true,
    sellbelow = true, freespace = true }
for _, name in ipairs(ns.commandOrder) do
    suite.check("/bbutler " .. name .. " has a place in Settings", covered[name] == true)
end

-- Position.
ns.db.settingsX = 400
SettingsUI:ResetPositions()
suite.check("putting it back forgets where it was dragged", ns.db.settingsX == nil)

-- A client with neither options API still loads.
local ns2 = env.Load()
suite.check("no options API is not an error", ns2.SettingsUI:RegisterGameOptions() == false)

suite.done()
