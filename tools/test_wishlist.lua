-- Recipes on the wishlist (the owner said build it, 2026-11-17).
--
-- What must hold:
--   1. Away from a vendor or trainer, without Tradeskills, or when it
--      raises, there is no row.
--   2. At a vendor, each starred recipe it sells is a "Buy a recipe on your
--      wishlist" row, naming the recipe and its price, with Buy.
--   3. At a trainer the row reads "Learn a recipe on your wishlist" with
--      Learn; a recipe the skill is too low for says the skill and has no
--      button.
--   4. Buy and Learn ask the game for one, by place, only when the place
--      still holds that recipe; never in combat.
--   5. Butler only reads the wishlist: nothing it does writes to it.
--   6. The window's redraw key follows the list.

local env = dofile(lfs_cwd .. "/tools/testenv.lua")
local suite = env.NewSuite("wishlist")

local ns = env.Load()
env.FakeBags({})
_G.C_Item.GetItemNameByID = function(id)
    return ({ [9100] = "Plans: Heavy Bronze Mace" })[id]
end
local Wishlist, UI, Jobs = ns.Wishlist, ns.UI, ns.Jobs

local answer
local written = 0
_G.BlackthornesTS = { Butler = {
    Advise = function() return nil end,
    Holdings = function() return {} end,
    Mailbox = function() end,
    Jobs = function() return {} end,
    WishlistHere = function() return answer end,
    -- Anything that would change the wishlist counts here, and must stay 0.
    SetWishlist = function() written = written + 1 end,
} }
env.Enable(ns)
Jobs:Changed()

local function WishRows()
    Wishlist:Read()
    local rows = {}
    for _, row in ipairs(Jobs:Lines()) do
        if row.type == "wishlist" then rows[#rows + 1] = row end
    end
    return rows
end

-- 1. Away from a vendor or trainer.
answer = { { recipeID = 100, name = "Heavy Bronze Mace", itemID = 9100, price = 8000, needs = 110,
    kind = "vendor", index = 2 } }
ns.Selling.merchantOpen = false
ns.ClassTraining.trainerOpen = false
suite.check("away from a vendor, no row", #WishRows() == 0)
suite.check("and an empty redraw key", Wishlist.key == "")

-- 2. At a vendor.
ns.Selling.merchantOpen = true
local rows = WishRows()
suite.check("a row for the starred recipe", #rows == 1, #rows)
local title, detail = Wishlist.Text(rows[1].entry)
suite.check("it says buy a recipe on your wishlist", title == "Buy a recipe on your wishlist", title)
suite.check("naming the recipe item", detail:find("Plans: Heavy Bronze Mace", 1, true) ~= nil, detail)
suite.check("and its price", detail:find("80", 1, true) ~= nil, detail)
suite.check("the redraw key follows it", Wishlist.key ~= "")
local key = Wishlist.key

local row = CreateFrame("Button")
UI.CreateRow(row)
UI.UpdateRow(row, rows[1])
suite.check("the row has Buy", row.action:IsShown() and row.action.label:GetText() == "Buy",
    row.action.label:GetText())

-- 4. Buy, by place.
local boughtAt, boughtCount
_G.BuyMerchantItem = function(index, count) boughtAt, boughtCount = index, count end
_G.GetMerchantItemLink = function(index)
    if index == 2 then return "|cffffffff|Hitem:9100::::::::|h[Plans: Heavy Bronze Mace]|h|r" end
end
suite.check("Buy asks the game for one", Wishlist:Click(rows[1].entry) == true and boughtAt == 2 and boughtCount == 1)
boughtAt = nil
_G.GetMerchantItemLink = function() return "|Hitem:1234|h[Other]|h" end
suite.check("a list that moved buys nothing", Wishlist:Click(rows[1].entry) == false and boughtAt == nil)
_G.GetMerchantItemLink = function() return "|Hitem:9100|h[Plans]|h" end
local savedCombat = _G.InCombatLockdown
_G.InCombatLockdown = function() return true end
suite.check("nothing in combat", Wishlist:Click(rows[1].entry) == false and boughtAt == nil)
_G.InCombatLockdown = savedCombat

-- 3. At a trainer.
ns.Selling.merchantOpen = false
ns.ClassTraining.trainerOpen = true
answer = {
    { recipeID = 200, name = "Patterned Bronze Bracers", price = 9000, needs = 120, kind = "trainer", index = 3 },
    { recipeID = 300, name = "Golden Scale Coif", needs = 145, short = 145, kind = "trainer" },
}
rows = WishRows()
suite.check("one row a recipe", #rows == 2, #rows)
title = Wishlist.Text(rows[1].entry)
suite.check("it says learn a recipe on your wishlist", title == "Learn a recipe on your wishlist", title)
UI.UpdateRow(row, rows[1])
suite.check("the row has Learn", row.action:IsShown() and row.action.label:GetText() == "Learn",
    row.action.label:GetText())
local _, low = Wishlist.Text(rows[2].entry)
suite.check("too low says the skill", low:find("Learn at 145", 1, true) ~= nil, low)
UI.UpdateRow(row, rows[2])
suite.check("and has no button", not row.action:IsShown())
suite.check("the key moved", Wishlist.key ~= key)

local trainedAt
_G.BuyTrainerService = function(index) trainedAt = index end
_G.GetTrainerServiceInfo = function(index)
    if index == 3 then return "Patterned Bronze Bracers", nil, "available" end
end
suite.check("Learn trains it by place", Wishlist:Click(rows[1].entry) == true and trainedAt == 3)
trainedAt = nil
suite.check("a recipe it can't teach yet is not tried", Wishlist:Click(rows[2].entry) == false and trainedAt == nil)
_G.GetTrainerServiceInfo = function() return "Something Else", nil, "available" end
suite.check("a list that moved trains nothing", Wishlist:Click(rows[1].entry) == false and trainedAt == nil)

-- 1 again: odd answers and errors.
answer = { { recipeID = "x", kind = "vendor" }, "junk", { recipeID = 5, kind = "elsewhere" } }
suite.check("odd entries are left out", #WishRows() == 0)
_G.BlackthornesTS.Butler.WishlistHere = function() error("boom") end
suite.check("an error shows nothing", #WishRows() == 0)
_G.BlackthornesTS = nil
suite.check("without Tradeskills, nothing", #WishRows() == 0)

-- 5. Read only.
suite.check("Butler never changed the wishlist", written == 0)

ns.ClassTraining.trainerOpen = false
_G.BuyMerchantItem, _G.GetMerchantItemLink, _G.BuyTrainerService, _G.GetTrainerServiceInfo = nil, nil, nil, nil
suite.done()
