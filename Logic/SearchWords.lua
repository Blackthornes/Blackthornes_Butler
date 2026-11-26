-- Blackthornes Butler -- Logic/SearchWords.lua
-- The search boxes take words as well as names (the owner said build it,
-- 2026-11-26, from the mockup "Search that knows words"): "cloth over 1g",
-- "gear level 30 to 40", "boe", "on auction", a character's name. All
-- Characters, Your Bags and the Bags window ask the same two calls:
--
--   SearchWords.Parse(text, characters)   -- a query, or nil for no words
--   SearchWords.Match(query, item)        -- does an item pass?
--
-- `item` is { itemID, name, link, quality, bound, quest, holders, bag,
-- slot, upgrade }, as much of it as the caller knows. Every word works in
-- the client's language and in English. The words of a kind ("quest") also
-- find items with that word in their name, so a search that found an item
-- by name before still finds it.
--
-- Smooth play: what the client says about an item is kept per item for the
-- session, and its worth and whether it is an upgrade until Butler judges
-- again (Verdicts.version). A query is read once per redraw, never per row.
-- Nothing is saved.

local _, ns = ...

local L = ns.L

local SearchWords = ns.NewModule("SearchWords")

local Items = ns.Items

local COPPER = { gold = 10000, silver = 100, copper = 1 }

--------------------------------------------------------------------------------
-- Folding: lower case, Latin accents and Cyrillic too
--------------------------------------------------------------------------------

-- string.lower only knows A to Z. Capital letters with accents (À to Þ)
-- and Cyrillic capitals (А to Я, Ё) are lowered here too, so "Über" and
-- "über" or "Серый" and "серый" match.
local function LowerTwo(a, b)
    local x, y = a:byte(), b:byte()
    if x == 195 and y >= 128 and y <= 158 and y ~= 151 then
        return string.char(195, y + 32)
    elseif x == 208 and y >= 144 and y <= 159 then
        return string.char(208, y + 32)
    elseif x == 208 and y >= 160 and y <= 175 then
        return string.char(209, y - 32)
    elseif x == 208 and y == 129 then
        return string.char(209, 145)
    end
    return a .. b
end

--- Text folded for matching: lower case, trimmed, spaces squeezed.
function SearchWords.Fold(text)
    if type(text) ~= "string" then return "" end
    text = text:lower():gsub("([\195\208])([\128-\191])", LowerTwo)
    return (text:gsub("%s+", " "):gsub("^ ", ""):gsub(" $", ""))
end

local Fold = SearchWords.Fold

