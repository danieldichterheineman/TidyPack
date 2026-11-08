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
local SECTION_GAP = 16     -- avstånd före en ny sektion, med en tunn linje i mitten
local SECTION_TITLE = 22   -- sektionens rubrik, t.ex. Equipment
local MONEY_GAP = 4        -- spelet lägger rutorna 4 enheter ovanför raden med pengar

-- Utrustning där nivån inte säger något visas utan nivå (skjortor och tabarder).
local NO_LEVEL = { INVTYPE_BODY = true, INVTYPE_TABARD = true, INVTYPE_NON_EQUIP_IGNORE = true }

local bagFrame                    -- spelets fönster med alla väskor i ett
local overlay                     -- vår egen ram i spelets fönster, för rubriker och linjer
local contentHeight               -- höjden på det Tidy Pack lägger ut
local chromeWidth, chromeHeight   -- fönstrets kanter, titelrad, sökruta och pengar
local location = ItemLocation:CreateEmpty() -- återanvänds för att läsa en saks nivå

---------------------------------------------------------------------------
-- Återanvända tabeller, textrader och linjer
---------------------------------------------------------------------------
-- Väskorna ändras ofta, t.ex. när man lootar. För att inte skapa nya tabeller och
-- textrader varje gång återanvänds de.

local entries = {}         -- en tabell per sak, eller per sorts tomma platser
local entryCount = 0
local groupLists = {}      -- gruppens namn → sakerna i gruppen
local emptyByFamily = {}   -- väsktyp → tomma platser av den typen (0 = vanlig väska)
local shownButtons = {}    -- rutorna som syns efter senaste genomgången

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

local function createPool(create)
    return { objects = {}, used = 0, create = create }
end

local function acquire(pool)
    pool.used = pool.used + 1
    local object = pool.objects[pool.used]
    if not object then
        object = pool.create()
        pool.objects[pool.used] = object
    end
    object:Show()
    return object
end

local function releaseAll(pool)
    for _, object in ipairs(pool.objects) do
        object:Hide()
    end
    pool.used = 0
end

local headers = createPool(function()
    return overlay:CreateFontString(nil, "OVERLAY", "GameFontNormal")
end)

local sectionTitles = createPool(function()
    return overlay:CreateFontString(nil, "OVERLAY", "GameFontNormalMed3")
end)

local dividers = createPool(function()
    local line = overlay:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(0.6, 0.5, 0.35, 0.5)
    line:SetSize(GRID_WIDTH, 1)
    return line
end)

-- Rubriker och linjer får sin plats först när hela höjden är känd.
local pendingRegions, pendingX, pendingY, pendingCount = {}, {}, {}, 0

local function placeLater(region, x, y)
    pendingCount = pendingCount + 1
    pendingRegions[pendingCount] = region
    pendingX[pendingCount] = x
    pendingY[pendingCount] = y
end

---------------------------------------------------------------------------
-- Text på rutorna: nivå, BoE och antal tomma platser
---------------------------------------------------------------------------

-- Våra textrader per ruta. Rutorna är spelets egna, så Tidy Pack sparar inget i dem –
-- bara här, i en tabell som släpper rutan om spelet slutar använda den.
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
        }
        extra.level:SetPoint("TOPLEFT", 2, -2)
        extra.bind:SetPoint("BOTTOMLEFT", 2, 2)
        extra.bind:SetText(L["BoE"])
        extra.free:SetPoint("BOTTOMRIGHT", -3, 2)
        extras[button] = extra
    end
    return extra
end

local function updateExtras(entry)
    local button = entry.button
    local extra = getExtras(button)

    -- Antalet tomma platser på den enda tomma ruta som syns.
    if entry.isEmpty then
        extra.free:SetText(entry.free)
        extra.free:Show()
    else
        extra.free:Hide()
    end

    -- Nivå uppe till vänster och BoE nere till vänster, på vapen och rustning.
    local level, boe
    if entry.group == "Weapons" or entry.group == "Armor" then
        local _, _, _, equipLocation = C_Item.GetItemInfoInstant(entry.itemID)
        if equipLocation and equipLocation ~= "" and not NO_LEVEL[equipLocation] then
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

    -- Grön pil på väskor som är större än någon av dina väskor (se BagSwap.lua). Pilen
    -- finns redan i spelets ruta men används inte av spelet i väskorna.
    if button.UpgradeIcon then
        local isUpgrade = entry.group == "Bags" and ns.IsBagUpgrade ~= nil
            and ns.IsBagUpgrade(entry.bagID, entry.slot, entry.itemID)
        button.UpgradeIcon:SetShown(isUpgrade == true)
    end
end

---------------------------------------------------------------------------
-- Utläggningen
---------------------------------------------------------------------------

-- Lägger en ruta, rubrik eller linje på plats. x och y räknas från övre vänstra hörnet av
-- det Tidy Pack lägger ut. Allt hänger i spelets rad med pengar, precis som spelets eget
-- rutnät, så att sökrutan, pengarna och spelets andra delar hamnar där de brukar.
local function anchor(region, x, y)
    region:ClearAllPoints()
    region:SetPoint("TOPLEFT", bagFrame.MoneyFrame, "TOPRIGHT", x - GRID_WIDTH, MONEY_GAP + contentHeight - y)
end

