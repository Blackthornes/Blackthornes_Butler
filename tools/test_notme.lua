-- Never an errand to the character playing (2026-10-11).
--
-- Tradeskills can hold the character playing under two records: its GUID
-- one and an old name-realm one ("Ana", no last name). Read as two
-- characters, Butler filled a mail to the character the player was on and
-- told them to log out for themselves. What must hold, with Tradeskills
-- marking the old record `playing`:
--   1. Errands:IsMe, the one test, knows every name of the character
--      playing: full, first name alone, any case or spacing, with a realm.
--   2. The old record is never a character to mail (the Always mail list,
--      NameOf for Equipment's alt upgrades), never topped up with gold.
--   3. A mail row addressed to any of those names is never filled.
--   4. A job under any of them is here, never one to log out for, and a
--      mail step to the one doing it is dropped.

local env = dofile(lfs_cwd .. "/tools/testenv.lua")
local suite = env.NewSuite("notme")

local ns = env.Load()
local fake = env.FakeBags({
    { bag = 0, slot = 1, id = 401, name = "Bolt of Wool", quality = 1, price = 50, count = 3 },
    { bag = 0, slot = 2, id = 402, name = "Medium Leather", quality = 1, price = 30, count = 8 },
})
fake.money = 2000000

local G = 10000
local now = 1000000
_G.time = function() return now end

local holdings = {
    { key = "Player-1-A", short = "Ana Blackthorne", name = "Ana Blackthorne", realm = "R", faction = "Horde",
      isCurrent = true, playing = true, gold = 1000000, goldAt = now },
    { key = "Ana-R", short = "Ana", name = "Ana", realm = "R", faction = "Horde", playing = true,
      gold = 1 * G, goldAt = now },
    { key = "Player-1-B", short = "Bob Stone", name = "Bob Stone", realm = "R", faction = "Horde",
      gold = 5 * G, goldAt = now },
}
local filled = {}
_G.BlackthornesTS = { Butler = {
    Advise = function(_, id)
        -- What an old record of the character playing led to: its own
        -- leather offered back to it, under its old short name.
        if id == 402 then return { mailTo = "Ana", mailCount = 8 } end
        if id == 401 then return { mailTo = "ana  blackthorne", mailCount = 3 } end
    end,
    FillMail = function(_, name, items, money)
        filled[#filled + 1] = { name = name, items = items, money = money }
        return true
    end,
    Holdings = function() return holdings end,
    Mailbox = function() end,
} }
env.Enable(ns)

local Errands, Verdicts, Funds, Jobs = ns.Errands, ns.Verdicts, ns.Funds, ns.Jobs

-- 1. The one test.
suite.check("the full name is me", Errands:IsMe("Ana Blackthorne"))
suite.check("in any case and spacing", Errands:IsMe("  ana   BLACKTHORNE "))
suite.check("with the realm", Errands:IsMe("Ana Blackthorne-R"))
suite.check("the old record's first name alone is me", Errands:IsMe("Ana"))
suite.check("another character is not", not Errands:IsMe("Bob Stone"))
suite.check("another Ana with a last name is not", not Errands:IsMe("Ana Stone"))
suite.check("no name is not", not Errands:IsMe(nil) and not Errands:IsMe(""))

-- 2. Never a character to mail or top up.
local names = Errands:Characters()
suite.check("the Always mail list has only Bob", #names == 1 and names[1] == "Bob Stone", table.concat(names, ", "))
suite.check("the old record has no name for Equipment's alt upgrades", Errands:NameOf("Ana-R") == nil)
suite.check("nor the GUID one", Errands:NameOf("Player-1-A") == nil)
suite.check("Bob does", Errands:NameOf("Player-1-B") == "Bob Stone")
Funds:SetMinimum(50 * G)
local plan = Funds:Plan()
suite.check("gold goes only to Bob", #plan == 1 and plan[1].to == "Bob Stone", plan[1] and plan[1].to)

-- 3. A mail to any name of the character playing is never filled.
ns.UI:Show()
Verdicts:Changed(true)
for _, recipient in ipairs(Errands:Recipients()) do
    suite.check("no mail is for the character playing: " .. recipient.to, not Errands:IsMe(recipient.to))
end
Errands.mailOpen = true
Errands.filled = {}
for _ = 1, 3 do Errands:FillMail() end
for _, mail in ipairs(filled) do
    suite.check("filled only for someone else: " .. mail.name, not Errands:IsMe(mail.name))
end
suite.check("the leather is not a Mail row", (function()
    for _, row in ipairs((Verdicts:Group("mail") or {}).rows or {}) do
        if row.itemID == 402 then return false end
    end
    return true
end)())

-- 4. Jobs.
local clean = Jobs.Clean({ { name = "Ana Blackthorne", isCurrent = true, steps = {
    { kind = "mail", to = "ana blackthorne", items = { { itemID = 2319, count = 8 } } },
} } })
suite.check("a mail step to the one doing it is dropped, whatever its case", #clean == 0, #clean)
Jobs.list, Jobs.readKey = nil, nil
_G.BlackthornesTS.Butler.Jobs = function()
    return {
        { name = "Ana", steps = { { kind = "mail", to = "Bob Stone", items = { { itemID = 2319, count = 8 } } } } },
        { name = "Bob Stone", steps = { { kind = "mail", to = "Cy Far", items = { { itemID = 2318, count = 4 } } } } },
    }
end
Jobs:Changed()
local jobs = Jobs:Plan()
suite.check("a job under the old name is here", jobs.here ~= nil and #jobs.here.steps == 1)
suite.check("and never one to log out for", jobs.nextJob == nil or not Errands:IsMe(jobs.nextJob.name),
    jobs.nextJob and jobs.nextJob.name)

suite.done()
