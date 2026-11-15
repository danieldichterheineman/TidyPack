-- TidyPack – QuestHints.lua
-- Items that a quest you haven't taken yet will need. The game doesn't tell what a quest needs
-- until you have taken it, so this feature needs the addon Questie, more precisely its
-- database QuestieDB. Tidy Pack uses only QuestieDB's public functions for other addons
-- (LibQuestieDB, see docs/api.md in QuestieDB). No data is copied into Tidy Pack.
-- An item counts when it is needed (as an objective or a required item) for a quest that:
--   - you haven't done and don't have in the quest log (those are locked by QuestLock.lua),
--   - is for your race and class,
--   - you can take now or within 5 levels, and that isn't too low for you.
-- Such items get the map's yellow exclamation mark (Layout.lua) and a line in the tooltip, and
-- grey ones are never sold or suggested for deletion (Junk.lua).
-- ⚠️ QuestieDB's data for Forever's new quests isn't complete, according to QuestieDB itself.
-- ⚠️ Without Questie, Tidy Pack says once (per account) in the chat how to turn this on.

local _, ns = ...
local L = ns.L

local LEVELS_AHEAD = 5        -- quests you can take within this many levels
local LEVELS_BELOW = 5        -- quests this much lower than you don't count
local MAX_TOOLTIP_QUESTS = 3  -- more than this are summed up in one line
local CONTRACT = 3            -- the QuestieDB version with race masks (Enum.raceMaskById)

local questie                 -- LibQuestieDB when Questie exists, otherwise nil
local raceMask, classMask     -- your race and class as bits in QuestieDB's masks
local questsForItem = {}      -- itemID → list of questIDs, cleared when level or quests change
local questText = {}          -- questID → text in the tooltip

-- True if the bit (a power of two) is in the mask. The masks can be larger than 32 bits, so
-- bit.band can't be used.
local function hasBit(mask, bitValue)
    return math.floor(mask / bitValue) % 2 == 1
end

-- True if the quest needs the item: as an objective ("Collect 10 Linen Cloth") or as an item
-- handed in without being an objective.
local function questNeedsItem(questID, itemID)
    local values = questie.Quest.GetAll(questID, { "objectives", "requiredSourceItems" })
    if not values then
        return false
    end
    local objectives, sourceItems = values[1], values[2]
    -- The objectives come in six groups; the third is items, as { itemID, text }.
    local itemObjectives = type(objectives) == "table" and objectives[3]
    if type(itemObjectives) == "table" then
        for _, objective in pairs(itemObjectives) do
            if objective == itemID or (type(objective) == "table" and objective[1] == itemID) then
                return true
            end
        end
    end
    if type(sourceItems) == "table" then
        for _, id in pairs(sourceItems) do
            if id == itemID then
                return true
            end
        end
    end
    return false
end

-- True if the quest is one you can take now or soon.
local function questFits(questID, playerLevel)
    if C_QuestLog.IsQuestFlaggedCompleted(questID) or C_QuestLog.GetLogIndexForQuestID(questID) then
        return false
    end
    local values = questie.Quest.GetAll(questID, { "requiredLevel", "questLevel", "requiredRaces", "requiredClasses" })
    if not values then
        return false
    end
    local requiredLevel, questLevel = values[1] or 0, values[2] or 0
    local races, classes = values[3] or 0, values[4] or 0
    if requiredLevel > playerLevel + LEVELS_AHEAD then
        return false
    end
    if questLevel > 0 and questLevel < playerLevel - LEVELS_BELOW then
        return false
    end
    if races ~= 0 and raceMask and not hasBit(races, raceMask) then
        return false
    end
    if classes ~= 0 and classMask and not hasBit(classes, classMask) then
        return false
    end
    return true
end

-- Quests you haven't taken yet that need the item, or nil without Questie. The answer is
-- kept per kind of item until your level or your quests change.
function ns.GetLaterQuests(itemID)
    if not questie or not itemID or not ns.db.questHints then
        return nil
    end
    local quests = questsForItem[itemID]
    if not quests then
        quests = {}
        -- QuestieDB is another addon. If something fails there, Tidy Pack must still work.
        local ok = pcall(function()
            local related = questie.Item.Get(itemID, "relatedQuests")
            if type(related) ~= "table" then
                return
            end
            local playerLevel = UnitLevel("player")
            for _, questID in pairs(related) do
                if questNeedsItem(questID, itemID) and questFits(questID, playerLevel) then
                    quests[#quests + 1] = questID
                end
            end
        end)
        if not ok then
            wipe(quests)
        end
        questsForItem[itemID] = quests
    end
    return quests
end

-- True if a quest you haven't taken yet needs the item. now = true counts at once (for grey
-- items before they are sold, see Junk.lua). Otherwise items not known yet are counted a little
-- at a time in the background, at most a few milliseconds per frame, and the bags are laid out
-- again when something is found. Questie's database can be slow for items many quests use,
-- and the bag window must never wait for it.
local WORK_BUDGET_MS = 3
local waiting, waitingList = {}, {}
local working, foundSomething = false, false

