-- Keep Level Up Materials (a player asked, the owner said build it,
-- 2026-11-17): materials an orange or yellow craft on Tradeskills' Level
-- Up list still uses stay under Keep.
--
-- What must hold:
--   1. Off unless ticked: the materials sell as before.
--   2. Ticked, each one is kept, saying which profession it levels
--      (Cooking and First Aid too).
--   3. Something Tradeskills doesn't name goes on down the rules.
--   4. The player's Always sell list still wins.
--   5. An alt's queued craft still gets its share in the mail.
--   6. Once Tradeskills stops naming it (the craft went green), it sells.
--   7. Tradeskills is asked once per look, not once per item.
--   8. A Tradeskills without the call, or one that raises, keeps nothing.

local env = dofile(lfs_cwd .. "/tools/testenv.lua")
local suite = env.NewSuite("keeplevelup")

local ns = env.Load()
env.FakeBags({
    { bag = 0, slot = 1, id = 2589, name = "Linen Cloth", quality = 1, price = 13, count = 20 },
    { bag = 0, slot = 2, id = 769, name = "Chunk of Boar Meat", quality = 1, price = 4, count = 5 },
    { bag = 0, slot = 3, id = 2840, name = "Copper Bar", quality = 1, price = 10, count = 10 },
    { bag = 0, slot = 4, id = 2835, name = "Rough Stone", quality = 1, price = 2, count = 10 },
    { bag = 0, slot = 5, id = 2318, name = "Light Leather", quality = 1, price = 15, count = 4 },
})

local asked = 0
local mats = { [2589] = "First Aid", [769] = "Cooking", [2840] = "Blacksmithing", [2835] = "Blacksmithing" }
local advice = {}
local tsButler = {
    Advise = function(_, id) return advice[id] or { auction = 0 } end,
    Holdings = function()
        return {
            { key = "me", short = "Me Here", realm = "R", faction = "Horde", isCurrent = true },
            { key = "bob", short = "Bob Stone", realm = "R", faction = "Horde" },
        }
    end,
    Mailbox = function() end,
    LevelUpMaterials = function()
        asked = asked + 1
        local copy = {}
        for id, name in pairs(mats) do copy[id] = name end
        return copy
    end,
}
_G.BlackthornesTS = { Butler = tsButler }
env.Enable(ns)
local Verdicts = ns.Verdicts
ns.UI:Show("bags")

local function Judge(id)
    for _, group in ipairs(Verdicts:Groups()) do
        for _, row in ipairs(group.rows or {}) do
            if row.itemID == id then return row.verdict or group.verdict, row.reason end
        end
    end
end

-- 1.
Verdicts:Changed(true)
suite.check("off by default", ns.db.keepLevelUp == false and not Verdicts:KeepLevelUpOn())
local offVerdict, offReason = Judge(2589)
suite.check("off, cloth is judged as before", offVerdict ~= nil and not tostring(offReason):find("level your"), tostring(offReason))

-- 2.
Verdicts:SetKeepLevelUp(true)
local verdict, reason = Judge(2589)
suite.check("ticked, cloth is kept", verdict == "keep", tostring(verdict))
suite.check("for First Aid", reason == "Used to level your First Aid", tostring(reason))
verdict, reason = Judge(769)
suite.check("meat is kept for Cooking", verdict == "keep" and reason == "Used to level your Cooking", tostring(reason))
verdict, reason = Judge(2835)
suite.check("stone is kept for Blacksmithing", verdict == "keep" and reason == "Used to level your Blacksmithing", tostring(reason))

-- 3.
verdict, reason = Judge(2318)
suite.check("leather no craft needs goes on down the rules", reason ~= nil and not reason:find("level your"), tostring(reason))

-- 7.
suite.check("Tradeskills asked once for the whole look", asked == 1, tostring(asked))

-- 4.
ns.Verdicts:MarkList("alwaysSell")[2840] = true
Verdicts:Changed(true)
verdict = Judge(2840)
suite.check("the Always sell list still wins", verdict == "sell", tostring(verdict))
ns.Verdicts:MarkList("alwaysSell")[2840] = nil

-- 5.
advice[2589] = { auction = 0, mailTo = "Bob Stone", mailCount = 6 }
Verdicts:Changed(true)
verdict, reason = Judge(2589)
suite.check("an alt's queued craft still gets its share", verdict == "mail", tostring(verdict) .. " " .. tostring(reason))
advice[2589] = nil

-- 6.
mats[2840] = nil
Verdicts:Changed(true)
verdict, reason = Judge(2840)
suite.check("once the craft is green, the bar goes on down the rules", verdict ~= "keep" or not tostring(reason):find("level your"), tostring(reason))

-- 8.
tsButler.LevelUpMaterials = function() error("boom") end
Verdicts:Changed(true)
verdict, reason = Judge(2835)
suite.check("a Tradeskills that raises keeps nothing", not tostring(reason):find("level your"), tostring(reason))
tsButler.LevelUpMaterials = nil
Verdicts:Changed(true)
verdict, reason = Judge(2835)
suite.check("an older Tradeskills keeps nothing", not tostring(reason):find("level your"), tostring(reason))

suite.done()
