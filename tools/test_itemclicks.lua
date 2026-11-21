-- Item rows answer the game's item clicks (the owner, 2026-11-21): Shift-click
-- with a chat box open puts the item's link in it, Ctrl-click tries gear on,
-- and a row's own click is left alone otherwise (UI/Widgets.lua ItemClick,
-- CreateRowList's itemOf, UI.ItemOfRow for the Butler window's rows).

local env = dofile(lfs_cwd .. "/tools/testenv.lua")
local suite = env.NewSuite("itemclicks")

local ns = env.Load({ ui = true })
local Widgets, UI = ns.Widgets, ns.UI

local LINK = "|cff1eff00|Hitem:2034:::::|h[Slayer's Gloves]|h|r"
local keys, chatOpen, inserted, dressed = {}, false, {}, {}
local function Reset() keys, chatOpen, inserted, dressed = {}, false, {}, {} end

_G.IsModifiedClick = function(kind)
    if kind == "CHATLINK" then return keys.shift and true or false end
    if kind == "DRESSUP" then return keys.ctrl and true or false end
    return false
end
_G.ChatEdit_GetActiveWindow = function() return chatOpen and {} or nil end
_G.ChatEdit_InsertLink = function(link)
    if not chatOpen then return false end
    inserted[#inserted + 1] = link
    return true
end
_G.DressUpItemLink = function(link) dressed[#dressed + 1] = link; return true end
local savedItem = _G.C_Item
_G.C_Item = { GetItemInfo = function(id) if id == 2034 then return "Slayer's Gloves", LINK end end }

-- 1. The helper.
do
    Reset()
    suite.check("a plain click is left to the row", Widgets.ItemClick(2034) == false)
    keys.shift = true
    suite.check("Shift with the chat box shut is left to the row", Widgets.ItemClick(2034) == false)
    chatOpen = true
    suite.check("Shift with the chat box open links it", Widgets.ItemClick(2034) == true and inserted[1] == LINK)
    suite.check("a link given is used as it is", Widgets.ItemClick(nil, "|Hitem:7:|h[x]|h") == true
        and inserted[2] == "|Hitem:7:|h[x]|h")
    keys.shift, keys.ctrl = false, true
    suite.check("Ctrl tries it on", Widgets.ItemClick(2034) == true and dressed[1] == LINK)
end

-- 2. The Butler window's rows: which are items.
do
    suite.check("an item row is its item", UI.ItemOfRow({ itemID = 2034, link = LINK, verdict = "sell" }) == 2034)
    suite.check("with its own link", select(2, UI.ItemOfRow({ itemID = 2034, link = LINK })) == LINK)
    suite.check("All characters' item row", UI.ItemOfRow({ type = "everyone", item = { itemID = 5 } }) == 5)
    suite.check("a quest buy", UI.ItemOfRow({ type = "questbuy", item = { itemID = 6 } }) == 6)
    suite.check("the vendor's ammo", UI.ItemOfRow({ type = "ammo", offer = { ammo = { itemID = 7 } } }) == 7)
    suite.check("a wishlist entry", UI.ItemOfRow({ type = "wishlist", entry = { itemID = 8 } }) == 8)
    suite.check("a heading is no item", UI.ItemOfRow({ type = "header", group = {} }) == nil)
    suite.check("a gold line is no item", UI.ItemOfRow({ type = "gold", entry = {} }) == nil)
end

-- 3. A row list with itemOf: Shift and Ctrl go to the item, the rest to the row.
do
    Reset()
    local clicks = {}
    local list = Widgets.CreateRowList(UIParent, {
        rowHeight = 20,
        itemOf = function(data) return UI.ItemOfRow(data) end,
        onClick = function(_, button) clicks[#clicks + 1] = button end,
    })
    list:SetData({ { itemID = 2034, link = LINK }, { type = "header", group = {} } })
    local row, heading = list.rows[1], list.rows[2]
    row:GetScript("OnClick")(row, "LeftButton")
    suite.check("a plain click reaches the row", #clicks == 1)
    keys.shift, chatOpen = true, true
    row:GetScript("OnClick")(row, "LeftButton")
    suite.check("Shift-click with the chat box open links it", inserted[1] == LINK and #clicks == 1)
    heading:GetScript("OnClick")(heading, "LeftButton")
    suite.check("a heading keeps its click", #clicks == 2 and #inserted == 1)
    row:GetScript("OnClick")(row, "RightButton")
    suite.check("a right-click is the row's", #clicks == 3)
end

_G.IsModifiedClick, _G.ChatEdit_GetActiveWindow, _G.ChatEdit_InsertLink, _G.DressUpItemLink = nil, nil, nil, nil
_G.C_Item = savedItem

suite.done()
