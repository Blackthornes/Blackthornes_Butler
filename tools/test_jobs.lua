-- Jobs on other characters (the owner asked 2026-10-11: "craft Medium
-- Leather on another then send back"). Tradeskills works out each
-- character's steps for its craft queue; Butler shows them.
--
-- What must hold:
--   1. Without Tradeskills there are no jobs and nothing shows.
--   2. The character playing's steps come first, then a line for each
--      other character with work, the one that can get on with it first.
--   3. Names are whole, first and last.
--   4. Craft asks Tradeskills to start it, and says what to do when the
--      profession is closed.
--   5. The Log out button is a secure /logout, shown only while another
--      character has work, never in combat or in All characters.
--   6. Once the last step here is done, Butler says who is next.
--   7. Logging in on a character with a job brings the window up, unless
--      that is turned off.
--   8. Anything of the wrong shape, or an error, shows nothing.

local env = dofile(lfs_cwd .. "/tools/testenv.lua")
local suite = env.NewSuite("jobs")

local ns = env.Load()
env.FakeBags({
    { bag = 0, slot = 1, id = 2318, name = "Light Leather", quality = 1, price = 15, count = 30 },
})
_G.C_Item.GetItemNameByID = function(id)
    return ({ [2318] = "Light Leather", [2319] = "Medium Leather", [4238] = "Linen Bag" })[id]
end

local Jobs, UI = ns.Jobs, ns.UI

-- 1. No Tradeskills.
_G.BlackthornesTS = nil
env.Enable(ns)
suite.check("no Tradeskills, no jobs", #Jobs:Lines() == 0)

local jobs
local crafted = {}
local craftAnswer = { true, "crafting" }
_G.BlackthornesTS = { Butler = {
    Advise = function() return nil end,
    Holdings = function() return {} end,
    Mailbox = function() end,
    Jobs = function() return jobs end,
    Craft = function(_, recipeID)
        crafted[#crafted + 1] = recipeID
        return craftAnswer[1], craftAnswer[2]
    end,
} }

local function Fresh(list)
    jobs = list
    Jobs:Changed()
    return Jobs:Plan()
end

local ANA = { name = "Ana Blackthorne", isCurrent = true, steps = {
    { kind = "mail", to = "Blackthornes Wither", items = { { itemID = 2318, count = 30 } } },
    { kind = "craft", recipeID = 11, itemID = 4238, name = "Linen Bag", count = 1, forNames = {},
      ready = false, missing = { { itemID = 2996, count = 2 } } },
} }
local CY = { name = "Cy Waiting", steps = {
    { kind = "craft", recipeID = 12, itemID = 9, name = "Thing", count = 2, forNames = {},
      ready = false, missing = { { itemID = 2318, count = 4 } } },
} }
local WITHER = { name = "Blackthornes Wither", steps = {
    { kind = "craft", recipeID = 10, itemID = 2319, name = "Medium Leather", count = 20,
      forNames = { "Ana Blackthorne" }, ready = true, missing = {} },
} }

-- 2. Order.
local plan = Fresh({ ANA, CY, WITHER })
suite.check("the character playing is here", plan.here and plan.here.name == "Ana Blackthorne")
suite.check("next is the one that can get on with it", plan.nextJob.name == "Blackthornes Wither")
local rows = Jobs:Lines()
suite.check("two steps here and two characters", #rows == 4, #rows)
suite.check("this character's steps first", rows[1].type == "job" and rows[1].step.kind == "mail")
suite.check("then the next character", rows[3].type == "jobnext" and rows[3].isNext
    and rows[3].job.name == "Blackthornes Wither")
suite.check("then the one waiting", rows[4].job.name == "Cy Waiting" and not rows[4].isNext)

-- 3. Words, with whole names.
local title, detail = Jobs.StepText(rows[1].step)
suite.check("a mail names the character in full", title == "Mail to Blackthornes Wither", title)
suite.check("and says what goes", detail:find("30 Light Leather", 1, true) ~= nil, detail)
title, detail = Jobs.StepText(rows[2].step)
suite.check("a craft of one has no number", title == "Craft Linen Bag", title)
suite.check("short of materials says so", detail:find("Still needs", 1, true) == 1, detail)
local summary = Jobs.Summary(WITHER)
suite.check("the next character's job in one line",
    summary == "Craft 20 Medium Leather, then mail it to Ana Blackthorne.", summary)
suite.check("one waiting on materials says so", Jobs.Summary(CY):find("Waiting on materials", 1, true) ~= nil)

-- The window shows them first.
UI:Show("bags")
local lines = UI:Lines()
suite.check("the Jobs group heads the window", lines[1].type == "header" and lines[1].group.verdict == "jobs")
suite.check("with its steps under it", lines[2].type == "job")

-- 4. Craft.
plan = Fresh({ { name = "Ana Blackthorne", isCurrent = true, steps = { WITHER.steps[1] } } })
suite.check("a craft with its materials", Jobs:Craft(plan.here.steps[1]) == true)
suite.check("asks Tradeskills for that recipe", crafted[1] == 10)
craftAnswer = { true, "opened" }
Jobs:Craft(plan.here.steps[1])
suite.check("a closed profession says how to open it", env.ChatText():find("Open button", 1, true) ~= nil)
craftAnswer = { false, "need materials" }
suite.check("a refusal is no craft", Jobs:Craft(plan.here.steps[1]) == false)
suite.check("and says why", env.ChatText():find("need materials", 1, true) ~= nil)
_G.InCombatLockdown = function() return true end
local before = #crafted
Jobs:Craft(plan.here.steps[1])
suite.check("never in combat", #crafted == before)
_G.InCombatLockdown = nil

-- 5. Log out.
UI.viewButton._left = 400
UI.viewButton.GetBottom = function() return 600 end
Fresh({ ANA, WITHER })
Jobs:UpdateLogout()
local button = Jobs.button
suite.check("the Log out button shows with someone next", button and button:IsShown())
suite.check("it is the game's own /logout", button:GetAttribute("type") == "macro"
    and button:GetAttribute("macrotext") == "/logout")
suite.check("its tooltip names who to pick", button.tooltipText:find("Blackthornes Wither", 1, true) ~= nil)
Fresh({ ANA })
Jobs:UpdateLogout()
suite.check("nobody next, no button", not button:IsShown())
Fresh({ ANA, WITHER })
env.Fire("PLAYER_REGEN_DISABLED")
suite.check("combat hides it", not button:IsShown())
env.Fire("PLAYER_REGEN_ENABLED")
suite.check("and it comes back after", button:IsShown())
UI.view = "all"
Jobs:UpdateLogout()
suite.check("not in All characters", not button:IsShown())
UI.view = "bags"

-- 6. Done here.
Fresh({ ANA, WITHER })
env.chat = {}
Fresh({ WITHER })
suite.check("done here says who is next", env.ChatText():find("Next: Blackthornes Wither", 1, true) ~= nil,
    env.ChatText())
env.chat = {}
Fresh({ WITHER })
suite.check("and only once", env.ChatText() == "")

-- 7. At login.
UI:Hide()
jobs = { { name = "Blackthornes Wither", isCurrent = true, steps = WITHER.steps } }
env.Fire("PLAYER_ENTERING_WORLD", true, false)
suite.check("a job here brings the window up", UI:IsShown())
suite.check("and says what it is", env.ChatText():find("a job for you here", 1, true) ~= nil)
UI:Hide()
ns.HandleSlash("joblogin")
suite.check("joblogin turns it off", ns.db.jobsAtLogin == false)
env.Fire("PLAYER_ENTERING_WORLD", true, false)
suite.check("then the window stays down", not UI:IsShown())
env.Fire("PLAYER_ENTERING_WORLD", false, true)
suite.check("a reload never brings it up", not UI:IsShown())

-- 8. Wrong shapes and errors.
local clean = Jobs.Clean({ { name = "X", steps = { { kind = "craft" }, { kind = "mail", to = "Y", items = {} },
    "junk", { kind = "dance" } } }, "junk", { steps = {} } })
suite.check("steps of the wrong shape are left out", #clean == 0)
_G.BlackthornesTS.Butler.Jobs = function() error("boom") end
Jobs:Changed()
suite.check("an error shows nothing", #Jobs:Lines() == 0)
env.chat = {}
ns.HandleSlash("jobs")
suite.check("/bbutler jobs says when there are none", env.ChatText():find("no jobs", 1, true) ~= nil)

_G.BlackthornesTS = nil
suite.done()
