-- TidyPack – Layout.lua
-- Ordnar om rutorna i spelets väskfönster, det med alla väskor i ett
-- (ContainerFrameCombinedBags), i grupper med rubriker. Spelet lägger först ut rutorna i
-- sitt eget rutnät, och direkt efteråt flyttar Tidy Pack dem till sina grupper. Rutorna,
-- sökrutan och pengarna är spelets egna, så högerklick, dra och släpp och handkontrollens
-- knappar fungerar som vanligt.
--
-- Tidy Pack skriver aldrig över spelets funktioner. Det använder hooksecurefunc, som kör
-- vår kod efter spelets, på tre funktioner i spelets fönster:
--   UpdateFrameSize  – spelet har räknat ut fönstrets storlek
--   UpdateItemLayout – spelet har lagt ut rutorna i sitt rutnät
--   UpdateItems      – spelet har uppdaterat vad som ligger i rutorna
-- ⚠️ Med mus visar spelet nyckelringen i ett eget fönster, som Tidy Pack inte ändrar. Med
-- handkontroll ligger nycklarna i väskfönstret och hamnar i gruppen Keys.
-- Måtten ska stämma med skissen i .design/sketch.html.

local addonName, ns = ...
local L = ns.L

-- Mått i enheter, samma som i skissen.
local BUTTON = 37          -- en ruta, samma som spelets mall ContainerFrameItemButtonTemplate
local SPACING = 5          -- avstånd mellan rutor, samma som i spelets eget rutnät
local COLUMNS = 12
local CELL = BUTTON + SPACING
local GRID_WIDTH = COLUMNS * BUTTON + (COLUMNS - 1) * SPACING -- 499
local HEADER = 18          -- gruppens rubrik, inklusive luft under den
local GROUP_GAP = 12       -- avstånd mellan grupper som delar rad
local SHELF_GAP = 6        -- avstånd mellan rader av grupper
-- Luft mellan ramen och rutorna. Spelets eget rutnät ligger bara 7–8 enheter från ramen
-- och 4 enheter ovanför pengarna. Tidy Pack lägger till lite mer, så att grupperna inte
-- trängs mot kanterna (användarens önskan 2026-11-09).
local BLIZZARD_MONEY_GAP = 4 -- spelets avstånd mellan rutorna och raden med pengar
local PADDING_SIDE = 6       -- extra på var sida
local PADDING_TOP = 4        -- extra mellan sökrutan och första rubriken
local MONEY_GAP = 9          -- mellan sista raden rutor och raden med pengar
local LOW_SPACE = 5        -- så här få lediga platser gör siffran i Empty röd

-- Utrustning där nivån inte säger något visas utan nivå (skjortor och tabarder).
local NO_LEVEL = { INVTYPE_BODY = true, INVTYPE_TABARD = true, INVTYPE_NON_EQUIP_IGNORE = true }

-- Stjärnan framför rubriken Favorites, samma bild som ★-knappen.
local FAVORITE_ICON = "|A:auctionhouse-icon-favorite:13:13|a "

local bagFrame                    -- spelets fönster med alla väskor i ett
local overlay                     -- vår egen ram i spelets fönster, för rubrikerna
local contentHeight               -- höjden på det Tidy Pack lägger ut
local chromeWidth, chromeHeight   -- fönstrets kanter, titelrad, sökruta och pengar
local location = ItemLocation:CreateEmpty() -- återanvänds för att läsa en saks nivå

---------------------------------------------------------------------------
-- Gruppen New
---------------------------------------------------------------------------
-- Spelet markerar saker du nyss har fått, men tar bort markeringen så fort du håller musen
-- över saken. Tidy Pack kommer därför ihåg vilka saker som var nya medan fönstret var
-- öppet, och glömmer dem när fönstret stängs.

local newItems = {} -- bagID * 1000 + slot → itemID

function ns.IsNew(bagID, slot, itemID)
    return newItems[bagID * 1000 + slot] == itemID
end

local function rememberNew(bagID, slot, itemID)
    if C_NewItems.IsNewItem(bagID, slot) then
        newItems[bagID * 1000 + slot] = itemID
    end
end

---------------------------------------------------------------------------
-- Återanvända tabeller och textrader
---------------------------------------------------------------------------
-- Väskorna ändras ofta, t.ex. när man lootar. För att inte skapa nya tabeller och
-- textrader varje gång återanvänds de.

