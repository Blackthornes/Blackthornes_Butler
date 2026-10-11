-- At a mailbox and the bank: Fill mail fills one character's mail a click
-- through Tradeskills and never sends; Move to bank puts the Always bank
-- list away; Take from bank brings out what the craft queue wants. The
-- window comes up for each when there is something to do, and goes with it.

local env = dofile(lfs_cwd .. "/tools/testenv.lua")
local suite = env.NewSuite("errands")

local ns = env.Load()
local fake = env.FakeBags({
    { bag = 0, slot = 1, id = 401, name = "Bolt of Wool", quality = 1, price = 50, count = 3 },
    { bag = 0, slot = 2, id = 402, name = "Patched Cloak", quality = 1, price = 30 },
    { bag = 0, slot = 3, id = 403, name = "Linen Cloth", quality = 1, price = 13, count = 20 },
    { bag = 0, slot = 4, id = 404, name = "Copper Ore", quality = 1, price = 5, count = 10 },
})

-- A bank of 16 slots, holding three stacks of Silk Cloth.
fake.bags[-1] = {}
local function PutBank(slot, id, count)
    local item = { bag = -1, slot = slot, id = id, name = "Silk Cloth", quality = 1, price = 40, count = count }
    fake.bags[-1][slot] = item
    fake.info[id] = item
end
PutBank(1, 501, 20)
PutBank(2, 501, 4)
PutBank(3, 501, 8)
_G.C_Container.GetContainerNumSlots = function(bag)
    if bag == 0 or bag == -1 then return fake.numSlots end
    return 0
end

