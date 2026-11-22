-- Each character keeps its own marks (a player found, 2026-11-22, that an
-- item marked Always mail to the alt on the main turned to Store in bank
-- on the main too once the alt marked it Store in bank). The six Always
-- lists live in each character's own save; the old account wide lists are
-- copied in once and never changed.

local env = dofile(lfs_cwd .. "/tools/testenv.lua")
local suite = env.NewSuite("charmarks")

local ns = env.Load()
env.FakeBags({})
env.Enable(ns)
local Verdicts = ns.Verdicts

-- What a player had saved before marks were per character.
ns.db.alwaysMail = { [501] = "Alt Two" }
ns.db.alwaysSell = { [502] = true }

-- The main logs in: its own save is new.
local main = {}
ns.charDB = main
local choice, to = Verdicts:Choice(501)
suite.check("the main keeps the old Always mail mark", choice == "mail" and to == "Alt Two")
suite.check("and the old Always sell mark", Verdicts:Choice(502) == "sell")

-- The alt logs in and marks the same item Store in bank.
local alt = {}
ns.charDB = alt
suite.check("the alt starts with the old marks too", Verdicts:Choice(502) == "sell")
Verdicts:SetChoice(501, "bank")
suite.check("the alt's mark is Store in bank", Verdicts:Choice(501) == "bank")

-- Back on the main: its mark is its own.
ns.charDB = main
choice, to = Verdicts:Choice(501)
suite.check("the main still mails it to the alt", choice == "mail" and to == "Alt Two", tostring(choice))

-- A mark made on the main stays off the alt.
Verdicts:SetChoice(503, "keep")
ns.charDB = alt
suite.check("a new mark on the main stays off the alt", Verdicts:Choice(503) == nil)

-- Reset This Item and the typed reset touch the character playing only.
Verdicts:ResetItem(502)
suite.check("Reset This Item clears it on the alt", Verdicts:Choice(502) == nil)
ns.charDB = main
suite.check("and leaves the main's mark", Verdicts:Choice(502) == "sell")
ns.charDB = alt
ns.HandleSlash("reset confirm")
suite.check("reset confirm empties the alt's marks", Verdicts:Choice(501) == nil)
ns.charDB = main
suite.check("and leaves the main's", Verdicts:Choice(501) == "mail" and Verdicts:Choice(503) == "keep")

-- The old lists are never deleted or changed.
suite.check("the old Always mail list is as it was", ns.db.alwaysMail[501] == "Alt Two")
suite.check("the old Always sell list is as it was", ns.db.alwaysSell[502] == true and ns.db.alwaysKeep == nil)

-- Saved where the game keeps each character's own file.
suite.check("saved in the character's own save", type(main.marks) == "table"
    and main.marks.alwaysMail[501] == "Alt Two" and alt.marks.alwaysBank ~= nil)

suite.done()
