-- Quick marks (the owner said build it, 2026-11-26, from mockup #4):
-- mark a bag item in one click or one key, and Keep For Now.
--
-- What must hold:
--   1. Keep For Now keeps an item until logout, beats Butler's rules and
--      the player's own Always marks, and is never saved.
--   2. A real mark ends Keep For Now; Reset This Item clears it.
--   3. The bar shows only marks that fit: no Mail or Auction for bound,
--      no Disenchant under green, no Sell for what no vendor buys.
--   4. The bar key over a bag square (the game's, through its tooltip, or
--      Butler Bags) shows the bar; a click sets a mark, a second click
--      takes it off. Not in a fight. Holding Alt shows nothing (the owner
--      asked, 2026-11-27).
--   5. The keys mark the item under the mouse, set only, never toggle.
--   6. Every key and new word is named and in every language.

local env = dofile(lfs_cwd .. "/tools/testenv.lua")
local suite = env.NewSuite("quickmarks")

local ns = env.Load()
env.FakeBags({
    { bag = 0, slot = 1, id = 801, name = "Broken Fang", quality = 0, price = 12, count = 3 },
    { bag = 0, slot = 2, id = 802, name = "Linen Cloth", quality = 1, price = 13, count = 20, class = 7 },
    { bag = 0, slot = 3, id = 803, name = "Green Boots", quality = 2, price = 90, count = 1, bound = true },
})

local hooks = {}
_G.hooksecurefunc = function(object, method, fn)
    hooks[#hooks + 1] = { object = object, method = method, fn = fn }
end
_G.GameTooltip.SetBagItem = function() end
local alt, fighting, barKey = false, false, nil
_G.IsAltKeyDown = function() return alt end
_G.InCombatLockdown = function() return fighting end
_G.GetBindingKey = function(name) if name == "BLACKTHORNESBUTLER_QUICKBAR" then return barKey end end

env.Enable(ns)
ns.Bags:Scan()

local Verdicts, QuickMarks = ns.Verdicts, ns.QuickMarks
suite.check("the module loads", QuickMarks ~= nil)

local function Entry(slot) return ns.Bags.ReadSlot(0, slot) end
local function Judge(slot) return (Verdicts:Judge(Entry(slot))) end

-- 1.
local before = Judge(2)
Verdicts:SetChoice(802, "sell")
suite.check("Always Sell sells it first", Judge(2) == "sell")
Verdicts:KeepForNow(802, true)
local verdict, reason = Verdicts:Judge(Entry(2))
suite.check("Keep For Now keeps it", verdict == "keep", tostring(verdict))
suite.check("and says until you log out", reason == "Kept until you log out.", tostring(reason))
suite.check("the Always mark is still there", Verdicts:Choice(802) == "sell")
suite.check("it counts as the player's own choice", Verdicts:HasOwnChoices(802))
local saved = false
for _, db in ipairs({ ns.db or {}, ns.charDB or {} }) do
    for _, value in pairs(db) do
        if value == Verdicts.keptForNow then saved = true end
    end
end
suite.check("nothing about it is saved", not saved)
Verdicts:KeepForNow(802, false)
suite.check("let go, the Always mark judges again", Judge(2) == "sell")

-- 2.
Verdicts:KeepForNow(802, true)
Verdicts:SetChoice(802, "bank")
suite.check("a real mark ends Keep For Now", not Verdicts:KeptForNow(802))
Verdicts:KeepForNow(802, true)
Verdicts:ResetItem(802)
suite.check("Reset This Item clears it", not Verdicts:KeptForNow(802) and Verdicts:Choice(802) == nil)
suite.check("and Butler decides as before", Judge(2) == before)

-- 3.
local function Ids(entry)
    local ids = {}
    for _, mark in ipairs(QuickMarks.Fits(entry)) do ids[#ids + 1] = mark.id end
    return table.concat(ids, " ")
end
suite.check("cloth gets every mark but Disenchant", Ids(Entry(2)) == "keep now sell auction bank mail", Ids(Entry(2)))
suite.check("bound green boots get no Mail or Auction", Ids(Entry(3)) == "keep now sell bank disenchant", Ids(Entry(3)))
local noValue = { itemID = 900, quality = 1, noValue = true }
suite.check("no Sell for what no vendor buys", not Ids(noValue):find("sell"), Ids(noValue))

-- 4.
local hooked
for _, h in ipairs(hooks) do
    if h.object == _G.GameTooltip and h.method == "SetBagItem" then hooked = h.fn end
end
suite.check("the game's bag tooltip is hooked, not changed", hooked ~= nil)

local square = env.Stub({ IsMouseOver = function() return true end, IsVisible = function() return true end })
_G.GameTooltip.GetOwner = function() return square end
hooked(_G.GameTooltip, 0, 2)
suite.check("hovering alone shows no bar", not (QuickMarks.bar and QuickMarks.bar:IsShown()))
alt = true
env.Fire("MODIFIER_STATE_CHANGED", "LALT", 1)
suite.check("holding Alt over an item shows no bar", not (QuickMarks.bar and QuickMarks.bar:IsShown()))
hooked(_G.GameTooltip, 0, 2)
suite.check("nor does hovering with Alt held", not (QuickMarks.bar and QuickMarks.bar:IsShown()))
QuickMarks:BarKey("down")
local bar = QuickMarks.bar
suite.check("the bar key over a game bag square shows the bar", bar and bar:IsShown())
suite.check("for that item", bar and bar.entry and bar.entry.itemID == 802)

QuickMarks:Click("keep")
suite.check("a click sets the mark", Verdicts:Choice(802) == "keep")
local lit
for _, slot in ipairs(bar.slots) do if slot.mark and slot.mark.id == "keep" then lit = slot.active end end
suite.check("and lights it", lit == true)
QuickMarks:Click("keep")
suite.check("a second click takes it off", Verdicts:Choice(802) == nil)
QuickMarks:Click("now")
suite.check("Keep For Now from the bar", Verdicts:KeptForNow(802))
QuickMarks:Click("now")
suite.check("and off again", not Verdicts:KeptForNow(802))
suite.check("no Auction on a bound item, even by click", not QuickMarks:Pick(Entry(3), "auction", true))

square.IsMouseOver = function() return false end
QuickMarks:Check()
suite.check("the bar goes when the mouse leaves", not bar:IsShown())

square.IsMouseOver = function() return true end
alt = false
local bagSquare = env.Stub({ bfrBag = 0, bfrSlot = 3, IsMouseOver = function() return true end })
QuickMarks:Hover(bagSquare, 0, 3)
QuickMarks:BarKey("down")
suite.check("Butler Bags squares show it too", bar:IsShown() and bar.entry.itemID == 803)

QuickMarks:HideBar()
fighting = true
QuickMarks:BarKey("down")
suite.check("never in a fight", not bar:IsShown())
suite.check("no marks in a fight", not QuickMarks:Pick(Entry(3), "keep", true))
fighting = false
QuickMarks:ShowBar()
env.Fire("PLAYER_REGEN_DISABLED")
suite.check("a fight starting closes the bar", not bar:IsShown())

QuickMarks:BarKey("up")
suite.check("letting go of the bar key does nothing", not bar:IsShown())

-- 5.
alt = false
QuickMarks:Hover(square, 0, 2)
env.chat = {}
suite.check("Mark to Sell marks the item under the mouse", QuickMarks:Key("sell") and Verdicts:Choice(802) == "sell")
suite.check("and says so in chat", env.ChatText():find("Always Sell", 1, true) ~= nil)
suite.check("a second press does not take it off", not QuickMarks:Key("sell") and Verdicts:Choice(802) == "sell")
suite.check("Mark to Keep", QuickMarks:Key("keep") and Verdicts:Choice(802) == "keep")
suite.check("Keep For Now", QuickMarks:Key("now") and Verdicts:KeptForNow(802))
square.IsMouseOver = function() return false end
suite.check("nothing when the mouse is off the item", not QuickMarks:Key("sell"))
Verdicts:ResetItem(802)

-- 6.
local function Read(path)
    local f = io.open(lfs_cwd .. "/" .. path)
    local text = f and f:read("*a") or ""
    if f then f:close() end
    return text
end
local bindings = Read("Bindings.xml")
for _, name in ipairs({ "MARKSELL", "MARKKEEP", "KEEPNOW", "QUICKBAR" }) do
    suite.check(name .. " is a binding", bindings:find("BLACKTHORNESBUTLER_" .. name, 1, true) ~= nil)
    suite.check(name .. " has a name", type(_G["BINDING_NAME_BLACKTHORNESBUTLER_" .. name]) == "string")
end
suite.check("no binding takes a key of the player's", not bindings:find("default=", 1, true))
for _, key in ipairs({ "Keep For Now", "Kept until you log out.", "Mark to Sell", "Mark to Keep", "Quick Marks Bar" }) do
    local all = true
    for _, code in ipairs({ "deDE", "zhCN", "frFR", "esES", "ruRU" }) do
        if not Read("Locale/" .. code .. ".lua"):find('L["' .. key .. '"]', 1, true) then all = false end
    end
    suite.check(key .. " is in every language", all)
end

suite.done()
