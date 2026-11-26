-- Blackthornes Butler -- Probe/Probe.lua
-- /bbutler probe: ask the running client what it actually supports for bags,
-- vendors and mail, rather than trusting documentation written for another
-- version of the game, and say which of the other Blackthornes addons are
-- loaded for Butler to ask.
--
-- Same idea as Tradeskills' /bts probe, Equipment's /beq probe and Pets'
-- /bpet probe. It only reads: nothing is changed, sold, sent or saved apart
-- from the probe's own lines (ns.KeepCheck). Every call is inside a pcall,
-- because Forever hands out secret values in instances that raise when
-- touched.
--
-- The item list and Sell at a vendor lean on these; what the client answers
-- goes in docs/FOREVER_API_FINDINGS.md, so later features are built on it
-- instead of on a guess. It also says what /bbutler selltest found.

local _, ns = ...

local Probe = ns.NewModule("Probe")

-- The calls the plan needs: reading the bags (retail C_Container and the
-- classic globals), an item's price, quality and quest flags, selling at a
-- vendor, the mail form, and the bank.
local APIS = {
    "C_Container.GetContainerNumSlots", "C_Container.GetContainerItemInfo",
    "C_Container.GetContainerNumFreeSlots", "C_Container.GetBagName",
    "C_Container.GetContainerItemLink", "C_Container.GetContainerItemQuestInfo",
    "C_Container.UseContainerItem", "C_Container.PickupContainerItem",
    "GetContainerNumSlots", "GetContainerItemInfo", "UseContainerItem",
    "C_Item.GetItemInfo", "GetItemInfo", "C_Item.GetItemInfoInstant", "GetItemInfoInstant",
    "C_Item.RequestLoadItemDataByID", "C_Item.IsBound", "C_TooltipInfo.GetBagItem",
    "C_MerchantFrame.IsSellAllJunkEnabled", "C_MerchantFrame.SellAllJunkItems",
    "GetNumBuybackItems", "GetBuybackItemInfo", "GetBuybackItemLink", "BuybackItem",
    "SendMail", "hooksecurefunc",
    "SetSendMailShowing", "ClickSendMailItemButton", "GetSendMailItem",
    "C_Bank.CanUseBank", "C_QuestLog.GetNumQuestLogEntries",
    "GetMerchantNumItems", "GetMerchantItemLink", "C_MerchantFrame.GetItemInfo",
    "GetMerchantItemInfo", "BuyMerchantItem", "GetInventoryItemID", "C_TooltipInfo.GetMerchantItem",
}

-- The other four, and the call each answers Butler through ("Butler:Advise",
-- Logic/Sisters.lua).
local SISTERS = {
    { name = "Tradeskills", global = "BlackthornesTS" },
    { name = "Equipment", global = "BlackthornesEquipment" },
    { name = "Farmer", global = "BlackthornesFarmer" },
    { name = "Pets", global = "BlackthornesPets" },
}

local function Line(label, value)
    local ok, text = pcall(tostring, value)
    ns.PrintRaw(("  |c%s%s|r  %s"):format(ns.COLORS.muted, label, ok and text or "(unreadable)"))
end

local function Resolve(path)
    local value = _G
    for part in path:gmatch("[^.]+") do
        if type(value) ~= "table" then return nil end
        value = value[part]
    end
    return value
end

local function Has(path)
    return type(Resolve(path)) == "function"
end

local function Line(label, value)
    local ok, text = pcall(tostring, value)
    ns.PrintRaw(("  |c%s%s|r  %s"):format(ns.COLORS.muted, label, ok and text or "(unreadable)"))
end

--- A client value as plain text. In instances and on some units Forever hands
--- back secret values. tostring of one stays secret, and so does joining it
--- with "..", which the client allows; only table.concat and comparisons
--- raise. So ask the client first, where it can say, and otherwise prove the
--- text survives table.concat before handing it on.
local function Text(value)
    local isSecret = _G.issecretvalue
    if type(isSecret) == "function" then
        local ok, secret = pcall(isSecret, value)
        if not ok or secret then return "(secret)" end
    end
    local ok, text = pcall(function()
        local plain = tostring(value)
        return table.concat({ plain })
    end)
    return ok and text or "(secret)"
