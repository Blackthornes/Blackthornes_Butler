-- Tradeskills' disenchanter (the owner asked 2026-10-11: "butler should
-- follow the mail disenchantable ... setting from Tradeskills for your DE
-- character when suggesting mails").
--
-- What must hold:
--   1. Gear Tradeskills names its `disenchanter` for goes under Mail to
--      them, even when the auction house pays more, with a Fill mail target.
--   2. A soulbound copy is never mailed, and the character playing never
--      gets mail.
--   3. Keeping still wins: an upgrade here stays.
--   4. With nobody typed in Tradeskills, nothing changes.

local env = dofile(lfs_cwd .. "/tools/testenv.lua")
local suite = env.NewSuite("disenchantermail")

local ns = env.Load()
env.FakeBags({
    { bag = 0, slot = 1, id = 601, name = "Ridge Cleaver", quality = 2, price = 400 },
    { bag = 0, slot = 2, id = 602, name = "Dire Wand", quality = 2, price = 300, bound = true },
    { bag = 0, slot = 3, id = 603, name = "Linen Cloth", quality = 1, price = 13, count = 20 },
})
env.Enable(ns)

local Verdicts = ns.Verdicts

local function Find(name)
    for _, group in ipairs(Verdicts:Groups()) do
        for _, row in ipairs(group.rows) do
            if row.name == name then return row end
        end
    end
end

local typed, upgrade = "Dusty Anvil", false
_G.BlackthornesTS = { Butler = {
    Advise = function(_, id)
        if id == 601 or id == 602 then
            return { auction = 50000, disenchant = 900, canDisenchant = false, disenchanter = typed }
        end
        if id == 603 then return { auction = 40 } end
    end,
} }
_G.BlackthornesEquipment = { Butler = { Advise = function(_, link)
    local id = tonumber(tostring(link):match("item:(%d+)"))
    if id ~= 601 then return nil end
    if upgrade then return { upgrade = "now", gain = 5 } end
end } }

-- 1. Mailed to the disenchanter, though the auction house pays more.
ns.UI:Show()
Verdicts:Changed(true)
local cleaver = Find("Ridge Cleaver")
suite.check("gear for the disenchanter goes under Mail", cleaver.verdict == "mail", cleaver.verdict)
suite.check("addressed to them", cleaver.mailTo == "Dusty Anvil", cleaver.mailTo)
suite.check("saying why", cleaver.reason:find("For your disenchanter: mail to Dusty Anvil", 1, true) ~= nil,
    cleaver.reason)
suite.check("cloth is not touched", Find("Linen Cloth").verdict ~= "mail")

-- 2. Never soulbound, never the character playing.
suite.check("a soulbound copy is never mailed", Find("Dire Wand").verdict ~= "mail", Find("Dire Wand").verdict)
local isMe = ns.Errands.IsMe
ns.Errands.IsMe = function(_, name) return name == "Dusty Anvil" end
Verdicts:Changed(true)
suite.check("never to the character playing", Find("Ridge Cleaver").verdict ~= "mail")
ns.Errands.IsMe = isMe

-- 3. Keeping wins.
upgrade = true
Verdicts:Changed(true)
suite.check("an upgrade here is kept", Find("Ridge Cleaver").verdict == "keep", Find("Ridge Cleaver").verdict)
upgrade = false

-- 4. Nobody typed: the old verdict (the auction house pays most).
typed = nil
Verdicts:Changed(true)
suite.check("nobody typed: no disenchanter mail", Find("Ridge Cleaver").verdict == "auction",
    Find("Ridge Cleaver").verdict)

suite.done()
