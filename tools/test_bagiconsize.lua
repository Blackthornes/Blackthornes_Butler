-- The Bags window's squares at every Item Size: what sits on a square grows
-- with it.
--
-- A player saw it (2026-11-21): at Large or Larger the rarity glow round an
-- item and the item level stayed the normal size, a small ring in the
-- middle of a big square. The game's template draws its glow and frame at a
-- fixed 37 pixels, and Butler's own item level and mark were fixed too.
--
-- What must hold:
--   1. At Larger, the template's rarity glow fills the square, and its
--      frame (drawn bigger than the square) grows by the same share.
--   2. Butler's item level and mark grow with the square.
--   3. Back at Normal, everything is its first size again.
--   4. A piece the template doesn't have, or one that won't give its size,
--      is left alone, and the same size twice does no work.

local env = dofile(lfs_cwd .. "/tools/testenv.lua")
local suite = env.NewSuite("bagiconsize")

local ns = env.Load()
env.Enable(ns)
local BagWindow, BagView = ns.BagWindow, ns.BagView

local function Piece(w, h)
    local piece = { w = w, h = h, sets = 0 }
    function piece:GetSize() return self.w, self.h end
    function piece:SetSize(nw, nh) self.w, self.h, self.sets = nw, nh, self.sets + 1 end
    return piece
end

local function Label(size)
    local label = { font = "Fonts\\FRIZQT__.TTF", size = size, flags = "" }
    function label:GetFont() return self.font, self.size, self.flags end
    function label:SetFont(font, nsize, flags) self.font, self.size, self.flags = font, nsize, flags end
    return label
end

local normal = BagView.SIZE_PIXELS.normal
local larger = BagView.SIZE_PIXELS.larger

local border, frameArt = Piece(normal, normal), Piece(64, 64)
local square = {
    _w = normal,
    GetWidth = function(self) return self._w end,
    IconBorder = border,
    GetNormalTexture = function() return frameArt end,
    bfrLevel = Label(10),
    bfrMark = Piece(14, 14),
}

-- 1 and 2. Larger.
square._w = larger
BagWindow.FitSquare(square, larger)
local share = larger / normal
local function Near(a, b) return type(a) == "number" and math.abs(a - b) < 0.6 end
suite.check("the rarity glow fills a Larger square", Near(border.w, larger) and Near(border.h, larger))
suite.check("the template's frame grows by the same share", Near(frameArt.w, 64 * share))
suite.check("the item level grows with the square", Near(square.bfrLevel.size, 10 * share))
suite.check("the mark grows with the square", Near(square.bfrMark.w, 14 * share))

-- 3. Back to Normal.
square._w = normal
BagWindow.FitSquare(square, normal)
suite.check("at Normal the glow is its first size", Near(border.w, normal))
suite.check("at Normal the frame is its first size", Near(frameArt.w, 64))
suite.check("at Normal the item level is its first size", square.bfrLevel.size == 10)
suite.check("at Normal the mark is its first size", Near(square.bfrMark.w, 14))

-- 4. Nothing to fit, and no work twice.
local sets = border.sets
BagWindow.FitSquare(square, normal)
suite.check("the same size twice does no work", border.sets == sets)
local bare = { bfrLevel = Label(10), bfrMark = Piece(14, 14),
    IconOverlay = { GetSize = function() return nil end, SetSize = function() error("touched") end } }
local ok = pcall(BagWindow.FitSquare, bare, larger)
suite.check("a square without the template's pieces still fits", ok and Near(bare.bfrMark.w, 14 * share))

suite.done()