end

--- A table a call returned, as its size and up to eight of its fields, so a
--- list of pets or a pet's info can be read without a second probe. A list
--- shows its first entry's fields.
local function Summary(tbl)
    local ok, text = pcall(function()
        local count = 0
        for _ in pairs(tbl) do count = count + 1 end
        local sample, label = tbl, "table of " .. count
        if type(tbl[1]) == "table" then
            sample, label = tbl[1], label .. ", first"
        end
        local keys = {}
        for key in pairs(sample) do keys[#keys + 1] = Text(key) end
        table.sort(keys)
        local parts = {}
        for i = 1, math.min(#keys, 8) do
            local value = sample[keys[i]]
            if value == nil then value = sample[tonumber(keys[i])] end
            parts[i] = keys[i] .. "=" .. (type(value) == "table" and "table" or Text(value))
        end
        return label .. (#parts > 0 and (": " .. table.concat(parts, ", ")) or "")
    end)
    return ok and text or "a table (unreadable)"
end

--- Call a global (or a dotted C_ path) inside a pcall and join what it
--- returns, or say why not.
local function Read(name, ...)
    if not Has(name) then return "absent" end
    local results = { pcall(Resolve(name), ...) }
    if not results[1] then return "raised" end
    if #results == 1 then return "nothing" end
    if type(results[2]) == "table" then return Summary(results[2]) end

    local parts = {}
    for i = 2, #results do parts[#parts + 1] = Text(results[i]) end
    return table.concat(parts, ", ")
end

--- Whether a sister addon is loaded, and whether it answers Butler yet.
local function Sister(info)
    local global = rawget(_G, info.global)
    if type(global) ~= "table" then return "not loaded" end
    local version = type(global.VERSION) == "string" and global.VERSION or "?"
    local butler = rawget(global, "Butler")
    local answers = type(butler) == "table" and type(butler.Advise) == "function"
    return ("loaded (%s), %s"):format(version, answers and "answers Butler" or "no Butler call (update it)")
end

--- The first item in the backpack, as the bag calls read it.
local function FirstItem()
    for slot = 1, 40 do
        local info = Resolve("C_Container.GetContainerItemInfo")
        if type(info) ~= "function" then return "C_Container.GetContainerItemInfo absent" end
        local ok, item = pcall(info, 0, slot)
        if not ok then return "raised" end
        if type(item) == "table" then
            return ("slot %d: %s"):format(slot, Summary(item))
        end
    end
    return "backpack empty"
end

-- How many items the Forever client's game tables give Butler, and for each
-- bag slot the family the client says beside the one the tables say, so a
-- report shows whether the two agree (Data/ForeverItems.lua).
local function ForeverTables()
    local data = ns.ForeverItems
    if not data then return "missing" end
    local prices, bags = 0, 0
    for _ in pairs(data.SELL or {}) do prices = prices + 1 end
    for _ in pairs(data.BAGS or {}) do bags = bags + 1 end
    local parts = { ("%d sell prices, %d bag kinds"):format(prices, bags) }
    for bag = 1, tonumber(_G.NUM_BAG_SLOTS) or 4 do
        local live = select(2, ns.Items.Call({ "C_Container.GetContainerNumFreeSlots", "GetContainerNumFreeSlots" }, bag))
        local ok, text = pcall(function() return tostring(live) end)
        parts[#parts + 1] = ("bag %d %s/%s"):format(bag, ok and text or "(secret)", tostring(ns.Items.TableBagFamily(bag)))
    end
    return table.concat(parts, ", ")
end

function Probe:Run()
    ns.Print("probe: what this client supports for bags, vendors and mail")

    -- Two lines rather than one per call, so the whole probe fits in the
    -- chat window without scrolling.
    local present, missing = {}, {}
    for _, api in ipairs(APIS) do
        if Has(api) then
            present[#present + 1] = api
        else
            missing[#missing + 1] = api
        end
    end
    Line("has", #present > 0 and table.concat(present, ", ") or "none of them")
    Line("missing", #missing > 0 and table.concat(missing, ", ") or "nothing")

    -- The Blizzard window style draws with the game's own art; this says
    -- which pieces the client has (UI/BlizzardLook.lua).
    if ns.BlizzardLook then
        for _, text in ipairs(ns.BlizzardLook.ProbeLines()) do
            local name, value = text:match("^(.-): (.*)$")
            Line(name or "style", value or text)
        end
    end

    for _, info in ipairs(SISTERS) do
        Line(info.name, Sister(info))
    end

    Line("backpack slots", Read("C_Container.GetContainerNumSlots", 0))
    Line("first item", FirstItem())
    Line("buyback", Read("GetNumBuybackItems"))
    if ns.Selling then Line("sell from Butler", ns.Selling:ProbeText()) end
    if ns.Disenchanting then Line("disenchant", ns.Disenchanting:ProbeText()) end
    if ns.FreeSpace then Line("free bag space", ns.FreeSpace:ProbeText()) end
    if ns.WhoHas then Line("who has it", ns.WhoHas:ProbeText()) end
    if ns.VerdictTip then Line("verdict on tooltips", ns.VerdictTip:ProbeText()) end
    if ns.VendorPrices then Line("vendor prices", ns.VendorPrices:ProbeText()) end
    if ns.Trash then Line("trash can", ns.Trash:ProbeText()) end
    if ns.SwapWhenFull then Line("swap when full", ns.SwapWhenFull:ProbeText()) end
    if ns.Ammo then Line("ammo", ns.Ammo:ProbeText()) end
    if ns.Restock then Line("restock", ns.Restock:ProbeText()) end
    if ns.BuyManyUI then Line("buy more", ns.BuyManyUI:ProbeText()) end
    if ns.ClassTraining then Line("class training", ns.ClassTraining:ProbeText()) end
    if ns.GoldGoals then Line("gold goals", ns.GoldGoals:ProbeText()) end
    Line("forever tables", ForeverTables())
    if ns.Jobs then Line("jobs", ns.Jobs:ProbeText()) end
    if ns.Quests then Line("quest items", ns.Quests:ProbeText()) end
    if ns.Kinds then Line("kinds", ns.Kinds:ProbeText()) end
    if ns.QuestBuy then Line("buy quest items", ns.QuestBuy:ProbeText()) end
    if ns.BagWindow then Line("bag window", ns.BagWindow:ProbeText()) end
end

--------------------------------------------------------------------------------
-- /bbutler bankprobe: what Forever allows at a banker
--------------------------------------------------------------------------------
-- Asked before a Butler Bank window is built (the owner said build it,
-- 2026-11-26): which bank calls, containers and frames the client has, and
-- whether the game's own item square, made by this addon, can move a bank
-- item. Run at a banker. It reads only, except for one test square of the
-- first bank item: nothing moves unless the player clicks that square. A
-- right-click on it should put the item in the bags, as the game's bank
-- does. What happened is printed and kept (ns.KeepCheck) once the bags
-- settle. What it finds goes in docs/FOREVER_API_FINDINGS.md.

local BankProbe = {}
Probe.Bank = BankProbe

BankProbe.APIS = {
    "C_Bank.CanUseBank", "C_Bank.FetchPurchasedBankTabData", "C_Bank.FetchNumPurchasedBankTabs",
    "C_Bank.AutoDepositItemsIntoBank", "GetNumBankSlots", "PurchaseSlot", "GetBankSlotCost",
    "BankButtonIDToInvSlotID", "C_Container.ContainerIDToInventoryID", "C_Container.SortBankBags",
    "SortBankBags", "C_Container.GetBankAutosortDisabled", "DepositReagentBank", "CloseBankFrame",
    "C_Container.UseContainerItem", "C_Container.PickupContainerItem", "CursorHasItem",
    "SetItemButtonTexture", "SetItemButtonCount",
}

BankProbe.FRAMES = {
    "BankFrame", "BankSlotsFrame", "BankFrameItem1", "BankFrameBag1", "BankFrameTab1",
    "BankFrameMoneyFrame", "BankItemSearchBox", "ReagentBankFrame", "BankPanel", "AccountBankPanel",
    "ContainerFrame6", "ContainerFrame7", "ContainerFrame8", "ContainerFrame9", "ContainerFrame10",
    "ContainerFrame11", "ContainerFrame12", "ContainerFrame13",
}

BankProbe.BAG_INDEX = {
    "Bank", "BankBag_1", "BankBag_7", "Reagentbank", "ReagentBank", "CharacterBankTab_1",
    "CharacterBankTab_6", "AccountBankTab_1",
}

-- BankItemButtonGenericTemplate is not in Forever (asking for it raised
-- and printed a taint line, 2026-11-26), so only the bag template is tried.
BankProbe.TEMPLATES = { "ContainerFrameItemButtonTemplate" }

-- Made once and kept, so running the probe again adds no frames.
local made = {}

local function InCombat()
    local fn = rawget(_G, "InCombatLockdown")
    if type(fn) ~= "function" then return false end
    local ok, value = pcall(fn)
    return ok and value == true
end

local function Ask(frame, method, ...)
    local fn = type(frame) == "table" and frame[method]
    if type(fn) ~= "function" then return nil end
    local ok, value = pcall(fn, frame, ...)
    if ok then return value end
    return nil
end

local function ItemAt(bag, slot)
    local info = Resolve("C_Container.GetContainerItemInfo")
    if type(info) ~= "function" then return nil end
    local ok, item = pcall(info, bag, slot)
    if ok and type(item) == "table" then return item end
    return nil
end

local function NumSlots(bag)
    local fn = Resolve("C_Container.GetContainerNumSlots")
    if type(fn) ~= "function" then return 0 end
    local ok, count = pcall(fn, bag)
    return ok and tonumber(count) or 0
end

--- The bank's containers as Butler reads them, each with its slots and
--- items, and the first item found.
function BankProbe.Containers()
    local parts, first = {}, nil
    local ids = ns.Errands and ns.Errands.BankBagIDs() or { -1 }
    -- Forever's bank is in tabs (Enum.BagIndex.CharacterBankTab_1 and on).
    -- Bag -1 still answers there with a few items, but the game shows none
    -- of them and a click says the spot is empty (seen 2026-11-26). So the
    -- test item comes from a tab when the client has tabs.
    local enum = rawget(_G, "Enum")
    local index = type(enum) == "table" and type(enum.BagIndex) == "table" and enum.BagIndex
    local firstTab = index and tonumber(index.CharacterBankTab_1)
    for _, bag in ipairs(ids) do
        local slots, items = NumSlots(bag), 0
        local counts = not firstTab or bag >= firstTab
        for slot = 1, slots do
            if ItemAt(bag, slot) then
                items = items + 1
                if counts and not first then first = { bag = bag, slot = slot } end
            end
        end
        parts[#parts + 1] = ("%d: %d slots %d items"):format(bag, slots, items)
    end
    return table.concat(parts, ", "), first
end

--- The game's frames for the bank: present ones with shown and protected,
--- then the missing ones in one list.
function BankProbe.Frames()
    local found, missing = {}, {}
    for _, name in ipairs(BankProbe.FRAMES) do
        local frame = rawget(_G, name)
        if type(frame) == "table" then
            found[#found + 1] = ("%s (shown %s, protected %s)"):format(name,
                tostring(Ask(frame, "IsShown") == true), tostring(Ask(frame, "IsProtected") == true))
        else
            missing[#missing + 1] = name
        end
    end
    return found, missing
end

function BankProbe.BagIndex()
    local enum = rawget(_G, "Enum")
    local index = type(enum) == "table" and enum.BagIndex
    if type(index) ~= "table" then return "Enum.BagIndex absent" end
    local parts = {}
    for _, key in ipairs(BankProbe.BAG_INDEX) do
        if index[key] ~= nil then parts[#parts + 1] = key .. "=" .. Text(index[key]) end
    end
    return #parts > 0 and table.concat(parts, ", ") or "no bank keys"
end

--- Makes (once) a square from the game's template for bag and slot: the
--- holder carries the bag, the square the slot, as Butler Bags does.
local function Square(template, bag, slot)
    local entry = made[template]
    if not entry then
        local number = 1
        for i, name in ipairs(BankProbe.TEMPLATES) do if name == template then number = i end end
        local holder = CreateFrame("Frame", nil, UIParent)
        local ok, button = pcall(CreateFrame, "ItemButton", "BlackthornesButlerBankProbe" .. number, holder, template)
        if not ok or type(button) ~= "table" then
            ok, button = pcall(CreateFrame, "Button", nil, holder, template)
        end
        entry = { holder = holder, ok = ok and type(button) == "table", button = ok and button or nil, err = not ok and Text(button) or nil }
        made[template] = entry
    end
    if entry.button then
        pcall(entry.holder.SetID, entry.holder, bag)
        pcall(entry.button.SetID, entry.button, slot)
    end
    return entry
end

--- How a template made by this addon behaves on the first bank item.
function BankProbe.Template(template, first)
    if not first then return "no bank item to try" end
    if InCombat() then return "in a fight, not made" end
    local entry = Square(template, first.bag, first.slot)
    if not entry.ok then return "raised: " .. tostring(entry.err) end
    local button = entry.button
    local bag = Ask(button, "GetBagID")
    local parts = {
        "made",
        "protected " .. tostring(Ask(button, "IsProtected") == true),
        "GetBagID " .. (bag == nil and "absent" or Text(bag)),
        "SetBagID " .. tostring(type(button.SetBagID) == "function"),
        "OnClick " .. tostring(type(Ask(button, "GetScript", "OnClick")) == "function"),
    }
    return table.concat(parts, ", ")
end

-- The live test: one square of the first bank item, and what the bags and
-- the game say after the player clicks it.
local watching

local function Report(result)
    local lines = BankProbe.lastLines or {}
    ns.KeepCheck("bankprobe", function()
        ns.Print("bankprobe: the test square")
        for _, line in ipairs(lines) do ns.PrintRaw(line) end
        for _, text in ipairs(result) do Line("click", text) end
    end)
end

function BankProbe:StopWatching()
    watching = nil
    for _, event in ipairs({ "BAG_UPDATE_DELAYED", "ADDON_ACTION_BLOCKED", "ADDON_ACTION_FORBIDDEN", "BANKFRAME_CLOSED" }) do
        ns.UnregisterEvent(BankProbe, event)
    end
    local entry = made[BankProbe.TEMPLATES[1]]
    if entry and entry.holder and not InCombat() then pcall(entry.holder.Hide, entry.holder) end
end

--- Called by the square's click (hooked, so the game's own click runs
--- first) and by the events while the test runs.
function BankProbe:Clicked(mouse)
    if not watching then return end
    watching.clicked = mouse or "?"
    local cursor = Resolve("CursorHasItem")
    if type(cursor) == "function" then
        local ok, has = pcall(cursor)
        watching.cursor = ok and has == true
    end
end

function BankProbe:Blocked(event, addon, call)
    if not watching then return end
    watching.blocked[#watching.blocked + 1] = ("%s %s %s"):format(event, Text(addon), Text(call))
end

function BankProbe:Settled()
    if not (watching and watching.clicked) then return end
    local w = watching
    local still = ItemAt(w.bag, w.slot)
    local result = {
        ("%s-click on bank %d slot %d"):format(tostring(w.clicked), w.bag, w.slot),
        "in a fight " .. tostring(InCombat()),
        "on the cursor " .. tostring(w.cursor == true),
        still and ("still in the bank (id %s)"):format(Text(still.itemID)) or "left the bank slot",
        #w.blocked > 0 and ("blocked: " .. table.concat(w.blocked, "; ")) or "nothing blocked",
    }
    BankProbe:StopWatching()
    Report(result)
end

function BankProbe:Watch(first)
    local entry = made[BankProbe.TEMPLATES[1]]
    if not (entry and entry.button) or InCombat() then return false end
    local button = entry.button
    local item = ItemAt(first.bag, first.slot)
    pcall(entry.holder.SetSize, entry.holder, 40, 40)
    pcall(entry.holder.ClearAllPoints, entry.holder)
    pcall(entry.holder.SetPoint, entry.holder, "CENTER", UIParent, "CENTER", 0, 120)
    pcall(entry.holder.SetFrameStrata, entry.holder, "DIALOG")
    pcall(button.SetSize, button, 37, 37)
    pcall(button.ClearAllPoints, button)
    pcall(button.SetPoint, button, "CENTER", entry.holder, "CENTER")
    local texture, count = Resolve("SetItemButtonTexture"), Resolve("SetItemButtonCount")
    if item and type(texture) == "function" then pcall(texture, button, item.iconFileID) end
    if item and type(count) == "function" then pcall(count, button, item.stackCount) end
    if not entry.hooked then
        entry.hooked = true
        pcall(button.HookScript, button, "OnClick", function(_, mouse) BankProbe:Clicked(mouse) end)
    end
    pcall(entry.holder.Show, entry.holder)
    pcall(button.Show, button)

    watching = { bag = first.bag, slot = first.slot, blocked = {} }
    ns.RegisterEvent(BankProbe, "BAG_UPDATE_DELAYED", function() BankProbe:Settled() end)
    ns.RegisterEvent(BankProbe, "ADDON_ACTION_BLOCKED", function(_, _, addon, call) BankProbe:Blocked("ADDON_ACTION_BLOCKED", addon, call) end)
    ns.RegisterEvent(BankProbe, "ADDON_ACTION_FORBIDDEN", function(_, _, addon, call) BankProbe:Blocked("ADDON_ACTION_FORBIDDEN", addon, call) end)
    ns.RegisterEvent(BankProbe, "BANKFRAME_CLOSED", function() BankProbe:StopWatching() end)
    return true
end

function BankProbe:Run()
    BankProbe:StopWatching()
    ns.Print("bankprobe: what this client allows at a banker")

    local atBank = ns.Errands and ns.Errands.bankOpen == true
    local lines = {}
    local function Add(label, value)
        Line(label, value)
        local ok, text = pcall(tostring, value)
        lines[#lines + 1] = ("  %s  %s"):format(label, ok and text or "(unreadable)")
    end

    Add("at a banker", tostring(atBank))
    Add("in a fight", tostring(InCombat()))
    local present, missing = {}, {}
    for _, api in ipairs(BankProbe.APIS) do
        if Has(api) then present[#present + 1] = api else missing[#missing + 1] = api end
    end
    Add("has", #present > 0 and table.concat(present, ", ") or "none of them")
    Add("missing", #missing > 0 and table.concat(missing, ", ") or "nothing")
    Add("can use bank", Read("C_Bank.CanUseBank", 0))
    Add("bank bag slots bought", Read("GetNumBankSlots"))
    Add("bag index", BankProbe.BagIndex())
    Add("NUM_BANKBAGSLOTS", Text(rawget(_G, "NUM_BANKBAGSLOTS")))
    local containers, first = BankProbe.Containers()
    Add("containers", containers)
    Add("first bank item", first and ("bag %d slot %d"):format(first.bag, first.slot) or "none")
    local found, gone = BankProbe.Frames()
    Add("frames", #found > 0 and table.concat(found, ", ") or "none")
    Add("frames missing", #gone > 0 and table.concat(gone, ", ") or "none")
    for _, template in ipairs(BankProbe.TEMPLATES) do
        Add(template, BankProbe.Template(template, first))
    end
    self.lastLines = lines

    if not atBank then
        Add("test square", "not shown: open the bank and run it again")
    elseif not first then
        Add("test square", "not shown: the bank is empty")
    elseif BankProbe:Watch(first) then
        Add("test square", "shown above the middle of the screen. Right-click it to move the item to your bags.")
    else
        Add("test square", "not shown (in a fight, or the template is missing)")
    end
    self.lastLines = lines
end

ns.RegisterHiddenCommand("bankprobe", function()
    ns.KeepCheck("bankprobe", BankProbe.Run, BankProbe)
end)

ns.RegisterHiddenCommand("probe", function()
    ns.KeepCheck("probe", Probe.Run, Probe)
end)
