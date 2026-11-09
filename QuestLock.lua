-- TidyPack – QuestLock.lua
-- Låser saker som du behöver: quest-saker, vanliga saker som en pågående quest kräver, och
-- saker i dina utrustningsset. Hos en handlare går låsta saker inte att klicka på
-- (Layout.lua), och Sell Junk säljer dem aldrig (Junk.lua).
-- ⚠️ Vanliga saker som en quest kräver känns igen på namnet i questloggens text, t.ex.
-- "Linen Cloth: 3/10", alltså på spelets språk.
-- ⚠️ Spelets egen knapp "Sell All Junk" i handlarfönstret känner inte till låsen.

local addonName, ns = ...
local L = ns.L

local neededBy = {}   -- sakens namn → questens namn, för saker som en pågående quest kräver
local setItems = {}   -- itemID → true, för saker i ett utrustningsset

-- Sakens namn i ett mål i questloggen, t.ex. "Linen Cloth: 3/10" eller "3/10 Linen Cloth".
local function objectiveItemName(text)
    return text:match("^(.-):%s*%d+%s*/%s*%d+") or text:match("^%d+%s*/%s*%d+%s+(.+)$")
end

-- Går igenom questloggen och noterar vilka saker varje pågående quest kräver.
local function scanQuests()
    wipe(neededBy)
    local numEntries = C_QuestLog.GetNumQuestLogEntries()
    for index = 1, numEntries do
        local info = C_QuestLog.GetInfo(index)
        if info and not info.isHeader and info.questID then
            local objectives = C_QuestLog.GetQuestObjectives(info.questID)
            if objectives then
                for _, objective in ipairs(objectives) do
                    -- Även mål som redan är klara: sakerna ska ju lämnas in.
                    local name = objective.type == "item" and objective.text and objectiveItemName(objective.text)
                    if name then
                        neededBy[name] = info.title
                    end
                end
            end
        end
    end
end

-- Går igenom dina utrustningsset och noterar vilka saker de består av.
local function scanEquipmentSets()
    wipe(setItems)
    if not C_EquipmentSet.CanUseEquipmentSets() then
        return
    end
    for _, setID in ipairs(C_EquipmentSet.GetEquipmentSetIDs()) do
        local itemIDs = C_EquipmentSet.GetItemIDs(setID)
        if itemIDs then
            -- pairs, eftersom tabellen har hål där setet saknar en sak.
            for _, itemID in pairs(itemIDs) do
                if type(itemID) == "number" and itemID > 0 then
                    setItems[itemID] = true
                end
            end
        end
    end
end

local function refresh()
    if ns.Refresh then
        ns.Refresh()
    end
end

-- Questens namn om saken behövs för en pågående quest, annars nil.
function ns.GetQuestNeed(bagID, slot, info)
    local questInfo = C_Container.GetContainerItemQuestInfo(bagID, slot)
    if questInfo and (questInfo.isQuestItem or questInfo.questID) then
        return questInfo.questID and C_QuestLog.GetTitleForQuestID(questInfo.questID) or L["Quest item"]
    end
    return neededBy[ns.GetItemName(info.hyperlink)]
end

-- Sant om saken är låst: den behövs för en quest eller ingår i ett utrustningsset.
function ns.IsLocked(bagID, slot, info)
    return setItems[info.itemID] == true or ns.GetQuestNeed(bagID, slot, info) ~= nil
end

-- Sant medan handlarfönstret är öppet.
function ns.IsAtMerchant()
    return MerchantFrame ~= nil and MerchantFrame:IsShown()
end

ns.RegisterEvent("PLAYER_LOGIN", function()
    scanQuests()
    scanEquipmentSets()
end)

ns.RegisterEvent("QUEST_LOG_UPDATE", function()
    scanQuests()
    refresh()
end)

ns.RegisterEvent("EQUIPMENT_SETS_CHANGED", function()
    scanEquipmentSets()
    refresh()
end)

-- Låsen gäller bara hos handlaren, så väskfönstret uppdateras när handeln börjar och slutar.
ns.RegisterEvent("MERCHANT_SHOW", refresh)
ns.RegisterEvent("MERCHANT_CLOSED", refresh)

-- En rad i sakens tooltip, t.ex. "Needed for: The Cloth Collector".
TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
    if not data or type(data.id) ~= "number" then
        return
    end
    local name = C_Item.GetItemNameByID(data.id)
    local quest = name and neededBy[name]
    if quest then
        tooltip:AddLine(L["Needed for: %s"]:format(quest), 1, 0.82, 0)
    end
end)
