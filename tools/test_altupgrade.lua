-- Gear that is an upgrade for another character goes in the mail to them,
-- but only as many as they wear (a player found two pairs of the same
-- pants going in one mail, 2026-10-11).
--
-- What must hold:
--   1. One copy goes to the alt; two for rings and trinkets.
--   2. A copy past that gets its own verdict (here, the vendor's Sell).
--   3. Fill mail sends only the alt's copies.
--   4. Once the mail goes, a copy left behind isn't offered again.
--   5. The Sell button sells the extra copy, though the item is also
--      someone's upgrade.

local env = dofile(lfs_cwd .. "/tools/testenv.lua")
local suite = env.NewSuite("altupgrade")

local ns = env.Load()
local fake = env.FakeBags({
    { bag = 0, slot = 1, id = 405, name = "Heavy Woolen Pants", quality = 2, price = 100 },
    { bag = 0, slot = 2, id = 405, name = "Heavy Woolen Pants", quality = 2, price = 100 },
    { bag = 0, slot = 3, id = 406, name = "Copper Band", quality = 2, price = 50 },
    { bag = 0, slot = 4, id = 406, name = "Copper Band", quality = 2, price = 50 },
    { bag = 0, slot = 5, id = 406, name = "Copper Band", quality = 2, price = 50 },
})
local instant = C_Item.GetItemInfoInstant
C_Item.GetItemInfoInstant = function(id)
    local a, b, c, _, e, f, g = instant(id)
    return a, b, c, id == 406 and "INVTYPE_FINGER" or "INVTYPE_LEGS", e, f, g
end

local filled = {}
_G.BlackthornesTS = { Butler = {
    Advise = function() return { auction = 0 } end,
    FillMail = function(_, name, items)
        filled[#filled + 1] = { name = name, items = items }
        return true
    end,
    Holdings = function()
        return {
            { key = "me", short = "Me Here", realm = "R", faction = "Horde", isCurrent = true },
            { key = "bob", short = "Bob Stone", realm = "R", faction = "Horde" },
        }
    end,
    Mailbox = function() end,
} }
_G.BlackthornesEquipment = { Butler = { Advise = function(_, link)
    return { alt = { key = "bob" } }
end } }
env.Enable(ns)
local Verdicts, UI = ns.Verdicts, ns.UI

local function Rows(verdict)
    local group = Verdicts:Group(verdict)
    local byID = {}
    for _, row in ipairs(group and group.rows or {}) do byID[row.itemID] = row end
    return byID
end

UI:Show("bags")
Verdicts:Changed(true)
local mail, sell = Rows("mail"), Rows("sell")

-- 1 and 2.
suite.check("one pair of pants goes to the alt", mail[405] and mail[405].count == 1 and mail[405].mailCount == 1,
    mail[405] and mail[405].count)
suite.check("the other pair gets its own verdict", sell[405] and sell[405].count == 1, sell[405] and sell[405].verdict)
suite.check("two rings go: a character wears two", mail[406] and mail[406].count == 2, mail[406] and mail[406].count)
suite.check("the third ring is its own", sell[406] and sell[406].count == 1)

-- 5. The Sell button's last look agrees with the window.
local extra = ns.Bags.ReadSlot(0, 2)
suite.check("the extra copy reads as Sell when a click checks it", Verdicts:VerdictOf(extra) == "sell",
    Verdicts:VerdictOf(extra))
suite.check("the alt's copy still reads as Mail", Verdicts:VerdictOf(ns.Bags.ReadSlot(0, 1)) == "mail")

-- 3. Fill mail sends only those.
env.Fire("MAIL_SHOW")
UI.mailButton:GetScript("OnClick")(UI.mailButton)
local counts = {}
for _, item in ipairs(filled[1] and filled[1].items or {}) do counts[item.itemID] = item.count end
suite.check("Fill mail sends one pair and two rings", counts[405] == 1 and counts[406] == 2,
    tostring(counts[405]) .. " " .. tostring(counts[406]))

-- 4. The mail goes: a copy left behind is not offered again.
fake.bags[0][1], fake.bags[0][3], fake.bags[0][4] = nil, nil, nil
env.Fire("MAIL_SEND_SUCCESS")
suite.check("what went is written down", ns.db.upgradeMailed[405] and ns.db.upgradeMailed[405].count == 1
    and ns.db.upgradeMailed[405].to == "Bob Stone")
ns.Bags:Scan()
mail = Rows("mail")
suite.check("the pair left isn't mailed again", mail[405] == nil)
suite.check("nor the ring left", mail[406] == nil)
env.Fire("MAIL_CLOSED")

-- After 30 days unclaimed mail goes back, and it is offered again.
ns.db.upgradeMailed[405].at = time() - Verdicts.MAILED_KEEP - 1
Verdicts:Changed(true)
suite.check("after 30 days it is offered again", Rows("mail")[405] ~= nil)

_G.BlackthornesEquipment = nil
_G.BlackthornesTS = nil
suite.done()
