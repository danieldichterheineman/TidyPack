-- TidyPack – Bank.lua
-- The Bank tab (issue #1, sketch .design/sketch-bank-tab.html): the bank sorted in the same groups
-- and parts as the bags. Layout.lua lays out the buttons; this file owns them.
--
-- At a banker: own buttons from the game's bag-button template (ContainerFrameItemButtonTemplate), one
-- per slot in each bank tab. The game's bank window shows only one page at a time, hence own buttons.
-- The template's click is the game's own and reads the bag number with the parent frame's GetID() and
-- the slot with the button's GetID() (ContainerFrameItemButtonMixin:GetBagID, ContainerFrame.lua in the
-- forever branch). Tidy Pack sets both with SetID and never writes the field bagID, so the click is the
-- game's: right-click moves the item to the bags, drag and drop work, and right-click on an item in
-- Bags puts it in the bank (the game then reads BankFrame:GetActiveBankType()).
--
-- The game's bank window (BankFrame) must not be hidden: its OnHide closes the bank (BankFrameBaseMixin:
-- OnHide → C_Bank.CloseBankFrame, Mainline/BankFrameTemplates.lua). Instead it is made invisible and
-- very small (SetAlpha and SetScale) while Tidy Pack shows the bank, and restored when the bank closes.
-- The gear menu can show the game's window again, e.g. to buy a bank slot.
--
-- Away from the bank: what you had last, saved per character (TidyPackCharDB.bank). Only images and
-- tooltips; nothing can be moved.
--
-- ⚠️ Not tried in the game. With a controller Tidy Pack doesn't take over the game's bank window (the
-- buttons aren't hooked into the controller's cursor), and the account (warband) bank isn't shown yet.

local _, ns = ...
local L = ns.L

local BANK_TYPE = Enum.BankType and Enum.BankType.Character

local atBank = false
local gameFrameHidden = false  -- the game's bank window is invisible (Tidy Pack shows the bank)
local showGameFrame = false    -- the player asked for the game's window (the gear menu)
local holders = {}             -- bank tab number → invisible frame with SetID(number)
local liveButtons = {}         -- bank tab number → slot → button
local offlineButtons = {}      -- buttons for saved items, in order
local allButtons = {}          -- all the bank's buttons, for Layout.lua (hide what isn't used)
local freeSlots = 0            -- free bank slots at the last pass
local bankTabShown = false     -- the Bank tab has shown since the bank opened
local bankLaidOut = false      -- safety net: don't hide the game's bank window until the tab laid out without errors

-- True between BANKFRAME_OPENED and BANKFRAME_CLOSED.
function ns.IsAtBank()
    return atBank
end

-- Tidy Pack shows the bank in its tab instead of the game's window: only with the mouse, and only when
-- the option is on.
local function takesOverBank()
    return ns.db.bankTab ~= false and not InputUtil.IsGamepadUIEnabled()
end
ns.TakesOverBank = takesOverBank -- the gear menu (Marks.lua)

