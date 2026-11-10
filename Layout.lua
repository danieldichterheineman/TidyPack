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

local _, ns = ...
local L = ns.L

-- Mått i enheter, samma som i skissen.
local BUTTON = 37          -- en ruta, samma som spelets mall ContainerFrameItemButtonTemplate
local SPACING = 5          -- avstånd mellan rutor, samma som i spelets eget rutnät
-- Antal kolumner: 14 som standard, och fler (upp till 20) när sakerna annars skulle göra
-- fönstret högre än skärmen (se chooseColumns). Fönstret blir då bredare i stället för högre.
local MIN_COLUMNS, MAX_COLUMNS, COLUMN_STEP = 14, 20, 2
local CELL = BUTTON + SPACING
local function widthOf(cols)
    return cols * BUTTON + (cols - 1) * SPACING
end
local HEADER = 18          -- gruppens rubrik, inklusive luft under den
local GROUP_GAP = 12       -- avstånd mellan grupper som delar rad
local SHELF_GAP = 10       -- avstånd mellan rader av grupper (luft ovanför nästa rubrik)
-- Luft mellan ramen och rutorna. Spelets eget rutnät ligger bara 7–8 enheter från ramen
-- och 4 enheter ovanför pengarna. Tidy Pack lägger till lite mer, så att grupperna inte
-- trängs mot kanterna (användarens önskan 2026-11-09).
local BLIZZARD_MONEY_GAP = 4 -- spelets avstånd mellan rutorna och raden med pengar
-- Den mörka bakgrunden ligger nära fönstrets kant, och sakerna har INSET_PAD luft innanför
-- den (användarens önskan 2026-11-10: luften hade försvunnit).
local PADDING_SIDE = 14      -- från fönstrets inre kant till sakerna (inklusive luften)
local INSET_PAD = 12         -- luft mellan bakgrundens kant och sakerna
local PADDING_TOP = 16       -- mellan sökrutan och första rubriken (4 till bakgrunden + luften)
local MONEY_GAP = 16         -- mellan sista raden rutor och raden med pengar
local TARGET_SCALE = 0.85    -- så mycket får spelet krympa fönstret för att få plats
local TAB_ROOM = 30          -- flikarna ovanför fönstret
local LOW_SPACE = 5        -- så här få lediga platser gör siffran i Empty röd
local DIVIDER_ATLAS = "bank-divider" -- spelets linje i Forevers bankfönster (Camelot/BankFrame.xml)
local DIVIDER_GAP = 6      -- luft ovanför och under linjen före specialväskorna
-- Väskplatser som kan ha en specialväska: de fyra vanliga och reagensväskan. Med mus visar
-- spelet reagensväskan i ett eget fönster, och då finns den inte i det här.
local LAST_BAG = Constants.InventoryConstants.NumBagSlots + Constants.InventoryConstants.NumReagentBagSlots

-- Utrustning där nivån inte säger något visas utan nivå (skjortor och tabarder).
local NO_LEVEL = { INVTYPE_BODY = true, INVTYPE_TABARD = true, INVTYPE_NON_EQUIP_IGNORE = true }

-- Stjärnan framför rubriken Favorites.
local FAVORITE_ICON = "|A:auctionhouse-icon-favorite:13:13|a "

local bagFrame                    -- spelets fönster med alla väskor i ett
local overlay                     -- vår egen ram i spelets fönster, för rubrikerna
local inset                       -- den mörka, infällda bakgrunden bakom sakerna
local contentHeight               -- höjden på det Tidy Pack lägger ut
local bagsContentHeight           -- höjden i fliken Bags, som fliken Sets minst får
local gridCols = MIN_COLUMNS      -- antal kolumner just nu
local gridWidth = widthOf(MIN_COLUMNS) -- rutnätets bredd just nu
local measurer                    -- osynlig text som mäter hur breda rubrikerna är
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
local emptyByFamily = {}   -- väsktyp → tomma platser av den typen (0 = vanlig väska), eller
                           -- "bag3" → tomma platser i specialväskan i plats 3
local specialBags = {}     -- bagID → true för specialväskor (koger, själsväska, yrkesväska …)
local divider              -- linjen ovanför specialväskorna
local shownButtons = {}    -- rutorna som syns efter senaste genomgången
local lockedButtons = setmetatable({}, { __mode = "k" }) -- rutor som är låsta hos handlaren
local disabledButtons = setmetatable({}, { __mode = "k" }) -- rutor som Tidy Pack stängt av
local emptyFree = setmetatable({}, { __mode = "k" })     -- tom ruta → antal lediga platser, för tooltipen

