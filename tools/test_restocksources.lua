-- The restock list, part 2 (the owner said "build 1-10", 2026-11-26): where
-- else a low line can come from, in order of cost.
--
-- What must hold:
--   1. Your own bank first: "Your bank has 3."
--   2. Another character who can spare some (past what it keeps): "Ana
--      Stone has 40 in the bank." and Add a Job, which saves an ask.
--      Never the character playing.
--   3. On that character the ask is a RESTOCK row with Fill Mail at a
--      mailbox, a mail recipient and a take from the bank; it goes once
--      mailed, and the one who asked drops it once it has enough.
--   4. A craft one of your characters can make: "NAME can make them." and
--      Queue, which queues enough crafts in Tradeskills.
--   5. The auction house: the price, and Search only at the auction house.
--      Nothing is bought.

local env = dofile(lfs_cwd .. "/tools/testenv.lua")
local suite = env.NewSuite("restocksources")

local ns = env.Load()
local POTION, BANDAGE, SILK = 929, 1251, 4306
local fake = env.FakeBags({
    { bag = 0, slot = 1, id = POTION, name = "Healing Potion", count = 1, price = 100, stack = 5, class = 0, subclass = 1 },
    { bag = 0, slot = 2, id = SILK, name = "Silk Bandage", count = 2, price = 10, stack = 20, class = 0, subclass = 7 },
})
fake.info[BANDAGE] = { id = BANDAGE, name = "Linen Bandage", price = 5, stack = 20 }

local MIRA, ANA = "Player-1-0000AAAA", "Player-1-0000BBBB"
local playing = MIRA
_G.UnitGUID = function(unit) if unit == "player" then return playing end end
_G.UnitName = function() return playing == MIRA and "Mira" or "Ana" end
_G.UnitLevel = function() return 20 end

local holdings
local function Holdings()
    return {
        { key = MIRA, name = "Mira Vale", short = "Mira Vale", isCurrent = playing == MIRA, playing = playing == MIRA,
          bags = playing == MIRA and { [POTION] = 1, [SILK] = 2 } or {}, bank = { [POTION] = 3 }, mail = {} },
        { key = ANA, name = "Ana Stone", short = "Ana Stone", isCurrent = playing == ANA, playing = playing == ANA,
          bags = playing == ANA and { [BANDAGE] = 40 } or {}, bank = playing == ANA and {} or { [BANDAGE] = 40 }, mail = {} },
    }
end
local queued, searched, makers = {}, nil, nil
_G.BlackthornesTS = { Butler = {
    Advise = function() return nil end,
    Holdings = function() return holdings and holdings() end,
    MakersOf = function(_, itemID) return makers and makers[itemID] end,
    QueueCraft = function(_, recipeID, crafts) queued[recipeID] = crafts return true end,
    SearchAuctions = function(_, items) searched = items return true, "all" end,
} }
holdings = Holdings
_G.BlackthornesTS_API = { GetPrice = function(itemID) return itemID == SILK and 210 or nil end }

env.Enable(ns)
local Restock, UI = ns.Restock, ns.UI

local function Fresh()
    ns.Bags:Scan()
    ns.KeepAcross.read = nil
    Restock.lowKey, Restock.offerKey, Restock.sourcesKey = nil, nil, nil
    ns.Verdicts:Changed(true)
end
Fresh()

local function RowFor(item)
    for _, row in ipairs(Restock:Rows()) do
        if (row.low and row.low.item == item) or (row.ask and row.ask.itemID == item) then return row end
    end
    return nil
end

Restock:Set(POTION, 5)
Restock:Set(BANDAGE, 20)
Restock:Set(SILK, 10)
Fresh()

-- 1. Your own bank first.
local potion = RowFor(POTION)
suite.check("the potion is low", potion ~= nil and potion.low.need == 4)
suite.check("your bank comes first", env.Plain(Restock.RowReason(potion)):find("^Your bank has 3%.") ~= nil,
    env.Plain(Restock.RowReason(potion)))

-- 2. Another character who can spare some.
local bandage = RowFor(BANDAGE)
suite.check("Ana can spare bandages", env.Plain(Restock.RowReason(bandage)) == "Ana Stone has 40 in the bank.",
    env.Plain(Restock.RowReason(bandage)))
local action = Restock.RowAction(bandage)
suite.check("with Add a Job", action and action.label == "Add a Job", action and action.label)
ns.KeepHere:Set(BANDAGE, 30, ANA)
Fresh()
suite.check("what Ana keeps herself isn't spare",
    env.Plain(Restock.RowReason(RowFor(BANDAGE))) == "Ana Stone has 10 in the bank.",
    env.Plain(Restock.RowReason(RowFor(BANDAGE))))