-- WoW Forever's bank (Camelot/BankFrame.lua in the game's code): "tab" 1 is the main bank (28 slots),
-- and tabs 2 to FetchMaxNumBankTabs are the bank's bag slots, bought one at a time. A bought slot is a
-- container (CharacterBankTab_1 + index - 1) as big as the bag in it, or 0 without a bag. The bag itself
-- sits in the pseudo container Characterbanktab at the slot's index. The game's tab names and icons
-- are only placeholders here ("Tab 1" and a question mark), so Tidy Pack names the main bank "Bank" and
-- each bag slot after its bag (sketch .design/sketch-bank-slots.html, the owner's wish 2026-11-15).
-- ⚠️ Buying a slot (C_Bank.PurchaseBankTab) is restricted to the game's own code: the "+" opens the
--    game's bank window, where the player buys it.
local BANK_ICON = "Interface\\Icons\\INV_Box_02"
local FIRST_TAB = Enum.BagIndex and Enum.BagIndex.CharacterBankTab_1
local BAG_SLOT_CONTAINER = Enum.BagIndex and Enum.BagIndex.Characterbanktab

-- The slot index (1 = the main bank) of a bank container, or nil when the game doesn't number them.
local function tabIndexOf(containerID)
    return FIRST_TAB and containerID - FIRST_TAB + 1 or nil
end

-- The bag in a bank bag slot: its location, or nil if the slot has no bag.
local function bankBagLocation(index)
    if not (BAG_SLOT_CONTAINER and index and index > 1) then
        return nil
    end
    local location = ItemLocation:CreateFromBagAndSlot(BAG_SLOT_CONTAINER, index)
    if location:IsValid() and C_Item.DoesItemExist(location) then
        return location
    end
    return nil
end

-- The bank tabs (containers' numbers, names, icons and sizes) the character has bought.
local function bankTabInfos()
    local result = {}
    if not (BANK_TYPE and C_Bank) then
        return result
    end
    if C_Bank.FetchPurchasedBankTabData then
        for position, tab in ipairs(C_Bank.FetchPurchasedBankTabData(BANK_TYPE) or {}) do
            local index = tabIndexOf(tab.ID) or position
            local info = {
                id = tab.ID,
                index = index,
                name = tab.name,
                icon = tab.icon,
                slots = C_Container.GetContainerNumSlots(tab.ID) or 0,
                free = C_Container.GetContainerNumFreeSlots(tab.ID) or 0,
            }
            if index == 1 then
                info.name, info.icon = L["Bank"], BANK_ICON
            else
                local location = bankBagLocation(index)
                if location then
                    info.icon = C_Item.GetItemIcon(location)
                    info.link = C_Item.GetItemLink(location)
                    info.name = C_Item.GetItemName(location) or info.name
                else
                    info.icon, info.name = nil, L["Empty bank bag slot"]
                end
            end
            result[#result + 1] = info
        end
        return result
    end
    if C_Bank.FetchPurchasedBankTabIDs then
        for index, id in ipairs(C_Bank.FetchPurchasedBankTabIDs(BANK_TYPE) or {}) do
            result[#result + 1] = {
                id = id,
                name = L["Tab %d"]:format(index),
                slots = C_Container.GetContainerNumSlots(id) or 0,
            }
        end
    end
    return result
end

---------------------------------------------------------------------------
-- The buttons at a banker
---------------------------------------------------------------------------

local function holderFor(containerID)
    local holder = holders[containerID]
    if not holder then
        holder = ns.CreateLiveSlotHolder(containerID)
        holders[containerID] = holder
    end
    return holder
end

local function liveButtonFor(containerID, slot)
    local list = liveButtons[containerID]
    if not list then
        list = {}
        liveButtons[containerID] = list
    end
    local button = list[slot]
    if not button then
        button = ns.CreateLiveSlotButton(holderFor(containerID), slot)
        list[slot] = button
        allButtons[#allButtons + 1] = button
    end
    return button
end

-- The same steps the game's bag window does for each button (Layout.lua).
local function updateLiveButton(button, containerID, slot, info)
    ns.UpdateLiveSlotButton(button, containerID, slot, info, false)
end

---------------------------------------------------------------------------
-- The buttons away from the bank
---------------------------------------------------------------------------
-- Plain buttons (the type ItemButton) that only show image, count, quality and tooltip.

local function showOfflineTooltip(self)
    if not self.link then
        return
    end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetHyperlink(self.link)
    GameTooltip:Show()
end

local function offlineButtonFor(index)
    local button = offlineButtons[index]
    if not button then
        -- The type ItemButton has image, count and quality border itself (Blizzard_ItemButton/Shared).
        button = CreateFrame("ItemButton", nil, ns.bagFrame)
        button:SetSize(ns.ITEM_BUTTON_SIZE or 37, ns.ITEM_BUTTON_SIZE or 37)
        button:SetFrameLevel(10) -- like the game's bag buttons
        button:RegisterForClicks("LeftButtonUp")
        button:SetScript("OnEnter", showOfflineTooltip)
        button:SetScript("OnLeave", GameTooltip_Hide)
        -- Shift-click links the item in the chat, as usual.
        button:SetScript("OnClick", function(self)
            if self.link then
                HandleModifiedItemClick(self.link)
            end
        end)
        offlineButtons[index] = button
        allButtons[#allButtons + 1] = button
    end
    return button
end

local function updateOfflineButton(button, item)
    button.link = item and item.link or nil
    SetItemButtonTexture(button, item and item.icon or nil)
    SetItemButtonCount(button, item and item.count or 0)
    SetItemButtonQuality(button, item and item.quality or nil, item and item.link or nil)
    button:SetAlpha(item and 1 or 0.65)
end

---------------------------------------------------------------------------
-- For Layout.lua
---------------------------------------------------------------------------

-- All the bank's buttons (also those not used right now), so Layout.lua can hide them.
function ns.EnumerateBankButtons()
    return ipairs(allButtons)
end

-- Saved bank for this character: { time, free, tabs, items = { { link, count, quality, icon, bag,
-- slot, quest, bound, noValue }, ... } }. Nil if the character hasn't been at a banker.
function ns.GetSavedBank()
    return ns.charDb and ns.charDb.bank
end

function ns.GetBankFreeSlots()
    if atBank then
        return freeSlots
    end
    local saved = ns.GetSavedBank()
    return saved and saved.free or 0
end

-- The bank tabs in order (at a banker straight from the game, away from what was saved last).
function ns.GetBankTabs()
    if atBank then
        return bankTabInfos()
    end
    local saved = ns.GetSavedBank()
    if not saved then
        return {}
    end
    if saved.tabs then
        return saved.tabs
    end
    -- An old saved bank without tab info: guess the order from the containers' numbers.
    local seen, tabs = {}, {}
    for _, item in ipairs(saved.items or {}) do
        if item.bag and not seen[item.bag] then
            seen[item.bag] = true
            tabs[#tabs + 1] = { id = item.bag }
        end
    end
    table.sort(tabs, function(a, b) return a.id < b.id end)
    for index, tab in ipairs(tabs) do
        tab.name = L["Tab %d"]:format(index)
    end
    return tabs
end

-- Goes through and saves the bank's content at a banker. onSlot(containerID, slot, info, isQuestItem)
-- is optional (used by ForEachBankSlot to also update the buttons).
local function scanLiveBank(onSlot)
    if not atBank or not ns.charDb then
        return
    end
    local tabs = bankTabInfos()
    local items, free = {}, 0
    for _, tab in ipairs(tabs) do
        for slot = 1, tab.slots do
            local info = C_Container.GetContainerItemInfo(tab.id, slot)
            local isQuestItem = info and ns.IsQuestItem(tab.id, slot, info) or false
            if info then
                items[#items + 1] = {
                    link = info.hyperlink, count = info.stackCount or 1, quality = info.quality,
                    icon = info.iconFileID, bag = tab.id, slot = slot, quest = isQuestItem or nil,
                    bound = info.isBound or nil, noValue = info.hasNoValue or nil,
                }
            else
                free = free + 1
            end
            if onSlot then
                onSlot(tab.id, slot, info, isQuestItem)
            end
        end
    end
    freeSlots = free
    local maxTabs = C_Bank.FetchMaxNumBankTabs and C_Bank.FetchMaxNumBankTabs(BANK_TYPE) or #tabs
    local nextTab = C_Bank.FetchNextPurchasableBankTabData and C_Bank.FetchNextPurchasableBankTabData(BANK_TYPE)
    ns.charDb.bank = {
        time = time(), free = free, items = items, tabs = tabs, maxTabs = maxTabs,
        nextCost = nextTab and nextTab.tabCost or nil,
    }
end

local function saveBank()
    scanLiveBank(nil)
end

-- Goes through the bank's slots. At a banker: every slot, with the game's data (info nil for an empty
-- slot), and the bank is saved for later. Away: the saved items (offline = true).
-- callback(button, bagID, slot, info, offline, isQuestItem)
function ns.ForEachBankSlot(callback)
    if atBank then
        scanLiveBank(function(containerID, slot, info, isQuestItem)
            local button = liveButtonFor(containerID, slot)
            updateLiveButton(button, containerID, slot, info)
            callback(button, containerID, slot, info, false, isQuestItem)
        end)
        return
    end
    local saved = ns.GetSavedBank()
    if not saved then
        return
    end
    local function emitSaved(index, item, bagID, slot)
        local itemID = item and item.link and C_Item.GetItemInfoInstant(item.link)
        if item and not itemID then
            return nil
        end
        local button = offlineButtonFor(index)
        updateOfflineButton(button, item)
        local info = item and {
            itemID = itemID, hyperlink = item.link, stackCount = item.count, quality = item.quality,
            iconFileID = item.icon, isBound = item.bound, hasNoValue = item.noValue,
        } or nil
        callback(button, bagID, slot, info, true, item ~= nil and item.quest == true)
        return true
    end
    if ns.db and ns.db.groupByBag and saved.tabs then
        local byPos = {}
        for _, item in ipairs(saved.items or {}) do
            byPos[item.bag] = byPos[item.bag] or {}
            byPos[item.bag][item.slot] = item
        end
        local btnIndex = 0
        for _, tab in ipairs(saved.tabs) do
            for slot = 1, tab.slots or 0 do
                btnIndex = btnIndex + 1
                local item = byPos[tab.id] and byPos[tab.id][slot]
                emitSaved(btnIndex, item, tab.id, slot)
            end
        end
        return
    end
    for index, item in ipairs(saved.items or {}) do
        emitSaved(index, item, item.bag, item.slot)
    end
end

-- The bank's slots for the bottom row of the Bank tab (Layout.lua), in order: 1 is the main bank, then
-- the bag slots. Each is { index, bought, id, slots, free, icon, name, link }, and nextCost is what the
-- next bag slot costs (nil when all are bought). At a banker from the game, away from what was saved.
function ns.GetBankSlots()
    local tabs, maxTabs, nextCost
    if atBank then
        tabs = bankTabInfos()
        maxTabs = C_Bank.FetchMaxNumBankTabs and C_Bank.FetchMaxNumBankTabs(BANK_TYPE) or #tabs
        local nextTab = C_Bank.FetchNextPurchasableBankTabData and C_Bank.FetchNextPurchasableBankTabData(BANK_TYPE)
        nextCost = nextTab and nextTab.tabCost or nil
    else
        local saved = ns.GetSavedBank()
        if not (saved and saved.tabs) then
            return {}, nil
        end
        tabs, maxTabs, nextCost = saved.tabs, saved.maxTabs or #saved.tabs, saved.nextCost
    end
    local byIndex = {}
    for position, tab in ipairs(tabs) do
        byIndex[tab.index or position] = tab
    end
    local slots = {}
    for index = 1, math.max(maxTabs or 0, #tabs) do
        local tab = byIndex[index]
        slots[index] = tab and {
            index = index, bought = true, id = tab.id, slots = tab.slots or 0, free = tab.free or 0,
            icon = tab.icon, name = tab.name, link = tab.link,
        } or { index = index, bought = false }
    end
    return slots, nextCost
end

-- The bottom row of the Bank tab: something dropped on a bank slot. A bag goes into a bag slot (or swaps
-- with the bag there, like the game's own bag slot buttons); any other item goes into the first free
-- slot of that container, or anywhere in the bank when it is full. Only at a banker.
function ns.DropOnBankSlot(index)
    if not atBank or GetCursorInfo() ~= "item" then
        return
    end
    local _, itemID = GetCursorInfo()
    local classID = itemID and select(6, C_Item.GetItemInfoInstant(itemID))
    if index > 1 and classID == Enum.ItemClass.Container and BAG_SLOT_CONTAINER then
        C_Container.PickupContainerItem(BAG_SLOT_CONTAINER, index)
        return
    end
    for _, tab in ipairs(bankTabInfos()) do
        if (tab.index or 0) == index then
            for slot = 1, tab.slots do
                if not C_Container.GetContainerItemInfo(tab.id, slot) then
                    C_Container.PickupContainerItem(tab.id, slot)
                    return
                end
            end
        end
    end
    -- That bag is full, or the slot has no bag: anywhere in the bank, like a drop on the window.
    ns.PutCursorItemInBank()
end

-- Picks up the bag in a bank bag slot (a click with nothing on the cursor), as the game's own bag slot
-- buttons do. Only at a banker.
function ns.PickupBankBag(index)
    if atBank and BAG_SLOT_CONTAINER and bankBagLocation(index) then
        C_Container.PickupContainerItem(BAG_SLOT_CONTAINER, index)
    end
end

-- Shows the bag in a bank bag slot in the tooltip: from the game at a banker, from its link away.
function ns.SetBankBagTooltip(tooltip, slot)
    if atBank and BAG_SLOT_CONTAINER and bankBagLocation(slot.index) then
        return tooltip:SetBagItem(BAG_SLOT_CONTAINER, slot.index)
    elseif slot.link then
        tooltip:SetHyperlink(slot.link)
        return true
    end
    return false
end

-- Puts the item on the cursor in the first free bank slot (drop anywhere in the Bank tab).
function ns.PutCursorItemInBank()
    if not atBank or GetCursorInfo() ~= "item" then
        return
    end
    for _, tab in ipairs(bankTabInfos()) do
        for slot = 1, tab.slots do
            if not C_Container.GetContainerItemInfo(tab.id, slot) then
                C_Container.PickupContainerItem(tab.id, slot)
                return
            end
        end
    end
    UIErrorsFrame:AddMessage(L["Your bank is full."], 1.0, 0.1, 0.1, 1.0)
end

-- How long ago the bank was saved, for the line away from the bank.
function ns.SavedBankAge()
    local saved = ns.GetSavedBank()
    if not (saved and saved.time) then
        return nil
    end
    return ns.AgeText(saved.time)
end

-- "today", "yesterday" or "3 days ago" for a time saved with time() (also Characters.lua).
function ns.AgeText(timestamp)
    local days = math.floor((time() - timestamp) / 86400)
    if days < 1 then
        return L["today"]
    elseif days == 1 then
        return L["yesterday"]
    end
    return L["%d days ago"]:format(days)
end

---------------------------------------------------------------------------
-- The game's bank window
---------------------------------------------------------------------------

local originalScale

-- Invisible and very small, but still open (see the top of the file). Made invisible only when the
-- Bank tab has been laid out without errors, and restored at once if an error stops the layout.
local function updateGameBankFrame()
    if not BankFrame then
        return
    end
    originalScale = originalScale or BankFrame:GetScale()
    local hide = atBank and takesOverBank() and bankLaidOut and not showGameFrame
    if hide then
        BankFrame:SetAlpha(0)
        BankFrame:SetScale(0.01)
    elseif gameFrameHidden then
        BankFrame:SetAlpha(1)
        BankFrame:SetScale(originalScale)
    end
    gameFrameHidden = hide
end

-- Safety net from Layout.lua: says when the Bank tab finished drawing (or when the layout failed).
function ns.SetBankLayoutOk(ok)
    bankLaidOut = ok == true
    if ok and atBank then
        bankTabShown = true
    end
    updateGameBankFrame()
end

-- The gear menu: show the game's bank window again (e.g. to buy a bank slot or swap a bag in the
-- bank), or hide it.
function ns.IsGameBankFrameShown()
    return not gameFrameHidden
end

function ns.ToggleGameBankFrame()
    showGameFrame = not showGameFrame
    updateGameBankFrame()
end

-- The option "Use the Bank tab at bankers" changed (Options.lua).
ns.ApplyBankSetting = updateGameBankFrame

-- Switches to the Bank tab when the game has opened the bags at a banker.
local function showBankTab()
    if not atBank or not ns.bagFrame then
        return
    end
    -- The game opens the bags itself at a banker. Tidy Pack never opens them from its own code (see
    -- LogoButton.lua).
    if ns.SetView then
        ns.SetView("bank")
    end
    bankTabShown = true
end

ns.RegisterEvent("BANKFRAME_OPENED", function()
    atBank = true
    showGameFrame = false
    bankTabShown = false
    bankLaidOut = false
    saveBank()
    updateGameBankFrame()
    if takesOverBank() then
        -- One frame later: the game opens the bags itself when the bank opens.
        C_Timer.After(0, showBankTab)
    elseif ns.Refresh then
        ns.Refresh()
    end
end)

ns.RegisterEvent("BANKFRAME_CLOSED", function()
    atBank = false
    showGameFrame = false
    bankTabShown = false
    bankLaidOut = false
    updateGameBankFrame()
    if ns.Refresh then
        ns.Refresh() -- the Bank tab now shows what was saved
    end
end)

-- The bank's content changes: always save it at a banker, and lay out again when the bank shows.
local function refreshIfBankShown()
    if not atBank then
        return
    end
    saveBank()
    if ns.GetView and ns.GetView() == "bank" and ns.Refresh then
        ns.Refresh()
    end
end
for _, event in ipairs({ "BAG_UPDATE_DELAYED", "ITEM_LOCK_CHANGED", "PLAYERBANKSLOTS_CHANGED",
    "BANK_TABS_CHANGED", "BAG_CONTAINER_UPDATE" }) do
    ns.RegisterEvent(event, refreshIfBankShown)
end

ns.OnLoad(function()
    if not ns.bagFrame then
        return
    end
    -- The game shows its bank window after BANKFRAME_OPENED; it is made invisible every time it shows.
    if BankFrame then
        BankFrame:HookScript("OnShow", updateGameBankFrame)
    end
    -- If you close the bags at a banker the bank closes too, since the game's window isn't shown. Only
    -- after the Bank tab has shown: the game may close and reopen the bags while the bank opens.
    ns.bagFrame:HookScript("OnHide", function()
        if atBank and bankTabShown and gameFrameHidden and C_Bank and C_Bank.CloseBankFrame then
            C_Bank.CloseBankFrame()
        end
    end)
end)
