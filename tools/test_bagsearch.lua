-- Your bags has a search box, as All characters has (the owner said yes,
-- 2026-10-13).
--
-- What must hold:
--   1. The box shows on Your bags, in the place All characters' sits.
--   2. Typing shows only the items whose name matches, under their groups,
--      even a folded one; the ammo, jobs and gold lines wait.
--   3. No match says so; clearing the box shows everything again.
--   4. Each view keeps its own words.

local env = dofile(lfs_cwd .. "/tools/testenv.lua")
local suite = env.NewSuite("bagsearch")

local ns = env.Load()
env.FakeBags({
    { bag = 0, slot = 1, id = 2452, name = "Swiftthistle", quality = 1, price = 15, count = 6 },
    { bag = 0, slot = 2, id = 2449, name = "Earthroot", quality = 1, price = 5, count = 8 },
    { bag = 0, slot = 3, id = 2589, name = "Linen Cloth", quality = 1, price = 13, count = 20 },
    { bag = 0, slot = 4, id = 3300, name = "Rabbit's Foot", quality = 0, price = 7 },
})
env.Enable(ns)
local UI, Verdicts = ns.UI, ns.Verdicts

UI:Show("bags")
Verdicts:Changed(true)
UI:Refresh(true)

local function Items()
    local names = {}
    for _, line in ipairs(UI:Lines()) do
        if line.type == "item" then names[#names + 1] = line.name end
    end
    table.sort(names)
    return table.concat(names, ",")
end

-- 1.
suite.check("the search shows on Your bags", UI.bagSearch:IsShown() and not UI.search:IsShown())
local all = Items()
suite.check("everything shows with the box empty", all:find("Earthroot") and all:find("Rabbit"), all)

-- 2.
UI:Folded().sell = true
UI.bagSearch:SetText("root")
suite.check("only the match shows", Items() == "Earthroot", Items())
UI.bagSearch:SetText("RABBIT")
suite.check("any case, and a folded group opens for it", Items() == "Rabbit's Foot", Items())
local header
for _, line in ipairs(UI:Lines()) do if line.type == "header" then header = line end end
suite.check("its heading counts what matched", header and header.group.count == 1 and header.group.verdict == "sell")
UI.bagSearch:SetText("2589")
suite.check("an item ID finds it too", Items() == "Linen Cloth", Items())

-- 3.
UI.bagSearch:SetText("nothing like it")
UI:Refresh()
suite.check("no match says so", UI.emptyLabel:IsShown() and UI.emptyLabel:GetText():find("Nothing matches", 1, true))
UI:Folded().sell = nil
UI.bagSearch:SetText("")
UI:Refresh()
suite.check("cleared, everything is back", Items() == all and not UI.emptyLabel:IsShown())

-- 4.
UI.bagSearch:SetText("linen")
UI:SetView("all")
suite.check("All characters has its own box", UI.search:IsShown() and not UI.bagSearch:IsShown()
    and UI.search:GetText() == "")
UI:SetView("bags")
suite.check("and Your bags keeps its words", UI.bagSearch:GetText() == "linen")

suite.done()
