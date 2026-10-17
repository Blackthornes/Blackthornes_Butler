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

-- Nor what a Farmer goal or the craft queue still needs (2026-10-14).
local goalNeed, queueNeed = 3, 0
_G.BlackthornesFarmer = { Butler = { Advise = function(_, id)
    if id == 702 and goalNeed > 0 then return { goal = "Old Boots", have = 1, target = 4, need = goalNeed } end
end } }
_G.BlackthornesTS = { Butler = { Advise = function(_, id)
    if id == 702 and queueNeed > 0 then return { need = queueNeed } end
end } }
Verdicts:Changed(true)
UI:Hide()
UI:Show()
local old = Find("Old Boots")
suite.check("a goal's item on Always sell is kept", old.verdict == "keep" and old.reason:find("goal", 1, true) ~= nil,
    old.verdict .. " " .. tostring(old.reason))
goalNeed, queueNeed = 0, 2
Verdicts:Changed(true)
UI:Hide()
UI:Show()
old = Find("Old Boots")
suite.check("so is what the craft queue needs", old.verdict == "keep"
    and old.reason:find("craft queue", 1, true) ~= nil, old.verdict .. " " .. tostring(old.reason))
queueNeed = 0
Verdicts:Changed(true)
UI:Hide()
UI:Show()
suite.check("nothing needs it: Sell again", Find("Old Boots").verdict == "sell", Find("Old Boots").verdict)
suite.check("and the list kept it all along", ns.db.alwaysSell[702] == true)
_G.BlackthornesFarmer, _G.BlackthornesTS = nil, nil

-- Always mail gives way to an upgrade to wear now, the same way (2026-10-17).
_G.BlackthornesEquipment = { Butler = { Advise = function(_, link)
    if tostring(link):find("701", 1, true) and upgrade then return { upgrade = "now" } end
end } }
Verdicts:SetChoice(701, "mail", "Someone Else")
upgrade = true
Verdicts:Changed(true)
UI:Hide()
UI:Show()
boots = Find("Thendal Boots")
suite.check("an upgrade on Always mail is Look at it", boots and boots.verdict == "look", boots and boots.verdict)
suite.check("the mail list still holds it", ns.db.alwaysMail[701] == "Someone Else")
upgrade = false
Verdicts:Changed(true)
UI:Hide()
UI:Show()
boots = Find("Thendal Boots")
suite.check("no longer an upgrade: Mail again", boots and boots.verdict == "mail", boots and boots.verdict)

suite.done()
