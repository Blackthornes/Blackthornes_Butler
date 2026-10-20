-- Blackthornes Butler -- Logic/SkillUp.lua
-- The cheapest skill-up (a player asked, the owner said build it
-- 2026-10-19, from a mockup with the words he approved): with "Cheapest
-- Skill-Up:" ticked, the end of this character's Jobs has a line for each
-- profession still being leveled, naming the craft Tradeskills' Level Up
-- tab puts first, with a Queue button. Tradeskills works it out, inside a
-- pcall, read only:
--
--   _G.BlackthornesTS.Butler:NextSkillUp()
--     -- { { profession, skill, max, recipeID, itemID, name,
--     --     tier ("optimal" or "medium"), cost (copper; below 0 pays), queued } }
--     -- a profession at its cap for now comes as { profession, english,
--     -- skill, max, capped = true }: the line names the trainer's next rank
--     -- (GoldGoals' RANKS, the owner 2026-10-20), and none past the last.
--   _G.BlackthornesTS.Butler:QueueSkillUp(recipeID)   -- true, or false and why
--
-- Saved, account wide, never rename it: skillUpLine (off unless ticked).

local _, ns = ...
local L = ns.L or setmetatable({ Format = string.format }, { __index = function(_, key) return key end })

local SkillUp = ns.NewModule("SkillUp")

local Items = ns.Items

--- Tradeskills' Butler table when it is loaded and has `method`.
local function Tradeskills(method)
    local global = rawget(_G, "BlackthornesTS")
    if type(global) ~= "table" then return nil end
    local butler = rawget(global, "Butler")
    if type(butler) ~= "table" or type(butler[method]) ~= "function" then return nil end
    return butler
end

local function Whole(value)
    value = tonumber(value)
    if value and value == value and value ~= math.huge and value ~= -math.huge then
        return math.floor(value + 0.5)
    end
    return nil
end

function SkillUp:IsOn()
    return ns.db ~= nil and ns.db.skillUpLine == true
end

function SkillUp:SetOn(on)
    if not ns.db then return end
    ns.db.skillUpLine = on and true or false
    if ns.Jobs then ns.Jobs:Changed() end
    if ns.UI and ns.UI.IsShown and ns.UI:IsShown() then ns.UI:Refresh(true) end
end

--- One entry a profession, checked field by field; empty while the
--- setting is off, without Tradeskills, or when it raises.
function SkillUp:Read()
    local list = {}
    if not self:IsOn() then return list end
    local ts = Tradeskills("NextSkillUp")
    if not ts then return list end
    local ok, answer = pcall(ts.NextSkillUp, ts)
    if not ok or type(answer) ~= "table" then return list end
    for _, entry in ipairs(answer) do
        if type(entry) == "table" then
            local recipeID, skill, max = Whole(entry.recipeID), Whole(entry.skill), Whole(entry.max)
            local cost = Whole(entry.cost)
            local profession = type(entry.profession) == "string" and entry.profession ~= "" and entry.profession
            if recipeID and recipeID > 0 and skill and max and skill < max and cost and profession then
                list[#list + 1] = {
                    profession = profession, skill = skill, max = max, recipeID = recipeID,
                    itemID = Whole(entry.itemID),
                    name = type(entry.name) == "string" and entry.name or nil,
                    sure = entry.tier ~= "medium",
                    cost = cost,
                    queued = entry.queued == true,
                }
            elseif entry.capped == true and skill and max and skill >= max and profession then
                list[#list + 1] = self.Train(profession, entry.english, skill, max)
            end
        end
    end
    return list
end

--- A capped profession's line: the next rank a trainer teaches, or nil
--- past the last one (or when this client's levels never reach it).
function SkillUp.Train(profession, english, skill, max)
    local GG = ns.GoldGoals
    local line = GG and type(english) == "string" and GG.LineOf(english)
    if not line then return nil end
    local rank = GG:NextRank(line, { skill = skill, max = max, name = profession }, GG.MaxLevel())
    if not rank then return nil end
    local index = max >= 225 and 3 or max >= 150 and 2 or 1
    return {
        capped = true, profession = profession, skill = skill, max = max,
        rank = GG.RANK_WORDS[index], cap = max + 75, cost = rank.cost, level = rank.level,
    }
end

--- The Jobs rows, one a profession.
function SkillUp:Rows()
    local rows = {}
    for _, entry in ipairs(self:Read()) do
        rows[#rows + 1] = { type = "skillup", entry = entry }
    end
    return rows
end

--- The line's title and the words under it.
function SkillUp.Text(entry)
    if entry.capped then
        local title = L.Format("Train %s %s", entry.rank, entry.profession)
        local detail
        if entry.level > (ns.GoldGoals.Level() or 1) then
            detail = L.Format("%s %d/%d. You can train it at level %d to raise your cap to %d.",
                entry.profession, entry.skill, entry.max, entry.level, entry.cap)
        elseif entry.profession:match("^[AEIOUaeiou]") then
            detail = L.Format("%s %d/%d. Visit an %s trainer to raise your cap to %d, about %s.",
                entry.profession, entry.skill, entry.max, entry.profession, entry.cap, Items.FormatMoney(entry.cost or 0))
        else
            detail = L.Format("%s %d/%d. Visit a %s trainer to raise your cap to %d, about %s.",
                entry.profession, entry.skill, entry.max, entry.profession, entry.cap, Items.FormatMoney(entry.cost or 0))
        end
        return title, detail
    end
    local name = ns.Jobs and ns.Jobs.ItemName(entry.itemID, entry.name)
        or entry.name or L.Format("Item %s", tostring(entry.itemID))
    local title = L.Format("Next skill point: %s", name)
    local detail
    if entry.cost < 0 then
        local back = Items.FormatMoney(-entry.cost)
        detail = entry.sure
            and L.Format("%s %d/%d. A sure point, and you make about %s back.", entry.profession, entry.skill, entry.max, back)
            or L.Format("%s %d/%d. A likely point, and you make about %s back.", entry.profession, entry.skill, entry.max, back)
    else
        local cost = Items.FormatMoney(entry.cost)
        detail = entry.sure
            and L.Format("%s %d/%d. A sure point for about %s.", entry.profession, entry.skill, entry.max, cost)
            or L.Format("%s %d/%d. A likely point for about %s.", entry.profession, entry.skill, entry.max, cost)
    end
    return title, detail
end

function SkillUp.Icon(entry)
    if entry.capped then return ns.GoldGoals.ICONS.profession end
    local icon = entry.itemID and Items.Call({ "C_Item.GetItemIconByID", "GetItemIcon" }, entry.itemID)
    return icon or [[Interface\Icons\INV_Misc_Book_08]]
end

--- The Queue button: one into Tradeskills' queue. A line already queued
--- reads Queued and does nothing.
function SkillUp:Queue(entry)
    if not entry or entry.queued or entry.capped then return false end
    local ts = Tradeskills("QueueSkillUp")
    if not ts then return false end
    local ok, done, why = pcall(ts.QueueSkillUp, ts, entry.recipeID)
    if not ok or not done then
        local name = ns.Jobs and ns.Jobs.ItemName(entry.itemID, entry.name) or tostring(entry.name)
        ns.Print(L.Format("couldn't queue %s: %s.", name, tostring(ok and why or L["the game said no"])))
        return false
    end
    entry.queued = true
    if ns.Jobs then ns.Jobs:Changed() end
    if ns.UI and ns.UI.Refresh then ns.UI:Refresh(true) end
    return true
end

ns.RegisterCommand("skillup", L["show the cheapest skill-up for each profession in Jobs (on|off)"], function(rest)
    local word = (rest or ""):lower():match("^%s*(%a+)")
    if word ~= "on" and word ~= "off" then word = SkillUp:IsOn() and "off" or "on" end
    SkillUp:SetOn(word == "on")
    ns.Print(word == "on" and L["Butler will show your cheapest skill-up in Jobs."]
        or L["Butler won't show your cheapest skill-up anymore."])
    if ns.SettingsUI and ns.SettingsUI.Refresh then ns.SettingsUI:Refresh() end
end)
