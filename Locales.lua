-- TidyPack – Locales.lua
-- All text som visas i spelet samlas här. Koden skriver L["Engelsk text"].
-- Finns ingen översättning för spelets språk visas texten som den står.

local _, ns = ...

-- Tabellen svarar med själva nyckeln när en översättning saknas.
local L = setmetatable({}, {
    __index = function(_, key)
        return key
    end,
})
ns.L = L

-- Spelets språk, t.ex. "enUS", "deDE" eller "frFR". Det finns ingen svensk klient.
local locale = GetLocale()

-- Lägg till ett block per språk när addonet ska översättas, t.ex.:
-- if locale == "deDE" then
--     L["Potions"] = "Tränke"
-- end