local entries = {}         -- en tabell per sak, eller per sorts tomma platser
local entryCount = 0
local groupLists = {}      -- gruppens namn → sakerna i gruppen
local emptyByFamily = {}   -- väsktyp → tomma platser av den typen (0 = vanlig väska)
local shownButtons = {}    -- rutorna som syns efter senaste genomgången
local lockedButtons = setmetatable({}, { __mode = "k" }) -- rutor som är låsta hos handlaren
local disabledButtons = setmetatable({}, { __mode = "k" }) -- rutor som Tidy Pack stängt av

-- För handkontrollen (Gamepad.lua): första rutan i varje grupp, i den ordning grupperna
-- visas, och vilken grupp varje ruta hör till.
local groupFirst = {}                                    -- 1, 2, 3 … → gruppens första ruta
local groupOfButton = setmetatable({}, { __mode = "k" }) -- ruta → plats i groupFirst
local newGroupIndex                                      -- gruppen New, om den visas

local function newEntry()
    entryCount = entryCount + 1
    local entry = entries[entryCount]
    if not entry then
        entry = {}
        entries[entryCount] = entry
    end
    entry.placed = false
    return entry
end

local function addToGroup(group, entry)
    local list = groupLists[group]
    if not list then
        list = {}
        groupLists[group] = list
    end
    list[#list + 1] = entry
end

local headers = { objects = {}, used = 0 }

local function acquireHeader()
    headers.used = headers.used + 1
    local header = headers.objects[headers.used]
    if not header then
        header = overlay:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        headers.objects[headers.used] = header
    end
    header:Show()
    return header
end

local function releaseHeaders()
    for _, header in ipairs(headers.objects) do
        header:Hide()
    end
    headers.used = 0
end

-- Rubrikernas plats sätts först när hela höjden är känd.
local headerX, headerY = {}, {}

---------------------------------------------------------------------------
-- Märken på rutorna: nivå, BoE, lås och antal tomma platser
---------------------------------------------------------------------------

-- Våra textrader och bilder per ruta. Rutorna är spelets egna, så Tidy Pack sparar inget i
-- dem – bara här, i en tabell som släpper rutan om spelet slutar använda den.
local extras = setmetatable({}, { __mode = "k" })

local function getExtras(button)
    local extra = extras[button]
    if not extra then
        -- Lagret ARTWORK ligger under spelets mörka lager för sökningen, så texten tonas
        -- ner tillsammans med rutan när den inte matchar sökningen.
        extra = {
            level = button:CreateFontString(nil, "ARTWORK", "NumberFontNormalSmall"),
            bind = button:CreateFontString(nil, "ARTWORK", "NumberFontNormalSmall"),
            free = button:CreateFontString(nil, "ARTWORK", "NumberFontNormal"),
            lock = button:CreateTexture(nil, "OVERLAY", nil, 6),
            later = button:CreateTexture(nil, "OVERLAY", nil, 6),
        }
        extra.level:SetPoint("TOPLEFT", 2, -2)
        extra.bind:SetPoint("BOTTOMLEFT", 2, 2)
        extra.bind:SetText(L["BoE"])
        -- Samma plats och typsnitt som spelets egen siffra för antal (Count i ItemButtonTemplate).
        extra.free:SetPoint("BOTTOMRIGHT", -5, 2)
        extra.lock:SetAtlas("LFG-lock")
        extra.lock:SetSize(12, 14)
        extra.lock:SetPoint("TOPRIGHT", -1, -1)
        -- Kartans gula utropstecken för quests du kan ta (QuestNormal), på samma plats som låset.
        extra.later:SetAtlas("QuestNormal")
        extra.later:SetSize(10, 14)
        extra.later:SetPoint("TOPRIGHT", -1, -1)
        extras[button] = extra
        -- En avstängd ruta visar annars ingen tooltip. Låsta saker hos en handlare ska visa
        -- sin, med raden om varför de är låsta.
        button:SetMotionScriptsWhileDisabled(true)
    end
    return extra
end

-- Låser eller släpper en ruta hos en handlare, så att saken inte kan säljas av misstag.
-- Med mus stängs rutan av. Med handkontroll får markören i stället inte klicka på den, för
-- när spelets markör står på en ruta som stängs av körs spelets kod för knapptipsen i Tidy
-- Packs namn, och sedan kan spelet blockera Use och Sell (se Gamepad.lua).
local function setLocked(button, locked)
    lockedButtons[button] = locked or nil
    local gamepad = InputUtil.IsGamepadUIEnabled() and ns.SetGamepadClickBlocked ~= nil
    if gamepad then
        ns.SetGamepadClickBlocked(button, locked)
    end
    local disable = locked and not gamepad
    if disable then
        button:Disable()
        disabledButtons[button] = true
    elseif disabledButtons[button] then
        button:Enable()
        disabledButtons[button] = nil
    end
end

local function updateExtras(entry, atMerchant)
    local button = entry.button
    local extra = getExtras(button)

    -- Antalet tomma platser på den enda tomma ruta som syns. Rött när det är få kvar.
    if entry.isEmpty then
        extra.free:SetText(entry.free)
        local color = entry.free <= LOW_SPACE and RED_FONT_COLOR or HIGHLIGHT_FONT_COLOR
        extra.free:SetTextColor(color:GetRGB())
        extra.free:Show()
    else
        extra.free:Hide()
    end

    -- Nivå uppe till vänster och BoE nere till vänster, bara på gröna och bättre vapen och
    -- rustningar – på enklare saker säger de sällan något.
    -- Markerat skräp får ingen nivå: där sitter skräpmyntet. Nivå och BoE går att stänga av i
    -- inställningarna (Options.lua).
    local level, boe
    if ns.db.itemLevelAndBoE and entry.isGear and entry.quality >= Enum.ItemQuality.Uncommon
        and not entry.junkMarked then
        if entry.equipLocation and entry.equipLocation ~= "" and not NO_LEVEL[entry.equipLocation] then
            location:SetBagAndSlot(entry.bagID, entry.slot)
            level = C_Item.GetCurrentItemLevel(location)
        end
        -- Bindningen är det 14:e värdet från GetItemInfo. Saknas sakens data ännu blir
        -- det nil, och då visas BoE nästa gång väskorna uppdateras.
        local bindType = select(14, C_Item.GetItemInfo(entry.link))
        boe = bindType == Enum.ItemBind.OnEquip and not entry.isBound
    end
    if level and level > 1 then
        extra.level:SetText(level)
        extra.level:Show()
    else
        extra.level:Hide()
    end
    extra.bind:SetShown(boe == true)

    -- Låset syns bara hos en handlare, och då går låsta saker inte att klicka på – varken
    -- med mus eller handkontroll – så de kan inte säljas av misstag (se QuestLock.lua).
    local locked = atMerchant and entry.locked == true
    extra.lock:SetShown(locked)
    setLocked(button, locked)

    -- Utropstecknet: en quest som du inte har tagit än behöver saken (QuestHints.lua).
    -- Låset går före, eftersom det sitter på samma plats.
    extra.later:SetShown(entry.neededLater == true and not locked)

    -- Spelets skräpmynt. Spelet visar det själv på grå saker hos en handlare
    -- (UpdateJunkItem), och Tidy Pack visar det också på saker som du har markerat som skräp.
    -- Villkoret innehåller spelets eget, så att spelets mynt står kvar.
    if button.JunkIcon then
        local gameShowsCoin = entry.quality == Enum.ItemQuality.Poor and not entry.noValue and atMerchant
        button.JunkIcon:SetShown(entry.junkMarked == true or gameShowsCoin)
    end

    -- Grön pil på väskor som är större än någon av dina väskor (se BagSwap.lua). Pilen
    -- finns redan i spelets ruta men används inte av spelet i väskorna.
    if button.UpgradeIcon then
        local isUpgrade = entry.group == "Bags" and ns.IsBagUpgrade ~= nil
            and ns.IsBagUpgrade(entry.bagID, entry.slot, entry.itemID)
        button.UpgradeIcon:SetShown(isUpgrade == true)
    end

    -- Alt-klick för favoriter och skräp (se Marks.lua).
    if ns.HookItemButton then
        ns.HookItemButton(button)
    end
end

---------------------------------------------------------------------------
-- Utläggningen
---------------------------------------------------------------------------

-- Lägger en ruta eller rubrik på plats. x och y räknas från övre vänstra hörnet av det
-- Tidy Pack lägger ut. Allt hänger i spelets rad med pengar, precis som spelets eget
-- rutnät, så att sökrutan, pengarna och spelets andra delar hamnar där de brukar.
local function anchor(region, x, y)
    region:ClearAllPoints()
    region:SetPoint("TOPLEFT", bagFrame.MoneyFrame, "TOPRIGHT", x - GRID_WIDTH - PADDING_SIDE,
        MONEY_GAP + contentHeight - y)
end

-- Ger spelets fönster Tidy Packs storlek: kanterna, titelraden och raden med pengar som
-- spelet räknade ut, plus det Tidy Pack lägger ut.
local function applySize()
    if not contentHeight or not chromeWidth then
        return
    end
    local height = contentHeight + chromeHeight + PADDING_TOP + (MONEY_GAP - BLIZZARD_MONEY_GAP)
    bagFrame:SetSize(GRID_WIDTH + chromeWidth + 2 * PADDING_SIDE, height)
    NineSliceUtil.UpdateCornerCropping(bagFrame, height)
end

-- Körs efter spelets UpdateFrameSize. Spelet har då gett fönstret storlek efter sitt eget
-- rutnät (GetColumns kolumner, GetRows rader). Det som är kvar när rutnätet räknas bort är
-- kanter, titelrad, sökruta och pengar.
local function onFrameSizeUpdated()
    local columns, rows = bagFrame:GetColumns(), math.max(bagFrame:GetRows(), 1)
    chromeWidth = bagFrame:GetWidth() - (columns * BUTTON + (columns - 1) * SPACING)
    chromeHeight = bagFrame:GetHeight() - (rows * BUTTON + (rows - 1) * SPACING)
    applySize()
end

-- Rubriken för en grupp. Favorites får en stjärna och Junk visar vad skräpet är värt.
local function headerText(group, junkValue)
    local text = ns.groupNames[group]
    if group == "Favorites" then
        return FAVORITE_ICON .. text
    elseif group == "Junk" and junkValue > 0 then
        return text .. "  " .. GetMoneyString(junkValue)
    end
    return text
end

-- Hela genomgången: sortera in sakerna i grupper, lägg ut grupperna och ge fönstret rätt
-- storlek. Körs efter spelets egen utläggning och varje gång innehållet ändras.
local function relayout()
    if not bagFrame:IsShown() then
        return -- görs när fönstret öppnas
    end
    local atMerchant = ns.IsAtMerchant()

    -- 1. Sortera in varje sak i sin grupp. Tomma platser räknas per väsktyp.
    entryCount = 0
    for _, list in pairs(groupLists) do
        wipe(list)
    end
    wipe(emptyByFamily)
    local junkValue = 0
    for _, button in bagFrame:EnumerateValidItems() do
        local bagID, slot = button:GetBagID(), button:GetID()
        local info = C_Container.GetContainerItemInfo(bagID, slot)
        if info then
            rememberNew(bagID, slot, info.itemID)
            local _, _, _, equipLocation, _, classID, subClassID = C_Item.GetItemInfoInstant(info.itemID)
            local entry = newEntry()
            entry.button, entry.bagID, entry.slot = button, bagID, slot
            entry.isEmpty = false
            local isQuestItem = ns.IsQuestItem(bagID, slot, info)
            entry.group, entry.subOrder = ns.GetGroup(bagID, slot, info, classID, subClassID, isQuestItem)
            entry.quality = info.quality or 0
            entry.name = ns.GetItemName(info.hyperlink)
            entry.count = info.stackCount or 1
            entry.itemID, entry.link, entry.isBound = info.itemID, info.hyperlink, info.isBound
            entry.isGear = classID == Enum.ItemClass.Weapon or classID == Enum.ItemClass.Armor
            entry.equipLocation = equipLocation
            entry.locked = isQuestItem or ns.IsInEquipmentSet(info.itemID)
            entry.junkMarked = ns.IsJunkMarked(info.itemID)
            entry.noValue = info.hasNoValue
            entry.neededLater = ns.IsNeededLater ~= nil and ns.IsNeededLater(info.itemID)
            if entry.group == "Junk" and not info.hasNoValue then
                local sellPrice = select(11, C_Item.GetItemInfo(info.hyperlink))
                junkValue = junkValue + (sellPrice or 0) * entry.count
            end
            addToGroup(entry.group, entry)
        elseif bagID ~= KEYRING_CONTAINER then -- tomma platser på nyckelringen visas inte
            local _, family = C_Container.GetContainerNumFreeSlots(bagID)
            family = family or 0
            local empty = emptyByFamily[family]
            if not empty then
                empty = newEntry()
                empty.button, empty.bagID, empty.slot = button, bagID, slot
                empty.isEmpty, empty.group, empty.family, empty.free = true, "Empty", family, 0
                -- Tabellen kan ha använts för en sak förut, så allt som märkena läser nollställs.
                empty.locked, empty.isGear, empty.junkMarked, empty.neededLater = false, false, false, false
                empty.quality, empty.noValue = 0, true
                emptyByFamily[family] = empty
                addToGroup("Empty", empty)
            elseif bagID < empty.bagID or (bagID == empty.bagID and slot < empty.slot) then
                -- Rutan som syns är den första lediga platsen, där spelet lägger nya saker.
                empty.button, empty.bagID, empty.slot = button, bagID, slot
            end
            empty.free = empty.free + 1
        end
    end
    for _, list in pairs(groupLists) do
        table.sort(list, ns.CompareEntries)
    end

    -- 2. Lägg ut grupperna rad för rad: en grupp delar rad med föregående om den får
    --    plats, annars börjar en ny rad.
    releaseHeaders()
    wipe(groupFirst)
    wipe(groupOfButton)
    newGroupIndex = nil
    local x, y, shelfHeight = 0, 0, 0
    for _, group in ipairs(ns.groupOrder) do
        local list = groupLists[group]
        if list and #list > 0 then
            local groupIndex = #groupFirst + 1
            groupFirst[groupIndex] = list[1].button
            if group == "New" then
                newGroupIndex = groupIndex
            end
            local header = acquireHeader()
            header:SetText(headerText(group, junkValue))
            local columns = math.min(#list, COLUMNS)
            local rows = math.ceil(#list / COLUMNS)
            -- Gruppen är minst lika bred som sin rubrik, så att rubrikerna inte krockar.
            local width = math.max(columns * BUTTON + (columns - 1) * SPACING, math.ceil(header:GetStringWidth()))
            local height = HEADER + rows * BUTTON + (rows - 1) * SPACING
            local left = (x == 0) and 0 or (x + GROUP_GAP)
            if x > 0 and left + width > GRID_WIDTH then
                -- Får inte plats på raden: börja en ny.
                y = y + shelfHeight + SHELF_GAP
                left, shelfHeight = 0, 0
            end
            headerX[headers.used], headerY[headers.used] = left, y
            for index, entry in ipairs(list) do
                entry.x = left + ((index - 1) % COLUMNS) * CELL
                entry.y = y + HEADER + math.floor((index - 1) / COLUMNS) * CELL
                entry.placed = true
                groupOfButton[entry.button] = groupIndex
            end
            x = left + width
            shelfHeight = math.max(shelfHeight, height)
        end
    end
    contentHeight = y + shelfHeight

    -- 3. Flytta rubrikerna och spelets rutor dit. Rutor som inte behövs (tomma platser
    --    utom en per väsktyp) döljs.
    for i = 1, headers.used do
        anchor(headers.objects[i], headerX[i], headerY[i])
    end
    wipe(shownButtons)
    for i = 1, entryCount do
        local entry = entries[i]
        if entry.placed then
            anchor(entry.button, entry.x, entry.y)
            entry.button:Show()
            updateExtras(entry, atMerchant)
            shownButtons[entry.button] = true
        end
    end
    for _, button in bagFrame:EnumerateValidItems() do
        if not shownButtons[button] then
            button:Hide()
        end
    end

    -- 4. Med handkontroll lägger spelet in väskorna du har på dig i rutnätet. De ska inte
    --    synas bland sakerna, så Tidy Pack döljer dem.
    if GamepadBagBar and GamepadBagBar:IsShown() then
        GamepadBagBar:Hide()
    end

    applySize()

    -- Knappen Sell Junk ligger ovanför fönstret och följer med när höjden ändras.
    if ns.UpdateJunkButton then
        ns.UpdateJunkButton()
    end

    -- Handkontrollens markör kan stå på en ruta som just dolts (se Gamepad.lua).
    if ns.OnLayoutChanged then
        ns.OnLayoutChanged()
    end
end

-- Andra filer (t.ex. Favorites.lua och QuestLock.lua) ber om en ny genomgång här.
function ns.Refresh()
    if bagFrame and bagFrame:IsShown() then
        relayout()
    end
end

-- Sant om rutan är låst just nu, hos en handlare. QuestLock.lua ger den en röd rad i
-- tooltipen.
function ns.IsLockedButton(button)
    return button ~= nil and lockedButtons[button] == true and ns.IsAtMerchant()
end

-- Rutan som handkontrollens markör börjar på: första saken i New, annars första rutan.
function ns.GetStartButton()
    return groupFirst[newGroupIndex or 1]
end

-- Första rutan i gruppen före (step = -1) eller efter (step = 1) rutans egen grupp. Efter
-- den sista gruppen kommer den första igen.
function ns.GetGroupJumpTarget(button, step)
    local count = #groupFirst
    local index = groupOfButton[button]
    if count == 0 or not index then
        return ns.GetStartButton()
    end
    return groupFirst[(index - 1 + step) % count + 1]
end

-- Den synliga ruta som ligger närmast en punkt i väskfönstret.
function ns.GetNearestShownButton(x, y)
    local nearest, nearestDistance
    for button in pairs(shownButtons) do
        local buttonX, buttonY = button:GetCenter()
        if buttonX then
            local distance = (buttonX - x) ^ 2 + (buttonY - y) ^ 2
            if not nearestDistance or distance < nearestDistance then
                nearest, nearestDistance = button, distance
            end
        end
    end
    return nearest
end

---------------------------------------------------------------------------
-- Varning när väskorna blir fulla
---------------------------------------------------------------------------

-- Visas en gång mitt på skärmen, som spelets egna felmeddelanden, när den sista lediga
-- platsen fylls.
local lastFree

ns.RegisterEvent("PLAYER_ENTERING_WORLD", function()
    lastFree = C_Container.CalculateTotalNumberOfFreeBagSlots()
end)

ns.RegisterEvent("BAG_UPDATE_DELAYED", function()
    local free = C_Container.CalculateTotalNumberOfFreeBagSlots()
    if free == 0 and lastFree and lastFree > 0 then
        UIErrorsFrame:AddMessage(L["Your bags are full."], 1.0, 0.1, 0.1, 1.0)
    end
    lastFree = free
end)

---------------------------------------------------------------------------
-- Start
---------------------------------------------------------------------------

ns.OnLoad(function()
    bagFrame = ContainerFrameCombinedBags
    if not (bagFrame and bagFrame.UpdateItemLayout and bagFrame.UpdateItems and bagFrame.UpdateFrameSize) then
        ns.Print(L["Couldn't find the game's bag window, so the bags look as usual."])
        return
    end
    ns.bagFrame = bagFrame

    overlay = CreateFrame("Frame", nil, bagFrame)
    overlay:SetAllPoints()

    hooksecurefunc(bagFrame, "UpdateFrameSize", onFrameSizeUpdated)
    hooksecurefunc(bagFrame, "UpdateItemLayout", relayout)
    hooksecurefunc(bagFrame, "UpdateItems", relayout)

    -- När fönstret stängs glöms gruppen New, och Sell Junk döljs.
    bagFrame:HookScript("OnHide", function()
        wipe(newItems)
        if ns.UpdateJunkButton then
            ns.UpdateJunkButton()
        end
    end)

    -- Spelets knapp för att städa väskorna behövs inte: sakerna visas alltid grupperade.
    -- Spelet visar den igen varje gång fönstret uppdateras, så den döljs direkt efteråt.
    if BagItemAutoSortButton then
        BagItemAutoSortButton:Hide()
        hooksecurefunc(BagItemAutoSortButton, "Show", BagItemAutoSortButton.Hide)
    end

    -- Spelets väskmeny (klick på väskikonen uppe till vänster, med väskfilter, städning och
    -- "Combined Bags") behövs inte heller. Utan den kan ingen råka stänga av Combined Bags.
    local menuButton = bagFrame.PortraitButton
    if menuButton then
        menuButton:Hide()
        hooksecurefunc(menuButton, "Show", menuButton.Hide)
    end
end)
