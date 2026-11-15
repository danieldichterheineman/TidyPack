-- TidyPack – BagSwap.lua
-- Swaps a bag with one click. When you right-click a bag in the group Bags (or choose Equip on
-- the controller) and all four bag slots are full, Tidy Pack replaces your smallest bag with the
-- new one. The game then moves the items from the old bag to the new one.
-- If a bag slot is empty, the game handles it itself.
-- ⚠️ Works only outside combat. Special bags (e.g. quivers and herb bags) aren't swapped,
-- because they only hold certain items.

local _, ns = ...
local L = ns.L

local NUM_BAGS = Constants.InventoryConstants.NumBagSlots -- the four normal bag slots

-- Windows where a right-click does something else with the item: sells it, puts it in the bank
-- or attaches it. Then Tidy Pack doesn't swap bags.
local OTHER_WINDOWS = { "MerchantFrame", "BankFrame", "MailFrame", "TradeFrame", "GuildBankFrame", "AuctionHouseFrame" }

-- Pattern for the line "14 Slot Bag" in a bag's tooltip. It is built from the game's own text
-- (CONTAINER_SLOTS, "%d Slot %s" in English) when it exists, so it works in more languages.
local slotPattern = "(%d+) Slot"
if type(CONTAINER_SLOTS) == "string" and CONTAINER_SLOTS:find("%d", 1, true) then
    slotPattern = CONTAINER_SLOTS
        :gsub("[%(%)%.%+%-%*%?%[%]%^%$]", "%%%0")
        :gsub("%%d", "(%%d+)")
        :gsub("%%s", ".+")
end

-- Slots per bag, so the tooltip only has to be read once per kind of bag.
local sizeByItemID = {}

-- Slots in a bag that lies among the items (not in a bag slot). The game has no function for
-- that, so Tidy Pack reads the line "14 Slot Bag" in the bag's tooltip.
local function getBagItemSize(bagID, slot, itemID)
    if sizeByItemID[itemID] then
        return sizeByItemID[itemID]
    end
    local data = C_TooltipInfo.GetBagItem(bagID, slot)
    if data and data.lines then
        for _, line in ipairs(data.lines) do
            local size = line.leftText and line.leftText:match(slotPattern)
            if size then
                sizeByItemID[itemID] = tonumber(size)
                return sizeByItemID[itemID]
            end
        end
    end
    return nil
end

-- True if the item is a normal bag, not a special bag.
local function isNormalBag(itemID)
    local _, _, _, _, _, classID = C_Item.GetItemInfoInstant(itemID)
    return classID == Enum.ItemClass.Container and (C_Item.GetItemFamily(itemID) or 0) == 0
end

local function hasEmptyBagSlot()
    for bagID = 1, NUM_BAGS do
        if C_Container.GetContainerNumSlots(bagID) == 0 then
            return true
        end
    end
    return false
end

-- The smallest normal bag in a bag slot that is smaller than newSize. The bag the new bag lies
-- in can't be replaced, since the new one would then move into itself.
local function findBagToReplace(newSize, fromBagID)
    local bestBag, bestSize
    for bagID = 1, NUM_BAGS do
        local size = C_Container.GetContainerNumSlots(bagID)
        local _, family = C_Container.GetContainerNumFreeSlots(bagID)
        if bagID ~= fromBagID and (family or 0) == 0 and size > 0 and size < newSize
            and (not bestSize or size < bestSize) then
            bestBag, bestSize = bagID, size
        end
    end
    return bestBag, bestSize
end

-- True if the bag would make the bags bigger: a bag slot is empty, or the bag is bigger than one
-- of your normal bags. Layout.lua then shows a green arrow on it.
function ns.IsBagUpgrade(bagID, slot, itemID)
    if not isNormalBag(itemID) then
        return false
    end
    if hasEmptyBagSlot() then
        return true
    end
    local size = getBagItemSize(bagID, slot, itemID)
    return size ~= nil and findBagToReplace(size, bagID) ~= nil
end

local function isOtherWindowOpen()
    for _, name in ipairs(OTHER_WINDOWS) do
        local frame = _G[name]
        if frame and frame:IsShown() then
            return true
        end
    end
    return false
end

-- Runs after the game's own click on an item button, with mouse and controller.
local function onItemClicked(_, button)
    if CursorHasItem() then
        return -- left click: the item was picked up or moved
    end
    local bagID, slot = button:GetBagID(), button:GetID()
    if not bagID or bagID < 0 or bagID > NUM_BAGS then
        return
    end
    local info = C_Container.GetContainerItemInfo(bagID, slot)
    if not info or info.isLocked or not isNormalBag(info.itemID) then
        return -- not a bag, or the game is already busy with it
    end
    if isOtherWindowOpen() or hasEmptyBagSlot() then
        return -- the game handles the click itself
    end
    if InCombatLockdown() then
        ns.Print(L["Bags can't be swapped in combat."])
        return
    end
    local newSize = getBagItemSize(bagID, slot, info.itemID)
    if not newSize then
        ns.Print(L["Couldn't read how big the bag is."])
        return
    end
    local target = findBagToReplace(newSize, bagID)
    if not target then
        ns.Print(L["All your bags are already this big or bigger."])
        return
    end
    -- Pick up the new bag and put it in the bag slot. The game swaps the bags and moves the
    -- items. If that fails, the bag is put back.
    C_Container.PickupContainerItem(bagID, slot)
    PutItemInBag(C_Container.ContainerIDToInventoryID(target))
    if CursorHasItem() then
        ClearCursor()
    end
end

-- The game sends this event last in every click on an item button.
EventRegistry:RegisterCallback("ContainerFrameItemButton.OnItemClicked", onItemClicked, ns)
