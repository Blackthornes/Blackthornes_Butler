-- Blackthornes Butler -- Logic/Verdicts.lua
-- One verdict for every item in the bags, and the reason for it.
--
-- The first rule that applies wins, and keeping always beats selling:
--
--   1. On the player's Always keep list            Keep
--      ... or Always bank list                     Bank
--   2. A quest item, or one that starts one        Keep
--   3. A vendor won't buy it                       Keep
--   4. On the player's Always sell list            Sell
--   5. Equipment: an upgrade now or later, a tool  Keep
--   6. Farmer: a goal of this character needs it   Keep
--   7. Tradeskills: the craft queue needs it here  Keep
--      ... or an alt needs it for theirs           Mail
--   8. Pets: the pet eats it                       Keep
--   8b. Tradeskills: bought on the auction house
--      to disenchant                              Disenchant, or Mail to
--                                                  the enchanter
--   9. Its price has not loaded yet                Look at it
--  10. Grey (worth vendor only)                    Sell
--  11. Worth less than the player's Sell below amount (vendor, auction
--      and disenchant, whichever is most)          Sell
--  12. The best of vendor, auction (marked down when it sells slowly)
--      and disenchant                              Sell, Auction,
--                                                  Disenchant or Mail
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

local Verdicts = ns.NewModule("Verdicts")

local Items = ns.Items
local Sisters = ns.Sisters

-- The order the groups show in: what to do first at the top.
Verdicts.ORDER = { "sell", "auction", "disenchant", "mail", "bank", "look", "keep" }

Verdicts.LABELS = {
    sell = "Sell",
    auction = "Auction",
    disenchant = "Disenchant",
    mail = "Mail",
    bank = "Bank",
    look = "Look at it",
    keep = "Keep",
}

-- An auction price is worth this much of itself when Tradeskills says the
-- item sells slowly: a slow sale ties up the slot and the deposit.
Verdicts.SLOW = 0.75


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
    self:Changed(true)
end

--------------------------------------------------------------------------------
-- Judging
--------------------------------------------------------------------------------

local function Each(unit)
    if not unit or unit <= 0 then return "" end
    return "Vendor " .. Items.FormatMoney(unit) .. " each"
end

--- The verdict for one carried item, why, what a vendor pays for one, and
--- for Mail { to, count }. `entry` is a slot from Bags (itemID, link,
--- quality, noValue, quest).
function Verdicts:Judge(entry)
    if memoVersion ~= self.version then
        memo, memoVersion = {}, self.version
    end
    local key = entry.link or entry.itemID
    local known = memo[key]
    if known then return known[1], known[2], known[3], known[4] end

    local verdict, reason, unit, final, extra = self:Decide(entry)
    -- An answer that waits on the client loading the item is asked again.
    if final then memo[key] = { verdict, reason, unit, extra } end
    return verdict, reason, unit, extra
end

--- The rules above, in order. The fourth return says whether the answer
--- will hold (false while the price is still loading); the fifth is who a
--- Mail row goes to and how many ({ to, count }).
function Verdicts:Decide(entry)
    local itemID = entry.itemID
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
        return "keep", "On your Always keep list", nil, true
    end
    if choice == "bank" then
        return "bank", "On your Always bank list", Items:SellPrice(itemID), true
    end
    if choice == "mail" then
        -- Soulbound can't go in the mail, whatever the list says, and the
        -- list is account wide, so it can name the character playing.
        if mailTo == self:Playing() then
            return "keep", ("On your Always mail list for %s, the character you're on"):format(mailTo), nil, true
        end
        if entry.bound then
            return "keep", ("Soulbound, so it can't be mailed to %s"):format(mailTo), nil, true
        end
        return "mail", ("On your Always mail list, to %s"):format(mailTo), Items:SellPrice(itemID), true,
            { to = mailTo }
    end

    if entry.quest == "starts" then
        return "keep", "Starts a quest", nil, true
    elseif entry.quest == "item" then
        return "keep", "Quest item", nil, true
    end

    if entry.noValue then
        return "keep", "Vendors won't buy it", nil, true
    end

    local unit = Items:SellPrice(itemID)
    if unit == 0 then
        return "keep", "Vendors won't buy it", 0, true
    end

    if choice == "sell" then
        return "sell", "On your Always sell list", unit, unit ~= nil
    end

    local said = Sisters:AskAll(entry)
    local verdict, reason, worth, extra = self:Kept(said)
    if verdict then return verdict, reason, worth or unit, unit ~= nil, extra end

    verdict, reason, worth, extra = self:Bought(entry, said)
    if verdict then return verdict, reason, worth or unit, unit ~= nil, extra end

    if unit == nil then
        return "look", "Still loading from the game", nil, false
    end

    if entry.quality == 0 then
        return "sell", "Grey, vendor only", unit, true
    end

    verdict, reason, worth, extra = self:Best(entry, unit, said)
    return verdict, reason, worth, true, extra
