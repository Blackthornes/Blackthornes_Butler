-- Ask Butler (the owner asked 2026-10-14 for the Ask box): a typed
-- question matched against a few question shapes and an item, answered
-- from what Butler and its sisters already know.
--
-- What must hold:
--   1. Each kind of question finds its shape, on whole words only.
--   2. The item comes from a link, else a name Butler knows, longest first.
--   3. Each answer reads its sister read only, and says what to add when
--      that sister isn't loaded.
--   4. Anything not understood, or an error, answers with examples.
--   5. /bbutler ask opens the window and asks; the window shows the answer
--      on dark glass lines, with its button when it has one.

local env = dofile(lfs_cwd .. "/tools/testenv.lua")
local suite = env.NewSuite("ask")

local ns = env.Load()
env.FakeBags({
    { bag = 0, slot = 1, id = 2589, name = "Linen Cloth", quality = 1, price = 13, count = 12 },
    { bag = 0, slot = 2, id = 2770, name = "Copper Ore", quality = 1, price = 5, count = 4 },
    { bag = 0, slot = 3, id = 4304, name = "Thick Leather", quality = 1, price = 50, count = 1 },
})
_G.C_Item.GetItemNameByID = function(id)
    return ({ [2589] = "Linen Cloth", [2770] = "Copper Ore", [4304] = "Thick Leather", [2592] = "Wool Cloth" })[id]
end
_G.BlackthornesTS, _G.BlackthornesEquipment, _G.BlackthornesFarmer, _G.BlackthornesPets = nil, nil, nil, nil
env.Enable(ns)

local Ask = ns.Ask
local done = false
ns.Bags:Scan(function() done = true end)
suite.check("the bags are read", done and ns.Bags:Carried(2589) == 12)

-- 1. Shapes.
local shapes = {
    ["What should I do next?"] = "next",
    ["How are my gold goals?"] = "gold",
    ["What is Linen Cloth worth?"] = "worth",
    ["Who has Copper Ore?"] = "who",
    ["Is this an upgrade?"] = "upgrade",
    ["Does my pet eat Tough Jerky?"] = "pet",
    ["Where do I farm Silk Cloth?"] = "farm",
    ["any spells to train"] = "train",
    ["what do I do with Thick Leather"] = "next",
    ["should I sell Thick Leather"] = "verdict",
    ["help"] = "help",
    ["Wer hat Copper Ore"] = "who",
    ["Wie stehen meine Goldziele?"] = "gold",
    ["Was soll ich als Nächstes tun?"] = "next",
    ["Was ist Leinenstoff wert?"] = "worth",
}
for question, want in pairs(shapes) do
    suite.check("'" .. question .. "' is " .. want, Ask.Intent(question) == want, tostring(Ask.Intent(question)))
end
suite.check("whole words only: competitor is no pet", Ask.Intent("my competitor") == nil)

-- 2. The item.
local id, name = Ask.FindItem("What is Linen Cloth worth?")
suite.check("a name in the bags is found", id == 2589 and name == "Linen Cloth", tostring(id))
id = Ask.FindItem("is |cffffffff|Hitem:2592::::::::|h[Wool Cloth]|h|r worth much")
suite.check("a link wins", id == 2592)
suite.check("no item, no answer", Ask.FindItem("what now") == nil)

-- 3. Answers without the sisters.
local answer = Ask:Answer("What is Linen Cloth worth?")
suite.check("worth says the vendor price", answer.title:find("Linen Cloth", 1, true)
    and answer.lines[1]:find("vendor pays", 1, true), answer.lines[1])
suite.check("and that Tradeskills would know the auction price", answer.lines[2]:find("Tradeskills", 1, true))

answer = Ask:Answer("Who has Copper Ore?")
suite.check("who has: what this character carries", answer.title == "You have 4 Copper Ore", answer.title)

answer = Ask:Answer("Is Thick Leather an upgrade?")
suite.check("upgrades need Equipment", answer.title:find("Equipment", 1, true))

answer = Ask:Answer("Where do I farm Thick Leather?")
suite.check("farming needs Farmer", answer.title:find("Farmer", 1, true))

