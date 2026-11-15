-- TidyPack – Core.lua
-- The addon's core: saved data and events.
-- The game runs this file when its turn comes in the TOC file.

-- The game gives each file two values: the addon's name and a private table (ns)
-- that all the addon's files share.
local addonName, ns = ...
local L = ns.L

-- Defaults for saved data. Add new keys here.
ns.defaults = {
    -- Becomes true when Tidy Pack has turned on the game's setting "Combined Bags" once.
    combinedBagsTurnedOn = false,
    -- Favorites (starred items): itemID → true (see Marks.lua).
    favorites = {},
    -- The junk list: itemID → true (see Marks.lua).
    junk = {},
    -- The player's own groups (see Groups.lua) and the number the next group gets.
    upgradeArrows = true,     -- green arrow on better gear (Layout.lua)
    replaceBagBar = true,     -- the logo instead of the game's bag bar (LogoButton.lua)
    showSearchBox = false,    -- the search box in the title bar on the Bags and Bank tabs (Layout.lua)
    groupByBag = false,       -- one group per bag (and bank tab) instead of by kind (Layout.lua, Bank.lua)
    tourDone = false,         -- the guide with the game's tips has been shown (Tour.lua)
    language = "auto",        -- the language: "auto" (the game's) or a code like "deDE" (Locales.lua)
    questOpen = {},           -- which parts of the Quests tab are open (QuestsView.lua)
    groups = {},
    nextGroupID = 1,
    -- Becomes true once Tidy Pack has told that Questie unlocks "Needed later"
    -- (see QuestHints.lua).
    questieNoticeShown = false,

    -- The options in the gear menu (Options.lua). Everything is on from the start except the
    -- search box and "Show by bag" above.
    suggestOnLoot = true,     -- ask when an item from the junk list is looted (MakeRoom.lua)
    suggestWhenFull = true,   -- suggest an item to delete when the bags are full (MakeRoom.lua)
    lockAtMerchant = true,    -- lock quest and equipment-set items at a merchant (Layout.lua)
    showQuestItemsInBags = true, -- quest items in the Bags tab (otherwise only in Quests, Layout.lua)
    bankTab = true,           -- the bank in the Bank tab instead of the game's bank window (Bank.lua)
    showCounts = true,        -- bag and bank counts in the item's tooltip (Characters.lua)
    showOtherCharacters = true, -- the counts on your other characters too (Characters.lua)
    -- itemID counts per character, shared by the account (new 2026-11-15, Characters.lua):
    -- ["Name-Realm"] = { name, realm, class, time, bags = { [itemID] = count }, bank = { [itemID] = count } }
    characters = {},
    tooltipLines = true,      -- the line "Tidy Pack group: …" in the item's tooltip (Groups.lua)
    junkValue = true,         -- the junk's value at the Junk heading (Layout.lua)
    questHints = true,        -- items that later quests need (QuestHints.lua)
    itemLevelAndBoE = true,   -- item level and BoE on gear (Layout.lua)
}

-- Defaults for data saved per character (TidyPackCharDB).
ns.charDefaults = {
    -- bank (new 2026-11-12, no default): what the bank held last, for the Bank tab away from the
    -- bank. { time, free, tabs, items = { { link, count, quality, icon, bag, slot, quest, bound, noValue } } }
    -- (see Bank.lua).
}

-- Writes a message in the player's own chat window, with the addon's name first.
function ns.Print(message)
    print(("|cff33ff99%s|r: %s"):format("Tidy Pack", message))
end

-- Fills in missing keys without overwriting what the player has already saved.
-- Tables within tables are filled the same way.
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
-- Saved data: version and migrations
---------------------------------------------------------------------------

-- The version of how the saved data is built. Raise it and add a step in
-- migrations when a saved key changes name, type or meaning, so the players'
-- old data comes along (see the skill wow-maintain).
local DATA_VERSION = 2
local CHAR_DATA_VERSION = 2

-- migrations[2] upgrades saved data from version 1 to 2, and so on.
local migrations = {
    -- 2: the Sell Junk button was removed (2026-11-09), so its setting is no longer needed.
    [2] = function(database)
        database.sellJunkButton = nil
    end,
}

local charMigrations = {
    -- 2: the Sets tab was removed (2026-11-14) because the game's own Equipment Manager exists.
    [2] = function(database)
        database.sets = nil
    end,
}

-- Upgrades saved data one step at a time to targetVersion.
local function migrate(database, targetVersion, stepTable)
    if next(database) == nil then
        database.dataVersion = targetVersion -- new install: nothing to upgrade
        return
    end
    local version = database.dataVersion or 1
    for target = version + 1, targetVersion do
        if stepTable[target] then
            stepTable[target](database)
        end
        version = target
    end
    database.dataVersion = version
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------

-- An invisible frame that receives events for the whole addon.
local eventFrame = CreateFrame("Frame")
local eventHandlers = {}

-- Lets all the addon's files listen to events, e.g.
-- ns.RegisterEvent("PLAYER_REGEN_ENABLED", function() ... end)
-- On a Mac the Alt key is called Option (the game reads it as Alt). Texts that mention Alt-click go
-- through here, so they say "Option-click" on a Mac (IsMacClient, BuildDocumentation in Forever).
function ns.KeyText(text)
    if IsMacClient and IsMacClient() then
        -- The translations also put "Alt-" before their word for click (e.g. "Alt-Klick").
        return (text:gsub("Alt%-", "Option-"))
    end
    return text
end

-- Makes a button wide enough for its text, but never narrower than minWidth. Translations are often
-- longer than English (e.g. "Umbenennen" or "Переименовать"), and a fixed width clips the text.
function ns.FitButtonText(button, minWidth)
    local text = button:GetFontString()
    local width = text and math.ceil(text:GetStringWidth()) + 24 or minWidth
    button:SetWidth(math.max(minWidth, width))
end

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

-- Functions to run once the saved data is loaded.
local loadCallbacks = {}

-- Other files (e.g. Layout.lua) register their start-up here.
function ns.OnLoad(callback)
    table.insert(loadCallbacks, callback)
end

ns.RegisterEvent("ADDON_LOADED", function(loadedName)
    if loadedName ~= addonName then
        return -- another addon loaded, not ours
    end
    -- Only now are the SavedVariables loaded from disk.
    TidyPackDB = TidyPackDB or {}
    migrate(TidyPackDB, DATA_VERSION, migrations) -- before the defaults, so old values come along
    applyDefaults(TidyPackDB, ns.defaults)
    ns.db = TidyPackDB
    -- Per character.
    TidyPackCharDB = TidyPackCharDB or {}
    migrate(TidyPackCharDB, CHAR_DATA_VERSION, charMigrations)
    applyDefaults(TidyPackCharDB, ns.charDefaults)
    ns.charDb = TidyPackCharDB

    -- The language first, so everything that starts below gets the right texts (Locales.lua).
    ns.SetLanguage(ns.db.language)

    for _, callback in ipairs(loadCallbacks) do
        callback(ns.db)
    end
end)

---------------------------------------------------------------------------
-- The game's setting for bags in one window
---------------------------------------------------------------------------

-- Tidy Pack rearranges the game's window with all bags in one. With a controller the game
-- always uses that window, with the mouse only when the setting "Combined Bags" is on
-- (CVar combinedBags, the same as the choice in the bag menu). Tidy Pack turns it on once.
-- If the player turns it off again, it stays off.
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

---------------------------------------------------------------------------
-- When the game stops something in Tidy Pack's name
---------------------------------------------------------------------------

-- The game then only shows the box "TidyPack has been blocked from an action only available to
-- the Blizzard UI", without saying what was stopped. The game sends the function's name
-- with the event, so Tidy Pack writes it in the chat – once per function – and the tester
-- can pass the line on. FORBIDDEN is for functions only the game itself may call,
-- BLOCKED for what is restricted in combat.
local reportedBlocks = {}

local function onActionBlocked(blockedAddon, functionName)
    if blockedAddon ~= addonName then
        return
    end
    functionName = tostring(functionName or "?")
    if reportedBlocks[functionName] then
        return
    end
    reportedBlocks[functionName] = true
    ns.Print(L["The game stopped %s because of Tidy Pack. Please send this line to the author."]
        :format(functionName))
end

ns.RegisterEvent("ADDON_ACTION_FORBIDDEN", onActionBlocked)
ns.RegisterEvent("ADDON_ACTION_BLOCKED", onActionBlocked)
