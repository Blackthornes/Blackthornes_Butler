-- Things about who is playing that must hold for any set of characters,
-- tried with many random ones. A property test states something that can
-- never be false and throws hundreds of made-up cases at it. The seed is
-- fixed so a failure comes back the same each run; the failing case is
-- printed. (The other always-true tests: tools/test_properties_window.lua.)
--
-- What must hold, for any characters on the account:
--   1. Errands:IsMe knows the character playing by its full name in any
--      case or spacing, and with a realm.
--   2. It never takes another character for the one playing, unless the two
--      share the same full name.
--   3. The Always mail list never holds the character playing.
--   4. NameOf never gives a name for the character playing's key.

local env = dofile(lfs_cwd .. "/tools/testenv.lua")
local suite = env.NewSuite("properties")

local ns = env.Load()
env.FakeBags({})

local holdings = {}
_G.BlackthornesTS = { Butler = {
    Advise = function() end,
    FillMail = function() return true end,
    Holdings = function() return holdings end,
    Mailbox = function() end,
} }
env.Enable(ns)
local Errands = ns.Errands

math.randomseed(20261117)
local TRIES = 300

local FIRST = { "Ana", "Bob", "Cor", "Dax", "Eli", "Fen", "Gus", "Ivy" }
local LAST = { "Stone", "Blackthorne", "Reed", "Ash", "Vale" }

local function Name()
    return FIRST[math.random(#FIRST)] .. " " .. LAST[math.random(#LAST)]
end

local function Bend(name)
    local out = name:gsub("%a", function(c)
        return math.random(1, 2) == 1 and c:upper() or c:lower()
    end)
    out = out:gsub(" ", string.rep(" ", math.random(1, 3)))
    if math.random(1, 3) == 1 then out = "  " .. out .. " " end
    if math.random(1, 3) == 1 then out = out .. "-R" end
    return out
end

local version = 0
for i = 1, TRIES do
    for k in pairs(holdings) do holdings[k] = nil end
    local me = Name()
    holdings[1] = { key = "Player-1-" .. i, short = me, name = me, realm = "R", faction = "Horde",
        isCurrent = true, playing = true, gold = 1, goldAt = 1 }
    local others = {}
    for j = 1, math.random(0, 6) do
        local name = Name()
        if name ~= me then
            others[#others + 1] = name
            holdings[#holdings + 1] = { key = "Player-1-" .. i .. "-" .. j, short = name, name = name,
                realm = "R", faction = "Horde", gold = 1, goldAt = 1 }
        end
    end
    version = version + 1
    ns.Verdicts.version = version

    local bent = Bend(me)
    suite.check(("try %d: %q is the one playing (%s)"):format(i, bent, me), Errands:IsMe(bent))
    for _, other in ipairs(others) do
        suite.check(("try %d: %s is not the one playing (%s)"):format(i, other, me), not Errands:IsMe(other))
    end
    for _, listed in ipairs(Errands:Characters() or {}) do
        suite.check(("try %d: the mail list never holds the one playing (%s)"):format(i, me),
            not Errands:IsMe(listed), listed)
    end
    suite.check(("try %d: no name for the one playing's key"):format(i),
        Errands:NameOf("Player-1-" .. i) == nil)
end

suite.done()
