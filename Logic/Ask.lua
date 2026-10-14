-- Blackthornes Butler -- Logic/Ask.lua
-- Ask Butler: a typed question, answered from what Butler and its sisters
-- already know.
--
-- The owner asked (2026-10-14) for an Ask box, kept out of releases until
-- he says go. Nothing here is an AI: addons cannot reach the internet, so a
-- question is matched against a short list of question shapes (Ask.INTENTS)
-- and an item named in it (a link, or a name Butler has seen), and each
-- shape has a small answer written in code. What it reads is what the
-- window already reads: the bags, the verdicts, the jobs, the gold goals,
-- class training and each sister's Butler call, read only, inside a pcall.
--
-- Smooth play: nothing runs until the player asks, and one question reads
-- only what its answer needs.

local _, ns = ...
local L = ns.L

local Ask = ns.NewModule("Ask")

local Items = ns.Items
local Sisters = ns.Sisters

-- Question shapes, tried in order; the first whose words appear wins. The
-- words are matched in the question as typed, lower case, and include the
-- German a player on a German client is likely to type.
Ask.INTENTS = {
    { key = "help", words = { "help", "what can you", "what do you know", "hilfe" } },
    { key = "farm", words = { "where do i farm", "where to farm", "where can i farm", "where can i get",
        "where do i get", "where does", "drops", "farm", "wo farme", "wo finde" } },
    { key = "who", words = { "who has", "who's got", "where is my", "where are my", "how many", "do i have",
        "do my alts", "wer hat", "wie viele" } },
    { key = "worth", words = { "worth", "price", "sell for", "value", "how much is", "how much are",
        "what does", "wert", "preis", "kostet" } },
    { key = "upgrade", words = { "upgrade", "better", "should i wear", "can i wear", "equip",
        "verbesserung", "anziehen" } },
    { key = "pet", words = { "pet", "feed", "eat", "begleiter", "futter", "frisst" } },
    { key = "gold", words = { "gold goal", "gold goals", "afford", "save for", "saving", "riding", "my gold",
        "how much gold", "money", "reiten", "gold", "goldziele" } },
    { key = "goal", words = { "goal", "goals", "ziel" } },
    { key = "train", words = { "train", "training", "spell", "spells", "trainer", "lernen", "zauber" } },
    { key = "next", words = { "what next", "what now", "what should i do", "what do i do", "next",
        "job", "jobs", "to do", "was soll ich", "todo", "anything to do", "als nächstes", "was jetzt", "aufgabe" } },
    { key = "verdict", words = { "do with", "should i sell", "should i keep", "sell", "keep", "vendor",
        "verkaufen", "behalten", "was mache ich mit" } },
}

-- Words left out when looking for an item name in what was left.
local FILLER = {
    a = true, an = true, the = true, my = true, i = true, is = true, are = true, of = true,
    ["for"] = true, it = true, me = true, ["do"] = true, does = true, to = true, ["in"] = true,
    any = true, some = true, what = true, how = true, much = true, many = true, where = true,
    who = true, has = true, have = true, can = true, get = true, ["with"] = true, this = true,
    that = true, should = true, worth = true, price = true, sell = true, keep = true
}

-- Questions shown under the box, as a hint and to click.
Ask.EXAMPLES = {
    L["What should I do next?"],
    L["How are my gold goals?"],
    L["What is Linen Cloth worth?"],
    L["Who has Copper Ore?"],
}

local function Lower(text)
    return (tostring(text or ""):lower():gsub("%s+", " "):gsub("^ ", ""):gsub(" $", ""))
end

--- The question as plain words: links kept out, lower case, no marks.
function Ask.Normalize(text)
    text = tostring(text or "")
    text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    text = text:gsub("|H.-|h%[?(.-)%]?|h", "%1")
    text = text:lower():gsub("[%?%!%.,;:\"]", " ")
    return Lower(text)
end

