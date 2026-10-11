-- Fill mail sends what an alt's queue wants now, not what it wanted when
-- the bags first held the item (the owner, 2026-10-11: eight Medium Leather
-- crafted one at a time went in the mail as one).
--
-- What must hold:
--   1. An item is judged again when how many of it the bags hold changes.
--   2. Fill mail asks Tradeskills afresh, so a queue changed since the
--      window last asked is what goes.

local env = dofile(lfs_cwd .. "/tools/testenv.lua")
local suite = env.NewSuite("mailcount")

local ns = env.Load()
local fake = env.FakeBags({
    { bag = 0, slot = 1, id = 2319, name = "Medium Leather", quality = 1, price = 15, count = 1 },
})

-- Tradeskills spares whatever the bags hold, up to what the alt's queue
-- wants (8, later 6).
local wants, asked = 8, 0
local function Carried()
    local n = 0
    for _, item in pairs(fake.bags[0]) do if item.id == 2319 then n = n + (item.count or 1) end end
    return n
end
local filled = {}
_G.BlackthornesTS = { Butler = {
    Advise = function(_, id)
        asked = asked + 1
        if id == 2319 then return { mailTo = "Bob Stone", mailCount = math.min(wants, Carried()) } end
    end,
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
env.Enable(ns)
local Verdicts, UI, Errands = ns.Verdicts, ns.UI, ns.Errands

local function MailRow()
    local group = Verdicts:Group("mail")
    for _, row in ipairs(group and group.rows or {}) do
        if row.itemID == 2319 then return row end
    end
end

UI:Show("bags")
Verdicts:Changed(true)
suite.check("one carried: one to mail", MailRow() and MailRow().mailCount == 1)

-- 1. Seven more crafted, one at a time, into the same stack.
for _ = 1, 7 do
    fake.bags[0][1].count = fake.bags[0][1].count + 1
    ns.Bags:Scan()
end
local row = MailRow()
suite.check("eight carried: eight to mail", row and row.mailCount == 8 and row.count == 8,
    row and row.mailCount)

-- A bag change that leaves the item alone asks nothing new about it.
fake.Put({ bag = 0, slot = 2, id = 900, name = "Linen Cloth", quality = 1, price = 13, count = 3 })
local before = asked
ns.Bags:Scan()
Verdicts:Groups()
suite.check("another item's change does not ask about it again", asked == before + 1, asked - before)

env.Fire("MAIL_SHOW")
UI.mailButton:GetScript("OnClick")(UI.mailButton)
local sent = filled[1] and filled[1].items[1]
suite.check("Fill mail sends all eight", sent and sent.itemID == 2319 and sent.count == 8, sent and sent.count)

-- 2. The alt's queue now wants 6: the next fill asks again.
wants = 6
Errands.filled = {}
UI.mailButton:GetScript("OnClick")(UI.mailButton)
sent = filled[2] and filled[2].items[1]
suite.check("a queue changed since sends what it wants now", sent and sent.count == 6, sent and sent.count)
env.Fire("MAIL_CLOSED")

_G.BlackthornesTS = nil
suite.done()
