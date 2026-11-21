-- Blackthornes Butler -- UI/PlaceBar.lua
-- The Butler bar (the owner said build it, 2026-11-16, from a mockup): at a
-- vendor, mailbox or bank a slim bar hangs under the game's own window, so
-- the big Butler window opens only when asked and nothing is covered.
--
--   * Off unless ticked ("Butler Bar:" on the Errands page, `placeBar`).
--   * It takes the place of the window opening by itself: it shows where
--     and when "Open Butler At:" would have opened the window, and Open on
--     the bar brings the window up for that visit.
--   * Vendor: how many stacks are under Sell, what they are worth, and the
--     Sell button (Logic/Selling.lua's secure one, sat on the bar out of
--     combat and handed back to UIParent as a fight starts). Left of Sell,
--     "Buy 3" when this vendor sells what the craft queue needs (the owner
--     tapped "Build A and B", 2026-11-21): Jobs:BuyAtVendor, the window's
--     own Buy, through Tradeskills.
--     Mailbox: Fill mail for the next character. Bank: Move to bank and
--     Take from bank. The buttons do what the window's do.
--   * The game's windows are never hidden, moved or changed: the bar is
--     our own frame on UIParent, anchored to theirs. A client without that
--     window (`PlaceBar.GAMES`) gets the big window as before.
--   * Hidden while the Butler window is up, in a fight, and once the place
--     is left. Redrawn only when Butler's verdicts, the bags or the
--     errands change, never on a timer.

local _, ns = ...
local L = ns.L

local Bar = ns.NewModule("PlaceBar")

local Theme, Widgets = ns.Theme, ns.Widgets

-- The game's window for each place, first one found.
Bar.GAMES = {
    vendor = { "MerchantFrame" },
    mail = { "MailFrame" },
    bank = { "BankFrame" },
}
-- Room for the tabs that hang under the game's windows.
Bar.BELOW = 32
Bar.HEIGHT = 32
local PAD = 10
local GAP = 6

--- The words under the mouse that a bar button carries in `tooltipText`.
local function Tip(button)
    local enter, leave = button:GetScript("OnEnter"), button:GetScript("OnLeave")
    button:SetScript("OnEnter", function(self, ...)
        if enter then enter(self, ...) end
        if self.tooltipText and GameTooltip then
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(self.tooltipText, 1, 1, 1, 1, true)
            GameTooltip:Show()
        end
    end)
    button:SetScript("OnLeave", function(self, ...)
        if leave then leave(self, ...) end
        if GameTooltip then GameTooltip:Hide() end
    end)
end

local function InFight()
    return type(InCombatLockdown) == "function" and InCombatLockdown() == true
end

function Bar:IsOn()
    return ns.db ~= nil and ns.db.placeBar == true
end

function Bar:SetOn(on)
    if not ns.db then return end
    ns.db.placeBar = on and true or false
    if not on then self:Left(self.place) end
end

--- The game's window for `place`, or nil when this client has none.
function Bar.Game(place)
    for _, name in ipairs(Bar.GAMES[place] or {}) do
        local frame = rawget(_G, name)
        if type(frame) == "table" and type(frame.IsShown) == "function" then return frame end
    end
    return nil
end

function Bar:Build()
    if self.frame then return self.frame end
    local frame = CreateFrame("Frame", "BlackthornesButlerBar", UIParent)
    frame:SetHeight(Bar.HEIGHT)
    frame:SetFrameStrata("HIGH")
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:Hide()
    Theme.Fill(frame, "window")
    Theme.Border(frame, "borderLit")

    self.title = Theme.CreateLabel(frame, "small", "accentHi")
    self.title:SetPoint("LEFT", PAD, 0)
    self.title:SetText("Butler")

    self.text = Theme.CreateLabel(frame, "small", "text")
    self.text:SetPoint("LEFT", self.title, "RIGHT", 10, 0)

    self.open = Widgets.CreateButton(frame, L["Open"], function() Bar:OpenWindow() end,
        { height = 22 })
    self.open:SetPoint("RIGHT", -PAD, 0)

    local function Run(fn, ...)
        local arguments = { ... }
        return function()
            local _, message = fn(ns.Errands, unpack(arguments))
            if message then ns.Print(message) end
        end
    end
    self.mail = Widgets.CreateButton(frame, L["Fill Mail"], function()
        local _, message = ns.Errands:FillMail(Bar.mailTo)
        if message then ns.Print(message) end
    end, { height = 22, primary = true })
    self.mail.tooltipText = L["Fills in the mail for you. Check it, then press Send."]
    self.toBank = Widgets.CreateButton(frame, L["Move to bank"], Run(ns.Errands.MoveToBank),
        { height = 22, primary = true })
    self.toBank.tooltipText = L["Puts your Always bank items in the bank."]
    self.fromBank = Widgets.CreateButton(frame, L["Take from bank"], Run(ns.Errands.TakeFromBank),
        { height = 22 })
    self.fromBank.tooltipText = L["Takes out upgrades to wear and what your crafts still need."]
    self.buy = Widgets.CreateButton(frame, L["Buying..."], function()
        if not ns.Jobs then return end
        ns.Jobs:BuyAtVendor()
        Bar:Changed()
    end, { height = 22, primary = true })
    self.buy:Hide()
    for _, button in ipairs({ self.mail, self.toBank, self.fromBank, self.buy }) do Tip(button) end

    self.frame = frame
    return frame
