-- TidyPack – QuestLock.lua
-- Låser saker som du behöver: quest-saker, vanliga saker som en pågående quest kräver, och
-- saker i dina utrustningsset. Hos en handlare går låsta saker inte att klicka på
-- (Layout.lua och Gamepad.lua), och Sell Junk säljer dem aldrig (Junk.lua).
-- ⚠️ Vanliga saker som en quest kräver känns igen på namnet i questloggens text, t.ex.
-- "Linen Cloth: 3/10", alltså på spelets språk.
-- ⚠️ Spelets egen knapp "Sell All Junk" i handlarfönstret känner inte till låsen.

local addonName, ns = ...
local L = ns.L

local neededBy = {}   -- sakens namn → questens namn, för saker som en pågående quest kräver
local scanned = {}    -- nästa genomgång av questloggen, jämförs med neededBy
local setItems = {}   -- itemID → true, för saker i ett utrustningsset

-- Sakens namn i ett mål i questloggen, t.ex. "Linen Cloth: 3/10" eller "3/10 Linen Cloth".
local function objectiveItemName(text)
    return text:match("^(.-):%s*%d+%s*/%s*%d+") or text:match("^%d+%s*/%s*%d+%s+(.+)$")
end

-- Sant om två tabeller har samma nycklar och värden.
local function sameContents(a, b)
    for key, value in pairs(a) do
        if b[key] ~= value then
            return false
        end
    end
    for key in pairs(b) do
        if a[key] == nil then
            return false
        end
    end
    return true
end

-- Går igenom questloggen och noterar vilka saker varje pågående quest kräver. Returnerar
-- sant om något ändrades sedan förra gången.
local function scanQuests()
    wipe(scanned)
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
                        scanned[name] = info.title
                    end
                end
            end
        end
    end
    if sameContents(scanned, neededBy) then
        return false
    end
    neededBy, scanned = scanned, neededBy
    return true
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

-- Sant om saken behövs för en quest: en quest-sak, eller en vanlig sak som en pågående
-- quest kräver.
function ns.IsQuestItem(bagID, slot, info)
    local questInfo = C_Container.GetContainerItemQuestInfo(bagID, slot)
    if questInfo and (questInfo.isQuestItem or questInfo.questID) then
        return true
    end
    return neededBy[ns.GetItemName(info.hyperlink)] ~= nil
end

-- Sant om saken ingår i ett av dina utrustningsset.
function ns.IsInEquipmentSet(itemID)
    return setItems[itemID] == true
end

-- Sant om saken är låst: den behövs för en quest eller ingår i ett utrustningsset eller
-- i ett av Tidy Packs egna set (Sets.lua).
function ns.IsLocked(bagID, slot, info)
    return ns.IsInEquipmentSet(info.itemID) or ns.IsInAnySet(info.itemID) or ns.IsQuestItem(bagID, slot, info)
end

-- Sant medan handlarfönstret är öppet.
function ns.IsAtMerchant()
    return MerchantFrame ~= nil and MerchantFrame:IsShown()
end

ns.RegisterEvent("PLAYER_LOGIN", function()
    scanQuests()
    scanEquipmentSets()
end)

-- QUEST_LOG_UPDATE kommer ofta, flera gånger i rad, t.ex. för varje framsteg i en quest.
-- Questloggen gås därför igenom högst en gång per bildruta, och väskfönstret uppdateras bara
-- när någon quest kräver något nytt.
local scanScheduled = false

ns.RegisterEvent("QUEST_LOG_UPDATE", function()
    if scanScheduled then
        return
    end
    scanScheduled = true
    C_Timer.After(0, function()
        scanScheduled = false
        if scanQuests() then
            refresh()
        end
    end)
end)

ns.RegisterEvent("EQUIPMENT_SETS_CHANGED", function()
    scanEquipmentSets()
    refresh()
end)

-- Låsen gäller bara hos handlaren, så väskfönstret uppdateras när handeln börjar och slutar.
ns.RegisterEvent("MERCHANT_SHOW", refresh)
ns.RegisterEvent("MERCHANT_CLOSED", refresh)

-- Rader i sakens tooltip: "Needed for: The Cloth Collector", och hos en handlare en röd rad
-- på saker som Tidy Pack har låst.
TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
    if not data or type(data.id) ~= "number" then
        return
    end
    local name = C_Item.GetItemNameByID(data.id)
    local quest = name and neededBy[name]
    if quest then
        tooltip:AddLine(L["Needed for: %s"]:format(quest), NORMAL_FONT_COLOR:GetRGB())
    end
    if ns.IsLockedButton and ns.IsLockedButton(tooltip:GetOwner()) then
        tooltip:AddLine(L["Locked by Tidy Pack: can't be sold."], RED_FONT_COLOR:GetRGB())
    end
end)
