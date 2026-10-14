-- Always mail keeps back what this character's own queued crafts need (the
-- owner, 2026-10-14: "if a material is needed for a queued craft on a
-- character, butler should not recommend mailing it even if the mail to
-- setting is set for that material. Anything above what is needed can be
-- mailed").
--
-- What must hold:
--   1. With the queue needing all of it, an Always mail item is kept.
--   2. With more than the queue needs, only the rest is mailed, and Fill
--      mail sends that many.
--   3. Without Tradeskills (or nothing queued), Always mail sends it all.

local env = dofile(lfs_cwd .. "/tools/testenv.lua")
local suite = env.NewSuite("alwaysmailqueue")

local ns = env.Load()
local fake = env.FakeBags({
    { bag = 0, slot = 1, id = 2319, name = "Medium Leather", quality = 1, price = 15, count = 10 },
})

local need = 10
local filled = {}
local ts = { Butler = {
    Advise = function(_, id)
        if id == 2319 then return { need = need } end
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
_G.BlackthornesTS = ts
env.Enable(ns)
local Verdicts, UI = ns.Verdicts, ns.UI

local function Row()
    for _, group in ipairs(Verdicts:Groups()) do
        for _, row in ipairs(group.rows) do
            if row.itemID == 2319 then return row end
        end
    end
end

Verdicts:SetChoice(2319, "mail", "Bob Stone")
UI:Show("bags")

-- 1. The queue needs all ten: kept.
Verdicts:Changed(true)
local row = Row()
suite.check("queue needs it all: kept", row.verdict == "keep", row.verdict)
suite.check("saying why", row.reason:find("craft queue needs 10", 1, true) ~= nil, row.reason)

-- 2. The queue needs four of ten: six go.
need = 4
Verdicts:Changed(true)
row = Row()
suite.check("the rest goes under Mail", row.verdict == "mail", row.verdict)
suite.check("to the list's character", row.mailTo == "Bob Stone", row.mailTo)
suite.check("only the spare six", row.mailCount == 6, row.mailCount)
env.Fire("MAIL_SHOW")
UI.mailButton:GetScript("OnClick")(UI.mailButton)
local sent = filled[1] and filled[1].items[1]
suite.check("Fill mail sends six", sent and sent.itemID == 2319 and sent.count == 6, sent and sent.count)

-- 3. Nothing queued, then no Tradeskills: all of it goes.
need = nil
Verdicts:Changed(true)
row = Row()
suite.check("nothing queued: all mailed", row.verdict == "mail" and not row.mailCount, row.mailCount)
_G.BlackthornesTS = nil
Verdicts:Changed(true)
row = Row()
suite.check("without Tradeskills: all mailed", row.verdict == "mail" and row.mailTo == "Bob Stone", row.verdict)

suite.done()
