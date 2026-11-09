-- TidyPack – MakeRoom.lua
-- Förslag på saker att radera, i en liten panel. Två tillfällen:
--   1. Du lootar en sak som står på skräplistan (Marks.lua): Tidy Pack frågar direkt om den
--      ska raderas. Varje sak räknas från det att den kom med på listan.
--   2. Något i lootfönstret får inte plats (spelet säger "Inventory is full."): Tidy Pack
--      föreslår en sak från skräplistan, annars den billigaste grå saken – men bara om det
--      du försöker loota är värt mer.
-- Panelen hänger under lootfönstret när det är öppet, i samma sorts panel och lika bred, så
-- att den känns som en del av det. Annars syns den uppe i mitten, där spelets egna frågor
-- visas. Vad som räknas som skräp avgör ns.GetJunkKind (Junk.lua): stjärnmärkta och låsta
-- saker, quest-saker och grå saker som en quest behöver senare föreslås aldrig.
-- Du godkänner med ett tryck på Delete. Båda tillfällena går att stänga av i inställningarna.
-- ⚠️ Spelet låter bara ett addon radera en sak när spelaren trycker eller klickar
--    (DeleteCursorItem kräver en hårdvaruhändelse sedan patch 9.0.2, och raderar högst en
--    sak per händelse sedan 9.1.5). Därför raderar Tidy Pack aldrig något av sig själv.
-- ⚠️ I strid väntar frågorna om skräplistan tills striden är över. Med handkontroll kopplas
--    panelen in i spelets styrning (lootfönstrets markör, eller som en fråga uppe i mitten),
--    men bara utanför strid.
-- ⚠️ Panelen använder spelets lootfönster (LootFrame). Byter ett annat addon ut
--    lootfönstret syns panelen uppe i mitten i stället.

local addonName, ns = ...
local L = ns.L

local NUM_BAGS = Constants.InventoryConstants.NumBagSlots
local NUM_ALL_BAGS = NUM_BAGS + Constants.InventoryConstants.NumReagentBagSlots
local LOOT_WIDTH = 220     -- samma bredd som spelets lootfönster (LootFrame i LootFrame.xml)
local ALONE_WIDTH = 260    -- ensam uppe i mitten
local ALONE_TOP = -135     -- där spelets egna frågor brukar visas
local TEXT_TOP = 30        -- under panelens rubrik, som är 20 enheter hög
local TEXT_INSET = 14      -- bakgrunden börjar 6 enheter in, och texten 8 enheter till
local BUTTON_WIDTH, BUTTON_HEIGHT = 90, 22
local BOTTOM_SPACE = 44    -- avstånd till knapparna, knapparna och marginalen under dem

local panel, message
local suggestion = {}           -- saken som föreslås: kind ("looted" eller "full"), bagID, slot, itemID
local queue = {}                -- itemID för lootade saker från skräplistan, i tur och ordning
local seenCount = {}            -- itemID → antal i väskorna senast, för sakerna på skräplistan
local countsReady = false
local registeredAsPopup = false -- panelen är kopplad till handkontrollen som en fråga
local showNext                  -- definieras längre ned

local function canUseNavigation()
    return SmartNavigation ~= nil and InputUtil.IsGamepadUIEnabled()
        and ns.CanUseNavigation ~= nil and ns.CanUseNavigation()
end

-- Sakens värde hos en handlare: pris × antal. Det andra värdet är falskt om spelet inte har
-- sakens data än.
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

-- Lediga platser i vanliga väskor, där vad som helst får plats.
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

-- Det dyraste som ligger kvar i lootfönstret: länk, värde och om värdet är känt.
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

-- Den sak i väskorna som bäst kan raderas för att det nya ska få plats. Bara vanliga väskor,
-- eftersom det nya inte säkert får plats i en specialväska.
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
                    -- Skräplistan föreslås alltid, grått bara om det nya är värt mer.
                    local allowed = marked or (lootValueKnown and value < lootValue)
                    -- Skräplistan går före grått, och billigast går först.
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

-- Var en sak från skräplistan ligger, om den fortfarande räknas som skräp.
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
-- Panelen
---------------------------------------------------------------------------

-- Lägger panelen under lootfönstret om det är öppet, annars (eller med alone) uppe i mitten.
-- Returnerar sant när den hamnade under lootfönstret.
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

-- Kopplar ifrån panelen som fråga för handkontrollen. Går inte i strid; då görs det efteråt.
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
    -- Med handkontroll: under lootfönstret kopplas knapparna in i lootfönstrets markör (de nås
    -- med styrkorset, och markören flyttas inte dit, så att ett tryck på A för att loota aldrig
    -- raderar). Ensam uppe i mitten blir panelen en fråga, som spelets egna frågor.
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

-- Döljer panelen och visar nästa fråga om fler saker från skräplistan har lootats. Stod
-- handkontrollens markör på en av panelens knappar under lootfönstret flyttas den tillbaka
-- till lootet.
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

