-- Blackthornes Butler -- Logic/Jobs.lua
-- Jobs on other characters: a step list across the player's characters
-- for Tradeskills' craft queue (the owner asked 2026-10-11: "if you need
-- to log on another character to do a step ... such as now you need to go
-- craft Medium Leather on another then send back").
--
-- Addons can't pick a character: they don't run on the character list. So
-- Butler does the rest. The window's first group, Jobs, lists what the
-- character playing has to do for the queue (craft this, mail that to
-- whom), each craft with a Craft button, and one line for each other
-- character with work waiting, the next one first. A Log out button on
-- the next one's line takes the player to the character list to switch.
-- Logging in on a character with a job brings the window up on its steps,
-- and once the last one here is done Butler says who is next.
--
-- Tradeskills keeps the queue and works out every step, inside a pcall,
-- read only (its Logic/Butler.lua):
--
--   _G.BlackthornesTS.Butler:Jobs()            -- one entry per character
--   _G.BlackthornesTS.Butler:Craft(recipeID)   -- from Butler's click
--
-- Without Tradeskills there are no jobs and nothing shows.
--
-- What is never done:
--   * Craft, mail or log out for the player: each is their own click.
--     Craft starts the queued craft only when the profession window is
--     open (Tradeskills' Crafting:Start, which needs a real click), and
--     mail is still Fill mail at a mailbox, where the player presses Send.
--   * Log out from addon code: the button is a secure button running the
--     game's own /logout, as a macro would, hidden in combat.
--   * Shorten a name: characters are named first and last, in full.
--
-- Smooth play: the jobs are asked for only while the window draws them,
-- again only when the bags moved (Bags.version, itself read 0.2 s after a
-- burst) or the window opened (Jobs.version). Nothing runs on a timer
-- apart from the one look a few seconds after logging in.

local _, ns = ...
local L = ns.L

local Jobs = ns.NewModule("Jobs")

local Items = ns.Items

-- After logging in, how long before Butler looks for a job here: the
-- other addons read their saves and the bags first.
Jobs.LOGIN_DELAY = 5

-- Moves whenever the jobs should be asked for again.
Jobs.version = 0

local BUTTON_WIDTH = 90
local BUTTON_HEIGHT = 20

local function InCombat()
    return type(InCombatLockdown) == "function" and InCombatLockdown() and true or false
end

--- Tradeskills' Butler table when it is loaded and has `method`.
local function Tradeskills(method)
    local global = rawget(_G, "BlackthornesTS")
    if type(global) ~= "table" then return nil end
    local butler = rawget(global, "Butler")
    if type(butler) ~= "table" or type(butler[method]) ~= "function" then return nil end
    return butler
end

--------------------------------------------------------------------------------
-- Reading Tradeskills' answer
--------------------------------------------------------------------------------

local function Text(value)
    if type(value) == "string" and value ~= "" then return value end
    return nil
end

local function Count(value)
    value = tonumber(value)
    if value and value == value and value > 0 then return math.floor(value) end
    return nil
end

local function ItemList(list)
    local items = {}
    for _, item in ipairs(type(list) == "table" and list or {}) do
        local itemID = type(item) == "table" and Count(item.itemID)
        local count = type(item) == "table" and Count(item.count)
        if itemID and count then
            -- `vendor`: a vendor sells it (Tradeskills gives the copper for
            -- one, or true), so it is bought rather than waited for.
            local vendor = type(item) == "table" and (item.vendor == true or Count(item.vendor) ~= nil)
            items[#items + 1] = { itemID = itemID, count = count, from = Text(item.from),
                bank = Count(item.bank), vendor = vendor or nil }
        end
    end
    return items
end

--- One step, or nil when it is not one Butler can read.
local function CleanStep(step)
    if type(step) ~= "table" then return nil end
    if step.kind == "craft" then
        local recipeID = Count(step.recipeID)
        if not recipeID then return nil end
        local forNames = {}
        for _, name in ipairs(type(step.forNames) == "table" and step.forNames or {}) do
            if Text(name) then forNames[#forNames + 1] = name end
        end
        return {
            kind = "craft",
            recipeID = recipeID,
            itemID = Count(step.itemID),
            name = Text(step.name),
            count = Count(step.count) or Count(step.crafts) or 1,
            forNames = forNames,
            ready = step.ready == true,
            missing = ItemList(step.missing),
        }
    elseif step.kind == "mail" then
        local to = Text(step.to)
        local items = ItemList(step.items)
        if not to or #items == 0 then return nil end
        return { kind = "mail", to = to, items = items, crafts = step.crafts == true,
            forCraft = step.forCraft == true }
    elseif step.kind == "pickup" then
        -- Mail waiting in the character's mailbox (the owner, 2026-10-13:
        -- a mailbox visit for something sent to it goes up the list).
        local items = ItemList(step.items)
        if #items == 0 then return nil end
        return { kind = "pickup", items = items, forCraft = step.forCraft == true }
    elseif step.kind == "cooldown" then
        -- A profession cooldown that is up (a transmute, Mooncloth): Craft
        -- makes it when it has a recipe; an item (the Salt Shaker) is used
        -- by hand.
        local name = Text(step.name)
        if not name then return nil end
        return { kind = "cooldown", name = name, craft = Text(step.craft) or name,
            recipeID = Count(step.recipeID), itemID = Count(step.itemID), ready = true }
    end
    return nil
end

--- Do two names name the same character? Without regard to case or
--- spacing; a mail step to the character doing it is never kept.
function Jobs.SameName(a, b)
    if type(a) ~= "string" or type(b) ~= "string" then return false end
    local function Fold(text) return (text:gsub("%s+", " "):gsub("^ ", ""):gsub(" $", ""):lower()) end
    return Fold(a) == Fold(b)
end

--- What a character's crafts still need to get, as up to two steps:
--- "buy" for materials a vendor sells, "gather" for the rest (the auction
--- house or out in the world; the owner, 2026-10-13: "missing materials
--- too that need to be purchased or gathered"). Left out: what another
--- character holds (`from`, a mail step brings it), what a queued craft
--- makes (`made`), and what is already waiting in the mailbox.
function Jobs.GetSteps(steps, made)
    made = made or {}
    local inMail = {}
    for _, step in ipairs(steps) do
        if step.kind == "craft" and step.itemID then made[step.itemID] = made[step.itemID] or true end
        if step.kind == "pickup" then
            for _, item in ipairs(step.items) do inMail[item.itemID] = true end
        end
    end
    local lists = { buy = { items = {}, byID = {} }, gather = { items = {}, byID = {} } }
    for _, step in ipairs(steps) do
        if step.kind == "craft" then
            for _, need in ipairs(step.missing) do
                if not need.from and not made[need.itemID] and not inMail[need.itemID] then
                    local list = need.vendor and lists.buy or lists.gather
                    local item = list.byID[need.itemID]
                    if not item then
                        item = { itemID = need.itemID, count = 0 }
                        list.byID[need.itemID] = item
                        list.items[#list.items + 1] = item
                    end
                    item.count = item.count + need.count
                end
            end
        end
    end
    local found = {}
    for _, kind in ipairs({ "buy", "gather" }) do
        if #lists[kind].items > 0 then found[#found + 1] = { kind = kind, items = lists[kind].items } end
    end
    return found
end

--- A character's steps in the order to do them (the owner, 2026-10-13:
--- "collecting all vendor materials and subcrafts should go to the top"):
--- a mailbox visit first, then buying vendor materials, then buying or
--- gathering the other materials (`made`: item IDs any queued craft
--- makes, on any character's line, which are not got), then the crafts
--- that make parts another craft on the line still needs, deepest part
--- first, then the rest as Tradeskills gave them.
function Jobs.Order(steps, made)
    -- How many crafts down the line a craft's item goes: 0 for one that
    -- nothing here waits on.
    local wantedBy = {}
    for _, step in ipairs(steps) do
        if step.kind == "craft" then
            for _, need in ipairs(step.missing) do
                wantedBy[need.itemID] = wantedBy[need.itemID] or {}
                table.insert(wantedBy[need.itemID], step)
            end
        end
    end
    local depth, visiting = {}, {}
    local function Depth(step)
        if depth[step] then return depth[step] end
        if visiting[step] or not step.itemID then return 0 end
        visiting[step] = true
        local most = 0
        for _, user in ipairs(wantedBy[step.itemID] or {}) do
            if user ~= step then most = math.max(most, Depth(user) + 1) end
        end
        visiting[step] = nil
        depth[step] = most
        return most
    end

    local pickups, parts, rest = {}, {}, {}
    for index, step in ipairs(steps) do
        if step.kind == "pickup" then
            pickups[#pickups + 1] = step
        elseif step.kind == "craft" and Depth(step) > 0 then
            parts[#parts + 1] = { step = step, depth = depth[step], index = index }
        else
            rest[#rest + 1] = step
        end
    end
    table.sort(parts, function(a, b)
        if a.depth ~= b.depth then return a.depth > b.depth end
        return a.index < b.index
    end)

    local ordered = {}
    for _, step in ipairs(pickups) do ordered[#ordered + 1] = step end
    for _, get in ipairs(Jobs.GetSteps(steps, made)) do ordered[#ordered + 1] = get end
    for _, part in ipairs(parts) do ordered[#ordered + 1] = part.step end
    for _, step in ipairs(rest) do ordered[#ordered + 1] = step end
    return ordered
end

--- Tradeskills' list with anything of the wrong shape left out.
function Jobs.Clean(answer)
    local list, made = {}, {}
    for _, job in ipairs(type(answer) == "table" and answer or {}) do
        local name = type(job) == "table" and Text(job.name)
        if name then
            local steps = {}
            for _, step in ipairs(type(job.steps) == "table" and job.steps or {}) do
                local clean = CleanStep(step)
                -- Never a mail to the character doing it.
                if clean and not (clean.kind == "mail" and Jobs.SameName(clean.to, name)) then
                    steps[#steps + 1] = clean
                    if clean.kind == "craft" and clean.itemID then made[clean.itemID] = true end
                end
            end
            if #steps > 0 then
                list[#list + 1] = { name = name, isCurrent = job.isCurrent == true, steps = steps }
            end
        end
    end
    -- Ordered once every line is read, so a part another character makes
    -- is never sent out to be bought or gathered.
    for _, job in ipairs(list) do job.steps = Jobs.Order(job.steps, made) end
    return list
end

--- Every character's jobs, kept until the bags or Jobs.version move.
function Jobs:Read()
    local key = ("%d:%d"):format(ns.Bags and ns.Bags.version or 0, self.version)
    if self.readKey == key and self.list then return self.list end
    self.readKey = key

    local list = {}
    local ts = Tradeskills("Jobs")
    if ts then
        local ok, answer = pcall(ts.Jobs, ts)
        if ok then list = Jobs.Clean(answer) end
    end
    self.list = list
    self:Noticed()
    return list
end

--- Ask Tradeskills again on the next look (the window opened).
function Jobs:Changed()
    self.version = self.version + 1
end

--- Can the character do any of its steps now? A mail, a vendor run or
--- materials to buy or gather always can; a craft once it has what it takes.
function Jobs.Ready(job)
    for _, step in ipairs(job.steps) do
        if step.kind == "mail" or step.kind == "pickup" or step.kind == "buy" or step.kind == "gather"
            or step.kind == "cooldown"
            or step.ready then return true end
    end
    return false
end

--- The character playing's jobs (`here`), the character to switch to next
--- (`nextJob`: the first other one that can get on with a step, else the
--- first), and every other one with work (`others`, next first).
--- `goFirst` when nothing here can be done yet and the next one can (the
--- owner, 2026-10-11: a sub-craft whose materials are on hand goes to the
--- top), so the window and the gold Log out send the player there first.
function Jobs:Plan()
    local here, others = nil, {}
    local errands = ns.Errands
    for _, job in ipairs(self:Read()) do
        if job.isCurrent or (errands and errands.IsMe and errands:IsMe(job.name)) then
            -- The character playing, under any record of it, is never one
            -- to log out for (a player was told to, 2026-10-11).
            here = here or { name = job.name, isCurrent = true, steps = {} }
            for _, step in ipairs(job.steps) do here.steps[#here.steps + 1] = step end
        else
            others[#others + 1] = job
        end
    end
    -- Next: one that can get on with it. First one whose mail or craft
    -- unblocks a craft here, then one with mail waiting for its crafts, then one with
    -- any mail waiting (the owner, 2026-10-13: a mailbox visit for
    -- something sent to it goes up the list).
    -- What the crafts here still wait on, so a character who can make one
    -- of those parts now goes next (the owner, 2026-10-13: subcrafts go
    -- to the top).
    local wantedHere = {}
    for _, step in ipairs(here and here.steps or {}) do
        if step.kind == "craft" then
            for _, need in ipairs(step.missing) do wantedHere[need.itemID] = true end
        end
    end
    local function Rank(job)
        local rank = 0
        for _, step in ipairs(job.steps) do
            if step.kind == "mail" and step.forCraft and here and step.to == here.name then return 3 end
            if step.kind == "craft" and step.ready and step.itemID and wantedHere[step.itemID] then return 3 end
            if step.kind == "pickup" then rank = math.max(rank, step.forCraft and 2 or 1) end
        end
        return rank
    end
    local nextJob, nextIndex, nextRank
    for index, job in ipairs(others) do
        if Jobs.Ready(job) then
            local rank = Rank(job)
            if not nextJob or rank > nextRank then
                nextJob, nextIndex, nextRank = job, index, rank
            end
        end
    end
    if nextJob then
        table.remove(others, nextIndex)
        table.insert(others, 1, nextJob)
    end
    local goFirst = here ~= nil and nextJob ~= nil and not Jobs.Ready(here)
    return { here = here, nextJob = nextJob or others[1], others = others, goFirst = goFirst }
end

--------------------------------------------------------------------------------
-- Words
--------------------------------------------------------------------------------

--- An item's name, asked of the client (and loaded when it doesn't know
--- it yet), else the name Tradeskills gave, else "Item N".
function Jobs.ItemName(itemID, fallback)
    if itemID then
        local name = Items.Call({ "C_Item.GetItemNameByID", "GetItemInfo" }, itemID)
        if Text(name) then return name end
        Items:RequestLoad(itemID)
    end
    return fallback or L.Format("Item %s", tostring(itemID))
end

local function ItemIcon(itemID)
    if not itemID then return nil end
    local icon = Items.Call({ "C_Item.GetItemIconByID", "GetItemIcon" }, itemID)
    return icon
end

--- "20 Medium Leather", or "Linen Bag" for one.
local function Amount(count, name)
    if count == 1 then return name end
    return ("%d %s"):format(count, name)
end

local function JoinNames(names)
    if #names <= 1 then return names[1] or "" end
    if #names == 2 then return L.Format("%s and %s", names[1], names[2]) end
    return L.Format("%s and %s", table.concat(names, ", ", 1, #names - 1), names[#names])
end

--- "20 Medium Leather", "20 Medium Leather and 3 Light Leather", or the
--- first and how many more.
function Jobs.ItemsText(items)
    local first = items[1]
    if not first then return "" end
    local text = Amount(first.count, Jobs.ItemName(first.itemID))
    if #items == 2 then
        return L.Format("%s and %s", text, Amount(items[2].count, Jobs.ItemName(items[2].itemID)))
    elseif #items > 2 then
        return L.Format("%s and %d more", text, #items - 1)
    end
    return text
end

--- A step as a title and a line under it.
function Jobs.StepText(step)
    if step.kind == "cooldown" then
        if step.recipeID then
            return L.Format("%s is ready", step.name),
                L.Format("Your %s cooldown is up. Open the profession and click Craft to make %s.", step.name, step.craft)
        end
        return L.Format("%s is ready", step.name),
            L.Format("Your %s cooldown is up. Use it from your bags.", step.name)
    end
    if step.kind == "pickup" then
        local what = Jobs.ItemsText(step.items)
        if step.forCraft then
            return L["Get your mail"],
                L.Format("%s for your crafts is in your mailbox. Take it out before you craft.", what)
        end
        return L["Get your mail"], L.Format("%s was sent to you and is waiting in your mailbox.", what)
    end
    if step.kind == "buy" then
        return L["Buy from a vendor"],
            L.Format("%s for your crafts. At a vendor that sells them, Tradeskills' Buy materials button gets them.",
                Jobs.ItemsText(step.items))
    end
    if step.kind == "gather" then
        return L["Buy or gather"],
            L.Format("%s for your crafts. Buy it on the auction house or gather it.", Jobs.ItemsText(step.items))
    end
    if step.kind == "mail" then
        local what = Jobs.ItemsText(step.items)
        -- What is in the bank has to come out before Fill mail can see it.
        local banked = {}
        for _, item in ipairs(step.items) do
            if item.bank then banked[#banked + 1] = { itemID = item.itemID, count = math.min(item.bank, item.count) } end
        end
        if #banked > 0 then
            return L.Format("Mail to %s", step.to),
                L.Format("%s. Take %s out of the bank first, then at a mailbox Fill mail adds it.",
                    what, Jobs.ItemsText(banked))
        end
        return L.Format("Mail to %s", step.to),
            L.Format("%s. At a mailbox, Fill mail adds it.", what)
    end
    local title = L.Format("Craft %s", Amount(step.count, Jobs.ItemName(step.itemID, step.name)))
    local detail
    if not step.ready and step.missing[1] then
        detail = L.Format("Still needs %s first.", Jobs.ItemsText(step.missing))
        local from = step.missing[1].from
        if from then detail = L.Format("%s %s has it.", detail, from) end
    elseif #step.forNames > 0 then
        detail = L.Format("For %s. Mail it over once it's made.", JoinNames(step.forNames))
    else
        detail = L["For your own queue."]
    end
    return title, detail
end

--- A step in one line, for the line about another character.
function Jobs.Short(step)
    if step.kind == "cooldown" then
        return L.Format("use the %s cooldown, it's ready", step.name)
    end
    if step.kind == "pickup" then
        return L.Format("get %s from the mailbox", Jobs.ItemsText(step.items))
    end
    if step.kind == "buy" then
        return L.Format("buy %s from a vendor", Jobs.ItemsText(step.items))
    end
    if step.kind == "gather" then
        return L.Format("buy or gather %s", Jobs.ItemsText(step.items))
    end
    if step.kind == "mail" then
        return L.Format("mail %s to %s", Jobs.ItemsText(step.items), step.to)
    end
    local text = L.Format("craft %s", Amount(step.count, Jobs.ItemName(step.itemID, step.name)))
    if #step.forNames > 0 then
        text = L.Format("%s, then mail it to %s", text, JoinNames(step.forNames))
    end
    return text
end

--- What another character has to do: its first step and how many more.
function Jobs.Summary(job)
    local first = job.steps[1]
    local text = Jobs.Short(first)
    text = text:sub(1, 1):upper() .. text:sub(2)
    if #job.steps > 1 then
        text = #job.steps == 2 and L.Format("%s, and %d more step", text, #job.steps - 1)
            or L.Format("%s, and %d more steps", text, #job.steps - 1)
    end
    if not Jobs.Ready(job) then return L.Format("%s. Waiting on materials.", text) end
    return text .. "."
end

function Jobs.Icon(step)
    if step.kind == "mail" or step.kind == "pickup" then return [[Interface\Icons\INV_Letter_15]] end
    if step.kind == "buy" or step.kind == "gather" then
        return ItemIcon(step.items[1] and step.items[1].itemID) or [[Interface\Icons\INV_Misc_Coin_01]]
    end
    if step.kind == "cooldown" then
        return ItemIcon(step.itemID) or [[Interface\Icons\INV_Misc_PocketWatch_01]]
    end
    return ItemIcon(step.itemID) or [[Interface\Icons\Trade_LeatherWorking]]
end

--------------------------------------------------------------------------------
-- The window's rows
--------------------------------------------------------------------------------

--- The Jobs group's rows: this character's steps, then a line for each
--- other character with work, the next one first. Empty with no jobs.
function Jobs:Lines()
    local plan = self:Plan()
    -- Only spells to train now lead; the rest waits under Later.
    local rows = {}
    for _, row in ipairs(self:TrainingLines()) do
        if row.type == "train" then rows[#rows + 1] = row end
    end
    -- Nothing here can be done yet: the one who can goes first.
    if plan.goFirst then
        rows[#rows + 1] = { type = "jobnext", job = plan.nextJob, isNext = true, isFirst = true }
    end
    for _, step in ipairs(plan.here and plan.here.steps or {}) do
        rows[#rows + 1] = { type = "job", step = step }
    end
    for index, job in ipairs(plan.others) do
        if not (plan.goFirst and index == 1) then
            rows[#rows + 1] = { type = "jobnext", job = job, isNext = index == 1 }
        end
    end
    return rows
end

--- The Later group's rows, at the foot of the list by Gold goals (the
--- owner, 2026-10-13: what can be done now goes at the top): spells at
--- the next level and other characters' spells to train.
function Jobs:LaterLines()
    local rows = {}
    for _, row in ipairs(self:TrainingLines()) do
        if row.type ~= "train" then rows[#rows + 1] = row end
    end
    return rows
end

--- Class spells to train lead the group (Logic/ClassTraining.lua): what
--- can be trained now, what comes at the next level, and a line for each
--- other character with spells waiting.
function Jobs:TrainingLines()
    local training = ns.ClassTraining
    local rows = {}
    if not (training and training:IsOn()) then return rows end
    local plan = training:Plan()
    if #plan.ready > 0 then
        rows[#rows + 1] = { type = "train", plan = plan }
    end
    if #plan.next > 0 then
        rows[#rows + 1] = { type = "trainnext", plan = plan }
    end
    for _, other in ipairs(training:Others()) do
        if not (ns.Errands and ns.Errands.IsMe and ns.Errands:IsMe(other.name)) then
            rows[#rows + 1] = { type = "trainalt", other = other }
        end
    end
    return rows
end

--------------------------------------------------------------------------------
-- Craft
--------------------------------------------------------------------------------

--- A Craft click on a step: Tradeskills starts it with the profession
--- open, else opens its Queue tab, where the Open button opens it.
function Jobs:Craft(step)
    if not (step and (step.kind == "craft" or (step.kind == "cooldown" and step.recipeID))) then return false end
    if InCombat() then
        ns.Print(L["crafting waits until the fight is over."])
        return false
    end
    local ts = Tradeskills("Craft")
    if not ts then
        ns.Print(L["crafting from here needs Blackthornes Tradeskills."])
        return false
    end
    local name = step.kind == "cooldown" and step.craft or Jobs.ItemName(step.itemID, step.name)
    local ok, done, why = pcall(ts.Craft, ts, step.recipeID)
    if not ok then
        ns.Print(L.Format("couldn't start %s.", name))
        return false
    end
    if done and why == "opened" then
        ns.Print(L.Format("open your profession for %s: Tradeskills' Open button is on its Queue tab. Then click Craft again.", name))
    elseif not done then
        ns.Print(L.Format("can't craft %s yet: %s.", name, tostring(why or L["the game said no"])))
    end
    return done == true
end

--------------------------------------------------------------------------------
-- Log out
--------------------------------------------------------------------------------

--- The Log out button: the game's own /logout, run by the player's click
--- on a secure button as a macro would (addon code may not log out by
--- itself). It sits on the row of the character to switch to, where a
--- craft's Craft button sits (the owner asked 2026-10-11: "the log out
--- button should be next to the step that needs the logout").
function Jobs:CreateLogout()
    if self.button then return self.button end
    local button = ns.Widgets.CreateButton(UIParent, L["Log out"], nil, {
        name = "BlackthornesButlerLogout", template = "SecureActionButtonTemplate",
        width = BUTTON_WIDTH, height = BUTTON_HEIGHT, primary = true,
    })
    button:Hide()
    button:SetFrameStrata("FULLSCREEN_DIALOG")
    button:SetFrameLevel(10)
    button:RegisterForClicks("AnyUp")
    button:SetAttribute("useOnKeyDown", false)
    button:SetAttribute("type", "macro")
    button:SetAttribute("macrotext", "/logout")
    button:HookScript("OnEnter", function(frame)
        if frame.tooltipText then
            GameTooltip:SetOwner(frame, "ANCHOR_BOTTOM")
            GameTooltip:SetText(frame.tooltipText, 1, 1, 1, 1, true)
            GameTooltip:Show()
        end
    end)
    button:HookScript("OnLeave", function() GameTooltip:Hide() end)
    self.button = button
    return button
end

local function Tip(nextJob)
    return L.Format("Log out for %s. %s\nLogs you out to the character list, where you pick %s. Addons can't pick a character for you.",
        nextJob.name, Jobs.Summary(nextJob), nextJob.name)
end

--- Everything here is done, or can't be until the next character has done
--- its part: the footer says so.
function Jobs:DoneHere()
    local plan = self:Plan()
    return plan.nextJob ~= nil and (plan.here == nil or plan.goFirst == true)
end

--- The list row showing the next character ("First:" or "Next:"), when it
--- is on screen.
function Jobs.NextRow(list)
    for _, row in ipairs((list and list.rows) or {}) do
        local data = row.data
        if row:IsShown() and data and data.type == "jobnext" and data.isNext then return row end
    end
end

--- Put the Log out button on the next character's row, while it is on
--- screen. Placed by screen position, as the Sell button is, so the window
--- stays free to move and close in combat; hidden in combat, while the
--- window moves and in All characters. Called each time the list is drawn
--- or scrolled, so it follows its row.
function Jobs:UpdateLogout()
    if self.fighting or InCombat() then return end
    local ui = ns.UI
    local list = ui and ui.list
    local show = list and ui:IsShown() and not ui.dragging and ui.view ~= "all"
    local row = show and Jobs.NextRow(list)
    local right, top, bottom = row and row:GetRight(), row and row:GetTop(), row and row:GetBottom()
    if not (right and top and bottom) then
        if self.button then self.button:Hide() end
        return
    end
    local button = self:CreateLogout()
    button.tooltipText = Tip(row.data.job)
    local scale = (row:GetEffectiveScale() or 1) / (UIParent:GetEffectiveScale() or 1)
    button:SetScale(scale)
    button:ClearAllPoints()
    button:SetPoint("RIGHT", UIParent, "BOTTOMLEFT", right - 8, (top + bottom) / 2)
    button:Show()
end

--------------------------------------------------------------------------------
-- Speaking up
--------------------------------------------------------------------------------

--- After a read: once the last step here is done and another character
--- has work, say who is next (once each time it happens).
function Jobs:Noticed()
    local plan = self:Plan()
    local hasHere = plan.here ~= nil
    if self.hadHere and not hasHere and plan.nextJob then
        ns.Print(L.Format("that's everything here. Next: %s. %s Log out on their line in the Butler window to switch.",
            plan.nextJob.name, Jobs.Summary(plan.nextJob)))
    end
    self.hadHere = hasHere
end

--- A few seconds after logging in: a character with a job brings the
--- window up on its steps ("Jobs at login", on unless unticked).
function Jobs:Greet()
    if InCombat() or not (ns.db and ns.db.jobsAtLogin ~= false) then return end
    self:Changed()
    local plan = self:Plan()
    local first = plan.here and plan.here.steps[1]
    if not first then return end
    ns.Print(L.Format("a job on this character: %s.", Jobs.Short(first)))
    if ns.UI and not ns.UI:IsShown() then ns.UI:Show("bags") end
end

--- Every character's jobs in chat.
function Jobs:Report()
    local list = self:Read()
    if not Tradeskills("Jobs") then
        ns.Print(L["jobs come from Blackthornes Tradeskills' craft queue, and it isn't loaded."])
        return
    end
    if #list == 0 then
        ns.Print(L["no jobs: nothing in the craft queue needs a character."])
        return
    end
    for _, job in ipairs(list) do
        ns.Print(job.isCurrent and L.Format("%s (you):", job.name) or (job.name .. ":"))
        for _, step in ipairs(job.steps) do
            ns.PrintRaw("   " .. Jobs.Short(step))
        end
    end
end

function Jobs:ProbeText()
    local secure
    if type(issecurevariable) == "function" then
        local ok, isSecure = pcall(issecurevariable, "Logout")
        secure = ok and isSecure
    end
    return ("Tradeskills jobs %s, Logout %s%s, /logout %s"):format(
        Tradeskills("Jobs") and "yes" or "no",
        type(rawget(_G, "Logout")) == "function" and "found" or "missing",
        secure and " (secure)" or "",
        rawget(_G, "SLASH_LOGOUT1") and "found" or "not found")
end

--------------------------------------------------------------------------------
-- Events
--------------------------------------------------------------------------------

--- At a class trainer with spells to train, the window comes up on them
--- (Train all is on their row) and goes when the trainer closes.
function Jobs:AtTrainer(open)
    local ui, training = ns.UI, ns.ClassTraining
    if not ui then return end
    if not open then
        if ui.openedFor == "trainer" then return ui:LeftPlace("trainer") end
        if ui:IsShown() then ui:Refresh(true) end
        return
    end
    if ui:IsShown() then return ui:Refresh(true) end
    if not (training:IsOn() and training.atClassTrainer and #training:Plan().ready > 0) then return end
    ui:Show("bags")
    ui.openedFor = "trainer"
end

function Jobs:OnEnable()
    local training = ns.ClassTraining
    if training then
        training.OnChanged = function()
            if ns.UI and ns.UI.IsShown and ns.UI:IsShown() then ns.UI:Refresh() end
        end
        training.OnTrainer = function(open) Jobs:AtTrainer(open) end
    end
    ns.RegisterEvent(self, "PLAYER_ENTERING_WORLD", function(_, _, isInitialLogin)
        if isInitialLogin and C_Timer and C_Timer.After then
            C_Timer.After(Jobs.LOGIN_DELAY, function() Jobs:Greet() end)
        end
    end)
    -- Just before combat locks secure frames: the button can still hide.
    ns.RegisterEvent(self, "PLAYER_REGEN_DISABLED", function()
        Jobs.fighting = true
        if Jobs.button then Jobs.button:Hide() end
    end)
    ns.RegisterEvent(self, "PLAYER_REGEN_ENABLED", function()
        Jobs.fighting = false
        if ns.UI and ns.UI.frame then ns.UI:FootRoom() end
    end)
end

ns.RegisterCommand("jobs", L["list every character's jobs for the craft queue"], function()
    Jobs:Report()
end)

ns.RegisterCommand("joblogin", L["turn bringing the window up for a job at login on or off"], function()
    ns.db.jobsAtLogin = ns.db.jobsAtLogin == false
    ns.Print(ns.db.jobsAtLogin and L["logging in on a character with a job brings the Butler window up."]
        or L["Butler no longer comes up at login for a job."])
end)
