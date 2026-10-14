-- Materials another character's queued crafts need go in the mail, even
-- when something else would keep or sell them here (a player's alchemist
-- was never sent its herbs and vials, 2026-10-14): an item on the Always
-- sell list, one Butler learned to keep from a buyback, and one no vendor
-- buys. Only the share Tradeskills names goes; soulbound never does.

local env = dofile(lfs_cwd .. "/tools/testenv.lua")
local suite = env.NewSuite("altcraftfirst")

local ns = env.Load()
env.FakeBags({
    { bag = 0, slot = 1, id = 785, name = "Mageroyal", count = 20, quality = 1, price = 5 },
    { bag = 0, slot = 2, id = 3372, name = "Leaded Vial", count = 10, quality = 1, price = 10 },
    { bag = 0, slot = 3, id = 900, name = "Odd Reagent", count = 4, quality = 1, price = 0, noValue = true },
    { bag = 0, slot = 4, id = 901, name = "Bound Reagent", count = 2, quality = 1, price = 0,
      noValue = true, bound = true },
})
env.Enable(ns)

local ALT = "Alice Alchemist"
local shares = { [785] = 12, [3372] = 6, [900] = 3, [901] = 2 }
_G.BlackthornesTS = { Butler = { Advise = function(_, id)
    if shares[id] then return { mailTo = ALT, mailCount = shares[id] } end
end } }

local Verdicts, UI = ns.Verdicts, ns.UI

local function Find(name)
    for _, group in ipairs(Verdicts:Groups()) do
        for _, row in ipairs(group.rows) do
            if row.name == name then return row end
        end
    end
end

local function Fresh()
    Verdicts:Changed(true)
    UI:Hide()
    UI:Show()
end

Verdicts:SetChoice(785, "sell")
ns.Learning.Get = function(_, id) if id == 3372 then return "keep" end end
Fresh()

local herb = Find("Mageroyal")
suite.check("Always sell gives the alt's craft its share", herb and herb.verdict == "mail", herb and herb.verdict)
suite.check("to the alt", herb.mailTo == ALT, herb.mailTo)
suite.check("only what it needs", herb.mailCount == 12, herb.mailCount)
suite.check("the list still holds it", ns.db.alwaysSell[785] == true)

local vial = Find("Leaded Vial")
suite.check("a learned keep gives the alt its share too", vial and vial.verdict == "mail", vial and vial.verdict)
suite.check("six of them", vial.mailCount == 6, vial.mailCount)

local odd = Find("Odd Reagent")
suite.check("no vendor buys it, but the alt's craft does", odd and odd.verdict == "mail", odd and odd.verdict)
suite.check("three of it", odd.mailCount == 3, odd.mailCount)

local bound = Find("Bound Reagent")
suite.check("soulbound is kept", bound and bound.verdict == "keep", bound and bound.verdict)

-- Once the alt needs nothing, each goes back to what it was.
shares = {}
Fresh()
suite.check("Always sell sells again", Find("Mageroyal").verdict == "sell", Find("Mageroyal").verdict)
suite.check("the learned keep keeps again", Find("Leaded Vial").verdict == "keep", Find("Leaded Vial").verdict)
suite.check("no vendor value is kept", Find("Odd Reagent").verdict == "keep", Find("Odd Reagent").verdict)

-- Never to the character playing.
shares = { [785] = 12 }
_G.BlackthornesTS.Butler.Advise = function(_, id)
    if shares[id] then return { mailTo = "Me Here", mailCount = shares[id] } end
end
local isMe = ns.Errands.IsMe
ns.Errands.IsMe = function(_, name) return name == "Me Here" end
Fresh()
suite.check("the character playing is never mailed", Find("Mageroyal").verdict == "sell", Find("Mageroyal").verdict)
ns.Errands.IsMe = isMe
_G.BlackthornesTS = nil

suite.done()
