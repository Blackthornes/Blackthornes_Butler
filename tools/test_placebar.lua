-- The Butler bar: off unless ticked; with it on, a slim bar comes up under
-- the game's vendor, mailbox or bank window in the Butler window's stead
-- (UI/PlaceBar.lua).

local env = dofile(lfs_cwd .. "/tools/testenv.lua")
local suite = env.NewSuite("placebar")

local ns = env.Load()
local items = {}
for slot = 1, 3 do
    items[#items + 1] = { bag = 0, slot = slot, id = 200 + slot, name = "Junk " .. slot,
        quality = 0, price = 10 }
end
local fake = env.FakeBags(items)
fake.canSell = true
env.Enable(ns)

local Bar, UI, Selling = ns.PlaceBar, ns.UI, ns.Selling

suite.check("off unless ticked", Bar:IsOn() == false and ns.db.placeBar == false)

-- Off: the window comes up as before.
env.Fire("MERCHANT_SHOW")
suite.check("off, the window comes up at a vendor", UI:IsShown() and not Bar:Shows())
env.Fire("MERCHANT_CLOSED")
suite.check("and goes with it", not UI:IsShown())

-- On: the bar comes up in its stead.
Bar:SetOn(true)
env.Fire("MERCHANT_SHOW")
suite.check("on, the window stays shut", not UI:IsShown())
suite.check("and the bar comes up", Bar:Shows("vendor"))
suite.check("it is our own frame on UIParent", Bar.frame:GetParent() == UIParent)
suite.check("anchored under the game's window", Bar.frame._point and Bar.frame._point[2] == MerchantFrame,
    Bar.frame._point and tostring(Bar.frame._point[2]))
suite.check("the game's window is left shown", MerchantFrame:IsShown())
suite.check("it says what there is to sell", (Bar.text:GetText() or ""):find("3", 1, true) ~= nil,
    Bar.text:GetText())
local button = Selling.button
suite.check("the Sell button sits on the bar", button and button:IsShown() and button:GetParent() == Bar.frame)

-- Open brings the window up for this visit, and the bar steps aside.
Bar:OpenWindow()
suite.check("Open brings the window up", UI:IsShown() and UI.openedByVendor == true)
suite.check("and the bar goes", not Bar:Shows())
Selling:Update()
suite.check("the Sell button goes back to the window", button:GetParent() ~= Bar.frame)

-- Closed by the player while still at the vendor: the bar comes back.
-- The test frames run no scripts on Hide, so its OnHide is run by hand.
UI:Hide()
UI.frame:GetScript("OnHide")(UI.frame)
suite.check("closing the window brings the bar back", Bar:Shows("vendor"))

-- A fight: the bar hides and lets the secure button go first.
env.Fire("PLAYER_REGEN_DISABLED")
suite.check("a fight hides the bar", not Bar:Shows())
suite.check("and hands the Sell button back", button:GetParent() == UIParent)
env.Fire("PLAYER_REGEN_ENABLED")
suite.check("after it the bar is back", Bar:Shows("vendor"))

env.Fire("MERCHANT_CLOSED")
suite.check("leaving the vendor hides the bar", not Bar:Shows() and Bar.place == nil)
suite.check("and no window is left up", not UI:IsShown())

-- A client without that window keeps the big window.
local merchant = MerchantFrame
_G.MerchantFrame = nil
env.Fire("MERCHANT_SHOW")
suite.check("no game window to hang under: the window opens", UI:IsShown() and not Bar:Shows())
env.Fire("MERCHANT_CLOSED")
_G.MerchantFrame = merchant

-- Unticking it while it is up takes it away.
env.Fire("MERCHANT_SHOW")
suite.check("up again", Bar:Shows("vendor"))
Bar:SetOn(false)
suite.check("unticked, it goes", not Bar:Shows() and ns.db.placeBar == false)
env.Fire("MERCHANT_CLOSED")

-- The mailbox: the same, under the game's mail window.
_G.MailFrame = env.Stub()
MailFrame:Show()
Bar:SetOn(true)
env.Fire("MAIL_SHOW")
suite.check("at a mailbox the bar comes up", Bar:Shows("mail") and not UI:IsShown())
suite.check("under the mail window", Bar.frame._point[2] == MailFrame)
suite.check("with no Sell button on it", not (Selling.button and Selling.button:IsShown()))
Bar:OpenWindow()
suite.check("Open brings the window up for the mailbox", UI:IsShown() and UI.openedFor == "mail")
env.Fire("MAIL_CLOSED")
suite.check("leaving the mailbox takes both away", not Bar:Shows() and not UI:IsShown())
Bar:SetOn(false)

-- The Settings row.
ns.HandleSlash("settings")
local box = ns.SettingsUI.controls.placeBar
suite.check("Settings has the tick, unticked", box ~= nil and not box:GetChecked())

ns.HandleSlash("bar on")
suite.check("/bbutler bar on ticks it", Bar:IsOn() and box:GetChecked())
ns.HandleSlash("bar off")
suite.check("/bbutler bar off unticks it", not Bar:IsOn())

suite.done()
