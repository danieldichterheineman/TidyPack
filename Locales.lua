-- TidyPack – Locales.lua
-- All text shown in the game goes through L["English text"]. English is the key and the default.
-- The translations are one file per language in the Locales folder (e.g. Locales/deDE.lua) and are
-- handed over with ns.AddTranslation. A text missing from a translation shows in English.
--
-- The language (the owner's choice 2026-11-15): Automatic follows the game (GetLocale), and the gear
-- menu's Language ▸ (Marks.lua) can pick another of the game's eleven languages. The choice is saved
-- in TidyPackDB.language ("auto" or a language code) and applies after /reload, because tabs and
-- buttons already have their texts. There is no Swedish: the game has no Swedish client.
-- ⚠️ The translations are machine-made. Corrections from players are welcome (README).

local _, ns = ...

local translations = {} -- language code → { ["English text"] = "translation" }
local active            -- the translation shown now, or nil for English

-- L answers with the translation for the chosen language, otherwise with the English text. The
-- lookup happens every time a text is used, so a language change applies to everything drawn later.
local L = setmetatable({}, {
    __index = function(_, key)
        return active and active[key] or key
    end,
})
ns.L = L

-- The game's eleven languages (WowLocale in the game's documentation), named in their own language.
-- The game itself shows enGB as enUS and ptPT as ptBR (GetLocale).
ns.LANGUAGES = {
    { code = "enUS", name = "English" },
    { code = "deDE", name = "Deutsch" },
    { code = "esES", name = "Español (España)" },
    { code = "esMX", name = "Español (Latinoamérica)" },
    { code = "frFR", name = "Français" },
    { code = "itIT", name = "Italiano" },
    { code = "ptBR", name = "Português (Brasil)" },
    { code = "ruRU", name = "Русский" },
    { code = "koKR", name = "한국어" },
    { code = "zhCN", name = "简体中文" },
    { code = "zhTW", name = "繁體中文" },
}

-- Which language a choice gives: "auto" (or no choice) means the game's language. A language
-- without a translation becomes English.
function ns.ResolveLanguage(choice)
    local code = (choice and choice ~= "auto") and choice or GetLocale()
    if translations[code] then
        return code
    end
    return "enUS"
end

-- Switches language. Core.lua calls it once the saved data is loaded, before the rest of the addon
-- starts (ns.OnLoad).
function ns.SetLanguage(choice)
    ns.language = ns.ResolveLanguage(choice)
    active = translations[ns.language]
end

-- The translation files hand over their texts here. While the files load, before the saved data
-- exists, the game's language applies (the same as Automatic).
function ns.AddTranslation(code, texts)
    translations[code] = texts
    if code == GetLocale() then
        ns.language = code
        active = texts
    end
end

ns.language = "enUS"