-- Raderar saken som föreslogs, om den ligger kvar där den låg och fortfarande räknas som
-- skräp. Körs bara när spelaren trycker på Delete – det är trycket som gör att spelet
-- tillåter raderingen.
local function deleteSuggestion()
    local bagID, slot, itemID = suggestion.bagID, suggestion.slot, suggestion.itemID
    hidePanel()
    local info = bagID and C_Container.GetContainerItemInfo(bagID, slot)
    if not info or info.itemID ~= itemID or not ns.GetJunkKind(bagID, slot, info) then
        return
    end
    ClearCursor()
    C_Container.PickupContainerItem(bagID, slot)
    local kind, cursorItemID = GetCursorInfo()
    if kind == "item" and cursorItemID == itemID then
        DeleteCursorItem()
    else
        ClearCursor()
    end
end

---------------------------------------------------------------------------
-- När väskorna är fulla
---------------------------------------------------------------------------

local function offerRoom()
    if not ns.db.suggestWhenFull or not LootFrame:IsShown() or freeNormalSlots() > 0 then
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
-- När en sak från skräplistan lootas
---------------------------------------------------------------------------

-- Visar frågan för nästa lootade sak från skräplistan. Väntar i strid och medan panelen
-- redan visar en fråga.
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

-- Antalet av varje sak på skräplistan just nu, som utgångsläge.
local function countListed()
    wipe(seenCount)
    for itemID in pairs(ns.db.junk) do
        seenCount[itemID] = C_Item.GetItemCount(itemID)
    end
    countsReady = true
end

-- Har någon sak från skräplistan blivit fler sedan sist, har den lootats (eller köpts).
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

-- Marks.lua anropar den här när en sak kommer med på listan eller tas bort. En sak räknas
-- från det att den kom med, så det du redan har frågas det inte om.
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
    button:SetScript("OnClick", onClick)
    return button
end

local function createPanel()
    -- Samma mall som spelets lootfönster bygger på (ScrollingFlatPanelTemplate ärver
    -- DefaultPanelFlatTemplate): ram, bakgrund och rubrik ser likadana ut. Namnet gör panelen
    -- lätt att hitta med /fstack och ger mallens delar egna namn.
    panel = CreateFrame("Frame", "TidyPackMakeRoomPanel", UIParent, "DefaultPanelFlatTemplate")
    panel:SetClampedToScreen(true)
    panel:EnableMouse(true)
    panel:SetTitle(L["Tidy Pack"])
    panel:Hide()

    message = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    message:SetPoint("TOPLEFT", TEXT_INSET, -TEXT_TOP)
    message:SetJustifyH("LEFT")

    -- Två knappar i mitten under texten, som i spelets egna frågor.
    createButton(L["Delete"], deleteSuggestion):SetPoint("BOTTOMRIGHT", panel, "BOTTOM", -4, 12)
    createButton(L["Not now"], hidePanel):SetPoint("BOTTOMLEFT", panel, "BOTTOM", 4, 12)
end

ns.OnLoad(function()
    if not LootFrame then
        return
    end
    createPanel()

    -- Spelets eget meddelande när något inte får plats, samma som lootfönstret lyssnar på.
    ns.RegisterEvent("UI_ERROR_MESSAGE", function(_, errorMessage)
        if errorMessage == ERR_INV_FULL and LootFrame:IsShown() then
            C_Timer.After(0, offerRoom) -- när lootfönstret har visat det som är kvar
        end
    end)

    ns.RegisterEvent("BAG_UPDATE_DELAYED", function()
        checkLooted()
        if not panel:IsShown() then
            return
        end
        -- Förslaget kan vara inaktuellt: saken har flyttats, eller det finns plats nu.
        if suggestion.kind == "full" then
            offerRoom()
        else
            local info = C_Container.GetContainerItemInfo(suggestion.bagID, suggestion.slot)
            if not info or info.itemID ~= suggestion.itemID then
                hidePanel()
            end
        end
    end)

    -- Lootfönstret stängs: förslaget vid fulla väskor behövs inte längre, men en fråga om
    -- skräplistan flyttar upp till mitten.
    ns.RegisterEvent("LOOT_CLOSED", function()
        if not panel:IsShown() or panel:GetParent() ~= LootFrame then
            return
        end
        if suggestion.kind == "looted" then
            local info = C_Container.GetContainerItemInfo(suggestion.bagID, suggestion.slot)
            if info then
                -- Lootfönstret kan vara kvar en stund medan det tonas bort, så panelen flyttas
                -- uttryckligen upp till mitten.
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

    -- Striden är över: koppla ifrån handkontrollen om det fick vänta, och visa det som har
    -- lootats.
    ns.RegisterEvent("PLAYER_REGEN_ENABLED", function()
        if not panel:IsShown() then
            releasePopup()
        end
        showNext()
    end)
end)
