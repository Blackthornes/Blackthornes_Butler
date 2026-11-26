-- Auction Only If It Pays: the auction house must beat a vendor by the
-- player's percent, after its cut, before Butler says Auction. It starts
-- at 0, where one copper more is enough, as before. It only ever moves an
-- item toward the vendor.

local env = dofile(lfs_cwd .. "/tools/testenv.lua")
local suite = env.NewSuite("auctionmargin")

local ns = env.Load()
env.FakeBags({
    { bag = 0, slot = 1, id = 601, name = "Wool Cloth", quality = 1, price = 33 },
    { bag = 0, slot = 2, id = 602, name = "Light Leather", quality = 1, price = 15 },
    { bag = 0, slot = 3, id = 603, name = "Moss Agate", quality = 2, price = 100 },
    { bag = 0, slot = 4, id = 604, name = "Silk Cloth", quality = 1, price = 150 },
    { bag = 0, slot = 5, id = 605, name = "Linen Cloth", quality = 1, price = 10 },
})
env.Enable(ns)

local Verdicts = ns.Verdicts

local function Find(name)
    for _, group in ipairs(Verdicts:Groups()) do
        for _, row in ipairs(group.rows) do
            if row.name == name then return row end
        end
    end
end

local function Look()
    ns.UI:Hide()
    ns.UI:Show()
end

-- What one brings at auction after the cut, the mockup's examples.
_G.BlackthornesTS = { Butler = { Advise = function(_, id)
    if id == 601 then return { auction = 36 } end
    if id == 602 then return { auction = 17 } end
    if id == 603 then return { auction = 610 } end
    if id == 604 then return { auction = 410 } end
    if id == 605 then return { auction = 8 } end   -- the vendor pays more
end } }

ns.UI:Show()
suite.check("starts at 0", Verdicts:AuctionMargin() == 0 and ns.db.auctionMargin == nil)
suite.check("at 0, three copper more is enough (Wool Cloth)", Find("Wool Cloth").verdict == "auction",
    Find("Wool Cloth").verdict)
suite.check("at 0, two copper more is enough (Light Leather)", Find("Light Leather").verdict == "auction")
suite.check("at 0, a vendor that pays more still wins", Find("Linen Cloth").verdict == "sell")

Verdicts:SetAuctionMargin(20)
suite.check("saved account wide", ns.db.auctionMargin == 20 and Verdicts:AuctionMargin() == 20)
Look()
local wool = Find("Wool Cloth")
suite.check("at 20%, Wool Cloth goes to the vendor", wool.verdict == "sell", wool.verdict)
suite.check("and says why", wool.reason and wool.reason:find("only a little more", 1, true), wool.reason)
suite.check("at the vendor's price", wool.unit == 33)
suite.check("at 20%, Light Leather goes to the vendor", Find("Light Leather").verdict == "sell")
suite.check("at 20%, Moss Agate still goes to auction", Find("Moss Agate").verdict == "auction")
suite.check("at 20%, Silk Cloth still goes to auction", Find("Silk Cloth").verdict == "auction")
local linen = Find("Linen Cloth")
suite.check("a vendor that pays more keeps its old words", linen.verdict == "sell"
    and linen.reason:find("Vendor pays more", 1, true), linen.reason)

-- Right at the line: 20% over 33 is 39.6, so 39 is not enough, 40 is.
_G.BlackthornesTS.Butler.Advise = function(_, id)
    if id == 601 then return { auction = 39 } end
end
Look()
suite.check("39 copper over a 33 copper vendor is not 20% more", Find("Wool Cloth").verdict == "sell")
_G.BlackthornesTS.Butler.Advise = function(_, id)
    if id == 601 then return { auction = 40 } end
end
Look()
suite.check("40 copper is", Find("Wool Cloth").verdict == "auction")

-- Back to 0: the old way again.
Verdicts:SetAuctionMargin(0)
suite.check("0 turns it off", ns.db.auctionMargin == nil and Verdicts:AuctionMargin() == 0)
_G.BlackthornesTS.Butler.Advise = function(_, id)
    if id == 601 then return { auction = 36 } end
end
Look()
suite.check("and the auction house wins on a copper again", Find("Wool Cloth").verdict == "auction")

Verdicts:SetAuctionMargin("lots")
suite.check("a value it can't read turns it off", ns.db.auctionMargin == nil)

-- The Settings drop-down.
_G.Settings = {
    RegisterCanvasLayoutCategory = function(panel, name) return { panel = panel, name = name } end,
    RegisterAddOnCategory = function() end,
}
for _, module in ipairs(ns.moduleOrder) do
    if module.OnEnable then module:OnEnable() end
end
ns.HandleSlash("settings")
local SettingsUI = ns.SettingsUI
local box = SettingsUI.controls.auctionMargin
suite.check("the Selling page has the drop-down", box ~= nil)
if box then
    SettingsUI.pages:Show("selling")
    SettingsUI:Refresh()
    suite.check("it shows 0%", box:GetValue() == 0 and box.label:GetText() == "0%", box.label:GetText())
    local values = {}
    for _, option in ipairs(box.options) do values[#values + 1] = option.value end
    suite.check("0, 5, 10, 20, 30 and 50", table.concat(values, ",") == "0,5,10,20,30,50")
    Verdicts:SetAuctionMargin(30)
    SettingsUI:Refresh()
    suite.check("it shows what is saved", box.label:GetText() == "30%", box.label:GetText())
end

_G.BlackthornesTS = nil
suite.done()
