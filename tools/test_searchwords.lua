-- The search that knows words (the owner said build it, 2026-11-26): All
-- Characters, Your Bags and the Bags window take words as well as names.
--
-- What must hold:
--   1. "cloth over 1g", "under 50s", "level 30 to 40" and the kind words
--      are read, in English and in the client's language.
--   2. Each kind finds what it says; a kind's word in an item's name
--      still finds that item, so no name search finds less than before.
--   3. A character's name finds what they hold.
--   4. All Characters counts worn gear (Equipment's Worn) and items on
--      auction (Tradeskills' Holdings), only while that addon is loaded.
--   5. The chips over All Characters filter the list and add up.
--   6. Your Bags and the Bags window take the same words.
--   7. German, Russian and Chinese words, and capitals in any of them.

local env = dofile(lfs_cwd .. "/tools/testenv.lua")
local suite = env.NewSuite("searchwords")

local ns = env.Load()
local fake = env.FakeBags({
    { bag = 0, slot = 1, id = 4306, name = "Silk Cloth", quality = 1, price = 150, count = 20, class = 7 },
    { bag = 0, slot = 2, id = 4338, name = "Mageweave Cloth", quality = 1, price = 250, count = 8, class = 7 },
    { bag = 0, slot = 3, id = 3300, name = "Rabbit's Foot", quality = 0, price = 7 },
    { bag = 0, slot = 4, id = 9001, name = "Gnoll Paw Bracers", quality = 2, price = 900, class = 4,
      equipLoc = "INVTYPE_WRIST", bind = 2 },
    { bag = 0, slot = 5, id = 9002, name = "Sealed Quest Note", quality = 1, price = 0 },
    { bag = 0, slot = 6, id = 9003, name = "Spider Fang", quality = 1, price = 0, class = 12, bind = 4 },
    { bag = 0, slot = 7, id = 9004, name = "Roasted Boar Meat", quality = 1, price = 25, class = 0, subclass = 5 },
    { bag = 0, slot = 8, id = 9005, name = "Bound Bracers", quality = 2, price = 900, class = 4,
      equipLoc = "INVTYPE_WRIST", bind = 2, bound = true },
})
_G.UnitName = function() return "Mia" end
env.Enable(ns)
local SW, UI, Everyone = ns.SearchWords, ns.UI, ns.Everyone

-- Levels: the fake client says 1 and 1; these say more.
local info = _G.C_Item.GetItemInfo
_G.C_Item.GetItemInfo = function(id)
    local r = { info(id) }
    if id == 9001 then r[4], r[5] = 35, 30 end
    if id == 9005 then r[4], r[5] = 45, 40 end
    if id == 4338 then r[4], r[5] = 35, 0 end
    return unpack(r)
end
SW:ForgetItems()

local function Item(id, extra)
    local item = fake.info[id]
    local out = { itemID = id, name = item.name, quality = item.quality, bound = item.bound }
    for k, v in pairs(extra or {}) do out[k] = v end
    return out
end

local function Passes(text, id, extra, characters)
    return SW.Match(SW.Parse(text, characters), Item(id, extra))
end

-- 1.
local q = SW.Parse("cloth over 1g")
suite.check("a name word and money", q.words[1] == "cloth" and #q.words == 1
    and q.tests[1].kind == "over" and q.tests[1].copper == 10000)
suite.check("silver", SW.Parse("under 50s").tests[1].copper == 5000)
suite.check("gold and silver in one", SW.Parse("over 1g50s").tests[1].copper == 15000)
suite.check("a number and a coin word", SW.Parse("over 2 gold").tests[1].copper == 20000)
suite.check("a bare number is gold", SW.Parse("over 3").tests[1].copper == 30000)
local level = SW.Parse("level 30 to 40").tests[1]
suite.check("a level range", level.kind == "level" and level.lo == 30 and level.hi == 40)
level = SW.Parse("lvl 40-30").tests[1]
suite.check("a range with a dash, either way round", level.lo == 30 and level.hi == 40)
suite.check("a phrase of two words", SW.Parse("binds when worn").tests[1].kind == "boe")
suite.check("over with no money is a name word", #SW.Parse("over").tests == 0 and SW.Parse("over").words[1] == "over")
suite.check("nothing typed is no query", SW.Parse("   ") == nil)

-- 2.
suite.check("cloth worth over 1g", Passes("cloth over 1g", 4306, nil) == false)
suite.check("cloth worth under 2s", Passes("cloth under 2s", 4306) and not Passes("cloth under 2s", 4338))
suite.check("gear", Passes("gear", 9001) and not Passes("gear", 4306))
suite.check("boe", Passes("boe", 9001) and not Passes("boe", 4306))
suite.check("boe already bound is not boe", not Passes("boe", 9005))
suite.check("bound", Passes("bound", 9005) and Passes("bound", 9003) and not Passes("bound", 9001))
suite.check("quest by its item class", Passes("quest", 9003))
suite.check("quest in the name still finds it", Passes("quest", 9002))
suite.check("quest is not everything", not Passes("quest", 4306))
suite.check("materials", Passes("mats", 4306) and not Passes("materials", 9004))
suite.check("food", Passes("food", 9004) and not Passes("food", 4306))
suite.check("grey", Passes("junk", 3300) and not Passes("grey", 4306))
suite.check("level by required level", Passes("level 30 to 40", 9001) and not Passes("level 30 to 34", 9005))
suite.check("level by item level without one", Passes("level 35", 4338))
suite.check("an item ID still finds it", Passes("4306", 4306))
suite.check("two name words, any order", Passes("cloth silk", 4306))
suite.check("an upgrade the bags already know", Passes("upgrade", 9001, { upgrade = true }))

-- Tradeskills' price counts once loaded: the best of it and a vendor.
_G.BlackthornesTS_API = { GetPrice = function(id) return (id == 4306 or id == 3300) and 20000 or nil end }
SW:ForgetItems()
suite.check("Tradeskills' price counts", Passes("cloth over 1g", 4306) and not Passes("cloth over 1g", 4338))
suite.check("greys at a vendor's price only", not Passes("over 1s", 3300) and Passes("over 5c", 3300))
_G.BlackthornesTS_API = nil
SW:ForgetItems()

-- 3. and 4.
local holdingsAsked = 0
_G.BlackthornesTS = { Butler = { Holdings = function()
    holdingsAsked = holdingsAsked + 1
    return {
        { key = "Player-1-MIA", name = "Mia Vale", short = "Mia", isCurrent = true, bags = {} },
        { key = "Player-1-ANA", name = "Ana Stone", short = "Ana", bags = { [4338] = 20 },
          bank = { [4338] = 40 }, bagsAt = 100, bankAt = 100,
          auctions = { [4306] = 20 }, auctionsAt = 90 },
    }
end } }
_G.UnitGUID = function() return "Player-1-MIA" end
local wornAsked = 0
_G.BlackthornesEquipment = { Butler = { Worn = function()
    wornAsked = wornAsked + 1
    return {
        { key = "Player-1-ANA", worn = { [9001] = 1 }, at = 80 },
        { key = "Player-1-MIA", worn = { [9005] = 1 }, at = 85 },
        { key = "Player-9-OTHER", worn = { [4306] = 9 } },
    }
end } }
ns.HandleSlash("all")
local function Find(id)
    for _, item in ipairs(Everyone.sorted) do if item.itemID == id then return item end end
end
local silk = Find(4306)
suite.check("on auction counts in the total", silk and silk.total == 40, silk and silk.total)
suite.check("and says where", silk and Everyone.Where(silk.byKey["Player-1-ANA"]) == "20 on auction",
    silk and Everyone.Where(silk.byKey["Player-1-ANA"]))
suite.check("Equipment is asked once a build, as Tradeskills is", wornAsked == holdingsAsked and wornAsked > 0, wornAsked)
local bracers = Find(9001)
suite.check("an alt's worn gear counts", bracers and bracers.byKey["Player-1-ANA"].worn == 1)
suite.check("the one playing's worn gear, by its GUID", Find(9005) and Find(9005).byKey["Player-1-MIA"].worn == 1)
suite.check("a character not listed adds nothing", silk and silk.byKey["Player-9-OTHER"] == nil)
suite.check("worn finds it", SW.Match(SW.Parse("worn"), bracers) and not SW.Match(SW.Parse("worn"), silk))
suite.check("on auction finds it", SW.Match(SW.Parse("on auction"), silk) and not SW.Match(SW.Parse("on auction"), bracers))
local mage = Find(4338)
suite.check("a first name finds what they hold",
    SW.Match(SW.Parse("ana", Everyone.characters), mage)
    and not SW.Match(SW.Parse("ana", Everyone.characters), Find(3300)))
suite.check("a whole name too", SW.Match(SW.Parse("Ana Stone", Everyone.characters), mage))
suite.check("a name and a kind", SW.Match(SW.Parse("ana cloth", Everyone.characters), mage))

local function Shown()
    local names = {}
    for _, line in ipairs(UI.list.data) do
        if line.type == "everyone" then names[#names + 1] = line.item.name end
    end
    table.sort(names)
    return table.concat(names, ",")
end
UI.search:SetText("ana")
UI:Refresh()
suite.check("All Characters: a name", Shown() == "Gnoll Paw Bracers,Mageweave Cloth,Silk Cloth", Shown())
suite.check("the footer says how many of all", UI.footer:GetText():find("3 of", 1, true) ~= nil, UI.footer:GetText())

-- 5.
UI.search:SetText("")
UI.chips.gear:GetScript("OnClick")(UI.chips.gear)
UI:Refresh()
suite.check("a chip lights", UI.chips.gear:IsSelected())
suite.check("the Gear chip", Shown() == "Bound Bracers,Gnoll Paw Bracers", Shown())
UI.chips.gear:GetScript("OnClick")(UI.chips.gear)
UI.chips.materials:GetScript("OnClick")(UI.chips.materials)
UI.chips.auction:GetScript("OnClick")(UI.chips.auction)
UI:Refresh()
suite.check("a second click lets a chip go", not UI.chips.gear:IsSelected())
suite.check("two chips add up", Shown() == "Silk Cloth", Shown())
UI.search:SetText("mageweave")
UI:Refresh()
suite.check("chips and words add up", Shown() == "", Shown())
suite.check("nothing matches says so", UI.emptyLabel:IsShown())
UI:ClearSearch(UI.search)
suite.check("Clear Search lets the chips go", not UI.chips.gear:IsSelected() and UI:ChipKey() == "")
UI.chips.auction:GetScript("OnClick")(UI.chips.auction)
UI:Refresh()
suite.check("the On Auction chip", Shown() == "Silk Cloth", Shown())
UI.chips.auction:GetScript("OnClick")(UI.chips.auction)
UI.chips.boe:GetScript("OnClick")(UI.chips.boe)
UI:Refresh()
suite.check("the Binds When Worn chip", Shown() == "Bound Bracers,Gnoll Paw Bracers", Shown())
UI.chips.boe:GetScript("OnClick")(UI.chips.boe)
UI:SetView("bags")
suite.check("the chips show on All Characters only", not UI.chipRow:IsShown())

-- Without Equipment or a Tradeskills that gives auctions, nothing more.
_G.BlackthornesEquipment = nil
_G.BlackthornesTS = nil
Everyone:Changed()
ns.HandleSlash("all")
silk = Find(4306)
suite.check("no auctions without Tradeskills", silk and silk.total == 20, silk and silk.total)
suite.check("no worn without Equipment", Find(9005) and Find(9005).byKey.self.worn == 0)

-- 6.
UI:SetView("bags")
UI.bagSearch:SetText("junk")
local names = {}
for _, line in ipairs(UI:Lines()) do if line.type == "item" then names[#names + 1] = line.name end end
suite.check("Your Bags takes the words", table.concat(names, ",") == "Rabbit's Foot", table.concat(names, ","))
UI.bagSearch:SetText("")
local entry
for _, e in pairs(ns.Bags.slots) do if e.itemID == 9001 then entry = e end end
suite.check("the Bags window takes the words", ns.BagView.MatchesEntry(entry, SW.Parse("boe level 30"))
    and not ns.BagView.MatchesEntry(entry, SW.Parse("food")))
suite.check("the Bags window still takes plain words", ns.BagView.MatchesEntry(entry, "gnoll"))

-- 7.
suite.check("capitals with accents fold", SW.Fold("ÜBER Серый") == "über серый", SW.Fold("ÜBER Серый"))
local de = env.Load("deDE")
de.SearchWords:Forget()
local dq = de.SearchWords.Parse("Stoff über 1g")
suite.check("German: über", dq.words[1] == "stoff" and dq.tests[1] and dq.tests[1].kind == "over")
suite.check("German: Kupfer", de.SearchWords.Parse("unter 50k").tests[1].copper == 50)
suite.check("German: Stufe 30 bis 40", de.SearchWords.Parse("Stufe 30 bis 40").tests[1].hi == 40)
suite.check("German: English still works", de.SearchWords.Parse("gear").tests[1].kind == "gear")
local ru = env.Load("ruRU")
ru.SearchWords:Forget()
suite.check("Russian: capitals fold", ru.SearchWords.Parse("Серый").tests[1].kind == "grey")
suite.check("Russian: 1з", ru.SearchWords.Parse("дороже 1з").tests[1].copper == 10000)
local zh = env.Load("zhCN")
zh.SearchWords:Forget()
local zq = zh.SearchWords.Parse("超过1金")
suite.check("Chinese: no spaces needed by money", zq.tests[1] and zq.tests[1].kind == "over"
    and zq.tests[1].copper == 10000)
suite.check("Chinese: a kind", zh.SearchWords.Parse("装备").tests[1].kind == "gear")
for _, lang in ipairs({ "frFR", "esES" }) do
    local other = env.Load(lang)
    other.SearchWords:Forget()
    local word = lang == "frFR" and "nourriture" or "comida"
    suite.check(lang .. ": a kind", other.SearchWords.Parse(word).tests[1].kind == "food")
end

suite.done()