--- Which shape a question has: an Ask.INTENTS key, or nil.
function Ask.Intent(text)
    -- Whole words only, so "pet" never matches "competitor".
    local words = " " .. Ask.Normalize(text) .. " "
    for _, intent in ipairs(Ask.INTENTS) do
        for _, word in ipairs(intent.words) do
            local at, stop = 1, nil
            repeat
                at, stop = words:find(word, at, true)
                if at then
                    local before, after = words:sub(at - 1, at - 1), words:sub(stop + 1, stop + 1)
                    if not before:match("[%w']") and not after:match("[%w']") then return intent.key end
                    at = at + 1
                end
            until not at
        end
    end
    return nil
end

--------------------------------------------------------------------------------
-- Finding the item
--------------------------------------------------------------------------------

local function ItemName(itemID)
    local name = Items.Call({ "C_Item.GetItemNameByID" }, itemID)
    if type(name) ~= "string" or name == "" then
        name = Items.Call({ "C_Item.GetItemInfo", "GetItemInfo" }, itemID)
    end
    if type(name) == "string" and name ~= "" then return name end
    return nil
end
Ask.ItemName = ItemName

--- Every item name Butler can put a number to without asking the client
--- for more: what is carried, and what Tradeskills says the other
--- characters hold. { [lower name] = itemID }.
function Ask.KnownNames()
    local names = {}
    local function Add(itemID, name)
        if type(itemID) == "number" and type(name) == "string" and name ~= "" then
            names[name:lower()] = names[name:lower()] or itemID
        end
    end
    for _, entry in pairs(ns.Bags and ns.Bags.slots or {}) do
        if entry.itemID then Add(entry.itemID, Items.NameFromLink(entry.link) or ItemName(entry.itemID)) end
    end
    local everyone = ns.Everyone and ns.Everyone:Read()
    for _, character in ipairs(everyone or {}) do
        for _, place in ipairs({ "bags", "bank", "mail" }) do
            for itemID in pairs(character[place] or {}) do
                Add(itemID, ItemName(itemID))
            end
        end
    end
    return names
end

