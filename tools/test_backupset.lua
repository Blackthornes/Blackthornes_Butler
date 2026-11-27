-- Equipment's backup weapon set is kept (the owner, 2026-11-27: Butler
-- said Disenchant for Mordresh's Lifeless Skull, the off hand of his
-- backup set).
--
-- What must hold:
--   1. Without Equipment's word, the off hand goes under Disenchant (what
--      the owner saw).
--   2. Equipment says `backup`: it goes under Keep, "Kept for your backup
--      set.", never Sell, Auction, Disenchant or Mail.
--   3. Its square wears the backup mark (blue swords), in Butler's Bags
--      and on the game's bags.
--   4. An Always mark of the player's still wins.

local env = dofile(lfs_cwd .. "/tools/testenv.lua")
local suite = env.NewSuite("backupset")

local ns = env.Load()
env.FakeBags({
    { bag = 0, slot = 1, id = 901, name = "Mordresh's Lifeless Skull", quality = 3, price = 1200 },
    { bag = 0, slot = 2, id = 902, name = "Sample Ritual Dagger", quality = 2, price = 900 },
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

local backup = false
_G.BlackthornesTS = { Butler = {
    Advise = function() return { disenchant = 6774, canDisenchant = true, youDisenchant = true } end,
} }
_G.BlackthornesEquipment = { Butler = { Advise = function(_, link)
    local id = tonumber(tostring(link):match("item:(%d+)"))
    if id == 901 and backup then return { backup = true, sell = false } end
    return { sell = false }
end } }
ns.UI:Show()

-- 1.
Verdicts:Changed(true)
local skull = Find("Mordresh's Lifeless Skull")
suite.check("without the word: Disenchant, as the owner saw", skull.verdict == "disenchant", skull.verdict)

-- 2.
backup = true
Verdicts:Changed(true)
skull = Find("Mordresh's Lifeless Skull")
suite.check("a backup piece goes under Keep", skull.verdict == "keep", skull.verdict)
suite.check("saying why", skull.reason == "Kept for your backup set.", skull.reason)
suite.check("the dagger is judged as before", Find("Sample Ritual Dagger").verdict ~= "keep",
    Find("Sample Ritual Dagger").verdict)

-- 3.
local entry = ns.Bags.slots["0:1"]
local marks = ns.BagView:Marks(entry)
suite.check("its marks say backup", marks and marks.backup == true)
suite.check("the backup mark is listed", (function()
    for _, kind in ipairs(ns.BagWindow.MARK_ORDER) do if kind == "backup" then return true end end
end)())
suite.check("the game's bag square wears it", ns.BagMarks.KindFor(0, 1) == "backup", ns.BagMarks.KindFor(0, 1))
local texture = env.Stub()
local tinted
texture.SetTexture = function(t, path) t._path = path end
texture.SetVertexColor = function(_, r, g, b) tinted = { r, g, b } end
ns.BagWindow.ShowMark(texture, "backup")
suite.check("drawn as blue swords", texture._path == ns.BagWindow.SWORDS and tinted and tinted[3] == 1)
ns.BagWindow.ShowMark(texture, "vendor")
suite.check("the next mark is back to its own colour", tinted[1] == 1 and tinted[2] == 1)

-- 4.
Verdicts:SetChoice(901, "sell")
skull = Find("Mordresh's Lifeless Skull")
suite.check("the Always sell list still wins", skull.verdict == "sell", skull.verdict)
Verdicts:SetChoice(901, nil)

suite.done()
