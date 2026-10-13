-- An item on the Always sell list is sold, unless Equipment says it is an
-- upgrade to wear now: then it shows as Look at it, so it is never sold on
-- a choice made when it was junk. Nothing is deleted.

local env = dofile(lfs_cwd .. "/tools/testenv.lua")
local suite = env.NewSuite("sellupgrade")

local ns = env.Load()
env.FakeBags({
    { bag = 0, slot = 1, id = 701, name = "Thendal Boots", quality = 2, price = 300 },
    { bag = 0, slot = 2, id = 702, name = "Old Boots", quality = 2, price = 300 },
})
env.Enable(ns)

local upgrade = true
_G.BlackthornesEquipment = { Butler = { Advise = function(_, link)
    if tostring(link):find("701", 1, true) and upgrade then return { upgrade = "now" } end
end } }

local Verdicts, UI = ns.Verdicts, ns.UI
Verdicts:SetChoice(701, "sell")
Verdicts:SetChoice(702, "sell")

local function Find(name)
    for _, group in ipairs(Verdicts:Groups()) do
        for _, row in ipairs(group.rows) do
            if row.name == name then return row end
        end
    end
end

UI:Hide()
UI:Show()
local boots = Find("Thendal Boots")
suite.check("an upgrade on Always sell is Look at it", boots and boots.verdict == "look", boots and boots.verdict)
suite.check("the other pair is sold", Find("Old Boots").verdict == "sell", Find("Old Boots").verdict)
suite.check("the list still holds it", ns.db.alwaysSell[701] == true)

upgrade = false
Verdicts:Changed(true)
UI:Hide()
UI:Show()
boots = Find("Thendal Boots")
suite.check("no longer an upgrade: Sell again", boots.verdict == "sell", boots.verdict)

suite.done()