end

--- "mail", why and { to, count } when Tradeskills says an alt's queued
--- crafts want some of an item on the Always keep list (only what
--- this character's own crafts can spare); nil otherwise.
function Verdicts:ForAltCraft(entry)
    if entry.bound then return nil end
    local ts = Sisters:Ask("ts", entry)
    local mailTo = Sisters.String(ts, "mailTo")
    local count = Sisters.Number(ts, "mailCount")
    if not mailTo or mailTo == self:Playing() or not (count and count > 0) then return nil end
    return "mail", ("Mail %d to %s for their crafts, keep the rest"):format(count, mailTo),
        { to = mailTo, count = count }
end

--- The short name of the character playing, as Tradeskills gives it (the
--- way Always mail and mail rows name characters), read once per
--- Verdicts.version (its last name can arrive after login). nil without
--- Tradeskills. Nothing is ever mailed to it.
local playing, playingVersion
function Verdicts:Playing()
    if playingVersion ~= self.version then
        playingVersion = self.version
        playing = ns.Errands and ns.Errands.PlayingName and ns.Errands:PlayingName() or nil
    end
    return playing
end

--- Steps 5 to 8: a sister says to keep the item (or mail it to the alt who
--- needs it). Returns verdict, reason, what one is worth and, for Mail,
--- { to, count }; or nil.
function Verdicts:Kept(said)
    local Number, String, True = Sisters.Number, Sisters.String, Sisters.True

    local eq = said.equipment
    if eq then
        if eq.upgrade == "now" then
            return "keep", "An upgrade: wear it"
        elseif eq.upgrade == "later" then
            return "keep", "An upgrade at a later level"
        elseif True(eq, "tool") then
            return "keep", "A tool you use"
        end
    end

    local farmer = said.farmer
    local need = Number(farmer, "need")
    if need and need > 0 then
        local goal = String(farmer, "goal")
        return "keep", goal and ("Your %s goal needs %d more"):format(goal, need)
            or ("A goal needs %d more"):format(need)
    end

    local ts = said.ts
    local queued = Number(ts, "need")
    local mailTo = String(ts, "mailTo")
    -- An older Tradeskills could name the character playing.
    if mailTo and mailTo == Verdicts:Playing() then mailTo = nil end
    if queued and queued > 0 then
        -- The alt's share goes in the mail too: Tradeskills' mailCount is
        -- what is left once this character's own crafts are kept back, so
        -- Fill mail sends that many and the rest stays (a player's leather
        -- was all kept while an alt's craft waited on it, 2026-10-11).
        local count = Number(ts, "mailCount")
        if mailTo and count and count > 0 then
            return "mail", ("Mail %d to %s for their crafts, keep %d for yours"):format(count, mailTo, queued),
                nil, { to = mailTo, count = count }
        end
        return "keep", ("Your craft queue needs %d"):format(queued)
    end
    if mailTo then
        local count = Number(ts, "mailCount")
        return "mail", count and ("Mail %d to %s for their crafts"):format(count, mailTo)
            or ("Mail to %s for their crafts"):format(mailTo), nil, { to = mailTo, count = count }
    end

    local pets = said.pets
    -- Pets' hours are for all the food carried, and only a rough guess
    -- (classic's hunger rule), so they are shown, never used to sell food.
    if True(pets, "eats") then
        local what = True(pets, "buff") and "Buff food for your pet" or "Your pet eats it"
        local hours = Number(pets, "hours")
        if hours and hours > 0 then
            what = ("%s (about %s h of food carried)"):format(what, Verdicts.Hours(hours))
        end
        return "keep", what
    end
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
    local about = value and (", about %s"):format(Items.FormatMoney(value)) or ""

    if True(ts, "canDisenchant") then
        return "disenchant", "Bought to disenchant" .. about, value, { bought = bought }
    end

    local enchanter = not entry.bound and String(ts, "enchanter") or nil
    if enchanter and enchanter == self:Playing() then enchanter = nil end
    if enchanter then
        return "mail", ("Bought to disenchant: mail to %s"):format(enchanter), value,
            { to = enchanter, bought = bought }
    end

    return "look", "Bought to disenchant, but none of your characters can yet", value, { bought = bought }
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
    if enchanter and enchanter == self:Playing() then enchanter = nil end
    if disenchant and not canDisenchant and not enchanter then disenchant = nil end

    -- Step 11: worth less than the player's Sell below amount, judged on
    -- the most it could fetch. Only once Tradeskills has priced it, and
    -- never soulbound green or better, which always gets a second look.
    local below = self:SellBelow()
    if below and ts and not (bound and (entry.quality or 0) >= 2) then
        local most = math.max(unit, auction or 0, disenchant or 0)
        if most < below then
            return "sell", ("Worth less than %s: %s each"):format(Items.FormatMoney(below),
                Items.FormatMoney(unit)), unit
        end
    end

    local best, value = "sell", unit
    if auctionWorth and auctionWorth > value then best, value = "auction", auctionWorth end
    if disenchant and disenchant > value then best, value = "disenchant", disenchant end

    if best == "disenchant" then
        if canDisenchant then
            return "disenchant", ("Disenchant, about %s"):format(Items.FormatMoney(disenchant)), disenchant
        end
        return "mail", ("Mail to %s to disenchant, about %s"):format(enchanter, Items.FormatMoney(disenchant)),
            disenchant, { to = enchanter }
    end

    if best == "auction" then
        local text = ("Auction about %s each"):format(Items.FormatMoney(auction))
        if slow then text = text .. ", sells slowly" end
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
            return "sell", ("Sells slowly at auction (about %s after the cut), vendor pays %s each")
                :format(Items.FormatMoney(auction), Items.FormatMoney(unit)), unit
        end
        if auction then
            return "sell", ("Vendor pays more than the auction house after its cut (about %s): %s each")
                :format(Items.FormatMoney(auction), Items.FormatMoney(unit)), unit
        end
        return "sell", ("Not an upgrade: %s each"):format(Items.FormatMoney(unit)), unit
    end

    if bound and (entry.quality or 0) >= 2 and eq and True(eq, "sell") then
        return "look", ("Not an upgrade. %s"):format(Each(unit)), unit
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

    for _, entry in pairs(ns.Bags.slots) do
        local verdict, reason, unit, extra = self:Judge(entry)
        local group = byVerdict[verdict]
        local key = verdict .. "|" .. tostring(entry.link or entry.itemID)
        local row = rowsByKey[key]
        if not row then
            row = {
                type = "item", verdict = verdict, reason = reason, unit = unit,
                itemID = entry.itemID, link = entry.link, icon = entry.icon,
                quality = entry.quality, bound = entry.bound,
                mailTo = extra and extra.to, mailCount = extra and extra.count,
                bought = extra and extra.bought,
                name = Items.NameFromLink(entry.link) or ("item " .. tostring(entry.itemID)),
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

    self.groupCache = { bags = bagsVersion, verdicts = self.version, groups = groups }
    return groups
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
    self.version = self.version + 1
end

--- The bags changed (Bags.version moved).
function Verdicts:BagsChanged()
    self:Redraw(true)
end

function Verdicts:Redraw()
    if ns.UI then ns.UI:Refresh() end
    if ns.Selling then ns.Selling:Update() end
end

--------------------------------------------------------------------------------
-- Commands
--------------------------------------------------------------------------------

local function PrintList(name, title)
    local ids = {}
    for itemID in pairs(List(name)) do ids[#ids + 1] = itemID end
    table.sort(ids)
    if #ids == 0 then
        ns.PrintRaw(("  |c%s%s:|r none"):format(ns.COLORS.muted, title))
        return
    end
    local names = {}
    for _, itemID in ipairs(ids) do
        local itemName, link = Items.Call({ "C_Item.GetItemInfo", "GetItemInfo" }, itemID)
        if not itemName then Items:RequestLoad(itemID) end
        local to = List(name)[itemID]
        names[#names + 1] = (link or itemName or ("item " .. itemID))
            .. (type(to) == "string" and (" to " .. to) or "")
    end
    ns.PrintRaw(("  |c%s%s (%d):|r %s"):format(ns.COLORS.muted, title, #ids, table.concat(names, ", ")))
end

ns.RegisterCommand("lists", "show your Always keep, Always sell, Always bank and Always mail lists", function()
    ns.Print("your lists (right-click a row in the Butler window to change them)")
    PrintList("alwaysKeep", "Always keep")
    PrintList("alwaysSell", "Always sell")
    PrintList("alwaysBank", "Always bank")
    PrintList("alwaysMail", "Always mail")
end)

ns.RegisterCommand("vendor", "turn the Butler window coming up at a vendor on or off", function()
    ns.db.openAtVendor = not ns.db.openAtVendor
    ns.Print(ns.db.openAtVendor and "the Butler window comes up at every vendor."
        or "the Butler window no longer comes up at a vendor by itself.")
end)

-- Deletes the player's choices, so typed only, with "confirm" (a house
-- rule: no button deletes data).
ns.RegisterCommand("reset", "empty your Always keep, sell, bank and mail lists (type: reset confirm)", function(rest)
    if rest ~= "confirm" then
        ns.Print("this empties your Always keep, Always sell, Always bank and Always mail lists. To do it, type /bbutler reset confirm")
        return
    end
    ns.db.alwaysKeep, ns.db.alwaysSell, ns.db.alwaysBank, ns.db.alwaysMail = {}, {}, {}, {}
    Verdicts:Changed(true)
    ns.Print("your Always keep, Always sell, Always bank and Always mail lists are empty. Butler decides every item again.")
end)

-- Asked 2026-10-11: anything worth less than an amount the player sets
-- joins Sell. It never deletes or sells by itself; Sell is still a click.
ns.RegisterCommand("sellbelow", "sell anything worth less than an amount, e.g. sellbelow 50s (sellbelow off to stop)", function(rest)
    rest = rest or ""
    if rest:match("^%s*$") then
        local below = Verdicts:SellBelow()
        ns.Print(below and ("items worth less than %s go under Sell. Type /bbutler sellbelow off to stop."):format(Items.FormatMoney(below))
            or "Sell below is off. Type an amount to turn it on, e.g. /bbutler sellbelow 50s or /bbutler sellbelow 1g 20s")
        return
    end
    local copper = Verdicts.ParseMoney(rest)
    if not copper then
        ns.Print("type an amount like 50s, 1g 20s or 75c, or off.")
        return
    end
    Verdicts:SetSellBelow(copper)
    local below = Verdicts:SellBelow()
    ns.Print(below and ("items worth less than %s now go under Sell. Nothing sells until you click Sell."):format(Items.FormatMoney(below))
        or "Sell below is off.")
end)
