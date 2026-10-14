-- Blackthornes Butler -- Logic/Verdicts.lua
-- One verdict for every item in the bags, and the reason for it.
--
-- The first rule that applies wins, and keeping always beats selling:
--
--   0. In one of the player's equipment sets       Keep
--   1. On the player's Always keep list            Keep
--      ... or Always bank list                     Bank
--      ... or learned: bought back after Butler sold it   Keep
--   2. A quest item, or one that starts one        Keep
--   3. A vendor won't buy it                       Keep
--   4. On the player's Always sell list            Sell, unless Equipment
--      says it is an upgrade to wear now          Look at it
--   4b. Ammo for the hunter's bow or gun           Keep
--   5. Equipment: an upgrade now or later, a tool  Keep
--   6. Farmer: a goal of this character needs it   Keep
--   7. Tradeskills: the craft queue needs it here  Keep
--      ... or an alt needs it for theirs           Mail
--   8. Pets: the pet eats it                       Keep
--   8b. Tradeskills: bought on the auction house
--      to disenchant                              Disenchant, or Mail to
--                                                  the enchanter
--   8bb. Tradeskills: a green, not crafted, that
--      gives a material this character's
--      Enchanting still lacks for a sure point     Disenchant
--   8c. Tradeskills: gear its Mail page sends to
--      the disenchanter typed in its Settings      Mail to the disenchanter
--   8d. Learned: the player mails it to one of
--      their characters by hand                    Mail
--   9. Its price has not loaded yet                Look at it
--   9b. Learned: the player sells it by hand       Sell
--  10. Grey (worth vendor only)                    Sell
--  11. Worth less than the player's Sell below amount (vendor, auction
--      and disenchant, whichever is most)          Sell
--  12. The best of vendor, auction (marked down when it sells slowly)
--      and disenchant                              Sell, Auction,
--                                                  Disenchant or Mail
--      ... Auction, but today's cheapest listing
--      is well under its usual price               Wait for a better price
--  13. Anything else                               Look at it
--
-- Steps 5 to 8, 11 and 12 ask the other four addons (Logic/Sisters.lua); a
-- sister that is not loaded is skipped. "Look at it" is never sold for the
-- player, and neither is soulbound green or better gear: it can only be
-- disenchanted or looked at.
--
-- The Always keep, Always sell and Always bank lists are the player's own
-- choices, account wide, by item ID: BlackthornesButlerDB.alwaysKeep,
-- .alwaysSell and .alwaysBank ([itemID] = true), and .alwaysMail
-- ([itemID] = the character's short name). Never rename them.
--
-- Sell below (a player asked, the owner agreed 2026-10-11) is
-- BlackthornesButlerDB.sellBelow, copper, account wide, nil when off (never
-- rename it). It only ever adds to Sell, never deletes, and only once
-- Tradeskills has said what the auction house pays: without it Butler can't
-- tell junk from a white item that sells well, so the step is skipped.
--
-- A Mail row also says who it goes to and how many (row.mailTo,
-- row.mailCount), for the Fill mail button (Logic/Errands.lua).

local _, ns = ...
local L = ns.L

local Verdicts = ns.NewModule("Verdicts")

local Items = ns.Items
local Sisters = ns.Sisters

-- The order the groups show in: what to do first at the top.
Verdicts.ORDER = { "sell", "auction", "disenchant", "mail", "bank", "look", "wait", "keep" }

Verdicts.LABELS = {
    sell = L["Sell"],
    auction = L["Auction"],
    disenchant = L["Disenchant"],
    mail = L["Mail"],
    bank = L["Bank"],
    look = L["Look at it"],
    wait = L["Wait for a better price"],
    keep = L["Keep"],
}

-- An auction price is worth this much of itself when Tradeskills says the
-- item sells slowly: a slow sale ties up the slot and the deposit.
Verdicts.SLOW = 0.75

-- An item to auction waits for a better price when today's cheapest listing
-- by someone else (Tradeskills' auctionNow) would fetch less than this much
-- of its usual price (auction). A little under is normal: the usual price is
-- an average of the cheapest listings, so only a real dip counts.
Verdicts.LOW_NOW = 0.85


-- Moves whenever a judgement could change (a choice made, an item loaded),
-- so kept answers and the drawn list are known to be stale.
Verdicts.version = 0

-- [link] = { verdict, reason, unit, extra }, for Verdicts.version.
local memo, memoVersion = {}, 0

--------------------------------------------------------------------------------
-- The player's own choices
--------------------------------------------------------------------------------

local function List(name)
    if not ns.db then return {} end
    if type(ns.db[name]) ~= "table" then ns.db[name] = {} end
    return ns.db[name]
end

--- "keep", "sell", "bank", "mail" or nil: what the player said about this
--- item. For "mail", the second return is who it goes to.
function Verdicts:Choice(itemID)
    if not itemID then return nil end
    if List("alwaysKeep")[itemID] then return "keep" end
    if List("alwaysSell")[itemID] then return "sell" end
    if List("alwaysBank")[itemID] then return "bank" end
    local to = List("alwaysMail")[itemID]
    if type(to) == "string" and to ~= "" then
        -- Saved before names were whole ("Ana S."): read as the full name.
        if ns.Errands and ns.Errands.FullName then to = ns.Errands:FullName(to) end
        return "mail", to
    end
    return nil
end

--- Put an item on the Always keep, Always sell, Always bank or Always mail
--- list (`to` the character, for "mail"), or take it off all four (`choice`
--- nil) so Butler decides again.
function Verdicts:SetChoice(itemID, choice, to)
    if not itemID then return end
    if choice == "mail" and not (type(to) == "string" and to ~= "") then return end
    List("alwaysKeep")[itemID] = (choice == "keep") or nil
    List("alwaysSell")[itemID] = (choice == "sell") or nil
    List("alwaysBank")[itemID] = (choice == "bank") or nil
    List("alwaysMail")[itemID] = (choice == "mail") and to or nil
    -- The player's own pick (or Let Butler decide) replaces what was learned.
    if ns.Learning then ns.Learning:Forget(itemID) end
    self:Changed(true)
end

--------------------------------------------------------------------------------
-- Judging
--------------------------------------------------------------------------------

local function Each(unit)
    if not unit or unit <= 0 then return "" end
    return L.Format("Vendor %s each", Items.FormatMoney(unit))
end

--- The verdict for one carried item, why, what a vendor pays for one, and
--- for Mail { to, count }. `entry` is a slot from Bags (itemID, link,
--- quality, noValue, quest).
--- `noAlt` judges a copy past what an alt's upgrade needs, or past the
--- greens that already cover what Enchanting lacks (Verdicts:Groups): as
--- if no alt and no skill-up wanted it.
function Verdicts:Judge(entry, noAlt)
    if memoVersion ~= self.version then
        memo, memoVersion = {}, self.version
    end
    -- How many are carried is part of the key: what the sisters say (how
    -- many an alt's queue still wants mailed, a goal's count, pet food)
    -- moves with it, so an item is asked again only when its own count
    -- changed (eight Medium Leather crafted one at a time were mailed as
    -- one, 2026-10-11).
    local carried = entry.itemID and ns.Bags.Carried and ns.Bags:Carried(entry.itemID) or 0
    -- Soulbound too: a link doesn't say it, and a bound copy of gear can't
    -- be mailed or auctioned as an unbound one beside it can.
    local key = (noAlt and "x|" or "") .. (entry.bound and "b|" or "")
        .. tostring(entry.link or entry.itemID) .. "#" .. carried
    local known = memo[key]
    if known then return known[1], known[2], known[3], known[4] end

    local verdict, reason, unit, final, extra = self:Decide(entry, noAlt)
    -- An answer that waits on the client loading the item is asked again.
    if final then memo[key] = { verdict, reason, unit, extra } end
    return verdict, reason, unit, extra
end

--- The rules above, in order. The fourth return says whether the answer
--- will hold (false while the price is still loading); the fifth is who a
--- Mail row goes to and how many ({ to, count }).
function Verdicts:Decide(entry, noAlt)
    local itemID = entry.itemID
    -- Gear in one of the player's equipment sets is never sold, mailed or
    -- broken, whatever a list or a sister says (a player asked, 2026-10-13).
    local set = self:InSet(itemID)
    if set then
        return "keep", type(set) == "string" and L.Format("In your %s equipment set", set)
            or L["In one of your equipment sets"], nil, true
    end
    local choice, mailTo = self:Choice(itemID)

    if choice == "keep" then
        -- An alt's queued craft still gets its share, and the list keeps
        -- the rest (the owner, 2026-10-11, whose leather on the
        -- Always keep list was never offered to the alt crafting with it).
        local verdict, reason, extra = self:ForAltCraft(entry)
        if verdict then
            return verdict, reason, Items:SellPrice(itemID), true, extra
        end
    end
    if choice == "keep" then
        return "keep", L["On your Always keep list"], nil, true
    end
    if choice == "bank" then
        return "bank", L["On your Always bank list"], Items:SellPrice(itemID), true
    end
    if choice == "mail" then
        -- Soulbound can't go in the mail, whatever the list says, and the
        -- list is account wide, so it can name the character playing.
        if self:IsMe(mailTo) then
            return "keep", L.Format("On your Always mail list for %s, the character you're on", mailTo), nil, true
        end
        if entry.bound then
            return "keep", L.Format("Soulbound, so it can't be mailed to %s", mailTo), nil, true
        end
        -- This character's own queued crafts come first (the owner,
        -- 2026-10-14): Tradeskills' `need` is what they still use from the
        -- bags, so only what is left over goes in the mail.
        local queued = Sisters.Number(Sisters:Ask("ts", entry), "need")
        if queued and queued > 0 then
            local spare = math.max(ns.Bags:Carried(itemID), entry.count or 1) - queued
            if spare <= 0 then
                return "keep", L.Format("On your Always mail list, but your craft queue needs %d", queued),
                    nil, true
            end
            return "mail", L.Format("Mail %d to %s, keep %d for your craft queue", spare, mailTo, queued),
                Items:SellPrice(itemID), true, { to = mailTo, count = spare }
        end
        return "mail", L.Format("On your Always mail list, to %s", mailTo), Items:SellPrice(itemID), true,
            { to = mailTo }
    end

    -- What Butler learned from the player (Logic/Learning.lua): a buyback
    -- keeps, here; a habit of selling or mailing waits for the sisters.
    local learned, learnedTo
    if not choice and ns.Learning then learned, learnedTo = ns.Learning:Get(itemID) end
    if learned == "keep" then
        return "keep", ns.Learning.Reason("keep"), nil, true
    end

    if entry.quest == "starts" then
        return "keep", L["Starts a quest"], nil, true
    elseif entry.quest == "item" then
        return "keep", L["Quest item"], nil, true
    end

    if entry.noValue then
        return "keep", L["Vendors won't buy it"], nil, true
    end

    local unit = Items:SellPrice(itemID)
    if unit == 0 then
        return "keep", L["Vendors won't buy it"], 0, true
    end

    if choice == "sell" then
        -- Always sell gives way to one thing: gear Equipment says is an
        -- upgrade to wear now. It is not sold on a list made when it was junk.
        local eq = Sisters:Ask("equipment", entry)
        if eq and eq.upgrade == "now" then
            return "look", L["On your Always sell list, but it's an upgrade for you"], unit, unit ~= nil
        end
        return "sell", L["On your Always sell list"], unit, unit ~= nil
    end

    -- A vendor always pays most for arrows and bullets, so the hunter's
    -- own ammo is kept (Logic/Ammo.lua).
    local ammo = ns.Ammo and ns.Ammo:Keeps(itemID)
    if ammo then return "keep", ammo, unit, unit ~= nil end

    local said = Sisters:AskAll(entry)
    local verdict, reason, worth, extra = self:Kept(said, entry, noAlt)
    if verdict then return verdict, reason, worth or unit, unit ~= nil, extra end

    verdict, reason, worth, extra = self:Bought(entry, said)
    if verdict then return verdict, reason, worth or unit, unit ~= nil, extra end

    if not noAlt then
        verdict, reason, worth, extra = self:ForEnchanting(entry, said)
        if verdict then return verdict, reason, worth or unit, unit ~= nil, extra end
    end

    verdict, reason, worth, extra = self:ForDisenchanter(entry, said)
    if verdict then return verdict, reason, worth or unit, unit ~= nil, extra end

    -- A habit of mailing it to one of the player's characters: soulbound
    -- can't go, and never to the character playing.
    if learned == "mail" and not entry.bound and not self:IsMe(learnedTo) then
        return "mail", ns.Learning.Reason("mail", learnedTo), unit, unit ~= nil, { to = learnedTo }
    end

    if unit == nil then
        return "look", L["Still loading from the game"], nil, false
    end

    -- A habit of selling it by hand. Soulbound green or better is never
    -- sold for the player, habit or not.
    if learned == "sell" and not (entry.bound and (entry.quality or 0) >= 2) then
        return "sell", L.Format("%s: %s each", ns.Learning.Reason("sell"), Items.FormatMoney(unit)), unit, true
    end

    if entry.quality == 0 then
        return "sell", L["Grey, vendor only"], unit, true
    end

    verdict, reason, worth, extra = self:Best(entry, unit, said)
    return verdict, reason, worth, true, extra
end

--------------------------------------------------------------------------------
-- Equipment sets
--------------------------------------------------------------------------------

-- [itemID] = the first set's name, read again after EQUIPMENT_SETS_CHANGED.
local setItems

--- Call a client function by dotted name inside a pcall: its results, or
--- nothing when it is missing or raises.
local function Client(path, ...)
    local fn = _G
    for part in path:gmatch("[^%.]+") do
        fn = type(fn) == "table" and fn[part] or nil
    end
    if type(fn) ~= "function" then return nil end
    local results = { pcall(fn, ...) }
    if not results[1] then return nil end
    return unpack(results, 2)
end

--- Every item in the player's equipment sets, by ID: the retail calls
--- (C_EquipmentSet) first, then the classic ones. A client with neither
--- has no sets, so nothing is held back.
function Verdicts.ReadSets()
    local items = {}
    local function Add(ids, name)
        if type(ids) ~= "table" then return end
        for _, id in pairs(ids) do
            id = tonumber(id)
            if id and id > 0 and not items[id] then items[id] = name end
        end
    end
    local setIDs = Client("C_EquipmentSet.GetEquipmentSetIDs")
    if type(setIDs) == "table" then
        for _, setID in ipairs(setIDs) do
            local name = Client("C_EquipmentSet.GetEquipmentSetInfo", setID)
            name = type(name) == "string" and name ~= "" and name or true
            Add(Client("C_EquipmentSet.GetItemIDs", setID), name)
        end
        return items
    end
    local count = tonumber(Client("GetNumEquipmentSets")) or 0
    for index = 1, count do
        local name = Client("GetEquipmentSetInfo", index)
        if type(name) == "string" and name ~= "" then
            Add(Client("GetEquipmentSetItemIDs", name), name)
        end
    end
    return items
end

--- The name of an equipment set holding this item, or nil.
function Verdicts:InSet(itemID)
    if not itemID then return nil end
    if not setItems then setItems = Verdicts.ReadSets() end
    return setItems[itemID]
end

--- The sets changed: read them again and judge again.
function Verdicts:SetsChanged()
    setItems = nil
    self:Changed()
end

function Verdicts:OnEnable()
    ns.RegisterEvent(self, "EQUIPMENT_SETS_CHANGED", function() Verdicts:SetsChanged() end)
end

--- "mail", why and { to, count } when Tradeskills says an alt's queued
--- crafts want some of an item on the Always keep list (only what
--- this character's own crafts can spare); nil otherwise.
function Verdicts:ForAltCraft(entry)
    if entry.bound then return nil end
    local ts = Sisters:Ask("ts", entry)
    local mailTo = Sisters.String(ts, "mailTo")
    local count = Sisters.Number(ts, "mailCount")
    if not mailTo or self:IsMe(mailTo) or not (count and count > 0) then return nil end
    return "mail", L.Format("Mail %d to %s for their crafts, keep the rest", count, mailTo),
        { to = mailTo, count = count }
end

--- The short name of the character playing, as Tradeskills gives it (the
--- way Always mail and mail rows name characters), read once per
--- Verdicts.version (its last name can arrive after login). nil without
--- Tradeskills. Nothing is ever mailed to it.
local playing, playingVersion
--- Is this name the character playing? Errands:IsMe, the one test: never
--- a mail, an upgrade or a learned habit to it. No name is not.
function Verdicts:IsMe(name)
    if type(name) ~= "string" or name == "" then return false end
    local errands = ns.Errands
    return errands ~= nil and errands.IsMe ~= nil and errands:IsMe(name) == true
end

function Verdicts:Playing()
    if playingVersion ~= self.version then
        playingVersion = self.version
        playing = ns.Errands and ns.Errands.PlayingName and ns.Errands:PlayingName() or nil
    end
    return playing
end

--- Steps 5 to 8: a sister says to keep the item (or mail it to the alt who
--- needs it). Returns verdict, reason, what one is worth and, for Mail,
--- { to, count }; or nil. `entry` (the bag slot) says whether it is
--- soulbound, which can't be mailed.
function Verdicts:Kept(said, entry, noAlt)
    local Number, String, True = Sisters.Number, Sisters.String, Sisters.True

    local eq = said.equipment
    if eq then
        if eq.upgrade == "now" then
            return "keep", L["An upgrade: wear it"]
        elseif eq.upgrade == "later" then
            return "keep", L["An upgrade at a later level"]
        elseif True(eq, "tool") then
            return "keep", L["A tool you use"]
        end
    end

    local ts = said.ts
    local queued = Number(ts, "need")
    local mailTo = String(ts, "mailTo")
    -- An older Tradeskills could name the character playing, and a
    -- soulbound stack can't go in the mail, whoever's craft wants it.
    if mailTo and (Verdicts:IsMe(mailTo) or (entry and entry.bound)) then mailTo = nil end
    -- An alt's queued craft comes before a Farmer goal here: the goal is
    -- usually Tradeskills' Set goal gathering for that queue, and Fill
    -- mail left two herbs out while it kept them (2026-10-13). Only what
    -- this character's own crafts can spare goes.
    local share = Number(ts, "mailCount")
    if mailTo and share and share > 0 then
        local reason = (queued and queued > 0)
            and L.Format("Mail %d to %s for their crafts, keep %d for yours", share, mailTo, queued)
            or L.Format("Mail %d to %s for their crafts", share, mailTo)
        return "mail", reason, nil, { to = mailTo, count = share }
    end

    local farmer = said.farmer
    local need = Number(farmer, "need")
    if need and need > 0 then
        local goal = String(farmer, "goal")
        return "keep", goal and L.Format("Your %s goal needs %d more", goal, need)
            or L.Format("A goal needs %d more", need)
    end

    if queued and queued > 0 then
        -- The alt's share goes in the mail too: Tradeskills' mailCount is
        -- what is left once this character's own crafts are kept back, so
        -- Fill mail sends that many and the rest stays (a player's leather
        -- was all kept while an alt's craft waited on it, 2026-10-11).
        local count = Number(ts, "mailCount")
        if mailTo and count and count > 0 then
            return "mail", L.Format("Mail %d to %s for their crafts, keep %d for yours", count, mailTo, queued),
                nil, { to = mailTo, count = count }
        end
        return "keep", L.Format("Your craft queue needs %d", queued)
    end
    if mailTo then
        local count = Number(ts, "mailCount")
        return "mail", count and L.Format("Mail %d to %s for their crafts", count, mailTo)
            or L.Format("Mail to %s for their crafts", mailTo), nil, { to = mailTo, count = count }
    end

    -- No use here, but an upgrade for another of the player's characters
    -- (the owner asked 2026-10-11): mail it to them. Equipment says which
    -- by GUID, and Tradeskills' record names it.
    -- An alt needs one (two rings or trinkets): `count` says how many go,
    -- less any already mailed to them, and Groups judges the rest as if no
    -- alt wanted them (a pair too many went in the mail, 2026-10-11).
    -- Bought to disenchant (Tradeskills' mark) is for breaking, never an
    -- alt's upgrade (a player was told to mail one, 2026-10-13): step 8b.
    -- Off unless the player ticks "Mail upgrades to your characters" (the
    -- owner, 2026-10-13): Verdicts:AltUpgradesOn.
    local alt = eq and eq.alt
    local bought = Number(ts, "bought")
    if bought and bought > 0 then alt = nil end
    if not Verdicts:AltUpgradesOn() then alt = nil end
    if type(alt) == "table" and not noAlt and not (entry and entry.bound) then
        local to = ns.Errands and ns.Errands.NameOf and ns.Errands:NameOf(alt.key)
        local wanted = to and Verdicts:UpgradeWanted(entry.itemID, to) or 0
        if to and not Verdicts:IsMe(to) and wanted > 0 and not Verdicts:UpgradeHeld(entry.itemID, to) then
            local gain = Number(alt, "gain")
            local level = Number(alt, "level")
            local reason
            if gain and level then
                reason = L.Format("An upgrade for %s (+%d%%) at level %d", to, gain, level)
            elseif gain then
                reason = L.Format("An upgrade for %s (+%d%%)", to, gain)
            elseif level then
                reason = L.Format("An upgrade for %s (an empty slot) at level %d", to, level)
            else
                reason = L.Format("An upgrade for %s (an empty slot)", to)
            end
            return "mail", reason, nil, { to = to, count = wanted, upgrade = true }
        end
    end

    local pets = said.pets
    -- Pets' hours are for all the food carried, and only a rough guess
    -- (classic's hunger rule), so they are shown, never used to sell food.
    if True(pets, "eats") then
        local buff = True(pets, "buff")
        local what = buff and L["Buff food for your pet"] or L["Your pet eats it"]
        local hours = Number(pets, "hours")
        if hours and hours > 0 then
            what = buff and L.Format("Buff food for your pet (about %s h of food carried)", Verdicts.Hours(hours))
                or L.Format("Your pet eats it (about %s h of food carried)", Verdicts.Hours(hours))
        end
        return "keep", what
    end
end

-- Rings and trinkets: a character wears two.
local PAIRS = { INVTYPE_FINGER = true, INVTYPE_TRINKET = true }

--- How many of an item an alt wears at once: 2 for rings and trinkets.
function Verdicts.Wears(itemID)
    local _, _, _, equipLoc = Items.Call({ "C_Item.GetItemInfoInstant", "GetItemInfoInstant" }, itemID)
    return PAIRS[equipLoc] and 2 or 1
end

-- An alt's upgrade mailed is counted for 30 days, when unclaimed mail
-- goes back; by then the alt has worn it or Equipment stops calling it one.
Verdicts.MAILED_KEEP = 30 * 24 * 60 * 60

local function Mailed()
    if not ns.db then return {} end
    if type(ns.db.upgradeMailed) ~= "table" then ns.db.upgradeMailed = {} end
    return ns.db.upgradeMailed
end

--- How many more of `itemID` the alt `to` wants as an upgrade: what it
--- wears at once, less what Butler saw mailed to it.
function Verdicts:UpgradeWanted(itemID, to)
    local wants = self.Wears(itemID)
    local sent = Mailed()[itemID]
    if type(sent) == "table" and sent.to == to and type(sent.at) == "number"
        and (time() - sent.at) < self.MAILED_KEEP then
        wants = wants - (tonumber(sent.count) or 0)
    end
    return math.max(0, wants)
end

-- The player can hold an upgrade back from an alt (the owner asked
-- 2026-10-12): one item (`noUpgradeMail[itemID][name] = true`) or every
-- upgrade (`noUpgradesFor[name] = true`), account wide, by full name.
-- Held back, the item gets its next verdict and Fill mail leaves it.
-- Never rename these keys.

--- True when the player said not to mail `itemID` to `to` as an upgrade.
--- Whether Butler offers to mail upgrades to the player's other
--- characters: off unless ticked (`altUpgrades`, account wide; the owner,
--- 2026-10-13). Never rename it.
function Verdicts:AltUpgradesOn()
    return ns.db ~= nil and ns.db.altUpgrades == true
end

function Verdicts:SetAltUpgrades(on)
    if not ns.db then return end
    ns.db.altUpgrades = on and true or false
    self:Changed(true)
end

function Verdicts:UpgradeHeld(itemID, to)
    if type(to) ~= "string" then return false end
    if List("noUpgradesFor")[to] then return true end
    local held = List("noUpgradeMail")[itemID]
    return type(held) == "table" and held[to] == true
end

--- Hold `itemID` back from `to` (`held` true), or let it go to them again.
function Verdicts:HoldUpgrade(itemID, to, held)
    if not itemID or type(to) ~= "string" or to == "" then return end
    local list = List("noUpgradeMail")
    local names = type(list[itemID]) == "table" and list[itemID] or {}
    names[to] = held and true or nil
    list[itemID] = next(names) and names or nil
    self:Changed(true)
end

--- Stop (`held` true) or start again mailing every upgrade to `to`.
function Verdicts:HoldAllUpgrades(to, held)
    if type(to) ~= "string" or to == "" then return end
    List("noUpgradesFor")[to] = held and true or nil
    self:Changed(true)
end

--- The items held back from `to` one by one, as item IDs in order.
function Verdicts:HeldItems(to)
    local ids = {}
    for itemID, names in pairs(List("noUpgradeMail")) do
        if type(names) == "table" and names[to] then ids[#ids + 1] = itemID end
    end
    table.sort(ids)
    return ids
end

--- Everyone with an upgrade held back, by full name in order.
function Verdicts:HeldNames()
    local seen, names = {}, {}
    local function Add(name)
        if type(name) == "string" and not seen[name] then
            seen[name] = true
            names[#names + 1] = name
        end
    end
    for name in pairs(List("noUpgradesFor")) do Add(name) end
    for _, held in pairs(List("noUpgradeMail")) do
        if type(held) == "table" then
            for name in pairs(held) do Add(name) end
        end
    end
    table.sort(names)
    return names
end

--- Undo both kinds for `to`: every upgrade goes to them again.
function Verdicts:UnholdUpgrades(to)
    if type(to) ~= "string" then return end
    List("noUpgradesFor")[to] = nil
    local list = List("noUpgradeMail")
    for itemID, names in pairs(list) do
        if type(names) == "table" then
            names[to] = nil
            if not next(names) then list[itemID] = nil end
        end
    end
    self:Changed(true)
end

--- A mail Butler filled went: write down the alt upgrades in it
--- (`upgradeMailed[itemID] = { to, count, at }`, account wide), so a copy
--- left in the bags isn't offered again.
function Verdicts:UpgradesMailed(to, items)
    if type(to) ~= "string" or type(items) ~= "table" or #items == 0 then return end
    local mailed = Mailed()
    for _, item in ipairs(items) do
        local sent = mailed[item.itemID]
        local count = item.count
        if type(sent) == "table" and sent.to == to then count = count + (tonumber(sent.count) or 0) end
        mailed[item.itemID] = { to = to, count = count, at = time() }
    end
    self:Changed()
end

--- Step 8b: bought on the auction house to disenchant (Tradeskills' mark,
--- a player's purchase after a search from its Disenchanting tab, or marked
--- by hand). Disenchant it whatever else it would fetch; mail it to the
--- enchanter when this character can't. Returns verdict, reason, worth and
--- { bought, to }; or nil when it was not bought to disenchant.
function Verdicts:Bought(entry, said)
    local Number, String, True = Sisters.Number, Sisters.String, Sisters.True
    local ts = said.ts
    local bought = Number(ts, "bought")
    if not bought or bought <= 0 then return nil end

    local value = Number(ts, "disenchant")

    if True(ts, "canDisenchant") then
        return "disenchant", value and L.Format("Bought to disenchant, about %s", Items.FormatMoney(value))
            or L["Bought to disenchant"], value, { bought = bought }
    end

    local enchanter = not entry.bound and String(ts, "enchanter") or nil
    if enchanter and self:IsMe(enchanter) then enchanter = nil end
    if enchanter then
        return "mail", L.Format("Bought to disenchant: mail to %s", enchanter), value,
            { to = enchanter, bought = bought }
    end

    return "look", L["Bought to disenchant, but none of your characters can yet"], value, { bought = bought }
end

--- Step 8bb: level Enchanting with your own greens (the owner asked
--- 2026-10-13). Tradeskills' `forEnchanting` names a green this character
--- can break, not crafted, whose likely material its Enchanting still lacks
--- for the crafts that give a point every time, after what it owns. Then
--- Disenchant, whatever the auction house or a vendor pays. Returns
--- verdict, reason, worth and { enchanting, yield }; or nil.
--- Verdicts:Groups stops once the greens already picked cover the shortfall.
function Verdicts:ForEnchanting(entry, said)
    local Number, String, True = Sisters.Number, Sisters.String, Sisters.True
    local ts = said.ts
    local wanted = ts and ts.forEnchanting
    if type(wanted) ~= "table" or not True(ts, "canDisenchant") then return nil end
    if (entry.quality or 2) ~= 2 then return nil end
    local material = Number(wanted, "material")
    local short = Number(wanted, "short")
    local recipe = String(wanted, "recipe")
    if not material or not short or short <= 0 or not recipe then return nil end

    local value = Number(ts, "disenchant")
    local name = String(wanted, "materialName")
    local reason = name and L.Format("To level Enchanting: %s needs %s", recipe, name)
        or L.Format("To level Enchanting: %s needs what it gives", recipe)
    return "disenchant", reason, value,
        { enchanting = material, short = short, yield = Number(wanted, "yield") or 1 }
end

--- Step 8c: Tradeskills' disenchanter (the owner asked 2026-10-11: Butler
--- follows that setting). Gear its Mail page would send there (green up
--- to the quality picked, can be disenchanted, never crafted, bind on
--- pickup or an upgrade for this character) is mailed there, whatever else it would
--- fetch. Never a soulbound copy, never the character playing. Returns
--- verdict, reason, worth and { to }; or nil.
function Verdicts:ForDisenchanter(entry, said)
    if entry.bound then return nil end
    local Number, String = Sisters.Number, Sisters.String
    local ts = said.ts
    local to = String(ts, "disenchanter")
    if not to then return nil end
    if ns.Errands and ns.Errands.FullName then to = ns.Errands:FullName(to) or to end
    if self:IsMe(to) then return nil end

    local value = Number(ts, "disenchant")
    local reason = value and L.Format("For your disenchanter: mail to %s, about %s", to, Items.FormatMoney(value))
        or L.Format("For your disenchanter: mail to %s", to)
    return "mail", reason, value, { to = to }
end

--------------------------------------------------------------------------------
-- Sell below
--------------------------------------------------------------------------------

--- The Sell below amount in copper, or nil when it is off.
function Verdicts:SellBelow()
    local amount = ns.db and ns.db.sellBelow
    if type(amount) == "number" and amount >= 1 then return math.floor(amount) end
    return nil
end

--- Save the Sell below amount (copper; nil or 0 turns it off) and judge
--- every item again.
function Verdicts:SetSellBelow(copper)
    if not ns.db then return end
    copper = tonumber(copper)
    if copper then copper = math.floor(copper) end
    if copper and copper < 1 then copper = nil end
    if copper == ns.db.sellBelow then return end
    ns.db.sellBelow = copper
    self:Changed(true)
end

--- Copper from "1g 50s", "75s", "30c" or "2g5s"; 0 for "off", "0" or
--- nothing. nil when it can't be read. A plain number counts as gold.
function Verdicts.ParseMoney(text)
    text = tostring(text or ""):lower():gsub("%s+", "")
    if text == "" or text == "off" or text == "0" then return 0 end
    if text:match("^%d+$") then return tonumber(text) * 10000 end
    local total, rest = 0, text
    for _, unit in ipairs({ { "g", 10000 }, { "s", 100 }, { "c", 1 } }) do
        local amount, after = rest:match("^(%d+)" .. unit[1] .. "(.*)$")
        if amount then
            total = total + tonumber(amount) * unit[2]
            rest = after
        end
    end
    if rest ~= "" then return nil end
    return total
end

--- Step 12: the best of what a vendor pays, the auction house (after the
--- cut) and disenchanting. Returns verdict, reason and one's worth.
function Verdicts:Best(entry, unit, said)
    local Number, String, True = Sisters.Number, Sisters.String, Sisters.True
    local ts, eq = said.ts, said.equipment

    -- Soulbound gear can only be sold or disenchanted, and green or better
    -- is never sold for the player (the plan: it needs a second look).
    local bound = entry.bound == true

    local auction = not bound and Number(ts, "auction") or nil
    local slow = auction and ts.fast == false
    local auctionWorth = auction and math.floor(auction * (slow and Verdicts.SLOW or 1)) or nil

    local disenchant = Number(ts, "disenchant")
    local canDisenchant = True(ts, "canDisenchant")
    local enchanter = not bound and String(ts, "enchanter") or nil
    if enchanter and self:IsMe(enchanter) then enchanter = nil end
    if disenchant and not canDisenchant and not enchanter then disenchant = nil end

    -- Step 11: worth less than the player's Sell below amount, judged on
    -- the most it could fetch. Only once Tradeskills has priced it, and
    -- never soulbound green or better, which always gets a second look.
    local below = self:SellBelow()
    if below and ts and not (bound and (entry.quality or 0) >= 2) then
        local most = math.max(unit, auction or 0, disenchant or 0)
        if most < below then
            return "sell", L.Format("Worth less than %s: %s each", Items.FormatMoney(below),
                Items.FormatMoney(unit)), unit
        end
    end

    local best, value = "sell", unit
    if auctionWorth and auctionWorth > value then best, value = "auction", auctionWorth end
    if disenchant and disenchant > value then best, value = "disenchant", disenchant end

    if best == "disenchant" then
        if canDisenchant then
            return "disenchant", L.Format("Disenchant, about %s", Items.FormatMoney(disenchant)), disenchant
        end
        return "mail", L.Format("Mail to %s to disenchant, about %s", enchanter, Items.FormatMoney(disenchant)),
            disenchant, { to = enchanter }
    end

    if best == "auction" then
        -- Tradeskills won't list it: the price it would list at is under
        -- what one costs to make, and selling at a loss is off there.
        -- Wait, as its Sell list does, rather than say Auction.
        local cost = Number(ts, "belowCost")
        if cost then
            return "wait", L.Format("Costs about %s to make, more than it sells for now",
                Items.FormatMoney(cost)), auctionWorth
        end
        -- Today's price is well under the usual one: hold it back, folded
        -- away under Wait for a better price (the owner asked 2026-10-13).
        local now = Number(ts, "auctionNow")
        if now and now < auction * Verdicts.LOW_NOW then
            return "wait", L.Format("Selling for about %s right now, usually about %s",
                Items.FormatMoney(now), Items.FormatMoney(auction)), auctionWorth
        end
        local text = slow and L.Format("Auction about %s each, sells slowly", Items.FormatMoney(auction))
            or L.Format("Auction about %s each", Items.FormatMoney(auction))
        return "auction", text, auctionWorth
    end

    -- A vendor pays the most. Sold only when something says so: the auction
    -- house was asked and pays less, or Equipment found no use for it.
    local judged = auction ~= nil or (eq and True(eq, "sell"))
    if judged and not (bound and (entry.quality or 0) >= 2) then
        -- Say which: the auction house pays less once its cut and deposit
        -- are taken, or it pays more but sells too slowly to wait for (a
        -- player read "vendor pays more" under a higher auction price).
        if auction and auction > unit then
            return "sell", L.Format("Sells slowly at auction (about %s after the cut), vendor pays %s each",
                Items.FormatMoney(auction), Items.FormatMoney(unit)), unit
        end
        if auction then
            return "sell", L.Format("Vendor pays more than the auction house after its cut (about %s): %s each",
                Items.FormatMoney(auction), Items.FormatMoney(unit)), unit
        end
        return "sell", L.Format("Not an upgrade: %s each", Items.FormatMoney(unit)), unit
    end

    if bound and (entry.quality or 0) >= 2 and eq and True(eq, "sell") then
        if unit and unit > 0 then
            return "look", L.Format("Not an upgrade. Vendor %s each", Items.FormatMoney(unit)), unit
        end
        return "look", L["Not an upgrade."], unit
    end

    -- Short enough for the row; the tooltip says right-click decides it.
    return "look", Each(unit), unit
end

--- "2.5" or "8": hours as the row shows them.
function Verdicts.Hours(hours)
    local rounded = math.floor(hours * 10 + 0.5) / 10
    if rounded == math.floor(rounded) then return tostring(math.floor(rounded)) end
    return tostring(rounded)
end

--------------------------------------------------------------------------------
-- Groups
--------------------------------------------------------------------------------

--- The bags as groups, in Verdicts.ORDER: { verdict, label, rows, count,
--- worth }, each row one item (stacks of the same link put together) with
--- its slots. Kept until the bags or a verdict change.
function Verdicts:Groups()
    local bagsVersion = ns.Bags.version
    local cache = self.groupCache
    if cache and cache.bags == bagsVersion and cache.verdicts == self.version then
        return cache.groups
    end

    local byVerdict, rowsByKey = {}, {}
    for _, verdict in ipairs(self.ORDER) do
        byVerdict[verdict] = { verdict = verdict, label = self.LABELS[verdict], rows = {}, count = 0, worth = 0 }
    end

    local entries = {}
    for _, entry in pairs(ns.Bags.slots) do entries[#entries + 1] = entry end
    table.sort(entries, function(a, b)
        if a.bag ~= b.bag then return a.bag < b.bag end
        return a.slot < b.slot
    end)

    -- How many of each item have gone to an alt's upgrade so far: past
    -- what it wants, a copy gets its own verdict.
    local allotted, slotVerdicts = {}, {}
    for _, entry in ipairs(entries) do
        local verdict, reason, unit, extra = self:Judge(entry)
        -- Greens broken to level Enchanting: once those before it should give
        -- enough of the material, a copy gets its own verdict.
        if extra and extra.enchanting then
            local id = extra.enchanting
            if (allotted["e" .. id] or 0) >= (extra.short or 0) then
                verdict, reason, unit, extra = self:Judge(entry, true)
            else
                allotted["e" .. id] = (allotted["e" .. id] or 0) + (extra.yield or 1) * (entry.count or 1)
            end
        end
        if extra and extra.upgrade then
            local id = entry.itemID
            if (allotted[id] or 0) >= (extra.count or 1) then
                verdict, reason, unit, extra = self:Judge(entry, true)
            else
                allotted[id] = (allotted[id] or 0) + entry.count
            end
        end
        slotVerdicts[entry.bag .. ":" .. entry.slot] = { key = entry.key, verdict = verdict }
        local group = byVerdict[verdict]
        local key = verdict .. "|" .. (entry.bound and "b|" or "") .. tostring(entry.link or entry.itemID)
        local row = rowsByKey[key]
        if not row then
            row = {
                type = "item", verdict = verdict, reason = reason, unit = unit,
                itemID = entry.itemID, link = entry.link, icon = entry.icon,
                quality = entry.quality, bound = entry.bound,
                mailTo = extra and extra.to, mailCount = extra and extra.count,
                upgrade = extra and extra.upgrade or nil,
                bought = extra and extra.bought,
                name = Items.NameFromLink(entry.link) or L.Format("item %s", tostring(entry.itemID)),
                count = 0, slots = {},
            }
            rowsByKey[key] = row
            group.rows[#group.rows + 1] = row
        end
        row.count = row.count + entry.count
        row.slots[#row.slots + 1] = entry
        group.count = group.count + 1
    end

    local groups = {}
    for _, verdict in ipairs(self.ORDER) do
        local group = byVerdict[verdict]
        for _, row in ipairs(group.rows) do
            row.worth = (row.unit or 0) * row.count
            group.worth = group.worth + row.worth
            -- Slots in bag order, so a sale goes through the bags as the
            -- player reads them.
            table.sort(row.slots, function(a, b)
                if a.bag ~= b.bag then return a.bag < b.bag end
                return a.slot < b.slot
            end)
        end
        -- Bought to disenchant first, then most valuable, then by name.
        table.sort(group.rows, function(a, b)
            if (a.bought ~= nil) ~= (b.bought ~= nil) then return a.bought ~= nil end
            if a.worth ~= b.worth then return a.worth > b.worth end
            return a.name < b.name
        end)
        group.count = #group.rows
        groups[#groups + 1] = group
    end

    self.groupCache = { bags = bagsVersion, verdicts = self.version, groups = groups,
        slots = slotVerdicts }
    return groups
end

--- The verdict a slot shows in the window: a copy past an alt's upgrade
--- has its own (Groups). Asked again before a click acts on a slot.
function Verdicts:VerdictOf(entry)
    self:Groups()
    local cache = self.groupCache
    local known = cache and cache.slots and cache.slots[entry.bag .. ":" .. entry.slot]
    if known and known.key == entry.key then return known.verdict end
    return (self:Judge(entry))
end

--- One group by its verdict.
function Verdicts:Group(verdict)
    for _, group in ipairs(self:Groups()) do
        if group.verdict == verdict then return group end
    end
end

--------------------------------------------------------------------------------
-- Change
--------------------------------------------------------------------------------

--- Something a verdict leans on moved (a choice, an item loaded): judge
--- again and redraw what shows. `now` redraws at once, for a click.
function Verdicts:Changed(now)
    self.version = self.version + 1
    self:Redraw(now)
end

--- Judge every item again next time it is asked, without a redraw: the
--- window opening, so what the other addons say is fresh for each look.
function Verdicts:Forget()
    -- Sets read again too: at login the client can answer before it has them.
    setItems = nil
    self.version = self.version + 1
end

--- The bags changed (Bags.version moved).
function Verdicts:BagsChanged()
    self:Redraw(true)
end

function Verdicts:Redraw()
    if ns.UI then ns.UI:Refresh() end
    if ns.Selling then ns.Selling:Update() end
    if ns.Trash then ns.Trash:Changed() end
end

--------------------------------------------------------------------------------
-- Commands
--------------------------------------------------------------------------------

local function PrintList(name, title)
    local ids = {}
    for itemID in pairs(List(name)) do ids[#ids + 1] = itemID end
    table.sort(ids)
    if #ids == 0 then
        ns.PrintRaw(("  |c%s%s|r"):format(ns.COLORS.muted, L.Format("%s: none", title)))
        return
    end
    local names = {}
    for _, itemID in ipairs(ids) do
        local itemName, link = Items.Call({ "C_Item.GetItemInfo", "GetItemInfo" }, itemID)
        if not itemName then Items:RequestLoad(itemID) end
        local to = List(name)[itemID]
        local shown = link or itemName or L.Format("item %s", tostring(itemID))
        names[#names + 1] = type(to) == "string" and L.Format("%s to %s", shown, to) or shown
    end
    ns.PrintRaw(("  |c%s%s|r %s"):format(ns.COLORS.muted, L.Format("%s (%d):", title, #ids), table.concat(names, ", ")))
end

ns.RegisterCommand("lists", L["show your Always keep, Always sell, Always bank and Always mail lists"], function()
    ns.Print(L["your lists (right-click a row in the Butler window to change them)"])
    PrintList("alwaysKeep", L["Always keep"])
    PrintList("alwaysSell", L["Always sell"])
    PrintList("alwaysBank", L["Always bank"])
    PrintList("alwaysMail", L["Always mail"])
    if ns.Learning then ns.Learning:PrintLearned() end
end)

local function ItemName(itemID)
    local itemName, link = Items.Call({ "C_Item.GetItemInfo", "GetItemInfo" }, itemID)
    if not itemName then Items:RequestLoad(itemID) end
    return link or itemName or L.Format("item %d", itemID)
end

-- Upgrades held back from a character (right-click a Mail upgrade row).
-- Undo lets them go again; nothing else is deleted.
ns.RegisterCommand("altupgrades", L["turn offering to mail upgrades to your other characters on or off"], function()
    Verdicts:SetAltUpgrades(not Verdicts:AltUpgradesOn())
    ns.Print(Verdicts:AltUpgradesOn() and L["Butler offers to mail gear to the character it's an upgrade for."]
        or L["Butler no longer offers to mail upgrades to your other characters."])
end)

ns.RegisterCommand("upgrademail", L["list upgrades you hold back from your characters (upgrademail undo Full Name to mail them again)"], function(rest)
    rest = (rest or ""):match("^%s*(.-)%s*$")
    local name = rest:match("^undo%s+(.+)$")
    if name then
        if ns.Errands and ns.Errands.FullName then name = ns.Errands:FullName(name) end
        local known = false
        for _, held in ipairs(Verdicts:HeldNames()) do
            if held == name then known = true end
        end
        if not known then
            ns.Print(L.Format("nothing is held back from %s.", name))
            return
        end
        Verdicts:UnholdUpgrades(name)
        ns.Print(L.Format("upgrades go to %s again.", name))
        return
    end
    local names = Verdicts:HeldNames()
    if #names == 0 then
        ns.Print(L["every upgrade goes to your characters. Right-click an upgrade under Mail to hold it back."])
        return
    end
    ns.Print(L["upgrades you hold back (type /bbutler upgrademail undo Full Name to mail them again)"])
    for _, who in ipairs(names) do
        if List("noUpgradesFor")[who] then
            ns.PrintRaw(("  |c%s%s|r"):format(ns.COLORS.muted, L.Format("%s: no upgrades", who)))
        end
        local items = {}
        for _, itemID in ipairs(Verdicts:HeldItems(who)) do items[#items + 1] = ItemName(itemID) end
        if #items > 0 then
            ns.PrintRaw(("  |c%s%s (%d):|r %s"):format(ns.COLORS.muted, who, #items, table.concat(items, ", ")))
        end
    end
end)

ns.RegisterCommand("vendor", L["turn the Butler window coming up at a vendor on or off"], function()
    ns.db.openAtVendor = not ns.db.openAtVendor
    ns.Print(ns.db.openAtVendor and L["the Butler window comes up at every vendor."]
        or L["the Butler window no longer comes up at a vendor."])
end)

-- Deletes the player's choices, so typed only, with "confirm" (a house
-- rule: no button deletes data).
ns.RegisterCommand("reset", L["empty your Always keep, sell, bank and mail lists and what Butler learned (type: reset confirm)"], function(rest)
    if rest ~= "confirm" then
        ns.Print(L["this empties your Always keep, Always sell, Always bank and Always mail lists, and forgets what Butler learned from you. To do it, type /bbutler reset confirm"])
        return
    end
    ns.db.alwaysKeep, ns.db.alwaysSell, ns.db.alwaysBank, ns.db.alwaysMail = {}, {}, {}, {}
    if ns.Learning then ns.Learning:ForgetAll() end
    Verdicts:Changed(true)
    ns.Print(L["your Always keep, Always sell, Always bank and Always mail lists are empty, and Butler has forgotten what it learned from you. Butler decides every item again."])
end)

-- Asked 2026-10-11: anything worth less than an amount the player sets
-- joins Sell. It never deletes or sells by itself; Sell is still a click.
ns.RegisterCommand("sellbelow", L["sell anything worth less than an amount, e.g. sellbelow 50s (sellbelow off to stop)"], function(rest)
    rest = rest or ""
    if rest:match("^%s*$") then
        local below = Verdicts:SellBelow()
        ns.Print(below and L.Format("items worth less than %s go under Sell. Type /bbutler sellbelow off to stop.", Items.FormatMoney(below))
            or L["Sell below is off. Type an amount to turn it on, e.g. /bbutler sellbelow 50s or /bbutler sellbelow 1g 20s"])
        return
    end
    local copper = Verdicts.ParseMoney(rest)
    if not copper then
        ns.Print(L["type an amount like 50s, 1g 20s or 75c, or off."])
        return
    end
    Verdicts:SetSellBelow(copper)
    local below = Verdicts:SellBelow()
    ns.Print(below and L.Format("items worth less than %s now go under Sell. Nothing sells until you click Sell.", Items.FormatMoney(below))
        or L["Sell below is off."])

end)
