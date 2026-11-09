-- TidyPack – QuestHints.lua
-- Saker som en quest du inte har tagit än kommer att behöva. Spelet berättar inte vad en
-- quest kräver förrän du har tagit den, så funktionen kräver addonet Questie, närmare
-- bestämt dess databas QuestieDB. Tidy Pack använder bara QuestieDB:s öppna funktioner för
-- andra addons (LibQuestieDB, se docs/api.md i QuestieDB). Ingen data kopieras in i Tidy Pack.
-- En sak räknas när den behövs (som mål eller som nödvändig sak) för en quest som:
--   - du inte har gjort och inte har i questloggen (de som finns där låser QuestLock.lua),
--   - är för din ras och klass,
--   - du kan ta nu eller inom 5 nivåer, och som inte är för låg för dig.
-- Sådana saker får kartans gula utropstecken (Layout.lua) och en rad i tooltipen, och grå
-- sådana saker säljs eller föreslås aldrig för radering (Junk.lua).
-- ⚠️ QuestieDB:s data för Forevers nya quests är inte komplett enligt QuestieDB själv.
-- ⚠️ Utan Questie skriver Tidy Pack en gång (per konto) i chatten hur funktionen slås på.

local addonName, ns = ...
local L = ns.L

local LEVELS_AHEAD = 5        -- quests du kan ta inom så här många nivåer
local LEVELS_BELOW = 5        -- quests som är så här mycket lägre än du räknas inte
local MAX_TOOLTIP_QUESTS = 3  -- fler än så sammanfattas på en rad
local CONTRACT = 3            -- QuestieDB-version med rasmasker (Enum.raceMaskById)

local questie                 -- LibQuestieDB när Questie finns, annars nil
local raceMask, classMask     -- din ras och klass som bitar i QuestieDB:s masker
local questsForItem = {}      -- itemID → lista med questID, töms när nivå eller quests ändras
local questText = {}          -- questID → text i tooltipen

-- Sant om biten (en tvåpotens) finns i masken. Maskerna kan vara större än 32 bitar, så
-- bit.band går inte att använda.
local function hasBit(mask, bitValue)
    return math.floor(mask / bitValue) % 2 == 1
end

-- Sant om saken behövs för questen: som mål ("Collect 10 Linen Cloth") eller som en sak
-- som ska lämnas in utan att vara ett mål.
local function questNeedsItem(questID, itemID)
    local values = questie.Quest.GetAll(questID, { "objectives", "requiredSourceItems" })
    if not values then
        return false
    end
    local objectives, sourceItems = values[1], values[2]
    -- Målen ligger i sex grupper; den tredje är saker, som { itemID, text }.
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

-- Sant om questen är en som du kan ta nu eller snart.
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

-- Quests som du inte har tagit än och som behöver saken, eller nil utan Questie. Svaret
-- sparas per sorts sak tills din nivå eller dina quests ändras.
function ns.GetLaterQuests(itemID)
    if not questie or not itemID or not ns.db.questHints then
        return nil
    end
    local quests = questsForItem[itemID]
    if not quests then
        quests = {}
        -- QuestieDB är ett annat addon. Går något fel där ska Tidy Pack fungera ändå.
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

-- Sant om en quest du inte har tagit än behöver saken. now = true räknar direkt (för grå
-- saker innan de säljs, se Junk.lua). Annars räknas saker som inte är kända än lite i
-- taget i bakgrunden, högst några millisekunder per bildruta, och väskan läggs om när
-- något hittats. Questies databas kan vara långsam för saker som många quests använder,
-- och väskfönstret ska aldrig vänta på den.
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
        -- Positiva tal är zoner (AreaTable), negativa är kategorier som yrken och klasser.
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

-- Nivå eller quests ändrades: räkna om, högst en gång per bildruta.
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

-- Inställningen ändrades (Options.lua): räkna om och lägg ut väskan igen.
function ns.QuestHintsChanged()
    forgetAndRefresh()
end

-- QuestieDB, om addonet finns och är tillräckligt nytt (kontrakt 3), annars nil.
local function findQuestie()
    local lib = LibQuestieDB -- QuestieDB:s enda globala namn för andra addons
    if lib and lib.RequireContract and lib.RequireContract(CONTRACT) and lib.Quest and lib.Item then
        return lib
    end
    return nil
end

-- Sant om Questie (QuestieDB) finns. Inställningarna visar det.
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
        classMask = classID and 2 ^ (classID - 1) -- klassmasker: bit 1 = klass 1, och så vidare
        ns.RegisterEvent("PLAYER_LEVEL_UP", forgetAndRefresh)
        ns.RegisterEvent("QUEST_ACCEPTED", forgetAndRefresh)
        ns.RegisterEvent("QUEST_TURNED_IN", forgetAndRefresh)
        ns.RegisterEvent("QUEST_REMOVED", forgetAndRefresh)
        forgetAndRefresh()
    elseif LibQuestieDB == nil and not ns.db.questieNoticeShown then
        -- En gång per konto, och aldrig mer.
        ns.db.questieNoticeShown = true
        ns.Print(L["Install Questie to also see which items quests you haven't taken yet will need."])
    end
end)

-- Raderna i sakens tooltip.
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
    if #quests > MAX_TOOLTIP_QUESTS then
        tooltip:AddLine(L["...and %d more quests"]:format(#quests - MAX_TOOLTIP_QUESTS), NORMAL_FONT_COLOR:GetRGB())
    end
end)
