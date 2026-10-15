-- Tradeskills prices a random suffix ("of the Monkey") as that suffix sells
-- when it is asked with the bag copy's link (2026-10-15). Butler passes the
-- link only to a Tradeskills that says it takes one (TAKES_LINK); an older
-- one is still asked by item ID.

local env = dofile(lfs_cwd .. "/tools/testenv.lua")
local suite = env.NewSuite("suffixlink")

local ns = env.Load()
env.FakeBags({
    { bag = 0, slot = 1, id = 801, name = "Lead Band of the Monkey", quality = 2, price = 300 },
})
env.Enable(ns)

local asked
local ts = { Butler = { Advise = function(_, item) asked = item; return {} end } }
_G.BlackthornesTS = ts

local entry = { itemID = 801, link = "|cff1eff00|Hitem:801::::::612:1:60|h[Lead Band of the Monkey]|h|r" }

ns.Sisters:Ask("ts", entry)
suite.check("an older Tradeskills is asked by item ID", asked == 801, tostring(asked))

ts.Butler.TAKES_LINK = true
ns.Sisters:Ask("ts", entry)
suite.check("one that takes a link gets the copy's link", asked == entry.link, tostring(asked))

ns.Sisters:Ask("ts", { itemID = 801 })
suite.check("no link: the item ID", asked == 801, tostring(asked))

ns.Sisters:Ask("farmer", entry)
suite.check("Farmer is not touched", true)

_G.BlackthornesTS = nil
suite.done()
