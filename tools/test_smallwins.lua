-- Three small wins (the owner said build them, 2026-11-26):
--   A. Items kept for an open quest, or that start one, get their own
--      group, Quest Items, first; a quest item no open quest needs stays
--      under Keep. The rows still say Keep.
--   B. One rule for a whole kind (Logic/Kinds.lua): nothing changes until
--      the player picks; a picked rule sorts every item of that kind; a
--      mark on one item wins; Sell never takes what a vendor won't buy; a
--      writ that starts a quest follows its kind's rule.
--   C. A Bags button in the Butler window's header opens Butler Bags.

local env = dofile(lfs_cwd .. "/tools/testenv.lua")
local suite = env.NewSuite("smallwins")

local ns = env.Load()
env.FakeBags({
    { bag = 0, slot = 1, id = 201, name = "Gnoll Paw", quality = 1, price = 3, quest = "item", bind = 4, count = 8 },
    { bag = 0, slot = 2, id = 202, name = "Torn Note", quality = 1, price = 0, quest = "starts" },
    { bag = 0, slot = 3, id = 203, name = "Old Seal", quality = 1, price = 0, quest = "item", bind = 1, bound = true },
    { bag = 0, slot = 4, id = 204, name = "Craftsman's Writ: Linen Bag", quality = 2, price = 50, quest = "starts" },
    { bag = 0, slot = 5, id = 205, name = "Battered Junkbox", quality = 1, price = 25, openable = true },
    { bag = 0, slot = 6, id = 206, name = "Scroll: CWAL", quality = 2, price = 40, class = 0 },
    { bag = 0, slot = 7, id = 207, name = "Recipe: Tasty Fish", quality = 1, price = 30, class = 9 },
    { bag = 0, slot = 8, id = 208, name = "Locked Chest", quality = 1, price = 0, noValue = true },
    { bag = 0, slot = 9, id = 209, name = "Linen Cloth", quality = 1, price = 13, count = 20 },
})
local tips = {
    [206] = { "Scroll: CWAL", "Classes: Mage" },
    [207] = { "Recipe: Tasty Fish", "Already known" },
    [208] = { "Locked Chest", "Locked" },
}
_G.C_TooltipInfo = {
    GetItemByID = function(id)
        local lines = {}
        for _, text in ipairs(tips[id] or {}) do lines[#lines + 1] = { leftText = text } end
        return { lines = lines }
    end,
}
env.Enable(ns)
ns.Quests.Reason = function(_, itemID)
    if itemID == 201 then return "For Gnoll Paws" end
end
ns.UI:Show()

local Verdicts = ns.Verdicts

local function Find(name)
    for _, group in ipairs(Verdicts:Groups()) do
        for _, row in ipairs(group.rows) do
            if row.name == name then return row, group end
        end
    end
end

-- A.
local groups = Verdicts:Groups()
suite.check("Quest Items is the first group", groups[1].verdict == "quest" and groups[1].label == "Quest Items")
local paw, pawGroup = Find("Gnoll Paw")
suite.check("an item an open quest needs is under Quest Items", pawGroup.verdict == "quest")
suite.check("its row still says Keep, with the quest's reason", paw.verdict == "keep" and paw.reason == "For Gnoll Paws")
local _, noteGroup = Find("Torn Note")
suite.check("an item that starts a quest is under Quest Items", noteGroup.verdict == "quest")
local seal, sealGroup = Find("Old Seal")
suite.check("a quest item no open quest needs stays under Keep", sealGroup.verdict == "keep" and seal.verdict == "keep")
suite.check("the window marks the heading like Keep", ns.UI.MARK_FOR.quest == "keep")
suite.check("Verdicts:Group still finds Keep, not Quest Items", Verdicts:Group("keep").verdict == "keep")

-- B. Nothing changes until a kind is picked.
local writ, writGroup = Find("Craftsman's Writ: Linen Bag")
suite.check("with no rule, a writ that starts a quest is kept for it", writGroup.verdict == "quest")
suite.check("no kind rule is saved", ns.db.kindRules == nil)
suite.check("the rule order has the Kinds step", (function()
    for _, id in ipairs(Verdicts.DEFAULT_ORDER) do if id == "kinds" then return true end end
end)() == true)
suite.check("the Order page names it", ns.RuleOrderUI == nil or ns.RuleOrderUI.RULES.kinds ~= nil)

ns.Kinds:SetRule("writs", "sell")
writ, writGroup = Find("Craftsman's Writ: Linen Bag")
suite.check("Writs: Sell puts a writ under Sell", writ.verdict == "sell", writ.verdict)
suite.check("saying it is the player's rule", writ.reason == "Your rule for Writs", writ.reason)
suite.check("saved account wide", ns.db.kindRules.writs == "sell")

ns.Kinds:SetRule("crates", "bank")
suite.check("Crates and Lockboxes: Bank banks an openable box", Find("Battered Junkbox").verdict == "bank")
suite.check("a locked box is a crate too", Find("Locked Chest").verdict == "bank")
ns.Kinds:SetRule("crates", "sell")
suite.check("Sell never takes a box no vendor buys", Find("Locked Chest").verdict == "keep")
suite.check("an openable box a vendor buys is sold", Find("Battered Junkbox").verdict == "sell")

ns.Kinds:SetRule("scrolls", "bank")
suite.check("Mage Scrolls: Bank banks a mage-only consumable", Find("Scroll: CWAL").verdict == "bank")
ns.Kinds:SetRule("recipes", "sell")
suite.check("Recipes I Know: Sell sells a known recipe", Find("Recipe: Tasty Fish").verdict == "sell")
tips[207] = { "Recipe: Tasty Fish" }
Verdicts:Changed(true)
suite.check("a recipe not known yet is left to Butler", Find("Recipe: Tasty Fish").reason ~= "Your rule for Recipes I Know")

suite.check("cloth is no kind", Find("Linen Cloth").reason ~= nil
    and not Find("Linen Cloth").reason:find("Your rule", 1, true))

-- A mark on one item wins over its kind.
Verdicts:SetChoice(204, "keep")
suite.check("a mark on one writ wins over Writs: Sell", Find("Craftsman's Writ: Linen Bag").verdict == "keep")
Verdicts:SetChoice(204, nil)

-- As Butler Says takes the rule away.
ns.Kinds:SetRule("writs", nil)
ns.Kinds:SetRule("crates", nil)
ns.Kinds:SetRule("scrolls", nil)
ns.Kinds:SetRule("recipes", nil)
suite.check("As Butler Says on every kind clears the save", ns.db.kindRules == nil)
local _, back = Find("Craftsman's Writ: Linen Bag")
suite.check("and the writ is kept for its quest again", back.verdict == "quest")
suite.check("a rule that is not a choice is refused", (function()
    ns.Kinds:SetRule("writs", "delete")
    return ns.db.kindRules == nil
end)())
suite.check("the probe has a line", ns.Kinds:ProbeText():find("in bags", 1, true) ~= nil)

-- C.
local toggled = 0
local toggle = ns.BagWindow.Toggle
ns.BagWindow.Toggle = function() toggled = toggled + 1 end
suite.check("the header has a Bags button", ns.UI.bagsButton ~= nil)
local click = ns.UI.bagsButton:GetScript("OnClick")
if click then click(ns.UI.bagsButton, "LeftButton") end
suite.check("clicking it opens Butler Bags", toggled == 1, toggled)
ns.BagWindow.Toggle = toggle

suite.done()
