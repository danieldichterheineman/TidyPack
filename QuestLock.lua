-- TidyPack – QuestLock.lua
-- Låser saker som du behöver: quest-saker, vanliga saker som en pågående quest kräver, och
-- saker i dina utrustningsset. Hos en handlare går låsta saker inte att klicka på
-- (Layout.lua och Gamepad.lua), och de föreslås aldrig för radering (Junk.lua).
-- ⚠️ Vanliga saker som en quest kräver känns igen på namnet i questloggens text, t.ex.
-- "Linen Cloth: 3/10", alltså på spelets språk. Antalet man har och behöver kommer ur
-- questloggens numFulfilled och numRequired och visas på rutan ("3/7"), i tooltipen och i
-- fliken Quests (QuestsView.lua). Har du flera högar av en quest-sak räknas bara så många som
-- behövs som quest-saker; resten går att sälja (UpdateQuestStacks).
-- ⚠️ Spelets egen knapp "Sell All Junk" i handlarfönstret känner inte till låsen.

local _, ns = ...
local L = ns.L

-- För varje sak som en pågående quest kräver (på namn): { title, questID, have, need, finished,
-- more }, där have och need är antalet man har och antalet som behövs (3 av 7) och more är hur
-- många fler quests som också behöver saken.
local neededBy = {}
local scanned = {}    -- nästa genomgång av questloggen, byts mot neededBy när något ändrats
local questList = {}  -- quests som kräver saker: { questID, title, level, ready, objectives = { { name, have, need, finished } } }
local lastSignature   -- sammanfattning av förra genomgången, för att se om något ändrats
local surplus = {}    -- bagID * 1000 + slot → true för högar som är över det en quest behöver
local setItems = {}   -- itemID → true, för saker i ett utrustningsset

-- Sakens namn i ett mål i questloggen, t.ex. "Linen Cloth: 3/10" eller "3/10 Linen Cloth".
local function objectiveItemName(text)
    return text:match("^(.-):%s*%d+%s*/%s*%d+") or text:match("^%d+%s*/%s*%d+%s+(.+)$")
end

