-- Blackthornes Butler -- UI/RightNow.lua
-- The Right Now card (the owner said build it, 2026-11-26, from a mockup):
-- the top of the Butler window says what to do here, in order, at most
-- four steps, each with its button. A lit dot can be done here; a dim one
-- waits for another place (a vendor, a mailbox). It changes with where the
-- player stands.
--
-- Off unless ticked: "Right Now Card:" on the WINDOWS page, saved account
-- wide as rightNow (never rename it). Nothing new is scanned: every step
-- reads what Butler already worked out (Verdicts:Groups, Errands, Jobs'
-- vendor offer, class training, free space). The card is built with the
-- window's lines (UI:Lines), so it is drawn again only when they are, after
-- Verdicts:Redraw or Errands:Update; never on a timer.
--
-- Buttons are the ones the groups use: the secure Sell button and Move to
-- bank dock on their step's line (UI:DockRow), Fill Mail sits on the
-- step for that character (UI:PlaceMail), and Buy and Train call the same
-- functions as the Jobs lines. While the card has a step, the groups below
-- start folded; one the player opens stays open.

local _, ns = ...
local L = ns.L

local RightNow = ns.NewModule("RightNow")

-- The most steps the card shows.
RightNow.MOST = 4

function RightNow:IsOn()
    return ns.db ~= nil and ns.db.rightNow == true
end

local function Plural(count, one, many)
    return L.Format("%d %s", count, count == 1 and one or many)
end

local function Names(rows, most)
    local names = {}
    for index, row in ipairs(rows) do
        if index > most then break end
        names[#names + 1] = row
    end
    return table.concat(names, ", ")
end

--- The steps, lit ones first, at most RightNow.MOST:
--- { type = "now", lit, title, detail, dock, mailTo, action = { label, run } }.
function RightNow:Steps()
    if not self:IsOn() then return {} end
    local Items = ns.Items
    local lit, dim = {}, {}
    local function Add(step)
        step.type = "now"
        if step.lit then lit[#lit + 1] = step else dim[#dim + 1] = step end
    end

    local atVendor = ns.Selling and ns.Selling.merchantOpen == true
    local errands = ns.Errands
    local atMailbox = errands and errands.mailOpen == true
    local atBank = errands and errands.bankOpen == true

    -- Sell: at a vendor, the secure Sell button sits on this line.
    local sell = ns.Verdicts:Group("sell")
    if sell and sell.count > 0 then
        local title = sell.count == 1 and L["Sell 1 item"] or L.Format("Sell %d items", sell.count)
        if atVendor then
            Add({ key = "sell", lit = true, title = title, dock = "sell",
                detail = L.Format("Worth %s. They stay in Buyback.", Items.FormatMoney(sell.worth or 0)) })
        else
            Add({ key = "sell", lit = false, title = title, detail = L["At the next vendor."] })
        end
    end

    -- What the craft queue needs from this vendor (Jobs' offer, already read).
    local offer = atVendor and ns.Jobs and ns.Jobs.offer
    if type(offer) == "table" and (offer.count or 0) > 0 and not offer.buying then
        local first = offer.items[1]
        local title
        if offer.count == 1 and first then
            title = L.Format("Buy %d %s", first.count, ns.Jobs.ItemName(first.itemID, ""))
        else
            title = L.Format("Buy %d things for your crafts", offer.count)
        end
        Add({ key = "buy", lit = true, title = title,
            detail = L.Format("For your craft queue. %s in all.", Items.FormatMoney(offer.cost or 0)),
            action = { label = L["Buy"], run = function() ns.Jobs:BuyAtVendor() end } })
    end

    -- Mail: Fill Mail on each character's step at a mailbox.
    local recipients = errands and errands:Recipients() or {}
    for _, recipient in ipairs(recipients) do
        local names = {}
        for _, item in ipairs(recipient.items) do
            names[#names + 1] = ns.Jobs and ns.Jobs.ItemName(item.itemID, "") or tostring(item.itemID)
        end
        local detail = Names(names, 3)
        if atMailbox then
            if not (errands.filled and errands.filled[recipient.to]) then
                Add({ key = "mail:" .. recipient.to, lit = true, mailTo = recipient.to,
                    title = L.Format("Fill mail to %s", recipient.to), detail = detail })
            end
        else
            Add({ key = "mail:" .. recipient.to, lit = false,
                title = L.Format("Mail %s to %s", Plural(#recipient.items, L["stack"], L["stacks"]), recipient.to),
                detail = L["Next time you are at a mailbox."] })
            break
        end
    end

    -- The bank: Move to bank sits on this line.
    if atBank then
        local count = #errands:ToBank()
        if count > 0 then
            Add({ key = "bank", lit = true, dock = "bank", title = L.Format("Move %d to bank", count),
                detail = L["Puts your Always bank items in the bank."] })
        end
    end

    -- Bags nearly full, anywhere.
    local space = ns.FreeSpace and ns.FreeSpace.Read and ns.FreeSpace.Read()
    if space and space.total > 0 and ns.FreeSpace.Level(space.free) ~= "plenty" then
        Add({ key = "space", lit = true, title = L["Bags are nearly full"],
            detail = L.Format("%d free.", space.free) })
    end

    -- New spells to train.
    local training = ns.ClassTraining
    if training and training:IsOn() then
        local plan = training:Plan()
        local count = #plan.ready
        if count > 0 then
            local spot = training:Nearest()
            local where = training.Where(spot)
            local class = training.Player().className or ""
            local atTrainer = training.trainerOpen and training.atClassTrainer
            local action
            if atTrainer then
                action = { label = L["Train All"], run = function() training:TrainAll() end }
            elseif spot then
                action = { label = L["Show the Way"], run = function() training:ShowTheWay() end }
            end
            Add({ key = "train", lit = atTrainer and true or false,
                title = count == 1 and L["Train 1 new spell"] or L.Format("Train %d new spells", count),
                detail = where and L.Format("%s trainer, %s", class, where) or L.Format("At any %s trainer", class),
                action = action })
        end
    end

    local steps = {}
    for _, step in ipairs(lit) do
        if #steps < self.MOST then steps[#steps + 1] = step end
    end
    for _, step in ipairs(dim) do
        if #steps < self.MOST then steps[#steps + 1] = step end
    end
    return steps
end