--- Words one by one. A number touching a letter of another script is
--- parted from it ("超过1金" reads as "超过 1 金"), so the money words of
--- every language can be read.
function SearchWords.Tokens(text)
    text = Fold(text):gsub("(%d)([\128-\255])", "%1 %2"):gsub("([\128-\255])(%d)", "%1 %2")
    local tokens = {}
    for token in text:gmatch("%S+") do tokens[#tokens + 1] = token end
    return tokens
end

--------------------------------------------------------------------------------
-- The words
--------------------------------------------------------------------------------

-- Each kind of word, with its English words and the client's. Both always
-- work. A line may name several words, comma between them.
SearchWords.WORDS = {
    { kind = "gear", en = "gear, armor, weapon, weapons", here = L["gear, armor, weapon, weapons"] },
    { kind = "boe", en = "boe, binds when worn", here = L["boe, binds when worn"] },
    { kind = "bound", en = "bound, soulbound, bop", here = L["bound, soulbound, bop"] },
    { kind = "quest", en = "quest, quests", here = L["quest, quests"] },
    { kind = "materials", en = "materials, mats, trade goods", here = L["materials, mats, trade goods"] },
    { kind = "food", en = "food, drink, water", here = L["food, drink, water"] },
    { kind = "grey", en = "grey, gray, junk", here = L["grey, gray, junk"] },
    { kind = "upgrade", en = "upgrade, upgrades", here = L["upgrade, upgrades"] },
    { kind = "worn", en = "worn, wearing, equipped", here = L["worn, wearing, equipped"] },
    { kind = "auction", en = "on auction, auction, auctions", here = L["on auction, auction, auctions"] },
    { kind = "over", en = "over, above, more than", here = L["over, above, more than"] },
    { kind = "under", en = "under, below, less than", here = L["under, below, less than"] },
    { kind = "level", en = "level, lvl", here = L["level, lvl"] },
}

-- Words read only inside "over", "under" and "level".
SearchWords.PART_WORDS = {
    { kind = "to", en = "to", here = L["to"] },
    { kind = "gold", en = "g, gold", here = L["g, gold"] },
    { kind = "silver", en = "s, silver", here = L["s, silver"] },
    { kind = "copper", en = "c, copper", here = L["c, copper"] },
}

local phrases, parts

--- Every phrase as its words, longest first: { tokens, kind }.
local function Phrases(list)
    local out, seen = {}, {}
    for _, entry in ipairs(list) do
        for _, source in ipairs({ entry.here, entry.en }) do
            for word in tostring(source or ""):gmatch("[^,]+") do
                local tokens = SearchWords.Tokens(word)
                local key = table.concat(tokens, " ")
                if #tokens > 0 and not seen[key] then
                    seen[key] = true
                    out[#out + 1] = { tokens = tokens, kind = entry.kind }
                end
            end
        end
    end
    table.sort(out, function(a, b) return #a.tokens > #b.tokens end)
    return out
end

--- The phrase that starts at tokens[i], or nil: its kind and length.
local function PhraseAt(list, tokens, i)
    for _, phrase in ipairs(list) do
        local n = #phrase.tokens
        local all = i + n - 1 <= #tokens
        for j = 1, n do
            if not all then break end
            if tokens[i + j - 1] ~= phrase.tokens[j] then all = false end
        end
        if all then return phrase.kind, n end
    end
    return nil
end

local function Lists()
    phrases = phrases or Phrases(SearchWords.WORDS)
    parts = parts or Phrases(SearchWords.PART_WORDS)
    return phrases, parts
end

--- Forget the read phrases (for tests that load another language).
function SearchWords:Forget()
    phrases, parts = nil, nil
end

--------------------------------------------------------------------------------
-- Reading what was typed
--------------------------------------------------------------------------------

--- Money from tokens[i] on: "1g", "1g50s", "50 s", "2 gold", or a bare
--- number for gold. The copper and how many tokens it took, or nil.
local function Money(tokens, i)
    local _, part = Lists()
    local total, used = 0, 0
    while i + used <= #tokens do
        local token = tokens[i + used]
        if token:match("^%d+$") then
            local number = tonumber(token)
            local coin, n = PhraseAt(part, tokens, i + used + 1)
            if coin and COPPER[coin] then
                total, used = total + number * COPPER[coin], used + 1 + n
            elseif used == 0 then
                return number * COPPER.gold, 1
            else
                break
            end
        else
            -- Pieces in one token: "1g50s", "1з", "1po".
            local sum, whole = 0, ""
            for digits, letters in token:gmatch("(%d+)(%D+)") do
                local coin = PhraseAt(part, { letters }, 1)
                if not (coin and COPPER[coin]) then sum = nil break end
                sum = sum + tonumber(digits) * COPPER[coin]
                whole = whole .. digits .. letters
            end
            if not sum or whole ~= token or whole == "" then break end
            total, used = total + sum, used + 1
        end
    end
    if used == 0 then return nil end
    return total, used
end

--- A level or a range from tokens[i] on: "30", "30 to 40", "30-40".
local function Levels(tokens, i)
    local _, part = Lists()
    local token = tokens[i]
    if not token then return nil end
    local lo, hi = token:match("^(%d+)%-(%d+)$")
    if lo then return tonumber(lo), tonumber(hi), 1 end
    if not token:match("^%d+$") then return nil end
    lo = tonumber(token)
    local kind, n = PhraseAt(part, tokens, i + 1)
    if (kind == "to" or tokens[i + 1] == "-") and tokens[i + 1 + (n or 1)]
        and tokens[i + 1 + (n or 1)]:match("^%d+$") then
        return lo, tonumber(tokens[i + 1 + (n or 1)]), 2 + (n or 1)
    end
    return lo, lo, 1
end

--- Each character's name as words, to find "Ana" or "Ana Stone" typed.
local function NamePhrases(characters)
    local out = {}
    for _, character in ipairs(type(characters) == "table" and characters or {}) do
        if type(character) == "table" and character.key then
            local seen = {}
            for _, name in ipairs({ character.name, character.short }) do
                if type(name) == "string" then
                    local tokens = SearchWords.Tokens(name)
                    for _, words in ipairs({ tokens, { tokens[1] } }) do
                        local key = table.concat(words, " ")
                        if #words > 0 and key ~= "" and not seen[key] then
                            seen[key] = true
                            out[#out + 1] = { tokens = words, kind = character.key }
                        end
                    end
                end
            end
        end
    end
    table.sort(out, function(a, b) return #a.tokens > #b.tokens end)
    return out
end

--- What was typed, read into a query: { words = name words, id, tests },
--- or nil when nothing was typed. `characters` ({ key, name, short })
--- lets a character's name be read as "what they hold".
function SearchWords.Parse(text, characters)
    local tokens = SearchWords.Tokens(text)
    if #tokens == 0 then return nil end
    local phrase = Lists()
    local names = NamePhrases(characters)
    local query = { words = {}, tests = {} }
    if #tokens == 1 and tokens[1]:match("^%d+$") then query.id = tonumber(tokens[1]) end

    local i = 1
    while i <= #tokens do
        local kind, n = PhraseAt(phrase, tokens, i)
        local taken = false
        if kind == "over" or kind == "under" then
            local copper, used = Money(tokens, i + n)
            if copper then
                query.tests[#query.tests + 1] = { kind = kind, copper = copper }
                i, taken = i + n + used, true
            end
        elseif kind == "level" then
            local lo, hi, used = Levels(tokens, i + n)
            if lo then
                if hi < lo then lo, hi = hi, lo end
                query.tests[#query.tests + 1] = { kind = "level", lo = lo, hi = hi }
                i, taken = i + n + used, true
            end
        elseif kind then
            local word = table.concat(tokens, " ", i, i + n - 1)
            query.tests[#query.tests + 1] = { kind = kind, word = word }
            i, taken = i + n, true
        end
        if not taken then
            local key, m = PhraseAt(names, tokens, i)
            if key then
                query.tests[#query.tests + 1] = { kind = "who", key = key,
                    word = table.concat(tokens, " ", i, i + m - 1) }
                i = i + m
            else
                query.words[#query.words + 1] = tokens[i]
                i = i + 1
            end
        end
    end
    return query
end

--- A query that is only the chips' tests (and a typed one's, if any).
function SearchWords.WithChips(query, chips)
    if type(chips) ~= "table" or not next(chips) then return query end
    local merged = { words = query and query.words or {}, tests = {}, id = query and query.id }
    for _, test in ipairs(query and query.tests or {}) do merged.tests[#merged.tests + 1] = test end
    for _, key in ipairs(SearchWords.CHIPS) do
        if chips[key] then merged.tests[#merged.tests + 1] = SearchWords.CHIP_TESTS[key] end
    end
    return merged
end

--------------------------------------------------------------------------------
-- The chips over All Characters
--------------------------------------------------------------------------------

SearchWords.CHIPS = { "gear", "boe", "materials", "quest", "food", "upgrade", "over1g", "auction" }
SearchWords.CHIP_WORDS = {
    gear = L["Gear"],
    boe = L["Binds When Worn"],
    materials = L["Materials"],
    quest = L["Quest"],
    food = L["Food"],
    upgrade = L["Upgrades"],
    over1g = L["Worth Over 1g"],
    auction = L["On Auction"],
}
SearchWords.CHIP_TESTS = {
    gear = { kind = "gear" },
    boe = { kind = "boe" },
    materials = { kind = "materials" },
    quest = { kind = "quest" },
    food = { kind = "food" },
    upgrade = { kind = "upgrade" },
    over1g = { kind = "over", copper = COPPER.gold },
    auction = { kind = "auction" },
}

--- The words Butler knows, for the search box's hover.
function SearchWords.TipLines()
    return {
        L["gear, boe, bound, quest, materials, food, grey"],
        L["upgrade, worn, on auction"],
        L["over 1g, under 50s, level 30 to 40"],
        L["a character's name"],
    }
end

--- Hovering a search box lists the words it knows.
function SearchWords.AttachTip(box)
    if type(box) ~= "table" or not box.HookScript then return end
    local function Show(owner)
        if not GameTooltip then return end
        GameTooltip:SetOwner(owner, "ANCHOR_BOTTOMLEFT")
        GameTooltip:SetText(L["Words Butler Knows:"], 1, 0.82, 0)
        for _, line in ipairs(SearchWords.TipLines()) do
            GameTooltip:AddLine(line, 1, 1, 1, true)
        end
        GameTooltip:Show()
    end
    local function Hide() if GameTooltip then GameTooltip:Hide() end end
    box:HookScript("OnEnter", function() Show(box) end)
    box:HookScript("OnLeave", Hide)
    local edit = rawget(box, "editBox")
    if edit and edit.HookScript then
        edit:HookScript("OnEnter", function() Show(box) end)
        edit:HookScript("OnLeave", Hide)
    end
end

--------------------------------------------------------------------------------
-- What an item is
--------------------------------------------------------------------------------

local facts = {}
local worths, upgrades, keptFor = {}, {}, nil

-- Item classes the game gives.
local CONSUMABLE, REAGENT, WEAPON, ARMOR, TRADE_GOODS, QUEST = 0, 5, 2, 4, 7, 12
local FOOD_AND_DRINK = 5
local BIND_PICKUP, BIND_EQUIP, BIND_QUEST = 1, 2, 4
local NOT_WORN = { [""] = true, INVTYPE_NON_EQUIP = true, INVTYPE_NON_EQUIP_IGNORE = true }

--- What the client says about an item: { classID, subclassID, equipLoc,
--- bind, level, itemLevel, quality }. Kept once the client has it all.
function SearchWords.Facts(itemID)
    local known = facts[itemID]
    if known then return known end
    local _, _, _, equipLoc, _, classID, subclassID = Items.Call({ "C_Item.GetItemInfoInstant", "GetItemInfoInstant" }, itemID)
    local fact = { classID = tonumber(classID), subclassID = tonumber(subclassID),
        equipLoc = type(equipLoc) == "string" and equipLoc or "" }
    local name, _, quality, itemLevel, level, _, _, _, _, _, _, _, _, bind =
        Items.Call({ "C_Item.GetItemInfo", "GetItemInfo" }, itemID)
    if type(name) == "string" and name ~= "" then
        fact.quality, fact.itemLevel = tonumber(quality), tonumber(itemLevel)
        fact.level, fact.bind = tonumber(level), tonumber(bind)
        facts[itemID] = fact
    end
    return fact
end

--- Forget what is kept (for tests, whose pretend items change).
function SearchWords:ForgetItems()
    facts, worths, upgrades, keptFor = {}, {}, {}, nil
end

local function KeptVersion()
    local version = ns.Verdicts and ns.Verdicts.version or 0
    if keptFor ~= version then worths, upgrades, keptFor = {}, {}, version end
end

--- What one is worth: a vendor's price for greys, else the best of a
--- vendor and Tradeskills' price. Nil when nothing prices it.
function SearchWords.Worth(itemID, quality)
    KeptVersion()
    local known = worths[itemID]
    if known ~= nil then return known or nil end
    local vendor = tonumber(Items:SellPrice(itemID)) or 0
    local best = vendor
    if quality ~= 0 then
        local api = rawget(_G, "BlackthornesTS_API")
        if type(api) == "table" and type(api.GetPrice) == "function" then
            local ok, price = pcall(api.GetPrice, itemID)
            if ok and type(price) == "number" and price > best then best = price end
        end
    end
    worths[itemID] = best > 0 and best or false
    return best > 0 and best or nil
end

local function IsGear(fact)
    return (fact.classID == WEAPON or fact.classID == ARMOR) and not NOT_WORN[fact.equipLoc]
end

--- Is it an upgrade, here or for another character? Equipment is asked,
--- once per item until Butler judges again.
function SearchWords.Upgrade(item, fact)
    if item.upgrade then return true end
    if not IsGear(fact) then return false end
    KeptVersion()
    local key = item.link or item.itemID
    local known = upgrades[key]
    if known ~= nil then return known end
    local answer = ns.Sisters and ns.Sisters:Ask("equipment",
        { itemID = item.itemID, link = item.link, bag = item.bag, slot = item.slot })
    local yes = type(answer) == "table"
        and (answer.upgrade == "now" or answer.upgrade == "later" or type(answer.alt) == "table")
    upgrades[key] = yes and true or false
    return yes and true or false
end

local function Held(item, place)
    for _, holder in ipairs(type(item.holders) == "table" and item.holders or {}) do
        if (holder[place] or 0) > 0 then return true end
    end
    return false
end

local CHECKS = {
    gear = function(item, fact) return IsGear(fact) end,
    boe = function(item, fact) return fact.bind == BIND_EQUIP and item.bound ~= true end,
    bound = function(item, fact)
        return item.bound == true or fact.bind == BIND_PICKUP or fact.bind == BIND_QUEST
    end,
    quest = function(item, fact)
        if item.quest or fact.classID == QUEST then return true end
        local quests = ns.Quests
        if quests and quests.For then
            local ok, wanted = pcall(quests.For, quests, item.itemID)
            if ok and wanted then return true end
        end
        return false
    end,
    materials = function(item, fact) return fact.classID == TRADE_GOODS or fact.classID == REAGENT end,
    food = function(item, fact) return fact.classID == CONSUMABLE and fact.subclassID == FOOD_AND_DRINK end,
    grey = function(item, fact) return (item.quality or fact.quality) == 0 end,
    upgrade = function(item, fact) return SearchWords.Upgrade(item, fact) end,
    worn = function(item) return Held(item, "worn") end,
    auction = function(item) return Held(item, "auction") end,
    over = function(item, fact, test)
        local worth = SearchWords.Worth(item.itemID, item.quality or fact.quality)
        return worth ~= nil and worth > test.copper
    end,
    under = function(item, fact, test)
        local worth = SearchWords.Worth(item.itemID, item.quality or fact.quality)
        return worth ~= nil and worth < test.copper
    end,
    level = function(item, fact, test)
        local level = (fact.level and fact.level > 0) and fact.level or fact.itemLevel
        return level ~= nil and level >= test.lo and level <= test.hi
    end,
    who = function(item, fact, test)
        for _, holder in ipairs(type(item.holders) == "table" and item.holders or {}) do
            if holder.character and holder.character.key == test.key then return true end
        end
        return false
    end,
}

--- Does an item pass the query? Every name word must be in its name, and
--- every test must pass (a kind's word may be in the name instead).
function SearchWords.Match(query, item)
    if not query then return true end
    if type(item) ~= "table" or not item.itemID then return false end
    if query.id and item.itemID == query.id then return true end
    local name = Fold(item.name)
    for _, word in ipairs(query.words) do
        if not name:find(word, 1, true) then return false end
    end
    if #query.tests == 0 then return true end
    local fact = SearchWords.Facts(item.itemID)
    for _, test in ipairs(query.tests) do
        local check = CHECKS[test.kind]
        local pass = check ~= nil and check(item, fact, test) == true
        if not pass and not (test.word and name:find(test.word, 1, true)) then return false end
    end
    return true
end
