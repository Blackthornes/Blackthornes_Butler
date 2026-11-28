-- Fill mail takes the version of an item Butler said to mail (2026-11-28).
-- Two versions of one item share an item ID ("Boots of the Monkey" kept,
-- "Boots of the Bear" to mail), and the filler picked stacks by ID alone,
-- so the kept pair could go in the mail.

local env = dofile(lfs_cwd .. "/tools/testenv.lua")
local suite = env.NewSuite("mailversion")

local ns = env.Load()
local monkey = { bag = 0, slot = 1, id = 7000, name = "Boots of the Monkey", quality = 2, price = 90 }
local bear = { bag = 0, slot = 2, id = 7000, name = "Boots of the Bear", quality = 2, price = 90 }
local fake = env.FakeBags({ monkey, bear })
_G.BlackthornesTS = nil

_G.UnitGUID = function() return "Player-1-AAA" end
_G.UnitName = function() return "Ana" end
_G.UnitFullName = function() return "Ana Smith" end
_G.GetRealmName = function() return "Stormhold" end
_G.UnitFactionGroup = function() return "Horde" end

env.Enable(ns)
local MailFill, Errands = ns.MailFill, ns.Errands

local function LinkOf(item)
    local info = C_Container.GetContainerItemInfo(item.bag, item.slot)
    return info and info.hyperlink
end
local bearLink, monkeyLink = LinkOf(bear), LinkOf(monkey)

-- What goes to whom: the Bear row from the Mail group carries its link.
local realGroup = ns.Verdicts.Group
ns.Verdicts.Group = function(self, key)
    if key ~= "mail" then return realGroup(self, key) end
    return { rows = { { itemID = 7000, link = bearLink, count = 1, mailTo = "Bob Stone" } } }
end
local recipients = Errands:Recipients()
local item = recipients[1] and recipients[1].items[1]
suite.check("the mail list keeps the link of the version to mail", item and item.link == bearLink,
    item and tostring(item.link))
ns.Verdicts.Group = realGroup

-- A Send Mail page.
local cursor, mail = nil, {}
_G.ATTACHMENTS_MAX_SEND = 12
_G.SendMailFrame = env.Stub({ _shown = true })
_G.SendMailNameEditBox = env.Stub()
_G.SendMailSubjectEditBox = env.Stub()
_G.CursorHasItem = function() return cursor ~= nil end
_G.ClearCursor = function() cursor = nil end
_G.GetSendMailItem = function(slot)
    local m = mail[slot]
    if not m then return nil end
    return m.name, m.id, 134400, m.count or 1
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
    local held = fake.bags[bag][slot]
    if held then cursor = { bag = bag, slot = slot, item = held } end
end

local function Names()
    local names = {}
    for _, m in pairs(mail) do names[#names + 1] = m.name end
    table.sort(names)
    return table.concat(names, ", ")
end

local ok, why = MailFill:Fill("Bob Stone", { { itemID = 7000, count = 1, link = bearLink } })
suite.check("it starts", ok == true, why)
suite.check("the Bear goes in the mail", Names() == "Boots of the Bear", Names())
suite.check("the Monkey stays in the bag", fake.bags[0][1] == monkey)

-- With no link, any version may go, as before.
mail = {}
fake.Put(bear)
suite.check("an item with no link still goes", #MailFill:PlanStacks(7000, 1, {}) == 1)

-- A link the bags no longer hold.
local stale = "|cffffffff|Hitem:7000:1::::::::|h[Boots of the Bear]|h|r"
suite.check("a stale link with two versions in the bags takes neither",
    #MailFill:PlanStacks(7000, 1, {}, stale) == 0)
fake.bags[0][1] = nil
local steps = MailFill:PlanStacks(7000, 1, {}, stale)
suite.check("a stale link with only one version there takes it",
    #steps == 1 and steps[1].slot == 2, #steps)

ns.Verdicts.Group = realGroup
_G.SendMailFrame, _G.SendMailNameEditBox, _G.SendMailSubjectEditBox = nil, nil, nil
_G.UnitGUID, _G.UnitName, _G.UnitFullName, _G.GetRealmName, _G.UnitFactionGroup = nil, nil, nil, nil, nil
_G.CursorHasItem, _G.ClearCursor, _G.GetSendMailItem, _G.ClickSendMailItemButton = nil, nil, nil, nil
_G.ATTACHMENTS_MAX_SEND = nil
suite.done()