-- En text som säger allt väskan visar om questerna. Är den lika som förra gången har inget ändrats.
local function signatureOf(list)
    local parts = {}
    for _, quest in ipairs(list) do
        parts[#parts + 1] = quest.questID .. (quest.ready and "r" or "p")
        for _, objective in ipairs(quest.objectives) do
            parts[#parts + 1] = ("%s=%d/%d%s"):format(objective.name, objective.have, objective.need,
                objective.finished and "f" or "")
        end
    end
    return table.concat(parts, "|")
end

-- Går igenom questloggen och noterar vilka saker varje pågående quest kräver, och hur många
-- (questloggens numFulfilled och numRequired). Returnerar sant om något ändrades sedan förra
-- gången.
local function scanQuests()
    wipe(scanned)
    local list = {}
    local numEntries = C_QuestLog.GetNumQuestLogEntries()
    for index = 1, numEntries do
        local info = C_QuestLog.GetInfo(index)
        if info and not info.isHeader and info.questID then
            local objectives = C_QuestLog.GetQuestObjectives(info.questID)
            local quest
            if objectives then
                for _, objective in ipairs(objectives) do
                    -- Även mål som redan är klara: sakerna ska ju lämnas in.
                    local name = objective.type == "item" and objective.text and objectiveItemName(objective.text)
                    if name then
                        quest = quest or {
                            questID = info.questID,
                            title = info.title,
                            level = info.level or 0,
                            ready = C_QuestLog.ReadyForTurnIn(info.questID) == true,
                            objectives = {},
                        }
                        local have, need = objective.numFulfilled or 0, objective.numRequired or 0
                        local finished = objective.finished == true
                        quest.objectives[#quest.objectives + 1] = { name = name, have = have, need = need, finished = finished }
                        local record = scanned[name]
                        if record then
                            -- Flera quests behöver samma sak: den första visas, och tooltipen nämner de andra.
                            record.more = record.more + 1
                            record.need = math.max(record.need, need)
                        else
                            scanned[name] = { title = info.title, questID = info.questID, have = have, need = need,
                                finished = finished, more = 0 }
                        end
                    end
                end
            end
            if quest then
                list[#list + 1] = quest
            end
        end
    end
    local signature = signatureOf(list)
    if signature == lastSignature then
        return false
    end
    lastSignature = signature
    neededBy, scanned = scanned, neededBy
    questList = list
    return true
end

-- Vad en quest kräver av en sak (på namn): { title, questID, have, need, finished, more }, eller nil.
function ns.GetQuestRecord(name)
    return neededBy[name]
end

-- Quests som kräver saker, i questloggens ordning (se scanQuests).
function ns.GetQuestList()
    return questList
end

-- Sant om någon quest med saker är klar att lämna in (pricken på fliken Quests).
function ns.HasReadyQuest()
    for _, quest in ipairs(questList) do
        if quest.ready then
            return true
        end
    end
    return false
end

-- Avgör vilka högar av en quest-sak som behövs och vilka som är över: har du flera högar av
-- samma sak tas de största först tills antalet räcker, och resten räknas inte som quest-saker
-- (de ligger bland vanliga saker och går att sälja). En ensam hög är alltid kvar hel, och saker
-- som spelet själv markerat som quest-saker rörs aldrig. Layout.lua anropar den före varje
-- genomgång.
local stacksByName = {}

function ns.UpdateQuestStacks()
    wipe(surplus)
    if next(neededBy) == nil then
        return
    end
    for _, stacks in pairs(stacksByName) do
        wipe(stacks)
    end
    for bagID = 0, Constants.InventoryConstants.NumBagSlots do
        for slot = 1, C_Container.GetContainerNumSlots(bagID) do
            local info = C_Container.GetContainerItemInfo(bagID, slot)
            if info then
                local name = ns.GetItemName(info.hyperlink)
                if neededBy[name] then
                    local questInfo = C_Container.GetContainerItemQuestInfo(bagID, slot)
                    if not (questInfo and (questInfo.isQuestItem or questInfo.questID)) then
                        local stacks = stacksByName[name]
                        if not stacks then
                            stacks = {}
                            stacksByName[name] = stacks
                        end
                        stacks[#stacks + 1] = { key = bagID * 1000 + slot, count = info.stackCount or 1 }
                    end
                end
            end
        end
    end
    for name, stacks in pairs(stacksByName) do
        local record = neededBy[name]
        if record and record.need > 0 and #stacks > 1 then
            table.sort(stacks, function(a, b)
                if a.count ~= b.count then
                    return a.count > b.count
                end
                return a.key < b.key
            end)
            local covered = 0
            for _, stack in ipairs(stacks) do
                if covered >= record.need then
                    surplus[stack.key] = true
                else
                    covered = covered + stack.count
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

-- Sant om saken behövs för en quest: en quest-sak, eller en vanlig sak som en pågående
-- quest kräver.
function ns.IsQuestItem(bagID, slot, info)
    local questInfo = C_Container.GetContainerItemQuestInfo(bagID, slot)
    if questInfo and (questInfo.isQuestItem or questInfo.questID) then
        return true
    end
    return neededBy[ns.GetItemName(info.hyperlink)] ~= nil and not surplus[bagID * 1000 + slot]
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
    local record = name and neededBy[name]
    if record then
        tooltip:AddLine(L["Needed for: %s (%d/%d)"]:format(record.title, record.have, record.need),
            NORMAL_FONT_COLOR:GetRGB())
        if record.more == 1 then
            tooltip:AddLine(L["And 1 more quest."], NORMAL_FONT_COLOR:GetRGB())
        elseif record.more > 1 then
            tooltip:AddLine(L["And %d more quests."]:format(record.more), NORMAL_FONT_COLOR:GetRGB())
        end
    end
    if ns.IsLockedButton and ns.IsLockedButton(tooltip:GetOwner()) then
        tooltip:AddLine(L["Locked by Tidy Pack: can't be sold."], RED_FONT_COLOR:GetRGB())
    end
end)
