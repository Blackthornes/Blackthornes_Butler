-- Item rows with no name (seen in game 2026-11-26): immediately after the game
-- starts with nothing remembered, a bag slot's link comes with empty
-- brackets, "|h[]|h", until the game loads the item. Butler read the empty
-- name as a name, so the row showed its icon and reason and no words, and
-- nothing asked the game for the name.

local env = dofile(lfs_cwd .. "/tools/testenv.lua")
local suite = env.NewSuite("blanknames")

local ns = env.Load()
local fake = env.FakeBags({
    { bag = 0, slot = 1, id = 301, name = "Linen Cloth", quality = 1, price = 13, count = 9 },
    { bag = 0, slot = 2, id = 302, name = "Late Thing", quality = 1, count = 1 },
})
-- The game hands out links with no name in them yet.
local real = _G.C_Container.GetContainerItemInfo
_G.C_Container.GetContainerItemInfo = function(bag, slot)
    local info = real(bag, slot)
    if info and info.hyperlink then
        info.hyperlink = info.hyperlink:gsub("%[.-%]", "[]")
    end
    return info
end
local asked = {}
_G.C_Item.RequestLoadItemDataByID = function(id) asked[id] = (asked[id] or 0) + 1 end
env.Enable(ns)
local UI, Items = ns.UI, ns.Items

suite.check("an empty name in a link is no name",
    Items.NameFromLink("|cffffffff|Hitem:301::::::::|h[]|h|r") == nil)
suite.check("a real name in a link is read",
    Items.NameFromLink("|cffffffff|Hitem:301::::::::|h[Linen Cloth]|h|r") == "Linen Cloth")

UI:Show()
UI.list._height = 2000
UI.list:Refresh()

local function ItemRow(itemID)
    for _, row in ipairs(UI.list.rows) do
        if row:IsShown() and row.data and row.data.type == "item" and row.data.itemID == itemID then
            return row
        end
    end
end

local cloth = ItemRow(301)
suite.check("the Linen Cloth row is drawn", cloth ~= nil)
suite.check("it shows its name, from the game's own record",
    cloth.name:GetText() == "Linen Cloth", tostring(cloth.name:GetText()))

-- The game knows nothing of this one yet (no price in the fake game).
local late = ItemRow(302)
suite.check("the unloaded item's row is drawn", late ~= nil)
local text = late.name:GetText()
suite.check("it never shows an empty name", type(text) == "string" and text ~= "", tostring(text))
suite.check("Butler asks the game for it", (asked[302] or 0) >= 1, tostring(asked[302]))

-- The game answers, and the name takes its place.
fake.info[302].price = 5
env.Fire("GET_ITEM_INFO_RECEIVED", 302, true)
UI.list:Refresh()
late = ItemRow(302)
suite.check("once loaded, the row shows the name",
    late and late.name:GetText() == "Late Thing", late and tostring(late.name:GetText()))

suite.done()
