-- Butler's own mail, without Tradeskills (2026-11-22): it writes down each
-- character's whole name, realm and side and nothing else, offers them in
-- the name picker, and fills the Send Mail page itself: whole stacks first,
-- part of a stack split off before it goes in, gold only with no COD.

local env = dofile(lfs_cwd .. "/tools/testenv.lua")
local suite = env.NewSuite("mailfill")

local ns = env.Load()
local fake = env.FakeBags({
    { bag = 0, slot = 1, id = 403, name = "Linen Cloth", quality = 1, price = 13, count = 20 },
    { bag = 0, slot = 2, id = 403, name = "Linen Cloth", quality = 1, price = 13, count = 5 },
    { bag = 0, slot = 3, id = 404, name = "Copper Ore", quality = 1, price = 5, count = 10 },
    { bag = 0, slot = 4, id = 405, name = "Bound Ring", quality = 2, price = 50, bound = true },
})
_G.BlackthornesTS = nil

local guid, first, full = "Player-1-AAA", "Ana", "Ana Smith"
_G.UnitGUID = function() return guid end
_G.UnitName = function() return first end
_G.UnitFullName = function() return full end
_G.GetRealmName = function() return "Stormhold" end
_G.UnitFactionGroup = function() return "Horde" end

env.Enable(ns)
local MailFill, Errands = ns.MailFill, ns.Errands

-- Your characters.
local saved = ns.db.myCharacters
local me = saved and saved[guid]
suite.check("the character playing is written down at login", me ~= nil)
suite.check("with its whole name", me and me.name == "Ana Smith", me and me.name)
suite.check("its realm and side", me and me.realm == "Stormhold" and me.faction == "Horde")
local keys = 0
for _ in pairs(me or {}) do keys = keys + 1 end
suite.check("and nothing else", keys == 3, keys)

guid = nil
suite.check("a GUID the game won't read writes nothing", MailFill:Remember() == false)
guid, full = "Player-1-BBB", nil
suite.check("no last name writes nothing", MailFill:Remember() == false and saved[guid] == nil)
_G.GetRealmName = function() return "" end
full = "Ana Smith"
guid = "Player-1-AAA"
MailFill:Remember()
suite.check("a blank realm keeps the one written before", saved[guid].realm == "Stormhold", saved[guid].realm)

