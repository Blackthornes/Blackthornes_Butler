-- Wait for a better price: an item Butler would put on the auction house
-- waits, folded away, while today's cheapest listing by someone else is
-- well under its usual price. Nothing is sold or deleted; the group only
-- starts folded, on every character, until the player opens it.

local env = dofile(lfs_cwd .. "/tools/testenv.lua")
local suite = env.NewSuite("waitprice")

local ns = env.Load()
env.FakeBags({
    { bag = 0, slot = 1, id = 601, name = "Silk Cloth", quality = 1, price = 40, count = 20 },
    { bag = 0, slot = 2, id = 602, name = "Iron Ore", quality = 1, price = 50 },
    { bag = 0, slot = 3, id = 603, name = "Mageweave Cloth", quality = 1, price = 60 },
    { bag = 0, slot = 4, id = 604, name = "Wool Cloth", quality = 1, price = 1200 },
})
env.Enable(ns)

local Verdicts, UI = ns.Verdicts, ns.UI

local function Find(name)
    for _, group in ipairs(Verdicts:Groups()) do
        for _, row in ipairs(group.rows) do
            if row.name == name then return row end
        end
    end
end

local function Look()
    UI:Hide()
    UI:Show()
end

local function Header(lines, verdict)
    for _, line in ipairs(lines) do
        if line.type == "header" and line.group.verdict == verdict then return line end
    end
end

local function Shows(lines, name)
    for _, line in ipairs(lines) do
        if line.type == "item" and line.name == name then return true end
    end
    return false
end

_G.BlackthornesTS = { Butler = { Advise = function(_, id)
    if id == 601 then return { auction = 1000, auctionNow = 600 } end  -- a real dip
    if id == 602 then return { auction = 1000, auctionNow = 900 } end  -- a little under is normal
    if id == 603 then return { auction = 1000 } end                    -- no fresh scan
    if id == 604 then return { auction = 1000, auctionNow = 100 } end  -- the vendor pays more anyway
end } }
Look()

local silk = Find("Silk Cloth")
suite.check("well under the usual price: Wait for a better price", silk.verdict == "wait", silk.verdict)
suite.check("the reason says today's price and the usual one",
    silk.reason:find("right now", 1, true) ~= nil, silk.reason)
suite.check("still worth its usual price", silk.unit == 1000, silk.unit)
suite.check("a little under is still Auction", Find("Iron Ore").verdict == "auction")
suite.check("no price for today is still Auction", Find("Mageweave Cloth").verdict == "auction")
suite.check("only items to auction wait", Find("Wool Cloth").verdict ~= "wait", Find("Wool Cloth").verdict)

-- Folded at first, also on a character whose folds were saved before.
ns.charDB.folded = { keep = true }
local lines = UI:Lines()
local header = Header(lines, "wait")
suite.check("the group has a heading", header ~= nil)
suite.check("folded at first", header and header.folded == true)
suite.check("its items are out of the way", not Shows(lines, "Silk Cloth"))
suite.check("Auction still shows its items", Shows(lines, "Iron Ore"))

UI:Clicked(header, "LeftButton")
lines = UI:Lines()
suite.check("a click opens it", Header(lines, "wait").folded == false and Shows(lines, "Silk Cloth"))
suite.check("and is kept as opened", ns.charDB.folded.wait == false)
UI:Clicked(Header(lines, "wait"), "LeftButton")
lines = UI:Lines()
suite.check("a second click folds it again", Header(lines, "wait").folded == true and not Shows(lines, "Silk Cloth"))

-- Other groups fold as before.
UI:Clicked(Header(lines, "auction"), "LeftButton")
suite.check("Auction folds as before", ns.charDB.folded.auction == true)
UI:Clicked(Header(UI:Lines(), "auction"), "LeftButton")
suite.check("and opens back to nothing saved", ns.charDB.folded.auction == nil)

-- The Sell button never takes them.
suite.check("nothing waiting is under Sell", Find("Silk Cloth").verdict ~= "sell")

_G.BlackthornesTS = nil
suite.done()
