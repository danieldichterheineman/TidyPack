-- TidyPack – BagSwap.lua
-- Byter väska med ett klick. När du högerklickar på en väska i gruppen Bags (eller väljer
-- Equip på handkontrollen) och alla fyra väskplatser är fulla, byter Tidy Pack ut din
-- minsta väska mot den nya. Spelet flyttar då sakerna från den gamla väskan till den nya.
-- Finns en tom väskplats sköter spelet det själv.
-- ⚠️ Fungerar bara utanför strid. Specialväskor (t.ex. koger och väskor för örter) byts
-- inte, eftersom de bara rymmer vissa saker.

local addonName, ns = ...
local L = ns.L

local NUM_BAGS = Constants.InventoryConstants.NumBagSlots -- de fyra vanliga väskplatserna

-- Fönster där ett högerklick gör något annat med saken: säljer den, lägger den i banken
-- eller bifogar den. Då byter Tidy Pack inte väska.
local OTHER_WINDOWS = { "MerchantFrame", "BankFrame", "MailFrame", "TradeFrame", "GuildBankFrame", "AuctionHouseFrame" }

-- Mönster för raden "14 Slot Bag" i väskans tooltip. Det byggs av spelets egen text
-- (CONTAINER_SLOTS, "%d Slot %s" på engelska) när den finns, så att det fungerar på fler språk.
local slotPattern = "(%d+) Slot"
if type(CONTAINER_SLOTS) == "string" and CONTAINER_SLOTS:find("%d", 1, true) then
    slotPattern = CONTAINER_SLOTS
        :gsub("[%(%)%.%+%-%*%?%[%]%^%$]", "%%%0")
        :gsub("%%d", "(%%d+)")
        :gsub("%%s", ".+")
end

-- Antal platser per väska, så att tooltipen bara behöver läsas en gång per sorts väska.
local sizeByItemID = {}

-- Antal platser i en väska som ligger bland sakerna (inte på en väskplats). Spelet har
-- ingen funktion för det, så Tidy Pack läser raden "14 Slot Bag" i väskans tooltip.
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

-- Sant om saken är en vanlig väska, inte en specialväska.
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

-- Den minsta vanliga väskan på en väskplats som är mindre än newSize. Väskan som den nya
-- väskan ligger i kan inte bytas ut, eftersom den nya då skulle flytta in i sig själv.
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

-- Sant om väskan skulle göra väskorna större: en väskplats är tom, eller väskan är större
-- än någon av dina vanliga väskor. Layout.lua visar då en grön pil på den.
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

-- Körs efter spelets eget klick på en ruta i väskorna, både med mus och handkontroll.
local function onItemClicked(_, button)
    if CursorHasItem() then
        return -- vänsterklick: saken plockades upp eller bytte plats
    end
    local bagID, slot = button:GetBagID(), button:GetID()
    if not bagID or bagID < 0 or bagID > NUM_BAGS then
        return
    end
    local info = C_Container.GetContainerItemInfo(bagID, slot)
    if not info or info.isLocked or not isNormalBag(info.itemID) then
        return -- inte en väska, eller så håller spelet redan på med den
    end
    if isOtherWindowOpen() or hasEmptyBagSlot() then
        return -- spelet sköter klicket själv
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
    -- Plocka upp den nya väskan och lägg den på väskplatsen. Spelet byter väskorna och
    -- flyttar sakerna. Går det inte läggs väskan tillbaka.
    C_Container.PickupContainerItem(bagID, slot)
    PutItemInBag(C_Container.ContainerIDToInventoryID(target))
    if CursorHasItem() then
        ClearCursor()
    end
end

-- Spelet skickar det här eventet sist i varje klick på en ruta i väskorna.
EventRegistry:RegisterCallback("ContainerFrameItemButton.OnItemClicked", onItemClicked, ns)