-- Ger spelets fönster Tidy Packs storlek: kanterna, titelraden och raden med pengar som
-- spelet räknade ut, plus det Tidy Pack lägger ut.
local function applySize()
    if not contentHeight or not chromeWidth then
        return
    end
    local height = contentHeight + chromeHeight
    bagFrame:SetSize(GRID_WIDTH + chromeWidth, height)
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

-- Sant om någon grupp i sektionen har saker.
local function sectionHasItems(section)
    for _, group in ipairs(section.groups) do
        local list = groupLists[group]
        if list and #list > 0 then
            return true
        end
    end
    return false
end

-- Hela genomgången: sortera in sakerna i grupper, lägg ut grupperna och ge fönstret rätt
-- storlek. Körs efter spelets egen utläggning och varje gång innehållet ändras.
local function relayout()
    if not bagFrame:IsShown() then
        return -- görs när fönstret öppnas
    end

    -- 1. Sortera in varje sak i sin grupp. Tomma platser räknas per väsktyp.
    entryCount = 0
    for _, list in pairs(groupLists) do
        wipe(list)
    end
    wipe(emptyByFamily)
    for _, button in bagFrame:EnumerateValidItems() do
        local bagID, slot = button:GetBagID(), button:GetID()
        local info = C_Container.GetContainerItemInfo(bagID, slot)
        if info then
            local entry = newEntry()
            entry.button, entry.bagID, entry.slot = button, bagID, slot
            entry.isEmpty = false
            entry.group = ns.GetGroup(bagID, slot, info)
            entry.quality = info.quality or 0
            entry.name = ns.GetItemName(info.hyperlink)
            entry.count = info.stackCount or 1
            entry.itemID, entry.link, entry.isBound = info.itemID, info.hyperlink, info.isBound
            addToGroup(entry.group, entry)
        elseif bagID ~= KEYRING_CONTAINER then -- tomma platser på nyckelringen visas inte
            local _, family = C_Container.GetContainerNumFreeSlots(bagID)
            family = family or 0
            local empty = emptyByFamily[family]
            if not empty then
                empty = newEntry()
                empty.button, empty.bagID, empty.slot = button, bagID, slot
                empty.isEmpty, empty.group, empty.family, empty.free = true, "Empty", family, 0
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

    -- 2. Lägg ut sektionerna uppifrån och ned. Inom en sektion läggs grupperna rad för rad:
    --    en grupp delar rad med föregående om den får plats, annars börjar en ny rad.
    releaseAll(headers)
    releaseAll(sectionTitles)
    releaseAll(dividers)
    pendingCount = 0
    local y, firstSection = 0, true
    for _, section in ipairs(ns.sections) do
        if sectionHasItems(section) then
            if not firstSection then
                placeLater(acquire(dividers), 0, y + SECTION_GAP / 2)
                y = y + SECTION_GAP
            end
            if section.title then
                local title = acquire(sectionTitles)
                title:SetText(section.title)
                placeLater(title, 0, y)
                y = y + SECTION_TITLE
            end
            firstSection = false

            local x, shelfHeight = 0, 0
            for _, group in ipairs(section.groups) do
                local list = groupLists[group]
                if list and #list > 0 then
                    local header = acquire(headers)
                    header:SetText(ns.groupNames[group])
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
                    placeLater(header, left, y)
                    for index, entry in ipairs(list) do
                        entry.x = left + ((index - 1) % COLUMNS) * CELL
                        entry.y = y + HEADER + math.floor((index - 1) / COLUMNS) * CELL
                        entry.placed = true
                    end
                    x = left + width
                    shelfHeight = math.max(shelfHeight, height)
                end
            end
            y = y + shelfHeight
        end
    end
    contentHeight = y

    -- 3. Flytta spelets rutor dit. Rutor som inte behövs (tomma platser utom en per
    --    väsktyp) döljs.
    for i = 1, pendingCount do
        anchor(pendingRegions[i], pendingX[i], pendingY[i])
    end
    wipe(shownButtons)
    for i = 1, entryCount do
        local entry = entries[i]
        if entry.placed then
            anchor(entry.button, entry.x, entry.y)
            entry.button:Show()
            updateExtras(entry)
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
end

---------------------------------------------------------------------------
-- Start
---------------------------------------------------------------------------

ns.OnLoad(function()
    bagFrame = ContainerFrameCombinedBags
    if not (bagFrame and bagFrame.UpdateItemLayout and bagFrame.UpdateItems and bagFrame.UpdateFrameSize) then
        ns.Print(L["Couldn't find the game's bag window, so the bags look as usual."])
        return
    end

    overlay = CreateFrame("Frame", nil, bagFrame)
    overlay:SetAllPoints()

    hooksecurefunc(bagFrame, "UpdateFrameSize", onFrameSizeUpdated)
    hooksecurefunc(bagFrame, "UpdateItemLayout", relayout)
    hooksecurefunc(bagFrame, "UpdateItems", relayout)

    -- Spelets knapp för att städa väskorna behövs inte: sakerna visas alltid grupperade.
    -- Spelet visar den igen varje gång fönstret uppdateras, så den döljs direkt efteråt.
    if BagItemAutoSortButton then
        BagItemAutoSortButton:Hide()
        hooksecurefunc(BagItemAutoSortButton, "Show", BagItemAutoSortButton.Hide)
    end
end)
