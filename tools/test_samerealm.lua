-- Only this realm and side: All characters, Who has it, the Bags window's
-- gold and the Always mail picker list only the player's characters on the
-- realm and side of the one playing. The one playing always counts, once.
-- A realm or side Tradeskills does not give is not held against a record.

local env = dofile(lfs_cwd .. "/tools/testenv.lua")
local suite = env.NewSuite("samerealm")

local ns = env.Load()
env.FakeBags({})
_G.GetTime = function() return 100 end
_G.GetMoney = function() return 500 end

_G.BlackthornesTS = { Butler = { Holdings = function()
    return {
        { key = "Player-1", name = "Ana Stone", realm = "Silverpine", faction = "Alliance",
            isCurrent = true, playing = true, gold = 400, bags = { [501] = 2 }, bank = {}, mail = {} },
        { key = "Ana-Old", name = "Ana Stone", realm = "Silverpine", faction = "Alliance",
            isCurrent = false, playing = true, gold = 999, bags = { [501] = 50 }, bank = {}, mail = {} },
        { key = "Player-2", name = "Bob Wither", realm = "silver pine", faction = "Alliance",
            gold = 100, bags = { [501] = 3 }, bank = {}, mail = {} },
        { key = "Player-3", name = "Cid Horde", realm = "Silverpine", faction = "Horde",
            gold = 1000, bags = { [501] = 7 }, bank = {}, mail = {} },
        { key = "Player-4", name = "Dee Far", realm = "Stormreach", faction = "Alliance",
            gold = 2000, bags = { [501] = 11 }, bank = {}, mail = {} },
        { key = "Player-5", name = "Eve Old", realm = "?",
            gold = 10, bags = { [501] = 1 }, bank = {}, mail = {} },
    }
end } }

env.Enable(ns)
local Everyone = ns.Everyone

suite.check("the one playing always counts", Everyone.SameSide({ isCurrent = true, realm = "X" }, { realm = "Y" }))
suite.check("another realm is left out", not Everyone.SameSide({ realm = "X" }, { realm = "Y" }))
suite.check("the other side is left out", not Everyone.SameSide({ realm = "Y", faction = "Horde" }, { realm = "Y", faction = "Alliance" }))
suite.check("a realm not given is kept", Everyone.SameSide({ realm = "?" }, { realm = "Y" }))

local names = {}
for _, character in ipairs(Everyone:Read() or {}) do names[#names + 1] = character.name end
table.sort(names)
local joined = table.concat(names, ", ")
suite.check("All characters: this realm and side only", joined == "Ana Stone, Bob Wither, Eve Old", joined)

local item = ns.WhoHas.Build()[501]
suite.check("Who has it: this realm and side only", item and item.total == 6, item and item.total)

suite.check("Bags gold: this realm and side, the one playing live and once",
    ns.BagView.Gold() == 610, ns.BagView.Gold())

local picker = table.concat(ns.Errands:Characters(), ", ")
suite.check("Always mail picker: this realm and side, not the one playing",
    picker == "Bob Wither, Eve Old", picker)

_G.GetTime = nil
_G.GetMoney = nil
suite.done()
