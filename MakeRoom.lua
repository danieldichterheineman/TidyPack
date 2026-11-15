-- TidyPack – MakeRoom.lua
-- Suggestions of items to delete, in a small panel. Two occasions:
--   1. You loot an item on the junk list (Marks.lua): Tidy Pack asks right away whether to
--      delete it. Each item counts from when it was added to the list.
--   2. Something in the loot window doesn't fit (the game says "Inventory is full."): Tidy Pack
--      suggests an item from the junk list, otherwise the cheapest grey item – but only if what
--      you are trying to loot is worth more.
-- The panel hangs under the loot window when it is open, in the same kind of panel and as wide, so
-- it feels like part of it. Otherwise it shows at the top middle, where the game's own questions
-- show. What counts as junk is decided by ns.GetJunkKind (Junk.lua): favorites and locked
-- items, quest items and grey items a quest needs later are never suggested.
-- You confirm with a press on Delete. Both occasions can be turned off in the options.
-- ⚠️ The game lets an addon delete an item only when the player presses or clicks
--    (DeleteCursorItem needs a hardware event since patch 9.0.2, and deletes at most one
--    item per event since 9.1.5). So Tidy Pack never deletes anything by itself.
-- ⚠️ In combat the junk-list questions wait until combat is over. With a controller the panel is
--    hooked into the game's controls (the loot window's cursor, or as a question at the top middle),
--    but only outside combat.
-- ⚠️ The panel uses the game's loot window (LootFrame). If another addon replaces the
--    loot window, the panel shows at the top middle instead.

local _, ns = ...
local L = ns.L

local NUM_BAGS = Constants.InventoryConstants.NumBagSlots
local NUM_ALL_BAGS = NUM_BAGS + Constants.InventoryConstants.NumReagentBagSlots
local LOOT_WIDTH = 220     -- the same width as the game's loot window (LootFrame in LootFrame.xml)
local ALONE_WIDTH = 260    -- alone at the top middle
local ALONE_TOP = -135     -- where the game's own questions usually show
local TEXT_TOP = 30        -- below the panel's title, which is 20 units tall
local TEXT_INSET = 14      -- the background starts 6 units in, and the text 8 units more
local BUTTON_WIDTH, BUTTON_HEIGHT = 90, 22
local BOTTOM_SPACE = 44    -- the gap to the buttons, the buttons and the margin below them

local panel, message
local suggestion = {}           -- the suggested item: kind ("looted" or "full"), bagID, slot, itemID
local queue = {}                -- itemID of looted junk-list items, in turn
local seenCount = {}            -- itemID → count in the bags last time, for the junk-list items
local countsReady = false
local registeredAsPopup = false -- the panel is hooked to the controller as a question
local showNext                  -- defined further down

local function canUseNavigation()
    return SmartNavigation ~= nil and InputUtil.IsGamepadUIEnabled()
        and ns.CanUseNavigation ~= nil and ns.CanUseNavigation()
end

-- The item's value at a merchant: price × count. The second value is false if the game doesn't
-- have the item's data yet.
local function stackValue(link, count)
    local price = link and select(11, C_Item.GetItemInfo(link))
    return (price or 0) * (count or 1), price ~= nil
end

local function moneyText(value)
    if value > 0 then
        return GetMoneyString(value)
    end
    return L["no value"]
end

-- Free slots in normal bags, where anything fits.
local function freeNormalSlots()
    local free = 0
    for bagID = 0, NUM_BAGS do
        local slots, family = C_Container.GetContainerNumFreeSlots(bagID)
        if (family or 0) == 0 then
            free = free + (slots or 0)
        end
    end
    return free
end

-- The most valuable thing left in the loot window: link, value and whether the value is known.
local function bestLoot()
    local bestLink, bestValue, bestKnown
    for slot = 1, GetNumLootItems() do
        if GetLootSlotType(slot) == Enum.LootSlotType.Item then
            local link = GetLootSlotLink(slot)
            local _, _, quantity = GetLootSlotInfo(slot)
            if link then
                local value, known = stackValue(link, quantity)
                if not bestValue or value > bestValue then
                    bestLink, bestValue, bestKnown = link, value, known
                end
            end
        end
    end
    return bestLink, bestValue, bestKnown