answer = Ask:Answer("blah blah")
suite.check("not understood: examples", answer.title == "I don't know that one yet" and #answer.lines > 3)
answer = Ask:Answer("")
suite.check("nothing typed: the help", #answer.lines > 3)

answer = Ask:Answer("Thick Leather")
suite.check("what to do with an item: Butler's verdict",
    Ask:Answer("what do I do with Thick Leather").title:find("Butler says", 1, true))
suite.check("an item alone: Butler's verdict", answer.title:find("Butler says", 1, true), answer.title)

-- With the sisters.
local asked = {}
_G.BlackthornesTS = { Butler = {
    Advise = function(_, itemID)
        asked[#asked + 1] = itemID
        return { auction = 40, auctionNow = 30, disenchant = "bad" }
    end,
    Holdings = function()
        return {
            { key = "Player-1", name = "Ana Stone", isCurrent = true, bags = { [2770] = 99 }, bank = { [2770] = 6 }, mail = {} },
            { key = "Player-2", name = "Bob Wither", bags = { [2770] = 20 }, bank = {}, mail = { [2592] = 3 } },
        }
    end,
} }
answer = Ask:Answer("What is Linen Cloth worth?")
suite.check("Tradeskills' auction price", answer.lines[2]:find("auction house", 1, true), answer.lines[2])
suite.check("and today's cheapest", answer.lines[3] and answer.lines[3]:find("cheapest", 1, true))
suite.check("a field of the wrong type is left out", #answer.lines == 3)

answer = Ask:Answer("Who has Copper Ore?")
suite.check("every character, the live bags for the one playing",
    answer.title == "You have 30 Copper Ore", answer.title)
suite.check("most first", answer.lines[1]:find("Bob Wither", 1, true), answer.lines[1])
suite.check("whole names", answer.lines[2]:find("Ana Stone (you)", 1, true), answer.lines[2])
suite.check("with a button to All characters", answer.action and answer.action.command == "all")

answer = Ask:Answer("Who has Wool Cloth")
suite.check("a name only another character holds is found", answer.title == "You have 3 Wool Cloth", answer.title)

_G.BlackthornesEquipment = { Butler = { Advise = function(_, item)
    if item == 4304 or (type(item) == "string" and item:find("4304")) then return { upgrade = "now", gain = 12 } end
    return nil
end } }
answer = Ask:Answer("Is Thick Leather an upgrade?")
suite.check("Equipment's upgrade", answer.title == "Yes, it's an upgrade" and answer.lines[1]:find("12%", 1, true))
answer = Ask:Answer("Is Copper Ore an upgrade?")
suite.check("not gear", answer.title:find("isn't gear", 1, true))
_G.BlackthornesEquipment.Butler.Advise = function() error("boom") end
answer = Ask:Answer("Is Thick Leather an upgrade?")
suite.check("a sister that raises is not gear, not an error", answer.title:find("isn't gear", 1, true))

_G.BlackthornesFarmer = { Butler = { Advise = function(_, itemID)
    if itemID == 2589 then return { goal = "Linen Cloth", have = 12, target = 20, need = 8 } end
end } }
answer = Ask:Answer("my goal for Linen Cloth")
suite.check("Farmer's goal", answer.title == "8 more to go" and answer.lines[1] == "You have 12 of 20.", answer.title)
local searched
_G.SlashCmdList.BLACKTHORNESFARMER = function(text) searched = text end
answer = Ask:Answer("Where do I farm Linen Cloth?")
suite.check("farming opens Farmer's search", answer.action and answer.action.farm == "Linen Cloth")
suite.check("and says what the goal still needs", answer.lines[2] and answer.lines[2]:find("8", 1, true))
Ask:Run(answer.action)
suite.check("the button runs Farmer's search", searched == "Linen Cloth")

_G.BlackthornesPets = { Butler = { Advise = function(_, itemID)
    if itemID == 4304 then return { eats = true, hours = 2.5, count = 1 } end
end } }
answer = Ask:Answer("does my pet eat Thick Leather")
suite.check("Pets: yes", answer.title:find("Yes", 1, true) and answer.lines[1]:find("2.5", 1, true))

-- Jobs: nothing waiting.
answer = Ask:Answer("what should I do next")
suite.check("next, with no jobs", answer.title ~= nil and #answer.lines >= 1)

-- 5. The window.
ns.HandleSlash("ask Who has Copper Ore?")
local AskUI = ns.AskUI
suite.check("/bbutler ask opens the window", AskUI:IsShown())
suite.check("and asks", AskUI.title:GetText() == "You have 30 Copper Ore", AskUI.title:GetText())
suite.check("a line for each thing it says", AskUI.lines[1]:IsShown() and AskUI.lines[2]:IsShown()
    and not AskUI.lines[3]:IsShown())
suite.check("with its button", AskUI.action:IsShown())
AskUI.action:GetScript("OnClick")(AskUI.action)
suite.check("which opens All characters", ns.UI:IsShown() and ns.UI.view == "all")
AskUI.examples[1]:GetScript("OnClick")(AskUI.examples[1])
suite.check("a question to click fills the box", AskUI.box:GetText() == "What should I do next?")
suite.check("and the button goes when there is none", not AskUI.action:IsShown() or AskUI.answer.action ~= nil)
ns.HandleSlash("ask")
suite.check("/bbutler ask on its own closes it", not AskUI:IsShown())

-- The size grip.
AskUI:SetScale(9)
suite.check("the size is kept between 60% and 150%", ns.db.askScale == 1.5)
AskUI.sizeGrip:GetScript("OnMouseDown")(AskUI.sizeGrip, "RightButton")
suite.check("right-click: the normal size", ns.db.askScale == 1)

-- The Butler window has an Ask button.
ns.UI.askButton:GetScript("OnClick")(ns.UI.askButton)
suite.check("the window's Ask button opens it", AskUI:IsShown())

-- The suites share one Lua: leave no sisters behind.
_G.BlackthornesTS, _G.BlackthornesEquipment, _G.BlackthornesFarmer, _G.BlackthornesPets = nil, nil, nil, nil
_G.SlashCmdList.BLACKTHORNESFARMER = nil

suite.done()
