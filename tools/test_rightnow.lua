-- The Right Now card (the owner said build it, 2026-11-26):
--   1. Off unless ticked: no card, the groups as before.
--   2. Ticked, away from a vendor: Sell waits with a dim dot, "At the next
--      vendor.", and the groups below start folded.
--   3. At a vendor: Sell is lit and the secure Sell button sits on its line.
--   4. A group opened by hand stays open while the card is up.
--   5. At most four steps, lit ones first.
--   6. At a mailbox, Fill Mail sits on the step for that character.

local env = dofile(lfs_cwd .. "/tools/testenv.lua")
local suite = env.NewSuite("rightnow")

local ns = env.Load()
local fake = env.FakeBags({
    { bag = 0, slot = 1, id = 401, name = "Broken Fang", quality = 0, price = 12, count = 3 },
    { bag = 0, slot = 2, id = 402, name = "Ruined Pelt", quality = 0, price = 5 },
    { bag = 0, slot = 3, id = 403, name = "Linen Cloth", quality = 1, price = 13, count = 20 },
})
fake.canSell = true
env.Enable(ns)
local UI = ns.UI
UI:Show()

local function Find(kind)
    local found = {}
    for _, line in ipairs(UI:Lines()) do
        if line.type == kind then found[#found + 1] = line end
    end
    return found
end
local function Header(verdict)
    for _, line in ipairs(UI:Lines()) do
        if line.type == "header" and line.group.verdict == verdict then return line end
    end
end

-- 1.
suite.check("off unless ticked", #Find("now") == 0 and ns.db.rightNow == nil)
suite.check("the Sell group is open as before", Header("sell").folded == false)

-- 2.
ns.db.rightNow = true
local steps = Find("now")
suite.check("ticked, the card has a step", #steps >= 1)
suite.check("under a Right Now heading, first", UI:Lines()[1].type == "header"
    and UI:Lines()[1].group.verdict == "now" and UI:Lines()[1].group.label == "Right Now")
suite.check("Sell waits for a vendor", steps[1].title == "Sell 2 items" and steps[1].lit == false
    and steps[1].detail == "At the next vendor.", steps[1].title)
suite.check("the groups below start folded", Header("sell").folded == true)
local row = UI.list.rows[1]
UI.DrawRow(row, steps[1])
suite.check("a dim dot", row.dot and row.dot:IsShown())
suite.check("no button of its own", not row.action:IsShown())

-- 4.
UI:Clicked(Header("sell"), "LeftButton")
suite.check("a group opened by hand stays open", Header("sell").folded == false)
UI:Folded().sell = nil

-- 3.
env.Fire("MERCHANT_SHOW")
UI:Refresh(true)
steps = Find("now")
suite.check("at a vendor Sell is lit", steps[1].lit == true and steps[1].dock == "sell")
suite.check("saying what it is worth", steps[1].detail:find("Buyback", 1, true) ~= nil, steps[1].detail)
local cardRow
for _, r in ipairs(UI.list.rows) do
    if r:IsShown() and r.data and r.data.type == "now" and r.data.key == "sell" then cardRow = r end
end
suite.check("the step is on screen", cardRow ~= nil)
suite.check("the Sell button's place is the card's line", cardRow ~= nil and UI:DockRow("sell") == cardRow)
ns.Selling:Update()
local sellButton = ns.Selling.button
suite.check("the Sell button sits on the step, at its right edge", sellButton and sellButton._point
    and sellButton._point[2] == cardRow and sellButton._point[4] == -8)
UI.UpdateRow(cardRow, cardRow.data)
suite.check("and the step's words stop short of it", cardRow.worth:GetWidth() >= 150)
env.Fire("MERCHANT_CLOSED")

-- 5.
local real = ns.RightNow.Steps
local many = {}
ns.FreeSpace.Read = function() return { free = 1, total = 16, bags = {}, special = {} } end
steps = ns.RightNow:Steps()
suite.check("bags nearly full is a lit step", (function()
    for _, step in ipairs(steps) do if step.key == "space" then return step.lit end end
end)() == true)
suite.check("lit steps come first", steps[1].lit == true and steps[#steps].lit == false)
ns.RightNow.MOST = 1
suite.check("never more than the most", #ns.RightNow:Steps() == 1)
ns.RightNow.MOST = 4

-- 6.
ns.Errands.mailOpen = true
local recipients = ns.Errands.Recipients
ns.Errands.Recipients = function() return { { to = "Ana Stone", items = { { itemID = 403, count = 20 } }, count = 20 } } end
steps = ns.RightNow:Steps()
local mailStep
for _, step in ipairs(steps) do if step.mailTo then mailStep = step end end
suite.check("a Fill mail step for each character", mailStep and mailStep.lit and mailStep.title == "Fill mail to Ana Stone")
UI:PlaceMail({ mailStep })
suite.check("Fill Mail sits on it", UI.fillRows[mailStep] == "Ana Stone")
ns.Errands.Recipients = recipients
ns.Errands.mailOpen = false

-- Off again: nothing changes.
ns.db.rightNow = nil
suite.check("unticked, the card is gone", #Find("now") == 0)
suite.check("and the groups open again", Header("sell").folded == false)

suite.done()