--- The item a question names: a link first, then the longest name Butler
--- knows inside it, then any run of its words the client knows as an item.
--- Returns itemID, name and link (the link only when one was given).
function Ask.FindItem(text)
    text = tostring(text or "")
    local link = text:match("|Hitem:[^|]+|h.-|h")
    local linked = text:match("|Hitem:(%d+)")
    if linked then
        local itemID = tonumber(linked)
        local full = text:match("(|c%x+|Hitem:[^|]+|h.-|h|r)") or link
        return itemID, ItemName(itemID) or Items.NameFromLink(full), full
    end

    local plain = Ask.Normalize(text)
    local best, bestID
    for name, itemID in pairs(Ask.KnownNames()) do
        if #name > 2 and plain:find(name, 1, true) and (not best or #name > #best) then
            best, bestID = name, itemID
        end
    end
    if bestID then return bestID, ItemName(bestID) or best end

    -- The client knows many more items by name than Butler has seen; ask
    -- it about runs of the question's words, longest first.
    local words = {}
    for word in plain:gmatch("%S+") do words[#words + 1] = word end
    for size = math.min(#words, 6), 1, -1 do
        for first = 1, #words - size + 1 do
            local run = table.concat(words, " ", first, first + size - 1)
            if not (size == 1 and FILLER[run]) and #run > 2 then
                local itemID = Items.Call({ "C_Item.GetItemInfoInstant", "GetItemInfoInstant" }, run)
                if type(itemID) == "number" then return itemID, ItemName(itemID) or run end
            end
        end
    end
    return nil
end

--- A carried copy of an item, for the verdict and Equipment's soulbound
--- check, or nil.
function Ask.Carried(itemID)
    for _, entry in pairs(ns.Bags and ns.Bags.slots or {}) do
        if entry.itemID == itemID then return entry end
    end
    return nil
end

--------------------------------------------------------------------------------
-- Answers
--------------------------------------------------------------------------------

local Money = function(copper) return Items.FormatMoney(copper) end

local function Answer(title, lines, action)
    return { title = title, lines = lines or {}, action = action }
end

local function NoItem()
    return Answer(L["Which item do you mean?"], {
        L["Name it in the question, or Shift-click it into the box."],
    })
end

local function Pick(entry, itemID)
    return entry or { itemID = itemID }
end

function Ask:Help()
    local lines = {
        L["I answer from what your Blackthornes addons already know. Try:"],
    }
    for _, example in ipairs(Ask.EXAMPLES) do lines[#lines + 1] = "  " .. example end
    lines[#lines + 1] = "  " .. L["Is this an upgrade? (Shift-click the item in)"]
    lines[#lines + 1] = "  " .. L["Where do I farm Silk Cloth?"]
    lines[#lines + 1] = "  " .. L["Does my pet eat Tough Jerky?"]
    return Answer(L["Ask me about your items, jobs and gold"], lines)
end

--- What to do now: this character's first step, then who is next.
function Ask:Next()
    local Jobs = ns.Jobs
    local ok, plan = pcall(Jobs.Plan, Jobs)
    if not ok or type(plan) ~= "table" then plan = {} end
    local lines = {}
    local here = plan.here
    if here and #here.steps > 0 then
        local text = Jobs.StepText(here.steps[1])
        lines[#lines + 1] = L.Format("Here: %s.", tostring(text))
        if #here.steps > 1 then
            lines[#lines + 1] = #here.steps == 2 and L["And 1 more step after that."]
                or L.Format("And %d more steps after that.", #here.steps - 1)
        end
    end
    if plan.nextJob and #plan.nextJob.steps > 0 then
        lines[#lines + 1] = L.Format("%s: %s", plan.nextJob.name, Jobs.Summary(plan.nextJob))
    end
    local gok, group = pcall(ns.Verdicts.Group, ns.Verdicts, "sell")
    local sell = gok and type(group) == "table" and tonumber(group.count) or 0
    if sell > 0 then
        lines[#lines + 1] = sell == 1 and L["1 item in your bags is ready to sell at a vendor."]
            or L.Format("%d items in your bags are ready to sell at a vendor.", sell)
    end
    if #lines == 0 then
        return Answer(L["Nothing is waiting on you"], {
            L["No jobs for your craft queue, and nothing to sell."],
        })
    end
    return Answer(L["Here's what's next"], lines, { label = L["Open Butler"], command = "window" })
end

--- The gold goals, each with what it costs and how close the purse is.
function Ask:Gold()
    local GG = ns.GoldGoals
    local ok, result = pcall(GG.Goals, GG)
    if not ok or type(result) ~= "table" then
        return Answer(L["I can't read your gold goals right now"], {})
    end
    local lines = { L.Format("You have %s.", Money(result.purse)) }
    if (result.aside or 0) > 0 then
        lines[#lines + 1] = L.Format("%s of it is set aside to mail to your other characters.", Money(result.aside))
    end
    for _, goal in ipairs(result.goals or {}) do
        local label = tostring(goal.label or "")
        if goal.state == "ready" then
            lines[#lines + 1] = L.Format("%s: ready, %s.", label, Money(goal.cost))
        elseif goal.state == "far" then
            lines[#lines + 1] = L.Format("%s: at level %d, %s.", label, goal.level or 0, Money(goal.cost))
        else
            lines[#lines + 1] = L.Format("%s: %s more to go.", label, Money(goal.short))
        end
    end
    if #(result.goals or {}) == 0 then lines[#lines + 1] = L["No gold goals right now."] end
    return Answer(L["Your gold goals"], lines)
end

--- Class spells to train now and at the next level.
function Ask:Train()
    local CT = ns.ClassTraining
    if not (CT and CT:IsOn()) then
        return Answer(L["Class training is turned off"], { L["Turn it on in Butler's Settings, on the Gold page."] })
    end
    local ok, plan = pcall(CT.Plan, CT)
    if not ok or type(plan) ~= "table" then return Answer(L["I can't read your class spells right now"], {}) end
    local lines = {}
    local count = #plan.ready
    if count > 0 then
        lines[#lines + 1] = count == 1
            and L.Format("1 new spell to train now, %s.", CT.CostText(plan.cost, plan.unknown, count))
            or L.Format("%d new spells to train now, %s in all.", count, CT.CostText(plan.cost, plan.unknown, count))
    else
        lines[#lines + 1] = L["Nothing to train right now."]
    end
    if plan.nextLevel and #plan.next > 0 then
        lines[#lines + 1] = L.Format("At level %d: %d more, %s.", plan.nextLevel, #plan.next,
            CT.CostText(plan.nextCost, plan.nextUnknown, #plan.next))
    end
    return Answer(L["Class training"], lines)
end

--- What an item fetches: vendor, auction house and disenchanting.
function Ask:Worth(itemID, name, entry)
    if not itemID then return NoItem() end
    local lines = {}
    local vendor = Items:SellPrice(itemID)
    if type(vendor) == "number" and vendor > 0 then
        lines[#lines + 1] = L.Format("A vendor pays %s each.", Money(vendor))
    else
        lines[#lines + 1] = L["Vendors don't buy it."]
    end
    local ts = Sisters:Ask("ts", Pick(entry, itemID))
    local auction = Sisters.Number(ts, "auction")
    local now = Sisters.Number(ts, "auctionNow")
    local disenchant = Sisters.Number(ts, "disenchant")
    if auction then
        lines[#lines + 1] = L.Format("On the auction house about %s each, after the cut.", Money(auction))
        if now and now < auction then
            lines[#lines + 1] = L.Format("Today's cheapest listing would give you %s.", Money(now))
        end
    elseif Sisters.Butler("ts") then
        lines[#lines + 1] = L["No auction price for it yet."]
    else
        lines[#lines + 1] = L["With Blackthornes Tradeskills I'd know its auction price too."]
    end
    if disenchant then
        lines[#lines + 1] = L.Format("Disenchanted, about %s.", Money(disenchant))
    end
    return Answer(L.Format("%s is worth", name or L["It"]), lines)
end

--- Who holds an item, character by character.
function Ask:Who(itemID, name)
    if not itemID then return NoItem() end
    local Everyone = ns.Everyone
    local characters = Everyone:Read()
    local lines, total = {}, 0
    if characters then
        local rows = {}
        for _, character in ipairs(characters) do
            local holder = { character = character, total = 0 }
            for _, place in ipairs(Everyone.PLACES) do
                local count = (character[place] and character[place][itemID]) or 0
                if character.isCurrent and place == "bags" then count = ns.Bags:Carried(itemID) end
                holder[place] = count
                holder.total = holder.total + count
            end
            if holder.total > 0 then rows[#rows + 1] = holder end
        end
        table.sort(rows, function(a, b) return a.total > b.total end)
        for _, holder in ipairs(rows) do
            total = total + holder.total
            local who = holder.character.name
            if holder.character.isCurrent then who = L.Format("%s (you)", who) end
            lines[#lines + 1] = L.Format("%s: %d, %s", who, holder.total, Everyone.Where(holder))
        end
    else
        total = ns.Bags:Carried(itemID)
        if total > 0 then lines[#lines + 1] = L.Format("You carry %d.", total) end
        lines[#lines + 1] = L["With Blackthornes Tradeskills I'd know what your other characters hold too."]
    end
    if total == 0 and characters then
        return Answer(L.Format("Nobody has %s", name or L["it"]), {
            L["None in any character's bags, bank or mail, as last seen."],
        })
    end
    return Answer(L.Format("You have %d %s", total, name or ""), lines,
        characters and { label = L["All characters"], command = "all" } or nil)
end

--- Is an item an upgrade, for this character or another?
function Ask:Upgrade(itemID, name, entry, link)
    if not itemID then return NoItem() end
    if not Sisters.Butler("equipment") then
        return Answer(L["I'd need Blackthornes Equipment for that"], {
            L["It works out upgrades from your stats and gear."],
        })
    end
    local item = entry or { itemID = itemID, link = link }
    local answer = Sisters:Ask("equipment", item)
    if not answer then
        return Answer(L.Format("%s isn't gear", name or L["It"]), { L["Only gear can be an upgrade."] })
    end
    local gain = Sisters.Number(answer, "gain")
    local upgrade = Sisters.String(answer, "upgrade")
    if upgrade == "now" then
        return Answer(L["Yes, it's an upgrade"], {
            gain and L.Format("About %d%% better than what you wear.", gain) or L["It fills an empty slot."],
        })
    elseif upgrade == "later" then
        return Answer(L["Yes, a bit later"], { L["It's an upgrade once you reach its level or train its skill."] })
    end
    local alt = type(answer.alt) == "table" and answer.alt or nil
    if alt and type(alt.key) == "string" then
        local who = ns.Errands and ns.Errands:NameOf(alt.key) or nil
        local altGain = type(alt.gain) == "number" and alt.gain or nil
        return Answer(L["Not for you"], {
            who and (altGain and L.Format("It's about %d%% better for %s.", altGain, who)
                or L.Format("It fills an empty slot for %s.", who))
                or L["It's an upgrade for one of your other characters."],
        })
    end
    return Answer(L["No, it's not an upgrade"], { L["What you wear now is as good or better."] })
end

--- Does the pet eat an item, and how long the food lasts.
function Ask:Pet(itemID, name)
    if not Sisters.Butler("pets") then
        return Answer(L["I'd need Blackthornes Pets for that"], {})
    end
    if not itemID then
        -- Any food will do for the hours: they are for all the food carried.
        for _, entry in pairs(ns.Bags.slots) do
            local answer = Sisters:Ask("pets", entry)
            local hours = Sisters.Number(answer, "hours")
            if hours then
                return Answer(L["Your pet's food"], {
                    L.Format("What you carry lasts about %.1f hours.", hours),
                })
            end
        end
        return NoItem()
    end
    local answer = Sisters:Ask("pets", { itemID = itemID })
    if not answer then
        return Answer(L.Format("%s isn't pet food", name or L["It"]), {
            L["Or you have no hunter pet out that eats."],
        })
    end
    local lines = {}
    local hours = Sisters.Number(answer, "hours")
    if hours then lines[#lines + 1] = L.Format("Your food lasts about %.1f hours.", hours) end
    if answer.eats == true then
        return Answer(L.Format("Yes, your pet eats %s", name or ""), lines)
    end
    return Answer(L.Format("No, your pet won't eat %s", name or ""), lines)
end

--- A Farmer goal's progress.
function Ask:Goal(itemID, name)
    if not Sisters.Butler("farmer") then
        return Answer(L["I'd need Blackthornes Farmer for that"], {})
    end
    if not itemID then return NoItem() end
    local answer = Sisters:Ask("farmer", { itemID = itemID })
    if not answer then
        return Answer(L.Format("No goal for %s", name or L["it"]), { L["Set one in Farmer's search."] })
    end
    local have, target, need = Sisters.Number(answer, "have"), Sisters.Number(answer, "target"), Sisters.Number(answer, "need")
    if need == 0 then
        return Answer(L["That goal is done"], { L.Format("You have %d of %d.", have or 0, target or 0) })
    end
    return Answer(L.Format("%d more to go", need or 0), { L.Format("You have %d of %d.", have or 0, target or 0) })
end

--- Where to farm an item: Farmer's search has the answer, so it is opened.
function Ask:Farm(itemID, name)
    if not name then return NoItem() end
    local slash = rawget(_G, "SlashCmdList")
    local farmer = type(slash) == "table" and slash.BLACKTHORNESFARMER
    if type(farmer) ~= "function" then
        return Answer(L["I'd need Blackthornes Farmer for that"], {
            L["It knows where every item drops, with mobs, zones and drop rates."],
        })
    end
    local lines = { L["Farmer's search has every place it drops, with the rates."] }
    local goal = Sisters:Ask("farmer", { itemID = itemID })
    local need = Sisters.Number(goal, "need")
    if need and need > 0 then lines[#lines + 1] = L.Format("Your goal still needs %d.", need) end
    return Answer(L.Format("Where to farm %s", name), lines, { label = L["Show in Farmer"], farm = name })
end

--- What Butler says to do with an item.
function Ask:Verdict(itemID, name, entry)
    if not itemID then return NoItem() end
    if not entry then
        local lines = {}
        local worth = self:Worth(itemID, name)
        for _, line in ipairs(worth.lines) do lines[#lines + 1] = line end
        return Answer(L.Format("You aren't carrying %s", name or L["it"]), lines)
    end
    local Verdicts = ns.Verdicts
    local ok, verdict = pcall(Verdicts.VerdictOf, Verdicts, entry)
    local reason, unit
    if ok and verdict then
        -- The window's verdict, with the words of the judgement behind it:
        -- a copy past what an alt wants is judged as if no alt wanted it.
        local judged
        judged, reason, unit = Verdicts:Judge(entry)
        if judged ~= verdict then judged, reason, unit = Verdicts:Judge(entry, true) end
    end
    if not ok or not verdict then return Answer(L["I'm still looking at it"], { L["Ask again in a moment."] }) end
    local lines = {}
    if type(reason) == "string" and reason ~= "" then lines[#lines + 1] = reason end
    if type(unit) == "number" and unit > 0 then lines[#lines + 1] = L.Format("Worth %s each.", Money(unit)) end
    return Answer(L.Format("Butler says: %s", ns.Verdicts.LABELS[verdict] or verdict), lines)
end

--- Answer a question: { title, lines, action }.
function Ask:Answer(text)
    local ok, answer = pcall(function()
        if Lower(text) == "" then return self:Help() end
        local intent = Ask.Intent(text)
        if intent == "help" then return self:Help() end
        if intent == "gold" then return self:Gold() end

        local itemID, name, link = Ask.FindItem(text)
        local entry = itemID and Ask.Carried(itemID)
        -- "What do I do with X" is about X; "what do I do" alone is the jobs.
        if intent == "next" then
            if itemID then return self:Verdict(itemID, name, entry) end
            return self:Next()
        end
        if intent == "train" and not itemID then return self:Train() end
        if intent == "farm" then return self:Farm(itemID, name) end
        if intent == "who" then return self:Who(itemID, name) end
        if intent == "worth" then return self:Worth(itemID, name, entry) end
        if intent == "upgrade" then return self:Upgrade(itemID, name, entry, link) end
        if intent == "pet" then return self:Pet(itemID, name) end
        if intent == "goal" then return self:Goal(itemID, name) end
        if intent == "train" then return self:Train() end
        if itemID then return self:Verdict(itemID, name, entry) end
        return nil
    end)
    if ok and answer then return answer end
    if not ok and ns.Debug then ns.Debug("Ask failed: " .. tostring(answer)) end
    local help = self:Help()
    help.title = L["I don't know that one yet"]
    return help
end

--- Run an answer's button.
function Ask:Run(action)
    if type(action) ~= "table" then return end
    if action.farm then
        local slash = rawget(_G, "SlashCmdList")
        local farmer = type(slash) == "table" and slash.BLACKTHORNESFARMER
        if type(farmer) == "function" then pcall(farmer, action.farm) end
    elseif action.command then
        ns.HandleSlash(action.command)
    end
end