-- Using an item at the bank moves it to the first free slot on the other
-- side, unless that side is full.
local bankFull, bagsFull = false, false
local used = {}
_G.C_Container.UseContainerItem = function(bag, slot)
    used[#used + 1] = bag .. ":" .. slot
    local item = fake.bags[bag][slot]
    if not item then return end
    local to = bag == -1 and 0 or -1
    if (to == -1 and bankFull) or (to == 0 and bagsFull) then return end
    for free = 1, fake.numSlots do
        if not fake.bags[to][free] then
            fake.bags[bag][slot] = nil
            item.bag, item.slot = to, free
            fake.bags[to][free] = item
            return
        end
    end
end

local filled, mailboxSaid = {}, {}
_G.BlackthornesTS = { Butler = {
    Advise = function(_, id)
        if id == 401 then return { mailTo = "Bob", mailCount = 1, auction = 300 } end
        if id == 403 then return { mailTo = "Bob", mailCount = 5 } end
        if id == 402 then return { auction = 25, disenchant = 500, canDisenchant = false, enchanter = "Ana" } end
    end,
    FillMail = function(_, name, items)
        filled[#filled + 1] = { name = name, items = items }
        return true
    end,
    FromBank = function() return { [501] = 10 } end,
    Holdings = function()
        return {
            { key = "me", short = "Me", realm = "Here", faction = "Horde", isCurrent = true },
            { key = "bob", short = "Bob", realm = "Here", faction = "Horde" },
            { key = "ana", short = "Ana", realm = "Here", faction = "Horde" },
            { key = "cy", short = "Cy", realm = "Here", faction = "Alliance" },
            { key = "di", short = "Di", realm = "Elsewhere", faction = "Horde" },
        }
    end,
    Mailbox = function(_, covered) mailboxSaid[#mailboxSaid + 1] = covered end,
} }
env.Enable(ns)

local UI, Errands = ns.UI, ns.Errands

-- The mailbox.
env.Fire("MAIL_SHOW")
suite.check("a mailbox brings the window up", UI:IsShown() and UI.openedFor == "mail")
suite.check("on Your bags", UI.view == "bags")
suite.check("with Fill mail for the character with the most", UI.mailButton:IsShown()
    and UI.mailButton.label:GetText() == "Fill mail to Bob", UI.mailButton.label:GetText())
suite.check("the footer says who presses Send", UI.footer:GetText():find("You press Send", 1, true) ~= nil)
suite.check("no bank buttons at a mailbox", not UI.bankButton:IsShown() and not UI.takeButton:IsShown())
suite.check("Tradeskills' mail panel is told to step aside", mailboxSaid[#mailboxSaid] == true)
-- The test frames run no scripts on Hide, so its OnHide is run by hand.
local function Close()
    UI:Hide()
    local onHide = UI.frame:GetScript("OnHide")
    if onHide then onHide(UI.frame) end
end
Close()
suite.check("closing Butler brings it back", mailboxSaid[#mailboxSaid] == false)
UI:Show("bags")
UI.openedFor = "mail"
suite.check("and opening it again covers it", mailboxSaid[#mailboxSaid] == true)

UI.mailButton:GetScript("OnClick")(UI.mailButton)
local first = filled[1]
suite.check("a click fills Bob's mail", first and first.name == "Bob")
local counts = {}
for _, item in ipairs(first and first.items or {}) do counts[item.itemID] = item.count end
suite.check("as many as the alt needs, no more", counts[401] == 1 and counts[403] == 5)
suite.check("then the next character", UI.mailButton.label:GetText() == "Fill mail to Ana", UI.mailButton.label:GetText())
UI.mailButton:GetScript("OnClick")(UI.mailButton)
suite.check("the enchanter gets the whole item", filled[2] and filled[2].name == "Ana"
    and filled[2].items[1].itemID == 402 and filled[2].items[1].count == 1)
suite.check("nobody left: the button goes", not UI.mailButton:IsShown())
local ok, why = Errands:FillMail()
suite.check("and nothing more is filled", not ok and why == "Nothing left to mail." and #filled == 2)

env.Fire("MAIL_CLOSED")
suite.check("leaving the mailbox closes the window it opened", not UI:IsShown())
suite.check("and the cover comes off", mailboxSaid[#mailboxSaid] == false)

-- Already open when the mailbox opens, it still goes when the player leaves.
UI:Show("bags")
env.Fire("MAIL_SHOW")
suite.check("open before the mailbox: it takes the mailbox", UI.openedFor == "mail")
env.Fire("MAIL_CLOSED")
suite.check("and goes when the mailbox closes", not UI:IsShown())

-- Walking away can end the interaction without MAIL_CLOSED.
env.Fire("MAIL_SHOW")
suite.check("the mailbox brings it up again", UI:IsShown())
env.Fire("PLAYER_INTERACTION_MANAGER_FRAME_HIDE", 17)
suite.check("walking away from the mailbox closes it", not UI:IsShown() and not Errands.mailOpen)
env.Fire("MAIL_CLOSED")
suite.check("and a MAIL_CLOSED after that changes nothing", not UI:IsShown())
UI:Show("bags")
env.Fire("PLAYER_INTERACTION_MANAGER_FRAME_HIDE", 5)
suite.check("another interaction ending leaves it be", UI:IsShown())
Close()

-- A new visit starts again from the first character.
env.Fire("MAIL_SHOW")
suite.check("a new visit starts again", UI.mailButton.label:GetText() == "Fill mail to Bob")
env.Fire("MAIL_CLOSED")

-- Without Tradeskills' FillMail.
local fillMail = _G.BlackthornesTS.Butler.FillMail
_G.BlackthornesTS.Butler.FillMail = nil
env.Fire("MAIL_SHOW")
ok, why = Errands:FillMail()
suite.check("without Tradeskills it says so", not ok and why:find("Tradeskills", 1, true) ~= nil)
_G.BlackthornesTS.Butler.FillMail = function() error("boom") end
ok = Errands:FillMail()
suite.check("a Tradeskills that raises fills nothing", not ok)
_G.BlackthornesTS.Butler.FillMail = function() return false, "still filling the last mail" end
ok, why = Errands:FillMail()
suite.check("and its reason is passed on", not ok and why:find("still filling", 1, true) ~= nil, why)
_G.BlackthornesTS.Butler.FillMail = fillMail
env.Fire("MAIL_CLOSED")

-- The setting off.
ns.db.openAtMailbox = false
env.Fire("MAIL_SHOW")
suite.check("Open at a mailbox off: it stays shut", not UI:IsShown())
env.Fire("MAIL_CLOSED")
ns.db.openAtMailbox = true

-- The bank. Copper Ore goes on the Always bank list.
ns.Verdicts:SetChoice(404, "bank")
ns.Bags:Changed()
env.Fire("BANKFRAME_OPENED")
suite.check("the bank brings the window up", UI:IsShown() and UI.openedFor == "bank")
suite.check("with Move to bank", UI.bankButton:IsShown() and UI.bankButton.label:GetText() == "Move 1 to bank",
    UI.bankButton.label:GetText())
suite.check("and Take from bank", UI.takeButton:IsShown())
suite.check("no Fill mail at the bank", not UI.mailButton:IsShown())

UI.bankButton:GetScript("OnClick")(UI.bankButton)
suite.check("the ore went to the bank", fake.bags[0][4] == nil and used[#used] == "0:4")
local banked = false
for _, item in pairs(fake.bags[-1]) do if item.id == 404 then banked = true end end
suite.check("and is there", banked)
suite.check("nothing left to put away: the button goes", not UI.bankButton:IsShown())

used = {}
UI.takeButton:GetScript("OnClick")(UI.takeButton)
suite.check("takes the smallest stacks that cover the need", table.concat(used, ",") == "-1:2,-1:3",
    table.concat(used, ","))
suite.check("and leaves the big one", fake.bags[-1][1] ~= nil and fake.bags[-1][1].count == 20)

-- A full bank stops the run.
ns.Verdicts:SetChoice(403, "bank")
ns.Bags:Changed()
bankFull = true
local before = #env.chat
ok = Errands:MoveToBank()
suite.check("a full bank stops and says so", ok and env.ChatText():find("bank is full", 1, true) ~= nil)
suite.check("and the cloth stays", fake.bags[0][3] ~= nil)
bankFull = false

-- Not in combat.
_G.InCombatLockdown = function() return true end
ok, why = Errands:MoveToBank()
suite.check("nothing moves in combat", not ok and why == "Not in combat.")
_G.InCombatLockdown = nil

env.Fire("BANKFRAME_CLOSED")
suite.check("leaving the bank closes the window it opened", not UI:IsShown())
ok, why = Errands:MoveToBank()
suite.check("away from the bank nothing moves", not ok and why == "Open your bank first.")

-- The right-click menu offers Always bank.
UI:Show()
UI:ShowMenu({ itemID = 401, name = "Bolt of Wool" })
UI.menu.bank:GetScript("OnClick")(UI.menu.bank)
suite.check("the menu puts it on the Always bank list", ns.db.alwaysBank[401] == true
    and ns.Verdicts:Choice(401) == "bank")
UI:ShowMenu({ itemID = 401, name = "Bolt of Wool" })
suite.check("and says so", UI.menu.bank.label:GetText() == "Always bank (now)" and UI.menu.decide:IsShown())
UI.menu.decide:GetScript("OnClick")(UI.menu.decide)
suite.check("Let Butler decide takes it off", ns.db.alwaysBank[401] == nil)

-- Always mail to: the player's characters on this realm and side.
local names = Errands:Characters()
suite.check("characters to mail to: same realm and side, not this one",
    table.concat(names, ",") == "Ana,Bob", table.concat(names, ","))
UI:ShowMenu({ itemID = 404, name = "Copper Ore" })
suite.check("the menu offers Always mail to", UI.menu.mail:IsShown())
UI.menu.mail:GetScript("OnClick")(UI.menu.mail)
suite.check("which lists them", UI.menu.characters[1]:IsShown()
    and UI.menu.characters[1].label:GetText() == "Ana" and UI.menu.back:IsShown())
UI.menu.characters[2]:GetScript("OnClick")(UI.menu.characters[2])
local choice, to = ns.Verdicts:Choice(404)
suite.check("a pick puts it on the Always mail list", choice == "mail" and to == "Bob"
    and ns.db.alwaysMail[404] == "Bob" and not ns.db.alwaysBank[404])
UI:ShowMenu({ itemID = 404, name = "Copper Ore" })
suite.check("and the menu says who", UI.menu.mail.label:GetText() == "Always mail to Bob")
UI:HideMenu()
local verdict, reason, _, _, extra = ns.Verdicts:Decide({ itemID = 404, count = 1 })
suite.check("it goes under Mail, to Bob", verdict == "mail" and extra and extra.to == "Bob", reason)
suite.check("bound to this character it is kept instead",
    (ns.Verdicts:Decide({ itemID = 404, count = 1, bound = true })) == "keep")
UI:ShowMenu({ itemID = 405, name = "Bound thing", bound = true })
suite.check("bound gear is not offered for mail", not UI.menu.mail:IsShown())
UI:ShowMenu({ itemID = 404, name = "Copper Ore" })
UI.menu.decide:GetScript("OnClick")(UI.menu.decide)
suite.check("Let Butler decide takes it off the mail list", ns.db.alwaysMail[404] == nil)

-- Never a mail to the character playing (a player found one, 2026-10-11):
-- the Always mail list is account wide, so it can name this character, and
-- an older Tradeskills could too.
ns.Verdicts:SetChoice(404, "mail", "Me")
verdict, reason = ns.Verdicts:Decide({ itemID = 404, count = 1 })
suite.check("Always mail to the character you're on keeps it", verdict == "keep"
    and reason:find("character you're on", 1, true) ~= nil, reason)
ns.Verdicts:SetChoice(404, nil)
local advise = _G.BlackthornesTS.Butler.Advise
_G.BlackthornesTS.Butler.Advise = function(_, id)
    if id == 401 then return { mailTo = "Me", mailCount = 1 } end
    if id == 402 then return { disenchant = 500, canDisenchant = false, enchanter = "Me" } end
end
suite.check("a craft mail to the character you're on is no mail",
    (ns.Verdicts:Decide({ itemID = 401, count = 1, link = "item:401" })) ~= "mail")
suite.check("nor a disenchant mail", (ns.Verdicts:Decide({ itemID = 402, count = 1, link = "item:402" })) ~= "mail")
_G.BlackthornesTS.Butler.Advise = advise

-- The chat line names the full name Tradeskills filled in.
_G.BlackthornesTS.Butler.FillMail = function(_, name) return true, nil, name .. " Smith" end
ns.Verdicts:Changed(true)
env.Fire("MAIL_SHOW")
ok, why = Errands:FillMail()
suite.check("the chat line has the full name", ok and why:find(" Smith: check it", 1, true) ~= nil, why)
_G.BlackthornesTS.Butler.FillMail = fillMail
env.Fire("MAIL_CLOSED")

-- At a mailbox with nothing to mail, Butler still takes over.
_G.BlackthornesTS.Butler.Advise = function() return nil end
ns.Verdicts:Changed(true)
ns.Bags:Changed()
Close()
env.Fire("MAIL_SHOW")
suite.check("nothing to mail: the window still comes up", UI:IsShown() and UI.openedFor == "mail")
suite.check("without a Fill mail button", not UI.mailButton:IsShown())
env.Fire("MAIL_CLOSED")

-- Typed toggles.
ns.HandleSlash("bank")
suite.check("/bbutler bank turns it off", ns.db.openAtBank == false)
ns.HandleSlash("mailbox")
suite.check("/bbutler mailbox turns it off", ns.db.openAtMailbox == false)

-- The next suites run in this same Lua, without Tradeskills.
_G.BlackthornesTS = nil

suite.done()