end

--- The big window, for this visit: it goes when the place does.
function Bar:OpenWindow()
    local place = self.place
    if not (ns.UI and place) then return end
    self.opened = true
    ns.UI:Show("bags")
    if place == "vendor" then
        ns.UI.openedByVendor = true
    else
        ns.UI.openedFor = place
        if ns.Errands then ns.Errands:TellTradeskills() end
    end
    self:Refresh()
end

--- A place opened and the window would have come up: the bar comes up in
--- its stead. False (the window opens as before) when the bar is off or
--- this client has no such window.
function Bar:Arrived(place)
    if not self:IsOn() or not Bar.Game(place) then return false end
    self.place = place
    self.opened = false
    -- Ask afresh, as the window does when it opens, and read the bags if
    -- they changed while nothing was looking.
    if ns.Verdicts then ns.Verdicts:Forget() end
    if ns.Bags then ns.Bags:Fresh(function() Bar:Changed() end) end
    self:Refresh()
    -- The game can show its window a moment after the event.
    if C_Timer and C_Timer.After then
        C_Timer.After(0, function() Bar:Refresh() end)
        C_Timer.After(0.3, function() Bar:Refresh() end)
    end
    return true
end

function Bar:Left(place)
    if not place or self.place ~= place then return end
    self.place = nil
    self.opened = false
    self:Refresh()
end

--- Is the bar up for `place` (any place when nil)?
function Bar:Shows(place)
    return self.frame ~= nil and self.frame:IsShown() == true and (place == nil or self.place == place)
end

--- Verdicts, the bags or the errands moved.
function Bar:Changed()
    if self.place then self:Refresh() end
end

--- The Sell button, sat on the bar. False in a fight.
function Bar:PlaceSell(button)
    local frame = self.frame
    if not (button and frame) or InFight() then return false end
    if button:GetParent() ~= frame then button:SetParent(frame) end
    button:SetScale(1)
    button:SetFrameStrata(frame:GetFrameStrata() or "HIGH")
    button:SetFrameLevel((frame:GetFrameLevel() or 1) + 5)
    button:ClearAllPoints()
    button:SetPoint("RIGHT", self.open, "LEFT", -GAP, 0)
    self.sell = button
    return true
end

--- A fight starts: the Sell button goes back to UIParent, so the bar can
--- still hide.
function Bar:LetGo()
    local button = self.sell
    self.sell = nil
    if not button then return end
    pcall(function()
        button:Hide()
        button:ClearAllPoints()
        button:SetParent(UIParent)
    end)
end

--- Buy, left of Sell when Sell is on the bar, else left of Open.
function Bar:PlaceBuy()
    local buy = self.buy
    if not (buy and buy:IsShown()) then return end
    local sell = self.sell
    local right = (sell and sell:IsShown() and sell:GetParent() == self.frame) and sell or self.open
    buy:ClearAllPoints()
    buy:SetPoint("RIGHT", right, "LEFT", -GAP, 0)
end

--- Words and width for Buy from what this vendor has for the queue
--- (Jobs:VendorOffer, read afresh: the window is shut, so nothing else
--- reads it). As wide as its longest words, so it never jumps.
function Bar:WordBuy()
    local buy, jobs = self.buy, ns.Jobs
    local offer = jobs and jobs:VendorOffer()
    if not (offer and (offer.buying or offer.count > 0)) then
        buy:Hide()
        return
    end
    local words = offer.buying and L["Buying..."] or L.Format("Buy %d", offer.count)
    buy:SetText(words)
    buy:SetWidth(math.max(Theme.TextWidth("small", L.Format("Buy %d", math.max(offer.count, 99))),
        Theme.TextWidth("small", L["Buying..."])) + 12)
    buy.tooltipText = jobs.BuyTooltip()
    buy:Show()