saved["Player-1-BOB"] = { name = "Bob Stone", realm = "Stormhold", faction = "Horde" }
saved["Player-1-CY"] = { name = "Cy Vale", realm = "Stormhold", faction = "Alliance" }
saved["Player-2-DI"] = { name = "Di Hart", realm = "Elsewhere", faction = "Horde" }
ns.Verdicts:Changed(true)
local names = Errands:Characters()
suite.check("the picker lists your other characters on this realm and side",
    #names == 1 and names[1] == "Bob Stone", table.concat(names, ", "))
suite.check("the one playing is still known as you", Errands:IsMe("Ana Smith"))
suite.check("Equipment's alt names read it too", Errands:NameOf("Player-1-BOB") == "Bob Stone")

-- A Send Mail page with a cursor, 12 slots and a stack split.
local cursor, mail = nil, {}
_G.ATTACHMENTS_MAX_SEND = 12
_G.SendMailFrame = env.Stub({ _shown = true })
_G.SendMailNameEditBox = env.Stub()
_G.SendMailSubjectEditBox = env.Stub()
_G.CursorHasItem = function() return cursor ~= nil end
_G.ClearCursor = function() cursor = nil end
_G.GetSendMailItem = function(slot)
    local item = mail[slot]
    if not item then return nil end
    return item.name, item.id, 134400, item.count or 1
end
_G.ClickSendMailItemButton = function(slot, clear)
    if clear then mail[slot] = nil return end
    if cursor and not mail[slot] then
        mail[slot] = cursor.item
        fake.bags[cursor.bag][cursor.slot] = nil
        cursor = nil
    end
end
_G.C_Container.PickupContainerItem = function(bag, slot)
    local item = fake.bags[bag][slot]
    if cursor and cursor.split and not item then
        local moved = cursor.split
        fake.bags[bag][slot] = moved
        moved.bag, moved.slot = bag, slot
        cursor = nil
    elseif item then
        cursor = { bag = bag, slot = slot, item = item }
    end
end
_G.C_Container.SplitContainerItem = function(bag, slot, count)
    local item = fake.bags[bag][slot]
    if not item or (item.count or 1) <= count then return end
    item.count = item.count - count
    local part = {}
    for k, v in pairs(item) do part[k] = v end
    part.count = count
    cursor = { split = part }
end

local done = {}
local ok, why = MailFill:Fill("Bob Stone", {
    { itemID = 403, count = 22 }, { itemID = 404, count = 10 }, { itemID = 405, count = 1 },
}, nil, function(attached, left) done = { attached = attached, left = left } end)
suite.check("it starts", ok == true, why)
suite.check("the To box gets the whole name", SendMailNameEditBox:GetText() == "Bob Stone")
suite.check("the subject says it is from Butler", SendMailSubjectEditBox:GetText() == "From Blackthornes Butler")
local inMail = {}
for _, item in pairs(mail) do inMail[item.id] = (inMail[item.id] or 0) + (item.count or 1) end
suite.check("22 Linen go in: the stack of 20 and 2 split off", inMail[403] == 22, inMail[403])
suite.check("the 5 stack keeps 3", fake.bags[0][2] and fake.bags[0][2].count == 3)
suite.check("all the ore goes in", inMail[404] == 10)
suite.check("soulbound never goes in", inMail[405] == nil)
suite.check("three stacks attached", done.attached == 3 and done.left == 0, done.attached)
suite.check("it is free for the next mail", not MailFill.filling)

-- Gold.
mail = {}
_G.SendMailMoney = env.Stub()
local set
_G.MoneyInputFrame_SetCopper = function(_, copper) set = copper end
fake.money = 100000
ok = MailFill:Fill("Bob Stone", {}, 5000)
suite.check("gold alone goes in the gold box", ok == true and set == 5000, set)
suite.check("and the subject says gold", SendMailSubjectEditBox:GetText() == "Gold from Blackthornes Butler")
_G.SendMailCODButton = env.Stub({ GetChecked = function() return true end })
ok, why = MailFill:Fill("Bob Stone", {}, 5000)
suite.check("never with COD ticked", not ok and why == "the mail is set to COD", why)
_G.SendMailCODButton = nil
fake.money = 10
ok, why = MailFill:Fill("Bob Stone", {}, 5000)
suite.check("never more gold than you carry", not ok and why == "not enough gold on you", why)

-- Left over: no empty slot to split into.
mail, done = {}, {}
fake.money = 0
for slot = 2, fake.numSlots do fake.bags[0][slot] = { id = 999, name = "Rock", count = 1 } end
fake.bags[0][1] = { bag = 0, slot = 1, id = 403, name = "Linen Cloth", count = 20 }
ok = MailFill:Fill("Bob Stone", { { itemID = 403, count = 2 } }, nil,
    function(attached, left) done = { attached = attached, left = left } end)
suite.check("with bags full a split is left out", ok and done.left == 1 and MailFill.splitBlocked == true)
env.chat = {}
MailFill.Done(0, 1)
suite.check("and chat says to free a bag slot", (env.chat[1] or ""):find("Free one bag slot", 1, true) ~= nil, env.chat[1])

_G.SendMailFrame, _G.SendMailNameEditBox, _G.SendMailSubjectEditBox, _G.SendMailMoney = nil, nil, nil, nil
_G.UnitGUID, _G.UnitFullName, _G.GetRealmName, _G.UnitFactionGroup = nil, nil, nil, nil
_G.CursorHasItem, _G.ClearCursor, _G.GetSendMailItem, _G.ClickSendMailItemButton = nil, nil, nil, nil
_G.MoneyInputFrame_SetCopper, _G.ATTACHMENTS_MAX_SEND = nil, nil
suite.done()
