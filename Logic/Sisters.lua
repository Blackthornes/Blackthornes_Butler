-- Blackthornes Butler -- Logic/Sisters.lua
-- What the other four Blackthornes addons say about an item.
--
-- Each sister has one call made for Butler (see CLAUDE.md, "How Butler
-- talks to the other four"), read only, inside a pcall, with no TOC
-- dependency. A sister that is not loaded, has no Butler call yet, raises
-- or answers something other than a table is simply not asked: its steps
-- in Logic/Verdicts.lua are skipped and Butler judges as it did on its own.
--
-- Answers are not kept here. Verdicts:Judge keeps its verdict per item
-- until Verdicts.version moves, which it does whenever the Butler window
-- opens, so each sister is asked about an item once per look.

local _, ns = ...

local Sisters = ns.NewModule("Sisters")

-- name = the global and whether Advise takes the item ID or the link.
-- Equipment also takes the bag and slot, which is how it tells soulbound
-- gear apart (its sell coin).
Sisters.LIST = {
    ts = { name = "Tradeskills", global = "BlackthornesTS", byLink = false },
    equipment = { name = "Equipment", global = "BlackthornesEquipment", byLink = true },
    farmer = { name = "Farmer", global = "BlackthornesFarmer", byLink = false },
    pets = { name = "Pets", global = "BlackthornesPets", byLink = false },
}

--- The sister's Butler table, when it is loaded and answers Butler.
function Sisters.Butler(key)
    local info = Sisters.LIST[key]
    if not info then return nil end
    local global = rawget(_G, info.global)
    if type(global) ~= "table" then return nil end
    local butler = rawget(global, "Butler")
    if type(butler) ~= "table" or type(butler.Advise) ~= "function" then return nil end
    return butler
end

--- What one sister says about a carried item (`entry` from Bags), or nil.
function Sisters:Ask(key, entry)
    local butler = Sisters.Butler(key)
    if not butler then return nil end
    local arg = Sisters.LIST[key].byLink and (entry.link or entry.itemID) or entry.itemID
    if arg == nil then return nil end
    local ok, answer
    if key == "equipment" then
        ok, answer = pcall(butler.Advise, butler, arg, entry.bag, entry.slot)
    else
        ok, answer = pcall(butler.Advise, butler, arg)
    end
    if not ok then
        if ns.Debug then ns.Debug("Butler:Advise raised in " .. Sisters.LIST[key].name) end
        return nil
    end
    if type(answer) ~= "table" then return nil end
    return answer
end

--- Everything the four say about an item: { ts, equipment, farmer, pets },
--- each a table or nil.
function Sisters:AskAll(entry)
    return {
        ts = self:Ask("ts", entry),
        equipment = self:Ask("equipment", entry),
        farmer = self:Ask("farmer", entry),
        pets = self:Ask("pets", entry),
    }
end

--------------------------------------------------------------------------------
-- Reading answers safely: a field of the wrong type counts as not given.
--------------------------------------------------------------------------------

function Sisters.Number(answer, field)
    local value = answer and answer[field]
    if type(value) == "number" and value == value then return value end
    return nil
end

function Sisters.String(answer, field)
    local value = answer and answer[field]
    if type(value) == "string" and value ~= "" then return value end
    return nil
end

function Sisters.True(answer, field)
    return answer ~= nil and answer[field] == true
end
