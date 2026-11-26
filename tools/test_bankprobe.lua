-- /bbutler bankprobe: asked before a Butler Bank window is built (the owner
-- said build it, 2026-11-26). At a banker it lists the bank calls,
-- containers and frames the client has, makes the game's item square on the
-- first bank item, and shows one test square. Nothing moves unless the
-- player clicks it; then what happened is printed and kept for Claude.

local env = dofile(lfs_cwd .. "/tools/testenv.lua")
local suite = env.NewSuite("bankprobe")

local ns = env.Load()
local fake = env.FakeBags({})
env.Enable(ns)

-- A bank of 28 slots (bag -1) with Linen Cloth in slot 3.
fake.bags[-1] = {}
local slotsOf = _G.C_Container.GetContainerNumSlots
_G.C_Container.GetContainerNumSlots = function(bag)
    if bag == -1 then return 28 end
    return slotsOf(bag)
end
fake.bags[-1][3] = { bag = -1, slot = 3, id = 2589, name = "Linen Cloth", count = 5 }

local function Lines() return table.concat(ns.db.lastProbe.lines, "\n") end
local function Kept(text) return Lines():find(text, 1, true) ~= nil end

-- Away from the bank: it still lists what it can, and shows no square.
ns.HandleSlash("bankprobe")
suite.check("the probe is kept", ns.db.lastProbe.check == "bankprobe", ns.db.lastProbe.check)
suite.check("it says it is not at a banker", Kept("at a banker  false"), Lines())
suite.check("and lists the missing game frames", Kept("BankFrame"), Lines())
suite.check("and shows no square away from the bank", Kept("not shown: open the bank"), Lines())

-- At the bank.
ns.Errands.bankOpen = true
_G.BankFrame = env.Stub({ _shown = true })
ns.HandleSlash("bankprobe")
suite.check("it says it is at a banker", Kept("at a banker  true"), Lines())
suite.check("it counts the bank's slots and items", Kept("-1: 28 slots 1 items"), Lines())
suite.check("it finds the first bank item", Kept("first bank item  bag -1 slot 3"), Lines())
suite.check("it reads the game's bank frame", Kept("BankFrame (shown true"), Lines())
suite.check("it makes the game's square", Kept("ContainerFrameItemButtonTemplate  made"), Lines())
suite.check("and shows the test square", Kept("Right-click it to move the item"), Lines())
suite.check("running it moved nothing", #fake.used == 0 and fake.bags[-1][3] ~= nil)

local square = _G.BlackthornesButlerBankProbe1
suite.check("the square is on screen", square and square:GetParent()._shown == true)

-- The bags settling with no click changes nothing.
env.Fire("BAG_UPDATE_DELAYED")
suite.check("no click, no report", Kept("Right-click it to move the item"), Lines())

-- The player right-clicks it and the item goes to the bags.
square:GetScript("OnClick")(square, "RightButton")
fake.bags[-1][3] = nil
env.Fire("BAG_UPDATE_DELAYED")
suite.check("the click is reported", Kept("RightButton-click on bank -1 slot 3"), Lines())
suite.check("the item left the bank slot", Kept("left the bank slot"), Lines())
suite.check("nothing was blocked", Kept("nothing blocked"), Lines())
suite.check("the first lines are kept with it", Kept("-1: 28 slots 1 items"), Lines())
suite.check("the square goes away", square:GetParent()._shown == false)

-- The game blocks the move.
fake.bags[-1][3] = { bag = -1, slot = 3, id = 2589, name = "Linen Cloth", count = 5 }
ns.HandleSlash("bankprobe")
env.Fire("ADDON_ACTION_BLOCKED", "Blackthornes_Butler", "UseContainerItem()")
square:GetScript("OnClick")(square, "RightButton")
env.Fire("BAG_UPDATE_DELAYED")
suite.check("a blocked move is reported", Kept("blocked: ADDON_ACTION_BLOCKED Blackthornes_Butler UseContainerItem()"), Lines())
suite.check("and the item stayed", Kept("still in the bank (id 2589)"), Lines())

-- Closing the bank takes the square away.
ns.HandleSlash("bankprobe")
suite.check("the square is back", square:GetParent()._shown == true)
env.Fire("BANKFRAME_CLOSED")
suite.check("closing the bank takes it away", square:GetParent()._shown == false)

-- In a fight nothing is made or shown.
_G.InCombatLockdown = function() return true end
ns.HandleSlash("bankprobe")
suite.check("in a fight it says so", Kept("in a fight  true"), Lines())
suite.check("and makes no square", Kept("in a fight, not made"), Lines())
suite.check("and shows none", square:GetParent()._shown == false)
_G.InCombatLockdown = nil

-- Forever's bank is in tabs: bag -1 answers with items the game does not
-- show, so the test item comes from the first tab (seen 2026-11-26).
_G.Enum = { BagIndex = { Bank = -1, CharacterBankTab_1 = 6 } }
fake.bags[6] = { [2] = { bag = 6, slot = 2, id = 2592, name = "Wool Cloth", count = 3 } }
fake.info[2592] = fake.bags[6][2]
_G.C_Container.GetContainerNumSlots = function(bag)
    if bag == -1 then return 28 elseif bag == 6 then return 48 end
    return slotsOf(bag)
end
ns.Errands.bankOpen = true
ns.HandleSlash("bankprobe")
suite.check("with tabs the test item comes from a tab", Kept("first bank item  bag 6 slot 2"), Lines())
suite.check("bag -1 is still counted", Kept("-1: 28 slots 1 items"), Lines())
_G.Enum = nil

suite.done()