-- För handkontrollen (Gamepad.lua): första rutan i varje grupp, i den ordning grupperna
-- visas, och vilken grupp varje ruta hör till.
local groupFirst = {}                                    -- 1, 2, 3 … → gruppens första ruta
local groupOfButton = setmetatable({}, { __mode = "k" }) -- ruta → plats i groupFirst
local newGroupIndex                                      -- gruppen New, om den visas
local startGroupIndex                                    -- första gruppen med en riktig sak (inte den tomma rutan)

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

-- Tooltip på den tomma rutan: hur många platser som är lediga och vad rutan är till för.
local function showEmptyTooltip(button)
    local free = emptyFree[button]
    if not free then
        return
    end
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    GameTooltip_SetTitle(GameTooltip, L["Free slots: %d"]:format(free))
    GameTooltip_AddInstructionLine(GameTooltip, L["Drop an item here to put it in your bags."])
    GameTooltip:Show()
end

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
            -- Ett + mitt på den tomma rutan, som den tomma rutan i fliken Sets: släpp en sak här.
            plus = button:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge"),
        }
        extra.plus:SetPoint("CENTER", 0, 1)
        extra.plus:SetText("+")
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
        button:HookScript("OnEnter", showEmptyTooltip)
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
    extra.plus:SetShown(entry.isEmpty == true)
    emptyFree[button] = entry.isEmpty and entry.free or nil
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
    -- Låsen går att stänga av i inställningarna (Options.lua).
    local locked = atMerchant and entry.locked == true and ns.db.lockAtMerchant
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
    region:SetPoint("TOPLEFT", bagFrame.MoneyFrame, "TOPRIGHT", x - gridWidth - PADDING_SIDE,
        MONEY_GAP + contentHeight - y)
end

-- Ger spelets fönster Tidy Packs storlek: kanterna, titelraden och raden med pengar som
-- spelet räknade ut, plus det Tidy Pack lägger ut.
local function applySize()
    if not contentHeight or not chromeWidth then
        return
    end
    local height = contentHeight + chromeHeight + PADDING_TOP + (MONEY_GAP - BLIZZARD_MONEY_GAP)
    bagFrame:SetSize(gridWidth + chromeWidth + 2 * PADDING_SIDE, height)
    -- Bakgrunden följer det Tidy Pack lägger ut, och hänger i raden med pengar som allt annat.
    if inset then
        inset:ClearAllPoints()
        inset:SetPoint("TOPLEFT", bagFrame.MoneyFrame, "TOPRIGHT", -gridWidth - PADDING_SIDE - INSET_PAD,
            MONEY_GAP + contentHeight + INSET_PAD)
        inset:SetPoint("BOTTOMRIGHT", bagFrame.MoneyFrame, "TOPRIGHT", -PADDING_SIDE + INSET_PAD,
            MONEY_GAP - INSET_PAD)
        inset:Show()
    end
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

-- Rubriken för en specialväska: väskans egen ikon och namn.
local function bagHeaderText(bagID)
    local icon = GetInventoryItemTexture("player", C_Container.ContainerIDToInventoryID(bagID))
    local name = C_Container.GetBagName(bagID) or ""
    return icon and ("|T%s:13:13|t %s"):format(icon, name) or name
end

-- Sant om väskan i platsen är en specialväska: den tar bara vissa sorters saker
-- (bagFamily är inte 0), eller är reagensväskan.
local function isSpecialBag(bagID)
    if C_Container.GetContainerNumSlots(bagID) == 0 then
        return false
    end
    if bagID == Enum.BagIndex.ReagentBag then
        return true
    end
    local _, family = C_Container.GetContainerNumFreeSlots(bagID)
    return family ~= nil and family ~= 0
end

-- Antalet lediga platser i väskikonen uppe till vänster, som spelet gör med handkontroll
-- (spelet visar siffran bara då). Spelets egen text, så den följer med fönstret.
local function updatePortraitCount()
    local container = bagFrame.CountContainer
    local count = container and container.Count
    if not count or InputUtil.IsGamepadUIEnabled() then
        return -- med handkontroll sköter spelet siffran själv
    end
    count:SetText(("(%d)"):format(C_Container.CalculateTotalNumberOfFreeBagSlots()))
    count:Show()
end

