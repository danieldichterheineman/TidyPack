-- TidyPack – Bank.lua
-- Fliken Bank (issue #1, skissen .design/sketch-bank-tab.html): banken sorterad i samma grupper
-- och avsnitt som väskan. Layout.lua lägger ut rutorna; den här filen äger dem.
--
-- Hos bankiren: egna rutor av spelets mall för väskrutor (ContainerFrameItemButtonTemplate), en per
-- plats i varje bankflik. Spelets bankfönster visar bara en sida åt gången, därför egna rutor.
-- Mallens klick är spelets eget och läser väskans nummer med föräldraramens GetID() och platsen med
-- rutans GetID() (ContainerFrameItemButtonMixin:GetBagID, ContainerFrame.lua i grenen forever). Tidy
-- Pack sätter båda med SetID och skriver aldrig fältet bagID, så klicket är spelets: högerklick
-- flyttar saken till väskorna, dra och släpp fungerar, och högerklick på en sak i Bags lägger den i
-- banken (spelet läser då BankFrame:GetActiveBankType()).
--
-- Spelets bankfönster (BankFrame) får inte döljas: dess OnHide stänger banken (BankFrameBaseMixin:
-- OnHide → C_Bank.CloseBankFrame, Mainline/BankFrameTemplates.lua). Det görs i stället osynligt och
-- mycket litet (SetAlpha och SetScale) medan Tidy Pack visar banken, och återställs när banken stängs.
-- Kugghjulets meny kan visa spelets fönster igen, t.ex. för att köpa en bankplats.
--
-- Borta från banken: det du hade senast, sparat per karaktär (TidyPackCharDB.bank). Bara bilder och
-- tooltips; inget går att flytta.
--
-- ⚠️ Inte provat i spelet. Med handkontroll tar Tidy Pack inte över spelets bankfönster (rutorna är
-- inte inkopplade i handkontrollens markör), och kontogemensam bank (Warband) visas inte än.

local _, ns = ...
local L = ns.L

local BANK_TYPE = Enum.BankType and Enum.BankType.Character

local atBank = false
local gameFrameHidden = false  -- spelets bankfönster är osynligt (Tidy Pack visar banken)
local showGameFrame = false    -- spelaren har bett om spelets fönster (kugghjulets meny)
local holders = {}             -- bankflikens nummer → osynlig ram med SetID(nummer)
local liveButtons = {}         -- bankflikens nummer → plats → ruta
local offlineButtons = {}      -- ruta för sparade saker, i ordning
local allButtons = {}          -- alla bankens rutor, för Layout.lua (dölj det som inte används)
local freeSlots = 0            -- lediga platser i banken vid senaste genomgången
local bankTabShown = false     -- fliken Bank har visats sedan banken öppnades

-- Sant mellan BANKFRAME_OPENED och BANKFRAME_CLOSED.
function ns.IsAtBank()
    return atBank
end

-- Tidy Pack visar banken i sin flik, i stället för spelets fönster: bara med mus, och bara när
-- inställningen är på.
local function takesOverBank()
    return ns.db.bankTab ~= false and not InputUtil.IsGamepadUIEnabled()
end
ns.TakesOverBank = takesOverBank -- kugghjulets meny (Marks.lua)

-- Bankflikarna (behållarnas nummer, CharacterBankTab_1 …) som karaktären har köpt.
local function bankContainers()
    if not (BANK_TYPE and C_Bank and C_Bank.FetchPurchasedBankTabIDs) then
        return {}
    end
    return C_Bank.FetchPurchasedBankTabIDs(BANK_TYPE) or {}
end

---------------------------------------------------------------------------
-- Rutorna hos bankiren
---------------------------------------------------------------------------

local function holderFor(containerID)
    local holder = holders[containerID]
    if not holder then
        holder = CreateFrame("Frame", nil, ns.bagFrame)
        holder:SetAllPoints()
        -- Spelets mall läser väskans nummer här (GetParent():GetID()).
        holder:SetID(containerID)
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
        button = CreateFrame("ItemButton", nil, holderFor(containerID), "ContainerFrameItemButtonTemplate")
        button:SetID(slot)
        list[slot] = button
        allButtons[#allButtons + 1] = button
    end
    return button
end

-- Samma steg som spelets väskfönster gör för varje ruta (ContainerFrameMixin:UpdateItems).
local function updateLiveButton(button, containerID, slot, info)
    local texture = info and info.iconFileID
    ClearItemButtonOverlay(button)
    button:SetHasItem(texture)
    button:SetItemButtonTexture(texture)
    button:SyncAppearanceWithHasItem()
    SetItemButtonQuality(button, info and info.quality, info and info.hyperlink, false, info and info.isBound)
    SetItemButtonCount(button, info and info.stackCount)
    SetItemButtonDesaturated(button, info and info.isLocked)
    local questInfo = C_Container.GetContainerItemQuestInfo(containerID, slot)
    button:UpdateQuestItem(questInfo and questInfo.isQuestItem, questInfo and questInfo.questID,
        questInfo and questInfo.isActive)
    button:UpdateJunkItem(info and info.quality, info and info.hasNoValue)
    button:UpdateCooldown(texture)
    button:SetReadable(info and info.isReadable)
    button:SetMatchesSearch(not (info and info.isFiltered))
end

---------------------------------------------------------------------------
-- Rutorna borta från banken
---------------------------------------------------------------------------
-- Vanliga rutor (typen ItemButton) som bara visar bild, antal, kvalitet och tooltip.

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
        -- Typen ItemButton har själv bild, antal och kvalitetsram (Blizzard_ItemButton/Shared).
        button = CreateFrame("ItemButton", nil, ns.bagFrame)
        button:SetSize(ns.ITEM_BUTTON_SIZE or 37, ns.ITEM_BUTTON_SIZE or 37)
        button:SetFrameLevel(10) -- som spelets väskrutor
        button:RegisterForClicks("LeftButtonUp")
        button:SetScript("OnEnter", showOfflineTooltip)
        button:SetScript("OnLeave", GameTooltip_Hide)
        -- Shift-klick länkar saken i chatten, som vanligt.
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
    button.link = item.link
    SetItemButtonTexture(button, item.icon)
    SetItemButtonCount(button, item.count)
    SetItemButtonQuality(button, item.quality, item.link)
end

---------------------------------------------------------------------------
-- För Layout.lua
---------------------------------------------------------------------------

-- Alla bankens rutor (också de som inte används just nu), så att Layout.lua kan dölja dem.
function ns.EnumerateBankButtons()
    return ipairs(allButtons)
end

-- Sparad bank för den här karaktären: { time, free, items = { { link, count, quality, icon, bag,
-- slot, quest, bound, noValue }, ... } }. Nil om karaktären inte har varit hos en bankir.
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

-- Går igenom bankens platser. Hos bankiren: varje plats, med spelets data (info nil för en tom
-- plats), och banken sparas för senare. Borta: de sparade sakerna (offline = true).
-- callback(button, bagID, slot, info, offline, isQuestItem)
function ns.ForEachBankSlot(callback)
    if atBank then
        local items = {}
        freeSlots = 0
        for _, containerID in ipairs(bankContainers()) do
            for slot = 1, C_Container.GetContainerNumSlots(containerID) do
                local info = C_Container.GetContainerItemInfo(containerID, slot)
                local button = liveButtonFor(containerID, slot)
                updateLiveButton(button, containerID, slot, info)
                local isQuestItem = info and ns.IsQuestItem(containerID, slot, info) or false
                if info then
                    items[#items + 1] = {
                        link = info.hyperlink, count = info.stackCount or 1, quality = info.quality,
                        icon = info.iconFileID, bag = containerID, slot = slot, quest = isQuestItem or nil,
                        bound = info.isBound or nil, noValue = info.hasNoValue or nil,
                    }
                else
                    freeSlots = freeSlots + 1
                end
                callback(button, containerID, slot, info, false, isQuestItem)
            end
        end
        ns.charDb.bank = { time = time(), free = freeSlots, items = items }
        return
    end
    local saved = ns.GetSavedBank()
    if not saved then
        return
    end
    for index, item in ipairs(saved.items) do
        local itemID = item.link and C_Item.GetItemInfoInstant(item.link)
        if itemID then
            local button = offlineButtonFor(index)
            updateOfflineButton(button, item)
            -- Samma fält som spelets ContainerItemInfo, så att Layout.lua kan sortera som vanligt.
            local info = {
                itemID = itemID, hyperlink = item.link, stackCount = item.count, quality = item.quality,
                iconFileID = item.icon, isBound = item.bound, hasNoValue = item.noValue,
            }
            callback(button, item.bag, item.slot, info, true, item.quest == true)
        end
    end
end

-- Lägger saken på markören på första lediga plats i banken (släpp var som helst i fliken Bank).
function ns.PutCursorItemInBank()
    if not atBank or GetCursorInfo() ~= "item" then
        return
    end
    for _, containerID in ipairs(bankContainers()) do
        for slot = 1, C_Container.GetContainerNumSlots(containerID) do
            if not C_Container.GetContainerItemInfo(containerID, slot) then
                C_Container.PickupContainerItem(containerID, slot)
                return
            end
        end
    end
    UIErrorsFrame:AddMessage(L["Your bank is full."], 1.0, 0.1, 0.1, 1.0)
end

-- Hur länge sedan banken sparades, för raden borta från banken.
function ns.SavedBankAge()
    local saved = ns.GetSavedBank()
    if not (saved and saved.time) then
        return nil
    end
    local days = math.floor((time() - saved.time) / 86400)
    if days < 1 then
        return L["today"]
    elseif days == 1 then
        return L["yesterday"]
    end
    return L["%d days ago"]:format(days)
end

---------------------------------------------------------------------------
-- Antal i väskan och banken i sakens tooltip
---------------------------------------------------------------------------
-- En rad "Bags 12 · Bank 40 · Total 52" (kollegans förslag 2026-11-12, skissen
-- .design/sketch-settings-in-bag.html, variant 1c). Bara när saken finns i banken. Väskan räknas av
-- spelet; banken ur den sparade banken, så att antalet syns också långt från bankiren. Bara den här
-- karaktären. Inställningen showCounts.

local countsFor     -- den sparade bank som bankCounts räknades ur
local bankCounts = {} -- itemID → antal i banken

local function bankCountOf(itemID)
    local saved = ns.GetSavedBank()
    if saved ~= countsFor then
        countsFor = saved
        wipe(bankCounts)
        for _, item in ipairs(saved and saved.items or {}) do
            local id = item.link and C_Item.GetItemInfoInstant(item.link)
            if id then
                bankCounts[id] = (bankCounts[id] or 0) + (item.count or 1)
            end
        end
    end
    return bankCounts[itemID] or 0
end

local COUNT_COLOR = CreateColor(0.44, 0.71, 1) -- ljusblått, som Tidy Packs andra rader om platser

TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
    if not data or type(data.id) ~= "number" or ns.db == nil or ns.db.showCounts == false then
        return
    end
    local bank = bankCountOf(data.id)
    if bank == 0 then
        return
    end
    local bags = C_Item.GetItemCount(data.id) or 0
    tooltip:AddLine(L["Bags %d · Bank %d · Total %d"]:format(bags, bank, bags + bank), COUNT_COLOR:GetRGB())
end)

---------------------------------------------------------------------------
-- Spelets bankfönster
---------------------------------------------------------------------------

local originalScale

-- Osynligt och mycket litet, men fortfarande öppet (se överst i filen).
local function updateGameBankFrame()
    if not BankFrame then
        return
    end
    originalScale = originalScale or BankFrame:GetScale()
    local hide = atBank and takesOverBank() and not showGameFrame
    if hide then
        BankFrame:SetAlpha(0)
        BankFrame:SetScale(0.01)
    elseif gameFrameHidden then
        BankFrame:SetAlpha(1)
        BankFrame:SetScale(originalScale)
    end
    gameFrameHidden = hide
end

-- Kugghjulets meny: visa spelets bankfönster igen (t.ex. för att köpa en bankplats eller byta en
-- väska i banken), eller dölj det.
function ns.IsGameBankFrameShown()
    return not gameFrameHidden
end

function ns.ToggleGameBankFrame()
    showGameFrame = not showGameFrame
    updateGameBankFrame()
end

-- Inställningen "Use the Bank tab at bankers" ändrades (Options.lua).
ns.ApplyBankSetting = updateGameBankFrame

-- Byter till fliken Bank när spelet har öppnat väskorna vid bankiren.
local function showBankTab()
    if not atBank or not ns.bagFrame then
        return
    end
    if not ns.bagFrame:IsShown() then
        OpenAllBags()
    end
    if ns.SetView then
        ns.SetView("bank")
    end
    bankTabShown = true
end

ns.RegisterEvent("BANKFRAME_OPENED", function()
    atBank = true
    showGameFrame = false
    bankTabShown = false
    updateGameBankFrame()
    if takesOverBank() then
        -- En bildruta senare: spelet öppnar själv väskorna när banken öppnas.
        C_Timer.After(0, showBankTab)
    elseif ns.Refresh then
        ns.Refresh()
    end
end)

ns.RegisterEvent("BANKFRAME_CLOSED", function()
    atBank = false
    showGameFrame = false
    bankTabShown = false
    updateGameBankFrame()
    if ns.Refresh then
        ns.Refresh() -- fliken Bank visar nu det sparade
    end
end)

-- Bankens innehåll ändras: lägg ut igen, men bara när banken syns.
local function refreshIfBankShown()
    if atBank and ns.GetView and ns.GetView() == "bank" and ns.Refresh then
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
    -- Spelet visar sitt bankfönster efter BANKFRAME_OPENED; det görs osynligt varje gång det visas.
    if BankFrame then
        BankFrame:HookScript("OnShow", updateGameBankFrame)
    end
    -- Stänger du väskan hos bankiren stängs banken också, eftersom spelets fönster inte syns. Bara
    -- efter att fliken Bank har visats: spelet kan stänga och öppna väskan medan banken öppnas.
    ns.bagFrame:HookScript("OnHide", function()
        if atBank and bankTabShown and gameFrameHidden and C_Bank and C_Bank.CloseBankFrame then
            C_Bank.CloseBankFrame()
        end
    end)
end)