local function work()
    local started = debugprofilestop()
    while #waitingList > 0 and debugprofilestop() - started < WORK_BUDGET_MS do
        local itemID = table.remove(waitingList)
        waiting[itemID] = nil
        local quests = ns.GetLaterQuests(itemID)
        if quests and #quests > 0 then
            foundSomething = true
        end
    end
    if #waitingList > 0 then
        C_Timer.After(0, work)
        return
    end
    working = false
    if foundSomething then
        foundSomething = false
        if ns.Refresh then
            ns.Refresh()
        end
    end
end

function ns.IsNeededLater(itemID, now)
    if not questie or not itemID or not ns.db.questHints then
        return false
    end
    local quests = questsForItem[itemID]
    if not quests and now then
        quests = ns.GetLaterQuests(itemID)
    end
    if quests then
        return #quests > 0
    end
    if not waiting[itemID] then
        waiting[itemID] = true
        waitingList[#waitingList + 1] = itemID
        if not working then
            working = true
            C_Timer.After(0, work)
        end
    end
    return false
end

-- "The Cloth Collector (Westfall, level 24)".
local function describeQuest(questID)
    local text = questText[questID]
    if not text then
        local values = questie.Quest.GetAll(questID, { "name", "questLevel", "zoneOrSort" }) or {}
        local name, level, zoneID = values[1] or "?", values[2] or 0, values[3] or 0
        -- Positive numbers are zones (AreaTable), negative ones are categories like professions and classes.
        local zone = zoneID > 0 and C_Map.GetAreaInfo(zoneID) or nil
        if zone and zone ~= "" and level > 0 then
            text = L["%s (%s, level %d)"]:format(name, zone, level)
        elseif level > 0 then
            text = L["%s (level %d)"]:format(name, level)
        else
            text = name
        end
        questText[questID] = text
    end
    return text
end

-- Level or quests changed: count again, at most once per frame.
local refreshScheduled = false

local function forgetAndRefresh()
    wipe(questsForItem)
    if refreshScheduled then
        return
    end
    refreshScheduled = true
    C_Timer.After(0, function()
        refreshScheduled = false
        if ns.Refresh then
            ns.Refresh()
        end
    end)
end

-- The setting changed (Options.lua): count again and lay out the bags again.
function ns.QuestHintsChanged()
    forgetAndRefresh()
end

-- QuestieDB, if the addon exists and is new enough (contract 3), otherwise nil.
local function findQuestie()
    local lib = LibQuestieDB -- QuestieDB's only global name for other addons
    if lib and lib.RequireContract and lib.RequireContract(CONTRACT) and lib.Quest and lib.Item then
        return lib
    end
    return nil
end

-- True if Questie (QuestieDB) exists. The options show it.
function ns.HasQuestie()
    return findQuestie() ~= nil
end

ns.RegisterEvent("PLAYER_LOGIN", function()
    local lib = findQuestie()
    if lib then
        questie = lib
        local _, _, raceID = UnitRace("player")
        raceMask = lib.Enum and lib.Enum.raceMaskById and lib.Enum.raceMaskById[raceID]
        local _, _, classID = UnitClass("player")
        classMask = classID and 2 ^ (classID - 1) -- class masks: bit 1 = class 1, and so on
        ns.RegisterEvent("PLAYER_LEVEL_UP", forgetAndRefresh)
        ns.RegisterEvent("QUEST_ACCEPTED", forgetAndRefresh)
        ns.RegisterEvent("QUEST_TURNED_IN", forgetAndRefresh)
        ns.RegisterEvent("QUEST_REMOVED", forgetAndRefresh)
        forgetAndRefresh()
    elseif LibQuestieDB == nil and not ns.db.questieNoticeShown then
        -- Once per account, and never again.
        ns.db.questieNoticeShown = true
        ns.Print(L["Install Questie to also see which items quests you haven't taken yet will need."])
    end
end)

-- The lines in the item's tooltip.
TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
    if not questie or not data or type(data.id) ~= "number" then
        return
    end
    local quests = ns.GetLaterQuests(data.id)
    if not quests or #quests == 0 then
        return
    end
    for index = 1, math.min(#quests, MAX_TOOLTIP_QUESTS) do
        tooltip:AddLine(L["Needed later for: %s"]:format(describeQuest(quests[index])), NORMAL_FONT_COLOR:GetRGB())
    end
    -- The same words as the line "Needed for" (QuestLock.lua), singular for a single quest.
    local more = #quests - MAX_TOOLTIP_QUESTS
    if more == 1 then
        tooltip:AddLine(L["And 1 more quest."], NORMAL_FONT_COLOR:GetRGB())
    elseif more > 1 then
        tooltip:AddLine(L["And %d more quests."]:format(more), NORMAL_FONT_COLOR:GetRGB())
    end
end)