end

-- The item in the bags best deleted so the new one fits. Only normal bags, because the
-- new one won't surely fit in a special bag.
local function findCandidate(lootValue, lootValueKnown)
    local bestBag, bestSlot, bestInfo, bestMarked, bestValue
    for bagID = 0, NUM_BAGS do
        local _, family = C_Container.GetContainerNumFreeSlots(bagID)
        if (family or 0) == 0 then
            for slot = 1, C_Container.GetContainerNumSlots(bagID) do
                local info = C_Container.GetContainerItemInfo(bagID, slot)
                local kind = info and ns.GetJunkKind(bagID, slot, info)
                if kind then
                    local marked = kind == "marked"
                    local value = info.hasNoValue and 0 or stackValue(info.hyperlink, info.stackCount)
                    -- The junk list is always suggested, grey only if the new item is worth more.
                    local allowed = marked or (lootValueKnown and value < lootValue)
                    -- The junk list comes before grey, and the cheapest first.
                    local better = not bestInfo or (marked and not bestMarked)
                        or (marked == bestMarked and value < bestValue)
                    if allowed and better then
                        bestBag, bestSlot, bestInfo, bestMarked, bestValue = bagID, slot, info, marked, value
                    end
                end
            end
        end
    end
    return bestBag, bestSlot, bestInfo, bestMarked, bestValue
end

-- Where an item from the junk list is, if it still counts as junk.
local function findListedItem(itemID)
    for bagID = 0, NUM_ALL_BAGS do
        for slot = 1, C_Container.GetContainerNumSlots(bagID) do
            local info = C_Container.GetContainerItemInfo(bagID, slot)
            if info and info.itemID == itemID and ns.GetJunkKind(bagID, slot, info) == "marked" then
                return bagID, slot, info
            end
        end
    end
    return nil
end

---------------------------------------------------------------------------
-- The panel
---------------------------------------------------------------------------

-- Puts the panel under the loot window if it is open, otherwise (or with alone) at the top middle.
-- Returns true when it ended up under the loot window.
local function placePanel(alone)
    local underLoot = not alone and LootFrame ~= nil and LootFrame:IsShown()
    local width = underLoot and LOOT_WIDTH or ALONE_WIDTH
    panel:SetParent(underLoot and LootFrame or UIParent)
    panel:SetFrameStrata(underLoot and LootFrame:GetFrameStrata() or "DIALOG")
    panel:ClearAllPoints()
    if underLoot then
        panel:SetPoint("TOP", LootFrame, "BOTTOM", 0, -2)
    else
        panel:SetPoint("TOP", UIParent, "TOP", 0, ALONE_TOP)
    end
    panel:SetWidth(width)
    message:SetWidth(width - 2 * TEXT_INSET)
    return underLoot
end

-- Unhooks the panel as a controller question. Not possible in combat; then it's done afterwards.
local function releasePopup()
    if registeredAsPopup and canUseNavigation() then
        GamepadMode.FrameControlsManager:HandlePopupHide(panel)
        registeredAsPopup = false
    end
end

local function showPanel(kind, text, bagID, slot, itemID, alone)
    suggestion.kind, suggestion.bagID, suggestion.slot, suggestion.itemID = kind, bagID, slot, itemID
    local underLoot = placePanel(alone)
    message:SetText(text)
    panel:SetHeight(TEXT_TOP + math.ceil(message:GetStringHeight()) + BOTTOM_SPACE)
    panel:Show()
    -- With a controller: under the loot window the buttons join the loot window's cursor (reached
    -- with the D-pad, and the cursor isn't moved there, so pressing A to loot never
    -- deletes). Alone at the top middle the panel becomes a question, like the game's own.
    if canUseNavigation() then
        if underLoot then
            releasePopup()
            SmartNavigation:RefreshButtonGroups(LootFrame)
        elseif not registeredAsPopup then
            GamepadMode.FrameControlsManager:HandlePopupShown(panel)
            registeredAsPopup = true
        end
    end
end