-- Listan med set i fliken Sets (SetsView.lua) i stället för sakerna.
local function layoutSetsView(atMerchant)
    -- Spelet visar sökrutan igen när fönstret uppdateras; i fliken Sets behövs den inte.
    if BagItemSearchBox and BagItemSearchBox:GetParent() == bagFrame then
        BagItemSearchBox:Hide()
    end
    releaseHeaders()
    if divider then
        divider:Hide()
    end
    for _, button in bagFrame:EnumerateValidItems() do
        if lockedButtons[button] or disabledButtons[button] then
            setLocked(button, false)
        end
        button:Hide()
    end
    wipe(shownButtons)
    wipe(groupFirst)
    wipe(groupOfButton)
    newGroupIndex, startGroupIndex = nil, nil
    -- Allt hänger i raden med pengar och räknas uppifrån, så höjden måste vara känd innan
    -- något placeras. Därför samlas platserna först och sätts sedan.
    local placements = {}
    local setsHeight, rows = ns.LayoutSetsView(function(region, x, y)
        placements[#placements + 1] = { region, x, y }
    end, gridWidth)
    -- Fönstret är lika högt i båda flikarna: fliken Sets är minst lika hög som fliken Bags.
    contentHeight = math.max(setsHeight, bagsContentHeight or 0)
    for _, placement in ipairs(placements) do
        anchor(placement[1], placement[2], placement[3])
    end
    for index, row in ipairs(rows) do
        shownButtons[row] = true
        groupFirst[index] = row
        groupOfButton[row] = index
    end
    if ns.UpdateSetsNotice then
        ns.UpdateSetsNotice()
    end
    applySize()
    updatePortraitCount()
    if ns.OnLayoutChanged then
        ns.OnLayoutChanged()
    end
end

-- Lägger ut grupperna rad för rad med cols kolumner: en grupp delar rad med föregående om
-- den får plats, annars börjar en ny rad. Med apply = false räknas bara höjden ut (för att
-- välja antal kolumner), med apply = true sätts också platserna. Returnerar höjden och var
-- linjen ovanför specialväskorna ska ligga (nil om det inte finns någon).
local function flow(cols, apply, junkValue)
    local width = widthOf(cols)
    local x, y, shelfHeight = 0, 0, 0
    local dividerY
    local function place(group, text)
        local list = groupLists[group]
        if not (list and #list > 0) then
            return
        end
        measurer:SetText(text)
        local groupCols = math.min(#list, cols)
        local rows = math.ceil(#list / cols)
        -- Gruppen är minst lika bred som sin rubrik, så att rubrikerna inte krockar.
        local groupWidth = math.max(widthOf(groupCols), math.ceil(measurer:GetStringWidth()))
        local height = HEADER + rows * BUTTON + (rows - 1) * SPACING
        local left = (x == 0) and 0 or (x + GROUP_GAP)
        if x > 0 and left + groupWidth > width then
            -- Får inte plats på raden: börja en ny.
            y = y + shelfHeight + SHELF_GAP
            left, shelfHeight = 0, 0
        end
        if apply then
            local groupIndex = #groupFirst + 1
            groupFirst[groupIndex] = list[1].button
            if group == "New" then
                newGroupIndex = groupIndex
            end
            if not startGroupIndex and not list[1].isEmpty then
                startGroupIndex = groupIndex
            end
            local header = acquireHeader()
            header:SetText(text)
            headerX[headers.used], headerY[headers.used] = left, y
            for index, entry in ipairs(list) do
                entry.x = left + ((index - 1) % cols) * CELL
                entry.y = y + HEADER + math.floor((index - 1) / cols) * CELL
                entry.placed = true
                groupOfButton[entry.button] = groupIndex
            end
        end
        x = left + groupWidth
        shelfHeight = math.max(shelfHeight, height)
    end
    for _, group in ipairs(ns.groupOrder) do
        place(group, headerText(group, junkValue))
    end

    -- Specialväskorna längst ned, under spelets linje, i väskplatsernas ordning.
    for bagID = 1, LAST_BAG do
        local list = specialBags[bagID] and groupLists["bag" .. bagID]
        if list and #list > 0 then
            if not dividerY then
                y = y + shelfHeight + DIVIDER_GAP
                dividerY = y
                y = y + divider:GetHeight() + DIVIDER_GAP
                x, shelfHeight = 0, 0
            end
            place("bag" .. bagID, bagHeaderText(bagID))
        end
    end
    return y + shelfHeight, dividerY
end

-- Så hög får det Tidy Pack lägger ut vara. Spelet krymper fönstret (högst till 75 %) så att
-- det får plats på skärmen, men Tidy Pack håller sig hellre till TARGET_SCALE och gör fönstret
-- bredare i stället (se chooseColumns). Nil om fönstrets mått inte är kända än.
local function maxContentHeight()
    if not chromeHeight then
        return nil
    end
    -- Under fönstret ligger spelets egen marginal (CONTAINER_OFFSET_Y), ovanför flikarna.
    local room = (GetScreenHeight() - (CONTAINER_OFFSET_Y or 85) - TAB_ROOM) / TARGET_SCALE
    return room - (chromeHeight + PADDING_TOP + (MONEY_GAP - BLIZZARD_MONEY_GAP))
end

-- Antal kolumner: så få som möjligt, men fönstret ska inte bli för högt för skärmen och inte
-- för brett (högst tre fjärdedelar av skärmens bredd).
local function chooseColumns(junkValue)
    local limit = maxContentHeight()
    local maxWidth = GetScreenWidth() * 0.75
    local chosen = MIN_COLUMNS
    for cols = MIN_COLUMNS, MAX_COLUMNS, COLUMN_STEP do
        if cols > MIN_COLUMNS and widthOf(cols) > maxWidth then
            break
        end
        chosen = cols
        if not limit or flow(cols, false, junkValue) <= limit then
            break
        end
    end
    return chosen
end

-- Hela genomgången: sortera in sakerna i grupper, lägg ut grupperna och ge fönstret rätt
-- storlek. Körs efter spelets egen utläggning och varje gång innehållet ändras.
local function relayout()
    if not bagFrame:IsShown() then
        return -- görs när fönstret öppnas
    end
    local atMerchant = ns.IsAtMerchant()
    if ns.IsSetsView and ns.IsSetsView() then
        layoutSetsView(atMerchant)
        return
    end

    -- Vilka väskplatser har en specialväska? Deras saker och tomma platser får egna grupper
    -- längst ned, med väskans namn.
    wipe(specialBags)
    for bagID = 1, LAST_BAG do
        specialBags[bagID] = isSpecialBag(bagID) or nil
    end

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
            if specialBags[bagID] then
                -- Allt i en specialväska stannar i väskans egen grupp.
                entry.group, entry.subOrder = "bag" .. bagID, 0
            else
                entry.group, entry.subOrder = ns.GetGroup(bagID, slot, info, classID, subClassID, isQuestItem)
            end
            entry.quality = info.quality or 0
            entry.name = ns.GetItemName(info.hyperlink)
            entry.count = info.stackCount or 1
            entry.itemID, entry.link, entry.isBound = info.itemID, info.hyperlink, info.isBound
            entry.isGear = classID == Enum.ItemClass.Weapon or classID == Enum.ItemClass.Armor
            entry.equipLocation = equipLocation
            entry.locked = isQuestItem or ns.IsInEquipmentSet(info.itemID) or ns.IsInAnySet(info.itemID)
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
            -- En specialväskas tomma platser räknas för sig, i väskans egen grupp.
            local key = specialBags[bagID] and ("bag" .. bagID) or family
            local group = specialBags[bagID] and ("bag" .. bagID) or "Empty"
            local empty = emptyByFamily[key]
            if not empty then
                empty = newEntry()
                empty.button, empty.bagID, empty.slot = button, bagID, slot
                empty.isEmpty, empty.group, empty.family, empty.free = true, group, family, 0
                -- Tabellen kan ha använts för en sak förut, så allt som märkena läser nollställs.
                empty.locked, empty.isGear, empty.junkMarked, empty.neededLater = false, false, false, false
                empty.quality, empty.noValue = 0, true
                emptyByFamily[key] = empty
                addToGroup(group, empty)
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

    -- 2. Välj antal kolumner och lägg ut grupperna (se flow).
    releaseHeaders()
    wipe(groupFirst)
    wipe(groupOfButton)
    newGroupIndex, startGroupIndex = nil, nil
    gridCols = chooseColumns(junkValue)
    gridWidth = widthOf(gridCols)
    local dividerY
    -- Höjden måste vara känd innan något placeras, eftersom allt räknas uppifrån men hänger
    -- i raden med pengar (se anchor). Linjen placerades tidigare före höjden: direkt efter
    -- inloggning eller /reload var höjden då okänd (nil) och genomgången stannade med ett fel
    -- när du bar en specialväska.
    contentHeight, dividerY = flow(gridCols, true, junkValue)
    bagsContentHeight = contentHeight
    if dividerY then
        anchor(divider, -6, dividerY)
        divider:SetWidth(gridWidth + 12)
        divider:Show()
    else
        divider:Hide()
    end

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
    updatePortraitCount()
    if ns.UpdateSetsNotice then
        ns.UpdateSetsNotice()
    end

    -- Handkontrollens markör kan stå på en ruta som just dolts (se Gamepad.lua).
    if ns.OnLayoutChanged then
        ns.OnLayoutChanged()
    end
end

-- Stoppar ett fel genomgången visar spelet sitt eget rutnät. Då skrivs felet en gång i
-- chatten, så att testare utan spelets felrutor (scriptErrors) kan skicka det vidare.
-- Felet skickas också till spelets vanliga felhantering.
local errorReported = false

local function safeRelayout()
    local ok, problem = pcall(relayout)
    if not ok then
        if not errorReported then
            errorReported = true
            ns.Print(L["Couldn't sort your bags because of an error. Please send this line to the author: %s"]
                :format(tostring(problem)))
        end
        geterrorhandler()(problem)
    end
end

-- Andra filer (t.ex. Marks.lua och QuestLock.lua) ber om en ny genomgång här.
function ns.Refresh()
    if bagFrame and bagFrame:IsShown() then
        safeRelayout()
    end
end

-- Sant om rutan är låst just nu, hos en handlare. QuestLock.lua ger den en röd rad i
-- tooltipen.
function ns.IsLockedButton(button)
    return button ~= nil and lockedButtons[button] == true and ns.IsAtMerchant()
end

-- Rutan som handkontrollens markör börjar på: första saken i New, annars första saken i första
-- gruppen som har en riktig sak (inte den tomma rutan "Add to bag", som står näst först).
function ns.GetStartButton()
    return groupFirst[newGroupIndex or startGroupIndex or 1]
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

    -- En hel, mörk bakgrund bakom sakerna (användarens önskan 2026-11-09). Spelets fönster
    -- är halvgenomskinligt, och när Tidy Pack döljer de tomma rutorna lyser världen och
    -- questlistan igenom. Mallen är spelets infällda yta (InsetFrameTemplate, som i handlarens
    -- fönster), med sin marmor mörkare. Den ritas på fönstrets egen nivå, under rutorna.
    inset = CreateFrame("Frame", nil, bagFrame, "InsetFrameTemplate")
    if inset.Bg then
        inset.Bg:SetVertexColor(0.7, 0.7, 0.7)
    end
    inset:Hide()

    -- Osynlig text som mäter hur breda rubrikerna är, för att kunna räkna ut höjden utan att
    -- lägga ut något (se flow).
    measurer = overlay:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    measurer:SetAlpha(0)

    -- Linjen ovanför specialväskorna, lika bred som rutorna och lite till (bredden sätts vid
    -- varje utläggning, eftersom antalet kolumner kan ändras).
    divider = overlay:CreateTexture(nil, "ARTWORK")
    divider:SetAtlas(DIVIDER_ATLAS)
    local atlasInfo = C_Texture.GetAtlasInfo(DIVIDER_ATLAS)
    local dividerWidth = gridWidth + 12
    divider:SetSize(dividerWidth, atlasInfo and atlasInfo.width > 0
        and math.max(2, math.floor(atlasInfo.height * dividerWidth / atlasInfo.width + 0.5)) or 8)
    divider:Hide()

    hooksecurefunc(bagFrame, "UpdateFrameSize", onFrameSizeUpdated)
    hooksecurefunc(bagFrame, "UpdateItemLayout", safeRelayout)
    hooksecurefunc(bagFrame, "UpdateItems", safeRelayout)

    -- När fönstret stängs glöms gruppen New.
    bagFrame:HookScript("OnHide", function()
        wipe(newItems)
    end)

    -- Rubriken "Backpack" i stället för spelets "Combined Backpack" (användarens önskan).
    -- Spelet sätter sin rubrik i UpdateName, så Tidy Pack byter den direkt efteråt. Ordet
    -- är spelets eget (BACKPACK_TOOLTIP), så det följer spelets språk.
    local function setTitle()
        bagFrame:SetTitle(BACKPACK_TOOLTIP)
    end
    hooksecurefunc(bagFrame, "UpdateName", setTitle)
    setTitle()

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