ns.KeepHere:Set(BANDAGE, 0, ANA)
Fresh()
bandage = RowFor(BANDAGE)
action = Restock.RowAction(bandage)
suite.check("the click saves an ask", action.run() == true and #ns.db.restockAsks == 1
    and ns.db.restockAsks[1].from == ANA and ns.db.restockAsks[1].count == 20
    and ns.db.restockAsks[1].toGUID == MIRA)
Fresh()
bandage = RowFor(BANDAGE)
suite.check("then says so", env.Plain(Restock.RowReason(bandage)):find("Asked Ana Stone to mail 20.", 1, true) ~= nil,
    env.Plain(Restock.RowReason(bandage)))
suite.check("and no second Add a Job", Restock.RowAction(bandage) == nil)
suite.check("never the character playing", Restock:Ask(BANDAGE, { key = MIRA, name = "Mira Vale", isCurrent = true }, 5) == false)
suite.check("the one playing doesn't do its own ask", #Restock:AsksHere() == 0)

-- 4. A craft one of yours can make.
makers = { [SILK] = { recipeID = 7929, per = 1, makers = { { short = "Ana Stone", playing = false } } } }
Fresh()
local silk = RowFor(SILK)
local reason = env.Plain(Restock.RowReason(silk))
suite.check("Ana can make silk bandages", reason:find("Ana Stone can make them.", 1, true) ~= nil, reason)
-- 5. The auction house: its price too.
suite.check("and the auction house price", reason:find("On the auction house, about 2s 10c each.", 1, true) ~= nil, reason)
action = Restock.RowAction(silk)
suite.check("away from the auction house: Queue", action and action.label == "Queue", action and action.label)
action.run()
suite.check("which queues enough crafts", queued[7929] == 8, queued[7929])
ns.Quests.auctionOpen = true
action = Restock.RowAction(silk)
suite.check("at the auction house: Search", action and action.label == "Search", action and action.label)
action.run()
suite.check("which searches for what's short", searched and searched[1].itemID == SILK and searched[1].count == 8)
suite.check("and buys nothing", fake.money == 0)
ns.Quests.auctionOpen = false

-- 3. On Ana: the ask is a mail.
playing = ANA
fake.bags[0][1], fake.bags[0][2] = nil, nil
fake.Put({ bag = 0, slot = 3, id = BANDAGE, name = "Linen Bandage", count = 20, price = 5, stack = 20 })
Fresh()
local asks = Restock:AsksHere()
suite.check("Ana sees Mira's ask", #asks == 1 and asks[1].to == "Mira Vale")
local ask = RowFor(BANDAGE)
suite.check("as a RESTOCK row", ask and ask.ask and env.Plain(Restock.RowName(ask)) == "Mail 20 Linen Bandage to Mira Vale",
    ask and env.Plain(Restock.RowName(ask)))
suite.check("saying why", Restock.RowReason(ask) == "Mira Vale runs low on these.")
local found
for _, recipient in ipairs(ns.Errands:Recipients()) do
    if recipient.to == "Mira Vale" then found = recipient end
end
suite.check("Mira is a mail recipient", found and found.byID[BANDAGE] and found.byID[BANDAGE].count == 20)
ns.Errands.mailOpen = true
local lines = UI:Lines()
local filled
for _, line in ipairs(lines) do
    if line.type == "restock" and UI.fillRows[line] == "Mira Vale" then filled = true end
end
suite.check("Fill Mail sits on the row at a mailbox", filled)
ns.Errands.mailOpen = false
fake.bags[0][3] = { bag = 0, slot = 3, id = BANDAGE, name = "Linen Bandage", count = 5, price = 5, stack = 20 }
Fresh()
suite.check("with too few in the bags, the bank gives the rest", ns.Errands:BankWants()[BANDAGE] == 15,
    ns.Errands:BankWants()[BANDAGE])
Restock:Mailed("Mira Vale", { [BANDAGE] = 20 })
suite.check("once mailed, the ask goes", #ns.db.restockAsks == 0)

-- 3. Back on Mira: an ask she no longer needs goes.
playing = MIRA
Restock:Ask(BANDAGE, { key = ANA, name = "Ana Stone" }, 20)
fake.Put({ bag = 0, slot = 4, id = BANDAGE, name = "Linen Bandage", count = 20, price = 5, stack = 20 })
Fresh()
Restock:Rows()
suite.check("with enough now, Mira's ask goes", #ns.db.restockAsks == 0, #ns.db.restockAsks)

-- The next suite starts with no Tradeskills.
_G.BlackthornesTS, _G.BlackthornesTS_API = nil, nil

suite.done()