-- Hides the panel and shows the next question if more junk-list items were looted. If the
-- controller's cursor was on one of the panel's buttons under the loot window, it moves back
-- to the loot.
local function hidePanel()
    local current = canUseNavigation() and SmartNavigation:GetCurrentButton()
    panel:Hide()
    releasePopup()
    if current and current:GetParent() == panel and LootFrame:IsShown() then
        C_Timer.After(0, function()
            if canUseNavigation() then
                SmartNavigation:SelectTopLeftButton()
            end
        end)
    end
    C_Timer.After(0, function()
        showNext()
    end)
end

-- Deletes the suggested item, if it is still where it was and still counts as
-- junk. Runs only when the player presses Delete – the press is what lets the game
-- allow the deletion. Nothing else may run between the click and DeleteCursorItem, and
-- in combat the deletion is cancelled.
local function deleteSuggestion()
    local kind, bagID, slot, itemID = suggestion.kind, suggestion.bagID, suggestion.slot, suggestion.itemID
    if InCombatLockdown() then
        if kind == "looted" and itemID then
            table.insert(queue, 1, itemID)
        end
        hidePanel()
        return
    end
    local info = bagID and C_Container.GetContainerItemInfo(bagID, slot)
    if info and info.itemID == itemID and ns.GetJunkKind(bagID, slot, info) then
        ClearCursor()
        C_Container.PickupContainerItem(bagID, slot)
        local cursorKind, cursorItemID = GetCursorInfo()
        if cursorKind == "item" and cursorItemID == itemID then
            DeleteCursorItem()
        else
            ClearCursor()
        end
    end
    hidePanel()
end

---------------------------------------------------------------------------
-- When the bags are full
---------------------------------------------------------------------------

local function offerRoom()
    if InCombatLockdown() or not ns.db.suggestWhenFull or not LootFrame:IsShown() or freeNormalSlots() > 0 then
        if suggestion.kind == "full" and panel:IsShown() then
            hidePanel()
        end
        return
    end
    local lootLink, lootValue, lootKnown = bestLoot()
    local bagID, slot, info, marked, value
    if lootLink then
        bagID, slot, info, marked, value = findCandidate(lootValue, lootKnown)
    end
    if not bagID then
        if suggestion.kind == "full" and panel:IsShown() then
            hidePanel()
        end
        return
    end
    local text
    if marked then
        text = L["Your bags are full. Delete %s (on your junk list) to make room for %s?"]:format(info.hyperlink, lootLink)
    else
        text = L["Your bags are full. Delete %s (%s) to make room for %s (%s)?"]
            :format(info.hyperlink, moneyText(value), lootLink, moneyText(lootValue))
    end
    showPanel("full", text, bagID, slot, info.itemID)
end

---------------------------------------------------------------------------
-- When an item from the junk list is looted
---------------------------------------------------------------------------

-- Shows the question for the next looted junk-list item. Waits in combat and while the panel
-- already shows a question.
showNext = function()
    if panel:IsShown() or InCombatLockdown() or not ns.db.suggestOnLoot then
        return
    end
    while #queue > 0 do
        local itemID = table.remove(queue, 1)
        local bagID, slot, info = findListedItem(itemID)
        if bagID then
            showPanel("looted", L["You looted %s, which is on your junk list. Delete it?"]:format(info.hyperlink),
                bagID, slot, itemID)
            return
        end
    end
end

-- The count of every junk-list item right now, as a starting point.
local function countListed()
    wipe(seenCount)
    for itemID in pairs(ns.db.junk) do
        seenCount[itemID] = C_Item.GetItemCount(itemID)
    end
    countsReady = true
end

