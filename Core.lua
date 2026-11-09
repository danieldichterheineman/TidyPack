-- TidyPack – Core.lua
-- Addonets kärna: sparad data och events.
-- Spelet kör filen när den står i tur i TOC-filen.

-- Spelet ger varje fil två värden: addonets namn och en privat tabell (ns)
-- som alla addonets filer delar.
local addonName, ns = ...
local L = ns.L

-- Standardvärden för sparad data. Lägg till nya nycklar här.
ns.defaults = {
    -- Blir sant när Tidy Pack har slagit på spelets inställning "Combined Bags" en gång.
    combinedBagsTurnedOn = false,
    -- Stjärnmärkta saker: itemID → true (se Marks.lua).
    favorites = {},
    -- Skräplistan: itemID → true (se Marks.lua).
    junk = {},
    -- Blir sant när Tidy Pack en gång har berättat att Questie låser upp "Needed later"
    -- (se QuestHints.lua).
    questieNoticeShown = false,

    -- Inställningarna på Tidy Packs sida i spelets Options (Options.lua). Allt är påslaget
    -- från början.
    suggestOnLoot = true,     -- fråga när en sak från skräplistan lootas (MakeRoom.lua)
    suggestWhenFull = true,   -- föreslå en sak att radera när väskorna är fulla (MakeRoom.lua)
    sellJunkButton = true,    -- knappen Sell Junk hos en handlare (Junk.lua)
    questHints = true,        -- saker som kommande quests behöver (QuestHints.lua)
    itemLevelAndBoE = true,   -- nivå och BoE på utrustning (Layout.lua)
}

-- Standardvärden för data som sparas per karaktär (TidyPackCharDB).
ns.charDefaults = {
    -- Egna set: { { name = "Fishing", items = { itemID, ... } }, ... } (se Sets.lua).
    sets = {},
}

-- Skriver ett meddelande i användarens eget chattfönster, med addonets namn först.
function ns.Print(message)
    print(("|cff33ff99%s|r: %s"):format("Tidy Pack", message))
end

-- Fyller i nycklar som saknas, utan att skriva över det användaren redan sparat.
-- Tabeller i tabeller fylls i på samma sätt.
local function applyDefaults(database, source)
    for key, value in pairs(source) do
        if type(value) == "table" then
            if database[key] == nil then
                database[key] = {}
            end
            if type(database[key]) == "table" then
                applyDefaults(database[key], value)
            end
        elseif database[key] == nil then
            database[key] = value
        end
    end
end

---------------------------------------------------------------------------
-- Sparad data: version och migreringar
---------------------------------------------------------------------------

-- Versionen av hur den sparade datan är uppbyggd. Höj den och lägg till ett steg i
-- migrations när en sparad nyckel byter namn, typ eller betydelse, så att spelarnas
-- gamla data följer med (se skillen wow-maintain).
local DATA_VERSION = 1

-- migrations[2] uppgraderar sparad data från version 1 till 2, och så vidare.
local migrations = {
}

-- Uppgraderar sparad data ett steg i taget till DATA_VERSION.
local function migrate(database)
    if next(database) == nil then
        database.dataVersion = DATA_VERSION -- ny installation: inget att uppgradera
        return
    end
    local version = database.dataVersion or 1
    for target = version + 1, DATA_VERSION do
        if migrations[target] then
            migrations[target](database)
        end
        version = target
    end
    database.dataVersion = version
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------

-- En osynlig ram som tar emot events åt hela addonet.
local eventFrame = CreateFrame("Frame")
local eventHandlers = {}

-- Låter addonets alla filer lyssna på events, t.ex.
-- ns.RegisterEvent("PLAYER_REGEN_ENABLED", function() ... end)
function ns.RegisterEvent(event, handler)
    if not eventHandlers[event] then
        eventHandlers[event] = {}
        eventFrame:RegisterEvent(event)
    end
    table.insert(eventHandlers[event], handler)
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
    for _, handler in ipairs(eventHandlers[event]) do
        handler(...)
    end
end)

-- Funktioner som ska köras när den sparade datan är inläst.
local loadCallbacks = {}

-- Andra filer (t.ex. Layout.lua) registrerar sin uppstart här.
function ns.OnLoad(callback)
    table.insert(loadCallbacks, callback)
end

ns.RegisterEvent("ADDON_LOADED", function(loadedName)
    if loadedName ~= addonName then
        return -- ett annat addon laddades, inte vårt
    end
    -- Först nu är SavedVariables inlästa från disk.
    TidyPackDB = TidyPackDB or {}
    migrate(TidyPackDB) -- före standardvärdena, så att gamla värden följer med
    applyDefaults(TidyPackDB, ns.defaults)
    ns.db = TidyPackDB
    -- Per karaktär. Fanns inte i 0.1.0, så det finns inget att migrera.
    TidyPackCharDB = TidyPackCharDB or {}
    applyDefaults(TidyPackCharDB, ns.charDefaults)
    ns.charDb = TidyPackCharDB

    for _, callback in ipairs(loadCallbacks) do
        callback(ns.db)
    end
end)

---------------------------------------------------------------------------
-- Spelets inställning för väskor i ett fönster
---------------------------------------------------------------------------

-- Tidy Pack ordnar om spelets fönster med alla väskor i ett. Med handkontroll använder
-- spelet alltid det fönstret, med mus bara när inställningen "Combined Bags" är på
-- (CVar combinedBags, samma som valet i väskans meny). Tidy Pack slår på den en gång.
-- Stänger spelaren av den igen får den vara avstängd.
ns.RegisterEvent("PLAYER_LOGIN", function()
    if ns.db.combinedBagsTurnedOn then
        return
    end
    ns.db.combinedBagsTurnedOn = true
    if not GetCVarBool("combinedBags") then
        SetCVar("combinedBags", 1)
        ns.Print(L["Turned on the game's setting that shows all bags in one window."])
    end
end)
