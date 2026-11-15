-- TidyPack – QuestLock.lua
-- Locks items you need: quest items, normal items an active quest needs, and items in your
-- equipment sets. At a merchant locked items can't be clicked (Layout.lua and Gamepad.lua),
-- and they are never suggested for deletion (Junk.lua).
-- ⚠️ Normal items a quest needs are recognised by their name in the quest log's text, e.g.
-- "Linen Cloth: 3/10", so in the game's language. How many you have and need come from the
-- quest log's numFulfilled and numRequired and show on the button ("3/7"), in the tooltip and in
-- the Quests tab (QuestsView.lua). With several stacks of a quest item, only as many as are
-- needed count as quest items; the rest can be sold (UpdateQuestStacks).
-- ⚠️ The game's own "Sell All Junk" button in the merchant window doesn't know about the locks.

local _, ns = ...
local L = ns.L

-- For each item an active quest needs (by name): { title, questID, have, need, finished,
-- more }, where have and need are how many you have and need (3 of 7) and more is how
-- many other quests also need the item.
local neededBy = {}
local scanned = {}    -- the next pass of the quest log, swapped with neededBy when something changed
local questList = {}  -- quests that need items: { questID, title, level, ready, objectives = { { name, have, need, finished } } }
local lastSignature   -- summary of the last pass, to see if something changed
local surplus = {}    -- bagID * 1000 + slot → true for stacks beyond what a quest needs
local setItems = {}   -- itemID → true, for items in an equipment set

-- The item's name in a quest log objective, e.g. "Linen Cloth: 3/10" or "3/10 Linen Cloth".
local function objectiveItemName(text)
    return text:match("^(.-):%s*%d+%s*/%s*%d+") or text:match("^%d+%s*/%s*%d+%s+(.+)$")
end

-- A text that says everything the bags show about quests. If it's the same as last time, nothing changed.
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

-- Goes through the quest log and notes which items each active quest needs, and how many
-- (the quest log's numFulfilled and numRequired). Returns true if something changed since the
-- last time.
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
                    -- Also objectives already done: the items must still be handed in.
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
                            -- Several quests need the same item: the first shows, and the tooltip names the others.
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

-- What a quest needs of an item (by name): { title, questID, have, need, finished, more }, or nil.
function ns.GetQuestRecord(name)
    return neededBy[name]
end

-- Quests that need items, in the quest log's order (see scanQuests).
function ns.GetQuestList()
    return questList
end

-- True if a quest with items is ready to turn in (the dot on the Quests tab).
function ns.HasReadyQuest()
    for _, quest in ipairs(questList) do
        if quest.ready then
            return true
        end
    end
    return false
end

-- Decides which stacks of a quest item are needed and which are extra: with several stacks of
-- the same item the biggest are taken first until the count is reached, and the rest don't count
-- as quest items (they lie among normal items and can be sold). A single stack always stays
-- whole, and items the game itself marks as quest items are never touched. Layout.lua calls this
-- before every pass.
local stacksByName = {}

function ns.UpdateQuestStacks()
    wipe(surplus)
    if next(neededBy) == nil then
        return
    end
    for _, stacks in pairs(stacksByName) do
        wipe(stacks)
    end
    for bagID = 0, Constants.InventoryConstants.NumBagSlots + Constants.InventoryConstants.NumReagentBagSlots do
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

-- Goes through your equipment sets and notes which items they hold.
local function scanEquipmentSets()
    wipe(setItems)
    if not C_EquipmentSet.CanUseEquipmentSets() then
        return
    end
    for _, setID in ipairs(C_EquipmentSet.GetEquipmentSetIDs()) do
        local itemIDs = C_EquipmentSet.GetItemIDs(setID)
        if itemIDs then
            -- pairs, because the table has holes where the set lacks an item.
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

-- True if the item is needed for a quest: a quest item, or a normal item an active quest
-- needs.
function ns.IsQuestItem(bagID, slot, info)
    local questInfo = C_Container.GetContainerItemQuestInfo(bagID, slot)
    if questInfo and (questInfo.isQuestItem or questInfo.questID) then
        return true
    end
    return neededBy[ns.GetItemName(info.hyperlink)] ~= nil and not surplus[bagID * 1000 + slot]
end

-- True if the item is in one of your equipment sets.
function ns.IsInEquipmentSet(itemID)
    return setItems[itemID] == true
end

-- True if the item is locked: a quest needs it or it is in one of the game's equipment sets.
function ns.IsLocked(bagID, slot, info)
    return ns.IsInEquipmentSet(info.itemID) or ns.IsQuestItem(bagID, slot, info)
end

-- True while the merchant window is open.
function ns.IsAtMerchant()
    return MerchantFrame ~= nil and MerchantFrame:IsShown()
end

ns.RegisterEvent("PLAYER_LOGIN", function()
    scanQuests()
    scanEquipmentSets()
end)

-- QUEST_LOG_UPDATE comes often, several times in a row, e.g. for every quest progress.
-- So the quest log is read at most once per frame, and the bag window updates only
-- when a quest needs something new.
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

-- The locks apply only at a merchant, so the bag window updates when trading starts and ends.
ns.RegisterEvent("MERCHANT_SHOW", refresh)
ns.RegisterEvent("MERCHANT_CLOSED", refresh)

-- Lines in the item's tooltip: "Needed for: The Cloth Collector", and at a merchant a red line
-- on items Tidy Pack has locked.
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
