-- Food to Keep (Pets' Pet page): Pets says how much of each food stays and
-- how much is extra; Butler keeps enough stacks and mails the rest to the
-- bank alt. With no bank alt, or the bank alt playing, it all stays.

local env = dofile(lfs_cwd .. "/tools/testenv.lua")
local suite = env.NewSuite("petfoodkeep")

local ns = env.Load()
env.FakeBags({
    { bag = 0, slot = 1, id = 117, name = "Tough Jerky", count = 10, price = 1, stack = 20 },
    { bag = 0, slot = 2, id = 117, name = "Tough Jerky", count = 10, price = 1, stack = 20 },
    { bag = 0, slot = 3, id = 2287, name = "Haunch of Meat", count = 6, price = 2, stack = 20 },
})
_G.UnitGUID = function(unit) if unit == "player" then return "Player-1-0000AAAA" end end
_G.UnitName = function() return "Ana Thornfield" end
env.Enable(ns)

local Verdicts, UI = ns.Verdicts, ns.UI

-- Pets keeps 14: all 20 jerky would be too many, so 14 jerky stay and the
-- haunches are all extra (Pets shares the number out best first).
local answers = {}
_G.BlackthornesPets = { Butler = { Advise = function(_, id) return answers[id] end } }
local function Off()
    answers[117] = { eats = true, buff = false, hours = 2, count = 20 }
    answers[2287] = { eats = true, buff = false, hours = 2, count = 6 }
end
local function On()
    answers[117] = { eats = true, buff = false, hours = 2, count = 20, keepAll = 14, keep = 14, extra = 6 }
    answers[2287] = { eats = true, buff = false, hours = 2, count = 6, keepAll = 14, keep = 0, extra = 6 }
end

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
local function Count(name, verdict)
    local count = 0
    for _, row in ipairs(Rows(name)) do
        if row.verdict == verdict then count = count + row.count end
    end
    return count
end
local function Mail(name)
    for _, row in ipairs(Rows(name)) do
        if row.verdict == "mail" then return row end
    end
end

-- Off in Pets: every piece is kept, as before.
Off()
ns.BankAlt:SetName("Bramble Stonehaven")
suite.check("off in Pets, all jerky is kept", Count("Tough Jerky", "keep") == 20, Count("Tough Jerky", "keep"))
suite.check("off in Pets, nothing is mailed", Count("Haunch of Meat", "mail") == 0)

-- On, with a bank alt: what Pets keeps stays, the rest goes to the bank alt.
On()
suite.check("the food kept stays", Count("Tough Jerky", "keep") >= 14, Count("Tough Jerky", "keep"))
suite.check("food past the number is mailed", Count("Haunch of Meat", "mail") == 6, Count("Haunch of Meat", "mail"))
local row = Mail("Haunch of Meat")
suite.check("to the bank alt", row and row.mailTo == "Bramble Stonehaven", row and row.mailTo)
suite.check("the row says why", row and row.reason == "Extra pet food. Pets keeps 14.", row and row.reason)
suite.check("nothing is sold for it", Count("Haunch of Meat", "sell") == 0 and Count("Tough Jerky", "sell") == 0)

-- No bank alt: it all stays.
ns.BankAlt:SetName(nil)
suite.check("no bank alt, the haunches stay", Count("Haunch of Meat", "keep") == 6, Count("Haunch of Meat", "keep"))
suite.check("no bank alt, nothing is mailed", Count("Haunch of Meat", "mail") == 0)

-- The bank alt is the one playing: it all stays.
ns.BankAlt:SetName("Ana Thornfield")
suite.check("on the bank alt, nothing is mailed", Count("Haunch of Meat", "mail") == 0
    and Count("Haunch of Meat", "keep") == 6)

-- The player's own Keep on This Character wins.
ns.BankAlt:SetName("Bramble Stonehaven")
ns.KeepHere:Set(2287, 6)
suite.check("the player's own keep wins", Count("Haunch of Meat", "keep") == 6
    and Count("Haunch of Meat", "mail") == 0, Count("Haunch of Meat", "mail"))
ns.KeepHere:Set(2287, 0)

_G.BlackthornesPets = nil
suite.done()