end

local function Width(control)
    return control and control:IsShown() and (tonumber(control:GetWidth()) or 0) + GAP or 0
end

--- As wide as the game's window, or wider when its words and buttons need it.
function Bar:Fit()
    local frame, game = self.frame, self.place and Bar.Game(self.place)
    if not (frame and game) then return end
    self:PlaceBuy()
    local need = PAD + Theme.TextWidth("small", self.title:GetText() or "") + 10
        + Theme.TextWidth("small", self.text:GetText() or "") + 12
        + Width(self.sell) + Width(self.buy) + Width(self.mail) + Width(self.toBank) + Width(self.fromBank)
        + (tonumber(self.open:GetWidth()) or 0) + PAD
    local okWidth, width = pcall(game.GetWidth, game)
    frame:SetWidth(math.max(need, okWidth and tonumber(width) or 0))
end

function Bar:Refresh()
    local place = self.place
    local game = place and Bar.Game(place)
    local okShown, gameShown = false, false
    if game then okShown, gameShown = pcall(game.IsShown, game) end
    local windowUp = ns.UI and ns.UI:IsShown()
    local show = self:IsOn() and game ~= nil and okShown and gameShown == true and not windowUp and not InFight()

    if not show then
        if self.frame and self.frame:IsShown() and not InFight() then
            self:LetGo()
            self.frame:Hide()
        end
        if place == "vendor" and ns.Selling and not self.inSelling then
            self.inSelling = true
            ns.Selling:Update()
            self.inSelling = false
        end
        return
    end

    local frame = self:Build()
    self.mail:Hide()
    self.toBank:Hide()
    self.fromBank:Hide()
    self.buy:Hide()
    local text = ""

    if place == "vendor" then
        self:WordBuy()
        local _, _, count = ns.Selling:Words()
        if count > 0 then
            local worth = 0
            for _, item in ipairs(ns.Selling:Queue()) do worth = worth + (item.unit or 0) * (item.count or 1) end
            text = L.Format("%d to sell", count) .. "  " .. ns.Items.FormatMoney(worth)
        else
            text = L["Nothing to sell"]
        end
    else
        local offers = ns.Errands:Offers()
        if place == "mail" then
            local to
            if offers.mail then
                for _, recipient in ipairs(ns.Errands:Recipients()) do
                    if not ns.Errands.filled[recipient.to] then
                        to = recipient.to
                        break
                    end
                end
            end
            self.mailTo = to
            self.mail:SetShown(to ~= nil)
            if to then self.mail:SetText(L.Format("Fill mail to %s", to)) end
        else
            self.toBank:SetShown(offers.toBank > 0)
            self.toBank:SetText(L.Format("Move %d to bank", offers.toBank))
            self.fromBank:SetShown(offers.fromBank > 0)
        end
    end
    self.text:SetText(text)

    -- The buttons line up leftward from Open.
    local previous = self.open
    for _, button in ipairs({ self.mail, self.toBank, self.fromBank }) do
        if button:IsShown() then
            button:ClearAllPoints()
            button:SetPoint("RIGHT", previous, "LEFT", -GAP, 0)
            previous = button
        end
    end

    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", game, "BOTTOMLEFT", 0, -Bar.BELOW)
    frame:Show()

    if place == "vendor" and ns.Selling and not self.inSelling then
        self.inSelling = true
        ns.Selling:Update()
        self.inSelling = false
    end
    self:Fit()
end

function Bar:OnEnable()
    -- Just before combat locks secure frames.
    ns.RegisterEvent(self, "PLAYER_REGEN_DISABLED", function()
        Bar:LetGo()
        if Bar.frame then Bar.frame:Hide() end
    end)
    ns.RegisterEvent(self, "PLAYER_REGEN_ENABLED", function() Bar:Changed() end)
end

ns.RegisterCommand("bar", L["show or hide the Butler bar under vendors, mailboxes and the bank"], function(argument)
    argument = (argument or ""):lower()
    if argument == "on" or argument == "off" then
        Bar:SetOn(argument == "on")
    else
        Bar:SetOn(not Bar:IsOn())
    end
    ns.Print(Bar:IsOn() and L["Butler bar on."] or L["Butler bar off."])
    if ns.SettingsUI and ns.SettingsUI.Refresh and ns.SettingsUI.frame then ns.SettingsUI:Refresh() end
end)
