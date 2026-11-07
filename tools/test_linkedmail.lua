-- Mail to a character on the player's other account (Trent, 2026-11-07,
-- a player with three accounts). With Tradeskills' Share Craft Queue
-- ticked on both accounts, Tradeskills can name a linked character in
-- Advise's mailTo and in a mail step of Jobs(). Butler takes the name as
-- it takes any alt's.
--
-- What must hold:
--   1. The item is a Mail row to the linked character, full name.
--   2. Fill mail hands that full name to Tradeskills.
--   3. The mail step stays on the character playing's line, and no line
--      (no Log out) is made for the linked character.
--   4. Nothing is mailed to the character playing, linked name or not.

local env = dofile(lfs_cwd .. "/tools/testenv.lua")
local suite = env.NewSuite("linkedmail")

local ns = env.Load()
env.FakeBags({
    { bag = 0, slot = 1, id = 2592, name = "Wool Cloth", quality = 1, price = 33, count = 20 },
})
_G.C_Item.GetItemNameByID = function(id) return ({ [2592] = "Wool Cloth" })[id] end

local mailTo = "Loom Weaver"
local filled = {}
local jobs = {
    { name = "Bob Stone", isCurrent = true, steps = {
        { kind = "mail", to = "Loom Weaver", items = { { itemID = 2592, count = 6 } } },
    } },
}
_G.BlackthornesTS = { Butler = {
    Advise = function(_, id)
        if id == 2592 then return { mailTo = mailTo, mailCount = 6 } end
    end,
    FillMail = function(_, name, items)
        filled[#filled + 1] = { name = name, items = items }
        return true, nil, name
    end,
    Holdings = function()
        return {
            { key = "Player-1-BOB", name = "Bob Stone", short = "Bob Stone", realm = "Forever Realm 7 PvE",
              faction = "Horde", isCurrent = true },
            { key = "Player-2-LOOM", name = "Loom Weaver", short = "Loom Weaver", realm = "Forever Realm 3 PvE",
              faction = "Horde", linked = "Loom" },
        }
    end,
    Jobs = function() return jobs end,
    Mailbox = function() end,
} }
env.Enable(ns)
local Verdicts, UI, Jobs = ns.Verdicts, ns.UI, ns.Jobs

local function MailRow()
    local group = Verdicts:Group("mail")
    for _, row in ipairs(group and group.rows or {}) do
        if row.itemID == 2592 then return row end
    end
end

UI:Show("bags")
Verdicts:Changed(true)

-- 1.
local row = MailRow()
suite.check("a Mail row to the linked character", row and row.mailTo == "Loom Weaver" and row.mailCount == 6,
    row and row.mailTo)

-- 2.
env.Fire("MAIL_SHOW")
ns.Errands:FillMail("Loom Weaver")
local sent = filled[1]
suite.check("Fill mail hands over the full name", sent and sent.name == "Loom Weaver", sent and sent.name)
suite.check("with the six wool", sent and sent.items[1] and sent.items[1].itemID == 2592
    and sent.items[1].count == 6, sent and sent.items[1] and sent.items[1].count)
env.Fire("MAIL_CLOSED")

-- 3.
Jobs:Changed()
local plan = Jobs:Plan()
suite.check("the mail step is on the character playing's line",
    plan.here and plan.here.steps[1] and plan.here.steps[1].to == "Loom Weaver")
suite.check("and no line for the linked character", plan.nextJob == nil and #plan.others == 0)

-- 4.
mailTo = "Bob Stone"
Verdicts:Changed(true)
row = MailRow()
suite.check("never a Mail row to the character playing", row == nil)

_G.BlackthornesTS = nil
suite.done()
