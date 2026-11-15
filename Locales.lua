-- TidyPack – Locales.lua
-- All text som visas i spelet går via L["Engelsk text"]. Engelskan är nyckeln och standardspråket.
-- Översättningarna ligger i en fil per språk i mappen Locales (t.ex. Locales/deDE.lua) och lämnas
-- hit med ns.AddTranslation. Saknas en text i en översättning visas den engelska.
--
-- Språket (användarens val 2026-11-15): Automatic följer spelets språk (GetLocale), och kugghjulets
-- meny Language ▸ (Marks.lua) kan välja ett annat av spelets elva språk. Valet sparas i
-- TidyPackDB.language ("auto" eller en språkkod) och gäller efter /reload, eftersom flikar och
-- knappar redan har sina texter. Svenska finns inte: spelet finns inte på svenska.
-- ⚠️ Översättningarna är maskinöversatta. Rättelser från spelare är välkomna (README).

local _, ns = ...

local translations = {} -- språkkod → { ["Engelsk text"] = "översättning" }
local active            -- översättningen som visas just nu, eller nil för engelska

-- L svarar med översättningen för det valda språket, och annars med den engelska texten.
-- Uppslaget görs varje gång en text används, så ett byte av språk gäller allt som ritas efteråt.
local L = setmetatable({}, {
    __index = function(_, key)
        return active and active[key] or key
    end,
})
ns.L = L

-- Spelets elva språk (WowLocale i spelets dokumentation), med namnet på det egna språket.
-- enGB visas som enUS och ptPT som ptBR av spelet självt (GetLocale).
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

-- Vilket språk ett val ger: "auto" (eller inget val) betyder spelets språk. Ett språk utan
-- översättning blir engelska.
function ns.ResolveLanguage(choice)
    local code = (choice and choice ~= "auto") and choice or GetLocale()
    if translations[code] then
        return code
    end
    return "enUS"
end

-- Byter språk. Core.lua anropar den när den sparade datan är inläst, innan resten av addonet
-- startar (ns.OnLoad).
function ns.SetLanguage(choice)
    ns.language = ns.ResolveLanguage(choice)
    active = translations[ns.language]
end

-- Översättningsfilerna lämnar sina texter här. Medan filerna laddas, innan den sparade datan finns,
-- gäller spelets språk (samma som Automatic).
function ns.AddTranslation(code, texts)
    translations[code] = texts
    if code == GetLocale() then
        ns.language = code
        active = texts
    end
end

ns.language = "enUS"
