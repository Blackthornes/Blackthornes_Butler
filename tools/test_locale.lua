-- The translations: on a German, Chinese, French, Spanish or Russian
-- client the window and settings speak that language, on any other they
-- speak English, and a word with no line falls back to its English key. L.Format puts values named by place
-- ("%2$s ... %1$d") in order, which the tests' Lua 5.1 cannot do itself.

local env = dofile(lfs_cwd .. "/tools/testenv.lua")
local suite = env.NewSuite("locale")

--- Every row label on every settings page, as one lookup.
local function SettingsLabels(ns)
    for _, module in ipairs(ns.moduleOrder) do
        if module.OnEnable then module:OnEnable() end
    end
    ns.SettingsUI:Show()
    local labels = {}
    for _, page in pairs(ns.SettingsUI.pages.pages) do
        for _, row in ipairs(page.rows or {}) do
            if row.labelText then labels[row.labelText] = true end
        end
    end
    return labels
end

-- English first.
local ns = env.Load()
local L = ns.L
suite.check("English shows English", L["Sell"] == "Sell")
suite.check("a group's title in English", ns.Verdicts.LABELS.sell == "Sell")
suite.check("the settings rows in English", SettingsLabels(ns)["Free Bag Space:"] == true)

-- A German client.
ns = env.Load("deDE")
L = ns.L
suite.check("a group's title in Deutsch", ns.Verdicts.LABELS.sell == "Verkaufen", ns.Verdicts.LABELS.sell)
local labels = SettingsLabels(ns)
suite.check("the settings rows speak Deutsch", labels["Freier Taschenplatz:"] == true)
suite.check("and none is left in English", labels["Free Bag Space:"] == nil)
suite.check("a word with no German line falls back to English",
    L["A string nobody translated"] == "A string nobody translated")
suite.check("and formats in English", L.Format("%d stacks, %s", 3, "grey") == "3 stacks, grey")

-- Simplified Chinese, French, Spanish (both clients) and Russian.
local OTHERS = {
    { "zhCN", "Simplified Chinese", "出售", "背包空位：" },
    { "frFR", "French", "Vendre", "Place libre dans les sacs :" },
    { "esES", "Spanish", "Vender", "Espacio libre en bolsas:" },
    { "esMX", "Spanish (Mexico)", "Vender", "Espacio libre en bolsas:" },
    { "ruRU", "Russian", "Продать", "Место в сумках:" },
}
for _, lang in ipairs(OTHERS) do
    ns = env.Load(lang[1])
    suite.check("a group's title in " .. lang[2], ns.Verdicts.LABELS.sell == lang[3], ns.Verdicts.LABELS.sell)
    labels = SettingsLabels(ns)
    suite.check("the settings rows speak " .. lang[2], labels[lang[4]] == true)
    suite.check("and none is left in English in " .. lang[2], labels["Free Bag Space:"] == nil)
    suite.check("a missing line falls back to English in " .. lang[2],
        ns.L["A string nobody translated"] == "A string nobody translated")
end

-- Another language that has no file shows English.
ns = env.Load("itIT")
suite.check("a client in a language with no file shows English", ns.L["Sell"] == "Sell")

_G.GetLocale = nil
suite.done()
