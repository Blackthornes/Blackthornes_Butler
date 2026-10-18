-- Keep on this character: a number of an item kept on one character, the
-- rest judged by the usual rules. Enough stacks are kept, a stack holding
-- more is split, the list is saved by GUID with a copy in the character's
-- own save, and Settings and the right-click menu show and change it.

local env = dofile(lfs_cwd .. "/tools/testenv.lua")
local suite = env.NewSuite("keephere")

local ns = env.Load()
local fake = env.FakeBags({
    { bag = 0, slot = 1, id = 901, name = "Elixir of Agility", count = 5, price = 30, stack = 20 },
    { bag = 0, slot = 2, id = 901, name = "Elixir of Agility", count = 3, price = 30, stack = 20 },
    { bag = 0, slot = 3, id = 902, name = "Heavy Leather", count = 20, price = 15, stack = 20 },
})
local GUID = "Player-1-0000AAAA"
_G.UnitGUID = function(unit) if unit == "player" then return GUID end end
_G.UnitName = function() return "Ana Thornfield" end
env.Enable(ns)

local Verdicts, UI, KeepHere = ns.Verdicts, ns.UI, ns.KeepHere

local function Rows(name)
    UI:Hide()
    UI:Show()
    local found = {}
    for _, group in ipairs(Verdicts:Groups()) do
        for _, row in ipairs(group.rows) do
            if row.name == name then found[#found + 1] = row end
        end
    end
    return found
end

local function Verdict(name, verdict)
    local count = 0
    for _, row in ipairs(Rows(name)) do
        if row.verdict == verdict then count = count + row.count end
    end
    return count
end

-- Both on the Always sell list, so everything not kept sells.
Verdicts:SetChoice(901, "sell")
Verdicts:SetChoice(902, "sell")
suite.check("nothing kept before a number is set", Verdict("Elixir of Agility", "sell") == 8)
suite.check("nothing saved before a number is set", ns.db.keepHere == nil)

-- Keep 5 elixirs: the stack of 5 stays, the 3 sell.
suite.check("the number is set", KeepHere:Set(901, 5) == true)
suite.check("saved by GUID", ns.db.keepHere[GUID].items[901] == 5)
suite.check("with the character's name", ns.db.keepHere[GUID].name == "Ana Thornfield")
suite.check("copied to this character's own save", ns.charDB.keepHere[901] == 5)
suite.check("five are kept", Verdict("Elixir of Agility", "keep") == 5, Verdict("Elixir of Agility", "keep"))
suite.check("the rest still sell", Verdict("Elixir of Agility", "sell") == 3, Verdict("Elixir of Agility", "sell"))
local kept
for _, row in ipairs(Rows("Elixir of Agility")) do
    if row.verdict == "keep" then kept = row end
end
suite.check("the row says why", kept and kept.reason == "Keeping 5 on this character", kept and kept.reason)

-- Keep 5 leather from one stack of 20: kept whole for now, the extra split off.
local splits = {}
_G.C_Container.SplitContainerItem = function(bag, slot, count)
    splits[#splits + 1] = { bag = bag, slot = slot, count = count }
    fake.held = { from = fake.bags[bag][slot], count = count }
end
_G.C_Container.PickupContainerItem = function(bag, slot)
    local held = fake.held
    if not held then return end
    held.from.count = held.from.count - held.count
    fake.Put({ bag = bag, slot = slot, id = held.from.id, name = held.from.name, count = held.count,
        price = held.from.price, stack = held.from.stack })
    fake.held = nil
end
_G.CursorHasItem = function() return fake.held ~= nil end
KeepHere:Set(902, 5)
suite.check("a stack past the number is kept whole", Verdict("Heavy Leather", "keep") == 20,
    Verdict("Heavy Leather", "keep"))
suite.check("the extra is split off", #splits == 1 and splits[1].slot == 3 and splits[1].count == 15,
    splits[1] and splits[1].count)
suite.check("into a free slot", fake.bags[0][4] and fake.bags[0][4].count == 15 and fake.bags[0][3].count == 5)
ns.Bags:Scan()
suite.check("after the split, five are kept", Verdict("Heavy Leather", "keep") == 5, Verdict("Heavy Leather", "keep"))
suite.check("and the split stack sells", Verdict("Heavy Leather", "sell") == 15, Verdict("Heavy Leather", "sell"))
suite.check("no split once it fits", #splits == 1, #splits)

-- No split in a fight, and none while the window is down.
_G.InCombatLockdown = function() return true end
fake.bags[0][4] = nil
fake.bags[0][3].count = 20
ns.Bags:Scan()
Rows("Heavy Leather")
suite.check("no split in a fight", #splits == 1, #splits)
_G.InCombatLockdown = nil

-- With no free slot, the row says what to do.
fake.numSlots = 3
UI:Hide()
ns.Bags:Scan()
local full
for _, row in ipairs(Rows("Heavy Leather")) do
    if row.verdict == "keep" then full = row end
end
suite.check("full bags: the whole stack is kept", full and full.count == 20)
suite.check("full bags: the row asks for a free slot",
    full and full.reason:find("Free one bag slot", 1, true) ~= nil, full and full.reason)
fake.numSlots = 16

-- How the stacks are picked: the same ones again after a split.
local function Slots(counts)
    local list = {}
    for i, count in ipairs(counts) do list[i] = { bag = 0, slot = i, count = count } end
    return list
end
local function Kept(counts, number)
    local list = Slots(counts)
    local kept, split = KeepHere.Plan(list, number)
    local sum = 0
    for _, entry in ipairs(list) do
        if kept[entry] then sum = sum + entry.count end
    end
    return sum, split and split.extra
end
local sum, extra = Kept({ 3, 3, 20 }, 5)
suite.check("3, 3, 20 keep 5: one 3 and split 1 off the other", sum == 6 and extra == 1, sum .. " " .. tostring(extra))
sum, extra = Kept({ 3, 2, 1, 20 }, 5)
suite.check("after that split it fits", sum == 5 and extra == nil, sum .. " " .. tostring(extra))
sum, extra = Kept({ 2, 7 }, 5)
suite.check("2, 7 keep 5: splits 4 off", sum == 9 and extra == 4)
sum, extra = Kept({ 2, 3, 4 }, 5)
suite.check("then 4 and a 1 split off the 2", sum == 6 and extra == 1)
sum, extra = Kept({ 1, 1, 3, 4 }, 5)
suite.check("then it fits", sum == 5 and extra == nil)
sum = Kept({ 2 }, 5)
suite.check("fewer than the number: all kept", sum == 2)

-- The rule can be turned off on the Order page.
Verdicts:SetRuleOn("keepHere", false)
suite.check("turned off, nothing is kept", Verdict("Elixir of Agility", "sell") == 8)
Verdicts:SetRuleOn("keepHere", true)

-- Settings: the character, the item and its number.
local SettingsUI = ns.SettingsUI
SettingsUI:Show()
local controls = SettingsUI.controls
suite.check("Settings shows the character playing", controls.keepWho:GetName() == "Ana Thornfield",
    controls.keepWho:GetName())
suite.check("and its first item", controls.keepWhat:GetName() == "Elixir of Agility", controls.keepWhat:GetName())
suite.check("with its number", controls.keepCount.editBox:GetText() == "5")
controls.keepCount.editBox:SetText("7")
controls.keepCount.editBox:GetScript("OnEditFocusLost")(controls.keepCount.editBox)
suite.check("a new number is saved", KeepHere:Count(901) == 7, KeepHere:Count(901))

-- Another character's list, from this one.
ns.db.keepHere["Player-1-0000BBBB"] = { name = "Bo Udderly", items = { [901] = 2 } }
SettingsUI:SyncKeepHere()
local names = {}
for _, each in ipairs(KeepHere:Characters()) do names[#names + 1] = each.name end
suite.check("the one playing first, then the others", names[1] == "Ana Thornfield" and names[2] == "Bo Udderly",
    table.concat(names, ", "))
suite.check("another character's number counts only for them", KeepHere:Count(901) == 7
    and KeepHere:CountFor("Player-1-0000BBBB", 901) == 2)
controls.keepWho.next:GetScript("OnClick")(controls.keepWho.next)
suite.check("stepping to the other character", controls.keepWho:GetName() == "Bo Udderly",
    controls.keepWho:GetName())
controls.keepRemove:GetScript("OnClick")(controls.keepRemove)
suite.check("Remove takes it off their list", KeepHere:CountFor("Player-1-0000BBBB", 901) == nil)
suite.check("and leaves this character's", KeepHere:Count(901) == 7)
SettingsUI:Hide()

-- In a dungeon the GUID can't be read: the copy is read, nothing written.
_G.UnitGUID = function() return nil end
suite.check("no GUID: the character's own copy is read", KeepHere:Count(902) == 5, KeepHere:Count(902))
local done, why = KeepHere:Set(901, 1)
suite.check("no GUID: nothing is written", done == false and why ~= nil and ns.db.keepHere[GUID].items[901] == 7)
_G.UnitGUID = function(unit) if unit == "player" then return GUID end end

-- The right-click menu: a page with a box.
local row = Rows("Elixir of Agility")[1]
UI:ShowMenu(row)
local menu = UI.menu
suite.check("the menu shows the number", menu.keepHere:IsShown() and menu.keepHere.label:GetText() == "Keep on This Character: 7",
    menu.keepHere.label:GetText())
menu.keepHere:GetScript("OnClick")(menu.keepHere)
suite.check("its page has the box", menu.keepBox:IsShown() and menu.keepBox.editBox:GetText() == "7")
menu.keepBox.editBox:SetText("0")
menu.keepSave:GetScript("OnClick")(menu.keepSave)
suite.check("0 takes it off the list", KeepHere:Count(901) == nil)
suite.check("and the elixirs sell again", Verdict("Elixir of Agility", "sell") == 8)
suite.check("the saved table stays", type(ns.db.keepHere[GUID]) == "table")

-- Tradeskills' own keep on this character: the bigger number wins.
local tsCount
_G.BlackthornesTS = { KeepHere = { Count = function(_, id) if id == 901 then return tsCount end end } }
tsCount = 3
suite.check("Tradeskills' number alone is kept", Verdict("Elixir of Agility", "keep") == 3,
    Verdict("Elixir of Agility", "keep"))
suite.check("and the rest sell", Verdict("Elixir of Agility", "sell") == 5)
local tsRow = Rows("Elixir of Agility")[1]
for _, row in ipairs(Rows("Elixir of Agility")) do if row.verdict == "keep" then tsRow = row end end
suite.check("the row says Tradeskills' number", tsRow.reason == "Keeping 3 on this character", tsRow.reason)
KeepHere:Set(901, 5)
suite.check("Butler's bigger number wins", Verdict("Elixir of Agility", "keep") == 5)
tsCount = 8
suite.check("Tradeskills' bigger number wins", Verdict("Elixir of Agility", "keep") == 8)
suite.check("Butler's own number is unchanged", KeepHere:Count(901) == 5)
_G.BlackthornesTS = { KeepHere = { Count = function() error("boom") end } }
suite.check("a Tradeskills that raises changes nothing", Verdict("Elixir of Agility", "keep") == 5)
_G.BlackthornesTS = nil
KeepHere:Set(901, 0)
suite.check("without either, the elixirs sell again", Verdict("Elixir of Agility", "sell") == 8)

-- Keep All: every copy stays, nothing to type, and it reads "All".
local splitsBefore = #splits
UI:ShowMenu(Rows("Elixir of Agility")[1])
menu.keepHere:GetScript("OnClick")(menu.keepHere)
suite.check("the page has Keep All beside Save", menu.keepAll:IsShown() and menu.keepAll.label:GetText() == "Keep All")
menu.keepAll:GetScript("OnClick")(menu.keepAll)
suite.check("Keep All saves the most", KeepHere:Count(901) == KeepHere.MOST and KeepHere.IsAll(KeepHere:Count(901)))
suite.check("every elixir is kept", Verdict("Elixir of Agility", "keep") == 8 and Verdict("Elixir of Agility", "sell") == 0)
local allRow
for _, row in ipairs(Rows("Elixir of Agility")) do allRow = row end
suite.check("the row says all", allRow and allRow.reason == "Keeping all on this character", allRow and allRow.reason)
suite.check("nothing is split for Keep All", #splits == splitsBefore)
UI:ShowMenu(Rows("Elixir of Agility")[1])
suite.check("the menu says All", menu.keepHere.label:GetText() == "Keep on This Character: All",
    menu.keepHere.label:GetText())
menu.keepHere:GetScript("OnClick")(menu.keepHere)
suite.check("the box is empty for All", menu.keepBox.editBox:GetText() == "")
UI:HideMenu()

SettingsUI:Show()
SettingsUI:SyncKeepHere()
controls = SettingsUI.controls
while controls.keepWhat:GetName() ~= "Elixir of Agility" do
    controls.keepWhat.next:GetScript("OnClick")(controls.keepWhat.next)
end
suite.check("Settings says Keeping All", controls.keepAll.label:GetText() == "Keeping All"
    and controls.keepCount.editBox:GetText() == "", controls.keepAll.label:GetText())
controls.keepCount.editBox:GetScript("OnEditFocusLost")(controls.keepCount.editBox)
suite.check("leaving the empty box keeps All", KeepHere.IsAll(KeepHere:Count(901)))
controls.keepCount.editBox:SetText("4")
controls.keepCount.editBox:GetScript("OnEditFocusLost")(controls.keepCount.editBox)
suite.check("a number replaces All", KeepHere:Count(901) == 4)
controls.keepAll:GetScript("OnClick")(controls.keepAll)
suite.check("Keep All in Settings", KeepHere.IsAll(KeepHere:Count(901)))
SettingsUI:Hide()

suite.done()