-- If a junk-list item has become more since last time, it was looted (or bought).
local function checkLooted()
    if not countsReady then
        countListed()
        return
    end
    local found = false
    for itemID in pairs(ns.db.junk) do
        local count = C_Item.GetItemCount(itemID)
        local before = seenCount[itemID]
        if before and count > before and ns.db.suggestOnLoot and not tContains(queue, itemID) then
            queue[#queue + 1] = itemID
            found = true
        end
        seenCount[itemID] = count
    end
    if found then
        showNext()
    end
end

-- Marks.lua calls this when an item is added to or removed from the list. An item counts
-- from when it was added, so you aren't asked about what you already have.
function ns.JunkListChanged(itemID)
    if ns.db.junk[itemID] then
        seenCount[itemID] = C_Item.GetItemCount(itemID)
    else
        seenCount[itemID] = nil
    end
end

---------------------------------------------------------------------------
-- Start
---------------------------------------------------------------------------

local function createButton(text, onClick)
    local button = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    button:SetSize(BUTTON_WIDTH, BUTTON_HEIGHT)
    button:SetText(text)
    ns.FitButtonText(button, BUTTON_WIDTH)
    button:SetScript("OnClick", onClick)
    return button
end

local function createPanel()
    -- The same template the game's loot window is built on (ScrollingFlatPanelTemplate inherits
    -- DefaultPanelFlatTemplate): frame, background and title look the same. The name makes the panel
    -- easy to find with /fstack and gives the template's parts their own names.
    panel = CreateFrame("Frame", "TidyPackMakeRoomPanel", UIParent, "DefaultPanelFlatTemplate")
    panel:SetClampedToScreen(true)
    panel:EnableMouse(true)
    panel:SetTitle(L["Tidy Pack"])
    panel:Hide()

    message = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    message:SetPoint("TOPLEFT", TEXT_INSET, -TEXT_TOP)
    message:SetJustifyH("LEFT")

    -- Two buttons in the middle under the text, as in the game's own questions.
    createButton(L["Delete"], deleteSuggestion):SetPoint("BOTTOMRIGHT", panel, "BOTTOM", -4, 12)
    createButton(L["Not now"], hidePanel):SetPoint("BOTTOMLEFT", panel, "BOTTOM", 4, 12)
end

ns.OnLoad(function()
    if not LootFrame then
        return
    end
    createPanel()

    -- The game's own message when something doesn't fit, the same the loot window listens to.
    ns.RegisterEvent("UI_ERROR_MESSAGE", function(_, errorMessage)
        if errorMessage == ERR_INV_FULL and LootFrame:IsShown() then
            C_Timer.After(0, offerRoom) -- once the loot window has shown what is left
        end
    end)

    ns.RegisterEvent("BAG_UPDATE_DELAYED", function()
        checkLooted()
        if not panel:IsShown() then
            return
        end
        -- The suggestion may be outdated: the item has moved, or there is room now.
        if suggestion.kind == "full" then
            offerRoom()
        else
            local info = C_Container.GetContainerItemInfo(suggestion.bagID, suggestion.slot)
            if not info or info.itemID ~= suggestion.itemID then
                hidePanel()
            end
        end
    end)

    -- The loot window closes: the full-bags suggestion is no longer needed, but a junk-list
    -- question moves up to the middle.
    ns.RegisterEvent("LOOT_CLOSED", function()
        if not panel:IsShown() or panel:GetParent() ~= LootFrame then
            return
        end
        if suggestion.kind == "looted" then
            local info = C_Container.GetContainerItemInfo(suggestion.bagID, suggestion.slot)
            if info then
                -- The loot window can stay a moment while it fades, so the panel is
                -- moved explicitly up to the middle.
                local alone = true
                showPanel("looted", message:GetText(), suggestion.bagID, suggestion.slot, suggestion.itemID, alone)
                return
            end
        end
        panel:Hide()
        suggestion.kind = nil
        C_Timer.After(0, showNext)
    end)

    ns.RegisterEvent("PLAYER_ENTERING_WORLD", countListed)

    -- If combat starts while the panel is open, it hides at once, so a click in combat isn't
    -- stopped by the game. The question about a looted junk-list item goes back in the queue and
    -- shows when combat is over.
    ns.RegisterEvent("PLAYER_REGEN_DISABLED", function()
        if not panel:IsShown() then
            return
        end
        if suggestion.kind == "looted" and suggestion.itemID then
            table.insert(queue, 1, suggestion.itemID)
        end
        panel:Hide()
        suggestion.kind = nil
    end)

    -- Combat is over: unhook the controller if that had to wait, and show what has been
    -- looted.
    ns.RegisterEvent("PLAYER_REGEN_ENABLED", function()
        if not panel:IsShown() then
            releasePopup()
        end
        if LootFrame:IsShown() and freeNormalSlots() == 0 then
            offerRoom()
        else
            showNext()
        end
    end)
end)
