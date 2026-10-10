-- The /bbutler routing and the saved data it starts from.

local env = dofile(lfs_cwd .. "/tools/testenv.lua")
local suite = env.NewSuite("slash")

local ns = env.Load()

suite.check("the global is the namespace", _G.BlackthornesButler == ns)
suite.check("/bbutler is registered", SLASH_BLACKTHORNESBUTLER1 == "/bbutler")
suite.check("so is /pets", SLASH_BLACKTHORNESBUTLER2 == "/butler")
suite.check("and routes to the handler",
    SlashCmdList["BLACKTHORNESBUTLER"] == ns.HandleSlash)

suite.check("account settings exist", type(ns.db) == "table")
suite.check("character settings exist", type(ns.charDB) == "table")

ns.HandleSlash("")
suite.check("a bare /bbutler opens the pets window", ns.UI.frame and ns.UI.frame:IsShown())
ns.HandleSlash("")
suite.check("and a second one closes it", not ns.UI.frame:IsShown())

env.chat = {}
ns.HandleSlash("  HELP  ")
suite.check("commands ignore case and spaces",
    env.ChatText():find("Blackthornes Butler", 1, true), env.ChatText())

env.chat = {}
ns.HandleSlash("nonsense")
suite.check("an unknown command says so",
    env.ChatText():find("unknown command: nonsense", 1, true), env.ChatText())

env.chat = {}
ns.RegisterCommand("boom", "fails on purpose", function() error("kaboom") end)
local ok = pcall(ns.HandleSlash, "boom")
suite.check("a failing command reaches the error handler", not ok)
suite.check("and says so in chat first",
    env.ChatText():find("/bbutler boom failed", 1, true), env.ChatText())

-- Saved data already on disk is kept; only missing keys are filled in.
_G.BlackthornesButlerCharDB = { kept = "yes" }
_G.BlackthornesButlerDB = { x = 120 }
ns.LoadSavedVariables()
suite.check("character data survives a reload", ns.charDB.kept == "yes")
suite.check("a moved window stays moved", ns.db.x == 120)
suite.check("missing settings get their default", ns.db.debug == false)

suite.done()
