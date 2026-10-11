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
-- character with work waiting, the next one first. A Log out button in
-- the window's header takes the player to the character list to switch.
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

local Jobs = ns.NewModule("Jobs")

local Items = ns.Items

-- After logging in, how long before Butler looks for a job here: the
-- other addons read their saves and the bags first.
Jobs.LOGIN_DELAY = 5

-- Moves whenever the jobs should be asked for again.
Jobs.version = 0

local BUTTON_WIDTH = 90
local BUTTON_HEIGHT = 20
-- The gold one at the foot, in Fill mail's place.
local FOOT_WIDTH = 180
local FOOT_HEIGHT = 24

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
            items[#items + 1] = { itemID = itemID, count = count, from = Text(item.from) }
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
    end
    return nil
end

--- Tradeskills' list with anything of the wrong shape left out.
function Jobs.Clean(answer)
    local list = {}
    for _, job in ipairs(type(answer) == "table" and answer or {}) do
        local name = type(job) == "table" and Text(job.name)
        if name then
            local steps = {}
            for _, step in ipairs(type(job.steps) == "table" and job.steps or {}) do
                steps[#steps + 1] = CleanStep(step)
            end
            if #steps > 0 then
                list[#list + 1] = { name = name, isCurrent = job.isCurrent == true, steps = steps }
            end
        end
    end
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

--- Can the character do any of its steps now? A mail always can; a craft
--- once it has what it takes.
function Jobs.Ready(job)
    for _, step in ipairs(job.steps) do
        if step.kind == "mail" or step.ready then return true end
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
    for _, job in ipairs(self:Read()) do
        if job.isCurrent then
            here = here or job
        else
            others[#others + 1] = job
        end
    end
    local nextJob
    for index, job in ipairs(others) do
        if Jobs.Ready(job) then
            nextJob = job
            table.remove(others, index)
            table.insert(others, 1, job)
            break
        end
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
    return fallback or ("Item %s"):format(tostring(itemID))
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
    if #names == 2 then return names[1] .. " and " .. names[2] end
    return table.concat(names, ", ", 1, #names - 1) .. " and " .. names[#names]
end

--- "20 Medium Leather", "20 Medium Leather and 3 Light Leather", or the
--- first and how many more.
function Jobs.ItemsText(items)
    local first = items[1]
    if not first then return "" end
    local text = Amount(first.count, Jobs.ItemName(first.itemID))
    if #items == 2 then
        return text .. " and " .. Amount(items[2].count, Jobs.ItemName(items[2].itemID))
    elseif #items > 2 then
        return ("%s and %d more"):format(text, #items - 1)
    end
    return text
end

--- A step as a title and a line under it.
function Jobs.StepText(step)
    if step.kind == "mail" then
        local what = Jobs.ItemsText(step.items)
        return ("Mail to %s"):format(step.to),
            ("%s. At a mailbox, Fill mail puts it in for you."):format(what)
    end
    local title = ("Craft %s"):format(Amount(step.count, Jobs.ItemName(step.itemID, step.name)))
    local detail
    if not step.ready and step.missing[1] then
        detail = ("Still needs %s first."):format(Jobs.ItemsText(step.missing))
        local from = step.missing[1].from
        if from then detail = ("%s %s has it."):format(detail, from) end
    elseif #step.forNames > 0 then
        detail = ("For %s. Mail it over once it's made."):format(JoinNames(step.forNames))
    else
        detail = "For your own queue."
    end
    return title, detail
end

--- A step in one line, for the line about another character.
function Jobs.Short(step)
    if step.kind == "mail" then
        return ("mail %s to %s"):format(Jobs.ItemsText(step.items), step.to)
    end
    local text = ("craft %s"):format(Amount(step.count, Jobs.ItemName(step.itemID, step.name)))
    if #step.forNames > 0 then
        text = ("%s, then mail it to %s"):format(text, JoinNames(step.forNames))
    end
    return text
end

--- What another character has to do: its first step and how many more.
function Jobs.Summary(job)
    local first = job.steps[1]
    local text = Jobs.Short(first)
    text = text:sub(1, 1):upper() .. text:sub(2)
    if #job.steps > 1 then
        text = ("%s, and %d more %s"):format(text, #job.steps - 1, #job.steps == 2 and "step" or "steps")
    end
    if not Jobs.Ready(job) then text = text .. ". Waiting on materials" end
    return text .. "."
end

function Jobs.Icon(step)
    if step.kind == "mail" then return [[Interface\Icons\INV_Letter_15]] end
    return ItemIcon(step.itemID) or [[Interface\Icons\Trade_LeatherWorking]]
end

--------------------------------------------------------------------------------
-- The window's rows
--------------------------------------------------------------------------------

--- The Jobs group's rows: this character's steps, then a line for each
--- other character with work, the next one first. Empty with no jobs.
function Jobs:Lines()
    local plan = self:Plan()
    local rows = {}
    -- Nothing here can be done yet: the one who can goes first.
    if plan.goFirst then
        rows[1] = { type = "jobnext", job = plan.nextJob, isNext = true, isFirst = true }
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

--------------------------------------------------------------------------------
-- Craft
--------------------------------------------------------------------------------

--- A Craft click on a step: Tradeskills starts it with the profession
--- open, else opens its Queue tab, where the Open button opens it.
function Jobs:Craft(step)
    if not (step and step.kind == "craft") then return false end
    if InCombat() then
        ns.Print("crafting waits until the fight is over.")
        return false
    end
    local ts = Tradeskills("Craft")
    if not ts then
        ns.Print("crafting from here needs Blackthornes Tradeskills.")
        return false
    end
    local name = Jobs.ItemName(step.itemID, step.name)
    local ok, done, why = pcall(ts.Craft, ts, step.recipeID)
    if not ok then
        ns.Print(("couldn't start %s."):format(name))
        return false
    end
    if done and why == "opened" then
        ns.Print(("open your profession for %s: Tradeskills' Open button is on its Queue tab. Then click Craft again."):format(name))
    elseif not done then
        ns.Print(("can't craft %s yet: %s."):format(name, tostring(why or "the game said no")))
    end
    return done == true
end

--------------------------------------------------------------------------------
-- Log out
--------------------------------------------------------------------------------

--- A Log out button: the game's own /logout, run by the player's click on
--- a secure button as a macro would (addon code may not log out by
--- itself). Two are made: the small one in the header and the big gold one
--- at the foot.
local function LogoutButton(name, label, opts)
    local button = ns.Widgets.CreateButton(UIParent, label, nil, {
        name = name, template = "SecureActionButtonTemplate",
        width = opts.width, height = opts.height, primary = opts.primary,
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
    return button
end

function Jobs:CreateLogout()
    if not self.button then
        self.button = LogoutButton("BlackthornesButlerLogout", "Log out",
            { width = BUTTON_WIDTH, height = BUTTON_HEIGHT })
    end
    return self.button
end

function Jobs:CreateFootLogout()
    if not self.footButton then
        self.footButton = LogoutButton("BlackthornesButlerLogoutFoot", "Log out",
            { width = FOOT_WIDTH, height = FOOT_HEIGHT, primary = true })
    end
    return self.footButton
end

local function Tip(nextJob)
    return ("Next: %s. %s\nLogs you out to the character list, where you pick %s. Addons can't pick a character for you."):format(
        nextJob.name, Jobs.Summary(nextJob), nextJob.name)
end

--- Once everything here is done (or nothing here can be done until the
--- next character has done its part), the big gold Log out button takes the
--- place Fill mail had at the window's foot (the owner liked it,
--- 2026-10-11): fill, Send, then one more click in the same spot to
--- switch. Only while nothing else sits at the foot (`room` is how wide
--- the Sell or errand buttons are) and another character has work.
-- @return how wide it is when shown, else 0
function Jobs:UpdateFoot(room)
    if self.fighting or InCombat() then return 0 end
    local ui = ns.UI
    local window = ui and ui.frame
    local show = window and ui:IsShown() and not ui.dragging and ui.view ~= "all" and (room or 0) == 0
    local plan = show and self:Plan()
    local nextJob = plan and (not plan.here or plan.goFirst) and plan.nextJob
    local right, bottom = window and window:GetRight(), window and window:GetBottom()
    if not (nextJob and right and bottom) then
        self.footShown = false
        if self.footButton then self.footButton:Hide() end
        return 0
    end
    local button = self:CreateFootLogout()
    button:SetText(("Log out for %s"):format(nextJob.name))
    button.tooltipText = Tip(nextJob)
    local scale = (window:GetEffectiveScale() or 1) / (UIParent:GetEffectiveScale() or 1)
    button:SetScale(scale)
    button:ClearAllPoints()
    button:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMLEFT", right - ui.SELL_INSET_X, bottom + ui.SELL_INSET_Y)
    button:Show()
    self.footShown = true
    return button:GetWidth() or FOOT_WIDTH
end

--- Show the Log out button in the window's header, left of All characters,
--- while another character has work waiting. Placed by screen position,
--- as the Sell button is, so the window stays free to move and close in
--- combat; hidden in combat, while the window moves and in All characters.
function Jobs:UpdateLogout()
    if self.fighting or InCombat() then return end
    local ui = ns.UI
    local anchor = ui and ui.viewButton
    local show = anchor and ui:IsShown() and not ui.dragging and ui.view ~= "all"
    local plan = show and self:Plan()
    -- The gold one at the foot says it already.
    local nextJob = plan and not self.footShown and plan.nextJob
    if not nextJob then
        if self.button then self.button:Hide() end
        return
    end

    local button = self:CreateLogout()
    local left, bottom = anchor:GetLeft(), anchor:GetBottom()
    if not (left and bottom) then
        button:Hide()
        return
    end
    button.tooltipText = Tip(nextJob)
    local scale = (ui.frame:GetEffectiveScale() or 1) / (UIParent:GetEffectiveScale() or 1)
    button:SetScale(scale)
    button:ClearAllPoints()
    button:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMLEFT", left - 6, bottom)
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
        ns.Print(("that's everything here. Next: %s. %s Log out at the foot of the Butler window to switch."):format(
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
    ns.Print(("a job for you here: %s."):format(Jobs.Short(first)))
    if ns.UI and not ns.UI:IsShown() then ns.UI:Show("bags") end
end

--- Every character's jobs in chat.
function Jobs:Report()
    local list = self:Read()
    if not Tradeskills("Jobs") then
        ns.Print("jobs come from Blackthornes Tradeskills' craft queue, and it isn't loaded.")
        return
    end
    if #list == 0 then
        ns.Print("no jobs: nothing in the craft queue needs a character.")
        return
    end
    for _, job in ipairs(list) do
        ns.Print(("%s%s:"):format(job.name, job.isCurrent and " (you)" or ""))
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

function Jobs:OnEnable()
    ns.RegisterEvent(self, "PLAYER_ENTERING_WORLD", function(_, _, isInitialLogin)
        if isInitialLogin and C_Timer and C_Timer.After then
            C_Timer.After(Jobs.LOGIN_DELAY, function() Jobs:Greet() end)
        end
    end)
    -- Just before combat locks secure frames: the button can still hide.
    ns.RegisterEvent(self, "PLAYER_REGEN_DISABLED", function()
        Jobs.fighting = true
        if Jobs.button then Jobs.button:Hide() end
        if Jobs.footButton then Jobs.footButton:Hide() end
        Jobs.footShown = false
    end)
    ns.RegisterEvent(self, "PLAYER_REGEN_ENABLED", function()
        Jobs.fighting = false
        if ns.UI and ns.UI.frame then ns.UI:FootRoom() end
    end)
end

ns.RegisterCommand("jobs", "list every character's jobs for the craft queue", function()
    Jobs:Report()
end)

ns.RegisterCommand("joblogin", "turn bringing the window up for a job at login on or off", function()
    ns.db.jobsAtLogin = ns.db.jobsAtLogin == false
    ns.Print(ns.db.jobsAtLogin and "logging in on a character with a job brings the Butler window up."
        or "Butler no longer comes up at login for a job.")
end)
