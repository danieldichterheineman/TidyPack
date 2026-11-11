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
ns.ITEM_BUTTON_SIZE = BUTTON -- QuestsView.lua gör rutorna mindre i fliken Quests
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
local PADDING_SIDE = 16      -- från fönstrets inre kant till sakerna (inklusive luften); 14 gav för lite luft vid sidorna
local INSET_PAD = 12         -- luft mellan bakgrundens kant och sakerna, upptill och nertill
-- Bakgrunden (och raden med pengar) når lite närmare fönstrets sidor än sakerna (användarens önskan
-- 2026-11-11): luften vid sidorna är större innanför bakgrunden än upptill och nertill.
local INSET_PAD_X = 15
local PADDING_TOP = 20       -- mellan titelraden och första rubriken (6 till bakgrunden + luften); 16 gav för lite luft
-- Raden med pengar görs högre, och "17 free" och väskraden står till vänster på den, pengarna till
-- höger (användarens önskan 2026-11-11). Spelets låga myntruta (MoneyFrame.Border) döljs och ersätts
-- av en högre med samma bilder; pengarna är kvar på spelets plats, mitt i den högre raden.
local BAR_HEIGHT = 46       -- den högre radens höjd (38 var för lågt: väskorna nådde kanterna)
-- Spelet sätter pengarna 8 från nederkanten (UpdateCurrencyFrames). De flyttas upp så här mycket, så
-- att de står mitt i den högre raden: (6 + 46 / 2) - (8 + 16 / 2) = 13. Fönstret blir lika mycket högre.
local MONEY_RAISE = 13
local BAG_ROW = 17          -- luft mellan bakgrunden och den högre raden
local moneyRaised = false   -- pengarna är flyttade (inte när spelet visar valutor under dem)
local MONEY_GAP = 16 + BAG_ROW -- mellan sista raden rutor och raden med pengar
local TARGET_SCALE = 0.85    -- så mycket får spelet krympa fönstret för att få plats
local TAB_ROOM = 30          -- flikarna ovanför fönstret
local MIN_QUESTS_HEIGHT = 120 -- fliken Quests är minst så här hög
-- Sökrutan visas inte (användarens önskan 2026-11-10), så raden spelet lämnar för den används av
-- sakerna. Spelet räknar 12 enheter mindre för raden med handkontroll (ContainerFrameCombinedBagsMixin:
-- GetPaddingHeight, 75 med mus och 63 med handkontroll). Måttet är justerat efter en skärmbild.
local function searchRoom()
    -- 30 och sedan 40 lämnade ett band mellan titelraden och bakgrunden där världen lyste igenom
    -- (skärmbilder 2026-11-10), därför 55.
    return InputUtil.IsGamepadUIEnabled() and 43 or 55
end
local LOW_SPACE = 5        -- så här få lediga platser gör siffran för lediga platser röd
local SECTION_GAP = 8      -- luft ovanför och under linjen mellan två avsnitt
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
local sharedHeight                -- samma höjd i alla tre flikarna (Bags, Sets, Quests)
local gridCols = MIN_COLUMNS      -- antal kolumner just nu
local gridWidth = widthOf(MIN_COLUMNS) -- rutnätets bredd just nu
local measurer                    -- osynlig text som mäter hur breda rubrikerna är
local questNote                   -- raden som ersätter quest-sakerna när de är dolda i väskan
local questNoteState              -- var raden ligger och vad den säger, eller nil
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
    entry.scale = nil -- mindre ruta i fliken Quests (QuestsView.lua)
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
            -- Antal man har / antal som behövs för en quest-sak ("3/7"), där nivån står på utrustning.
            quest = button:CreateFontString(nil, "ARTWORK", "NumberFontNormalSmall"),
            -- Märket "..." som syns på varje sak medan Alt hålls ner: sakerna går att Alt-klicka.
            altBg = button:CreateTexture(nil, "OVERLAY", nil, 5),
            -- Blått sken runt sakerna i den väska som musen står på i väskraden (spelets glöd för nya
            -- saker, bags-glow-white, färgad blå).
            bagGlow = button:CreateTexture(nil, "OVERLAY", nil, 7),
            alt = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"),
        }
        extra.bagGlow:SetAtlas("bags-glow-white", true)
        extra.bagGlow:SetPoint("CENTER")
        extra.bagGlow:SetBlendMode("ADD")
        extra.bagGlow:SetVertexColor(0.25, 0.6, 1)
        extra.bagGlow:Hide()
        extra.altBg:SetColorTexture(0, 0, 0, 0.75)
        extra.altBg:SetSize(18, 11)
        extra.altBg:SetPoint("TOPRIGHT", -1, -1)
        extra.alt:SetPoint("CENTER", extra.altBg, "CENTER", 0, 2)
        extra.alt:SetText("...")
        extra.altBg:Hide()
        extra.alt:Hide()
        extra.quest:SetPoint("TOPLEFT", 2, -2)
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
        -- Spelets gula ram runt quest-saker behövs inte: de står redan i Quest Items (användarens
        -- önskan 2026-11-11). Spelet sätter den i UpdateQuestItem; Tidy Pack döljer den direkt efteråt.
        -- Det gula utropstecknet på saker som startar en quest står kvar.
        if button.UpdateQuestItem and button.IconQuestTexture then
            hooksecurefunc(button, "UpdateQuestItem", function(self, _, questID, isActive)
                if not (questID and not isActive) then
                    self.IconQuestTexture:Hide()
                end
            end)
        end
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

    -- Antal man har / antal som behövs för en quest-sak, grönt när det räcker. Saken är då
    -- ingen utrustning att visa nivån på. I fliken Quests står siffrorna i raden i stället.
    local record = entry.questRecord
    if record and record.need > 0 and not entry.hideProgress and not entry.isEmpty then
        extra.quest:SetText(("%d/%d"):format(record.have, record.need))
        extra.quest:SetTextColor((record.have >= record.need and GREEN_FONT_COLOR or HIGHLIGHT_FONT_COLOR):GetRGB())
        extra.quest:Show()
        extra.level:Hide()
    else
        extra.quest:Hide()
    end

    -- Låset syns bara hos en handlare, och då går låsta saker inte att klicka på – varken
    -- med mus eller handkontroll – så de kan inte säljas av misstag (se QuestLock.lua).
    -- Låsen går att stänga av i inställningarna (Options.lua).
    local locked = atMerchant and entry.locked == true and ns.db.lockAtMerchant
    extra.lock:SetShown(locked)
    setLocked(button, locked)
    local showAlt = IsAltKeyDown() and not entry.isEmpty and not locked
    extra.alt:SetShown(showAlt)
    extra.altBg:SetShown(showAlt)

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
-- Allt hänger i raden med pengar, men den sitter längre från fönstrets högra kant än ramen är tjock
-- till vänster. Därför flyttas innehållet så att luften blir lika stor på båda sidor (användarens
-- önskan 2026-11-11: bakgrunden låg närmare vänster kant än höger). Mäts i measureShift.
local contentShift = 0

-- Har rutan en annan skala (fliken Quests visar små rutor) räknas avståndet i rutans egna enheter.
local function anchor(region, x, y, scale)
    scale = scale or 1
    region:ClearAllPoints()
    region:SetPoint("TOPLEFT", bagFrame.MoneyFrame, "TOPRIGHT", (x - gridWidth - PADDING_SIDE + contentShift) / scale,
        (MONEY_GAP + contentHeight - y) / scale)
end

local updateFreeText -- längre ner; applySize uppdaterar antalet lediga platser

-- Ger spelets fönster Tidy Packs storlek: kanterna, titelraden och raden med pengar som
-- spelet räknade ut, plus det Tidy Pack lägger ut.
local function applySize()
    if not contentHeight or not chromeWidth then
        return
    end
    local height = contentHeight + chromeHeight - searchRoom() + PADDING_TOP + (MONEY_GAP - BLIZZARD_MONEY_GAP)
        + (moneyRaised and MONEY_RAISE or 0)
    bagFrame:SetSize(gridWidth + chromeWidth + 2 * PADDING_SIDE, height)
    -- Bakgrunden följer det Tidy Pack lägger ut, och hänger i raden med pengar som allt annat.
    if inset then
        inset:ClearAllPoints()
        inset:SetPoint("TOPLEFT", bagFrame.MoneyFrame, "TOPRIGHT", -gridWidth - PADDING_SIDE - INSET_PAD_X + contentShift,
            MONEY_GAP + contentHeight + INSET_PAD)
        inset:SetPoint("BOTTOMRIGHT", bagFrame.MoneyFrame, "TOPRIGHT", -PADDING_SIDE + INSET_PAD_X + contentShift,
            MONEY_GAP - INSET_PAD)
        inset:Show()
    end
    NineSliceUtil.UpdateCornerCropping(bagFrame, height)
    updateFreeText()
    if ns.DockReagentBag then
        ns.DockReagentBag()
    end
end

-- Körs efter spelets UpdateFrameSize. Spelet har då gett fönstret storlek efter sitt eget
-- rutnät (GetColumns kolumner, GetRows rader). Det som är kvar när rutnätet räknas bort är
-- kanter, titelrad, sökruta och pengar.
-- Hur långt innehållet ska flyttas åt höger: avståndet mellan pengaradens högra kant och fönstrets,
-- minus halva ramens bredd (ramen räknas lika på båda sidor). Sant om värdet ändrades.
local function measureShift()
    local right, moneyRight = bagFrame:GetRight(), bagFrame.MoneyFrame:GetRight()
    if not (right and moneyRight and chromeWidth) then
        return false
    end
    local shift = math.floor((right - moneyRight) - chromeWidth / 2 + 0.5)
    if shift ~= contentShift then
        contentShift = shift
        return true
    end
    return false
end

local function onFrameSizeUpdated()
    local columns, rows = bagFrame:GetColumns(), math.max(bagFrame:GetRows(), 1)
    chromeWidth = bagFrame:GetWidth() - (columns * BUTTON + (columns - 1) * SPACING)
    chromeHeight = bagFrame:GetHeight() - (rows * BUTTON + (rows - 1) * SPACING)
    applySize()
    -- Första gången avståndet är känt läggs allt ut igen med rätt förskjutning.
    if measureShift() and ns.Refresh then
        ns.Refresh()
    end
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

-- Linjerna mellan avsnitten i fliken Bags. flow fyller sectionYs, placeSectionLines ritar dem.
local sectionYs = {}
local sectionLines = {}
local freeText -- antalet lediga platser nere till vänster (med mus, i stället för "Add to bag")

local function hideSectionLines()
    for _, line in ipairs(sectionLines) do
        line:Hide()
    end
end

local function placeSectionLines()
    hideSectionLines()
    for index, lineY in ipairs(sectionYs) do
        local line = sectionLines[index]
        if not line then
            line = overlay:CreateTexture(nil, "ARTWORK")
            line:SetColorTexture(1, 0.82, 0, 0.18)
            sectionLines[index] = line
        end
        line:SetSize(gridWidth + 8, 1)
        anchor(line, -4, lineY)
        line:Show()
    end
end

-- "10 free" nere till vänster, rött när det är få kvar. Med handkontroll visar rutan "Add to bag"
-- samma sak, så då visas inte texten.
updateFreeText = function()
    if not freeText then
        return
    end
    if InputUtil.IsGamepadUIEnabled() then
        freeText:Hide()
        return
    end
    if ns.UpdateBagBar then
        ns.UpdateBagBar()
    end
    local free = C_Container.CalculateTotalNumberOfFreeBagSlots()
    freeText:SetText(L["%d free"]:format(free))
    freeText:SetTextColor((free <= LOW_SPACE and RED_FONT_COLOR or HIGHLIGHT_FONT_COLOR):GetRGB())
    freeText:Show()
end

-- Listan med set i fliken Sets (SetsView.lua) i stället för sakerna.
local function layoutSetsView(atMerchant)
    releaseHeaders()
    hideSectionLines()
    if divider then
        divider:Hide()
    end
    questNoteState = nil
    questNote:Hide()
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
    -- Fönstret är lika högt i alla flikar (se relayout).
    contentHeight = math.max(setsHeight, sharedHeight or 0)
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
    if apply then
        wipe(sectionYs)
    end
    local function place(group, text)
        local list = groupLists[group]
        if not (list and #list > 0) then
            return
        end
        -- Är quest-sakerna dolda i väskan (inställningen) står en rad i stället för rutorna.
        local hideQuests = group == "QuestItems" and ns.db.showQuestItemsInBags == false
        measurer:SetText(text)
        local headerWidth = math.ceil(measurer:GetStringWidth())
        local groupWidth, height
        if hideQuests then
            -- En enda ruta med antalet, i stil med "Add to bag" (användarens önskan 2026-11-10).
            groupWidth = math.max(headerWidth, BUTTON)
            height = HEADER + BUTTON
        else
            local groupCols = math.min(#list, cols)
            local rows = math.ceil(#list / cols)
            -- Gruppen är minst lika bred som sin rubrik, så att rubrikerna inte krockar.
            groupWidth = math.max(widthOf(groupCols), headerWidth)
            height = HEADER + rows * BUTTON + (rows - 1) * SPACING
        end
        local left = (x == 0) and 0 or (x + GROUP_GAP)
        if x > 0 and left + groupWidth > width then
            -- Får inte plats på raden: börja en ny.
            y = y + shelfHeight + SHELF_GAP
            left, shelfHeight = 0, 0
        end
        if apply then
            local header = acquireHeader()
            header:SetText(text)
            headerX[headers.used], headerY[headers.used] = left, y
            if hideQuests then
                questNoteState = { x = left, y = y + HEADER, count = #list }
            else
                local groupIndex = #groupFirst + 1
                groupFirst[groupIndex] = list[1].button
                if group == "New" then
                    newGroupIndex = groupIndex
                end
                if not startGroupIndex and not list[1].isEmpty then
                    startGroupIndex = groupIndex
                end
                for index, entry in ipairs(list) do
                    entry.x = left + ((index - 1) % cols) * CELL
                    entry.y = y + HEADER + math.floor((index - 1) / cols) * CELL
                    entry.placed = true
                    groupOfButton[entry.button] = groupIndex
                end
            end
        end
        x = left + groupWidth
        shelfHeight = math.max(shelfHeight, height)
    end
    -- Med mus behövs inte rutan "Add to bag": hela väskan tar emot saker, och antalet lediga platser
    -- står nere till vänster. Med handkontroll är den kvar som platsen där en sak släpps.
    local showEmpty = InputUtil.IsGamepadUIEnabled()
    local lastSection
    for _, group in ipairs(ns.groupOrder) do
        local list = groupLists[group]
        if list and #list > 0 and (group ~= "Empty" or showEmpty) then
            -- Ett nytt avsnitt börjar på en ny rad, med en tunn linje ovanför.
            local section = ns.GetGroupSection(group)
            if lastSection and section ~= lastSection then
                y = y + shelfHeight + SECTION_GAP
                if apply then
                    sectionYs[#sectionYs + 1] = y
                end
                y = y + 1 + SECTION_GAP
                x, shelfHeight = 0, 0
            end
            lastSection = section
            place(group, headerText(group, junkValue))
        end
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
    return room - (chromeHeight - searchRoom() + PADDING_TOP + (MONEY_GAP - BLIZZARD_MONEY_GAP) + MONEY_RAISE)
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

-- Sorterar in varje sak i sin grupp och räknar ut vad skräpet är värt (första steget i en
-- genomgång av fliken Bags eller Quests).
local function classify()
    -- Vilka väskplatser har en specialväska? Deras saker och tomma platser får egna grupper
    -- längst ned, med väskans namn.
    wipe(specialBags)
    for bagID = 1, LAST_BAG do
        specialBags[bagID] = isSpecialBag(bagID) or nil
    end

    -- Vilka högar av en quest-sak som behövs och vilka som är över (QuestLock.lua).
    ns.UpdateQuestStacks()

    -- Sortera in varje sak i sin grupp. Tomma platser räknas per väsktyp.
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
            -- Vad en quest kräver av saken (antal man har och behöver), för siffran på rutan.
            entry.questRecord = isQuestItem and ns.GetQuestRecord(entry.name) or nil
            entry.hideProgress = false
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
                empty.questRecord, empty.hideProgress = nil, false
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
    return junkValue
end

-- Flyttar spelets rutor och rubrikerna till sina platser (sista steget i en genomgång). Rutor
-- som inte behövs (tomma platser utom en per väsktyp) döljs.
local function commit(atMerchant)
    for i = 1, headers.used do
        anchor(headers.objects[i], headerX[i], headerY[i])
    end
    wipe(shownButtons)
    for i = 1, entryCount do
        local entry = entries[i]
        if entry.placed then
            entry.button:SetScale(entry.scale or 1)
            anchor(entry.button, entry.x, entry.y, entry.scale)
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

    -- Raden som ersätter quest-sakerna när de är dolda i väskan. Ett klick öppnar fliken Quests.
    if questNoteState then
        questNote.count:SetText(questNoteState.count)
        questNote.slots = questNoteState.count
        anchor(questNote, questNoteState.x, questNoteState.y)
        questNote:Show()
    else
        questNote:Hide()
    end

    -- Med handkontroll lägger spelet in väskorna du har på dig i rutnätet. De ska inte synas
    -- bland sakerna, så Tidy Pack döljer dem.
    if GamepadBagBar and GamepadBagBar:IsShown() then
        GamepadBagBar:Hide()
    end

    applySize()
    if ns.UpdateSetsNotice then
        ns.UpdateSetsNotice()
    end
    if ns.UpdateQuestsNotice then
        ns.UpdateQuestsNotice()
    end

    -- Handkontrollens markör kan stå på en ruta som just dolts (se Gamepad.lua).
    if ns.OnLayoutChanged then
        ns.OnLayoutChanged()
    end
end

-- Fliken Quests (QuestsView.lua): quest-sakerna ordnade per quest, med de riktiga rutorna.
local function layoutQuestsView(atMerchant)
    releaseHeaders()
    hideSectionLines()
    if divider then
        divider:Hide()
    end
    questNoteState = nil
    wipe(groupFirst)
    wipe(groupOfButton)
    newGroupIndex, startGroupIndex = nil, nil
    -- Vilka rutor hör till vilken sak (på namn), och vilka är quest-saker utan quest.
    local byName, others = {}, {}
    for i = 1, entryCount do
        local entry = entries[i]
        entry.hideProgress = true
        if not entry.isEmpty then
            -- Även en quest-sak som ligger i New eller Favorites i väskan hör hit.
            if entry.questRecord then
                local stacks = byName[entry.name]
                if not stacks then
                    stacks = {}
                    byName[entry.name] = stacks
                end
                stacks[#stacks + 1] = entry
            elseif entry.group == "QuestItems" then
                others[#others + 1] = entry
            end
        end
    end
    -- Allt hänger i raden med pengar och räknas uppifrån, så höjden måste vara känd innan något
    -- placeras (som i fliken Sets): texterna och staplarna samlas först.
    local placements = {}
    -- Fliken Quests får inte bli högre än de andra: det som inte ryms står som "...and N more".
    local height, _, firsts = ns.BuildQuestsView(byName, others, gridWidth, sharedHeight,
        function(entry, x, y)
            entry.x, entry.y, entry.placed = x, y, true
        end,
        function(region, x, y)
            placements[#placements + 1] = { region, x, y }
        end)
    -- Fönstret är lika högt i alla flikar: minst lika högt som fliken Bags.
    -- Fliken Quests växer aldrig: det som inte ryms rullar man fram (QuestsView.lua).
    contentHeight = sharedHeight or math.max(height, MIN_QUESTS_HEIGHT)
    for _, placement in ipairs(placements) do
        anchor(placement[1], placement[2], placement[3])
    end
    for index, first in ipairs(firsts) do
        groupFirst[index] = first
        groupOfButton[first] = index
    end
    commit(atMerchant)
end

-- Hela genomgången: sortera in sakerna i grupper, lägg ut grupperna och ge fönstret rätt
-- storlek. Körs efter spelets egen utläggning och varje gång innehållet ändras.
local function relayout()
    if not bagFrame:IsShown() then
        return -- görs när fönstret öppnas
    end
    local atMerchant = ns.IsAtMerchant()
    local view = ns.GetView and ns.GetView() or "bags"

    -- 1. Sortera in varje sak i sin grupp, och räkna ut fliken Bags storlek. Alla tre flikarna
    -- får samma bredd och höjd: den högsta av fliken Bags, de fem platserna i Sets och Quests
    -- minsta höjd. Fönstret ändrar alltså bara storlek när innehållet i väskorna gör det, aldrig
    -- när du byter flik (användarens önskan 2026-11-10).
    local junkValue = classify()
    gridCols = chooseColumns(junkValue)
    gridWidth = widthOf(gridCols)
    local bagsHeight = flow(gridCols, false, junkValue)
    sharedHeight = math.max(bagsHeight, ns.SETS_VIEW_HEIGHT or 0, MIN_QUESTS_HEIGHT)

    if view == "sets" then
        if ns.HideQuestsView then
            ns.HideQuestsView()
        end
        layoutSetsView(atMerchant)
        return
    end
    if view == "quests" then
        layoutQuestsView(atMerchant)
        return
    end
    if ns.HideQuestsView then
        ns.HideQuestsView()
    end

    -- 2. Välj antal kolumner och lägg ut grupperna (se flow).
    releaseHeaders()
    wipe(groupFirst)
    wipe(groupOfButton)
    newGroupIndex, startGroupIndex = nil, nil
    questNoteState = nil
    local dividerY
    -- Höjden måste vara känd innan något placeras, eftersom allt räknas uppifrån men hänger
    -- i raden med pengar (se anchor). Linjen placerades tidigare före höjden: direkt efter
    -- inloggning eller /reload var höjden då okänd (nil) och genomgången stannade med ett fel
    -- när du bar en specialväska.
    contentHeight = sharedHeight
    dividerY = select(2, flow(gridCols, true, junkValue))
    placeSectionLines()
    if dividerY then
        anchor(divider, -6, dividerY)
        divider:SetWidth(gridWidth + 12)
        divider:Show()
    else
        divider:Hide()
    end

    -- 3. Flytta rubrikerna och spelets rutor dit.
    commit(atMerchant)
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

-- Första riktiga saken i väskan (inte "Add to bag"), för guiden i Tour.lua. Nil om väskan är tom.
function ns.GetFirstItemButton()
    local first = startGroupIndex and groupFirst[startGroupIndex]
    if first and first:IsVisible() then
        return first
    end
    return nil
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

    -- Släpp var som helst (användarens önskan 2026-11-11): bakgrunden ligger under rutorna, så den
    -- tar bara emot en sak som släpps på tom yta. Saken läggs på första lediga plats i en vanlig
    -- väska, som spelets "Add to bag"-ruta. Släpps den på en annan sak byter spelet plats på dem.
    local function dropAnywhere()
        local kind = GetCursorInfo()
        if kind ~= "item" then
            return
        end
        for bagID = 0, Constants.InventoryConstants.NumBagSlots do
            local free, family = C_Container.GetContainerNumFreeSlots(bagID)
            if free and free > 0 and (family == nil or family == 0) then
                for slot = 1, C_Container.GetContainerNumSlots(bagID) do
                    if not C_Container.GetContainerItemInfo(bagID, slot) then
                        C_Container.PickupContainerItem(bagID, slot)
                        return
                    end
                end
            end
        end
        UIErrorsFrame:AddMessage(ERR_INV_FULL, 1.0, 0.1, 0.1, 1.0)
    end
    ns.PutCursorItemInBags = dropAnywhere -- också loggknappen (LogoButton.lua)
    inset:EnableMouse(true)
    -- Mushjulet rullar listan i fliken Quests.
    inset:EnableMouseWheel(true)
    inset:SetScript("OnMouseWheel", function(_, delta)
        if ns.GetView and ns.GetView() == "quests" and ns.ScrollQuests then
            ns.ScrollQuests(delta)
        end
    end)
    inset:SetScript("OnReceiveDrag", dropAnywhere)
    inset:SetScript("OnMouseUp", function(_, mouseButton)
        if mouseButton == "LeftButton" then
            dropAnywhere()
        end
    end)

    -- En gul kant och en rad längst ner medan du håller en sak över väskan. Kollas bara medan
    -- markören håller något (CURSOR_CHANGED), så det kostar inget annars.
    -- I lagret HIGH, som kugghjulet: varken +1 eller +20 i nivå räckte för att synas ovanpå
    -- bakgrundens ram (skärmbilder 2026-11-11). Linjerna ligger i kanten, utanför rutorna.
    local glow = CreateFrame("Frame", nil, bagFrame)
    glow:SetAllPoints(inset)
    glow:SetFrameStrata("HIGH")
    for _, edge in ipairs({
        { "TOPLEFT", "TOPRIGHT", nil, 2 }, { "BOTTOMLEFT", "BOTTOMRIGHT", nil, 2 },
        { "TOPLEFT", "BOTTOMLEFT", 2, nil }, { "TOPRIGHT", "BOTTOMRIGHT", 2, nil },
    }) do
        local line = glow:CreateTexture(nil, "OVERLAY")
        line:SetColorTexture(1, 0.82, 0, 0.9)
        line:SetPoint(edge[1])
        line:SetPoint(edge[2])
        if edge[3] then
            line:SetWidth(edge[3])
        else
            line:SetHeight(edge[4])
        end
    end
    local label = CreateFrame("Frame", nil, bagFrame)
    label:SetFrameStrata("HIGH")
    -- I raden med pengar, efter antalet lediga platser och väskraden (ankras längre ner).
    label.bg = label:CreateTexture(nil, "BACKGROUND")
    label.bg:SetAllPoints()
    label.bg:SetColorTexture(0, 0, 0, 0.8)
    label.text = label:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label.text:SetPoint("CENTER")
    label.text:SetText(L["Drop anywhere to put it in your bags"])
    label:SetSize(label.text:GetStringWidth() + 16, 18)
    glow:Hide()
    label:Hide()

    -- I en egen ram i lagret HIGH, som raden "Drop anywhere": direkt i fönstret ritades texten under
    -- raden med pengar och syntes inte (skärmbild 2026-11-11).
    local freeHolder = CreateFrame("Frame", nil, bagFrame)
    freeHolder:SetFrameStrata("HIGH")
    freeHolder:SetAllPoints()
    freeText = freeHolder:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    -- Den högre raden med spelets bilder för myntrutan (samma som MoneyFrame.Border).
    local bar = CreateFrame("Frame", nil, bagFrame)
    bar:SetFrameLevel(math.max(bagFrame:GetFrameLevel() + 1, bagFrame.MoneyFrame:GetFrameLevel() - 1))
    bar:SetHeight(BAR_HEIGHT)
    -- Lika bred som bakgrunden ovanför, så att de står som två kort i en kolumn.
    bar:SetPoint("LEFT", inset, "LEFT")
    bar:SetPoint("RIGHT", inset, "RIGHT")
    -- Nederkanten nära fönstrets kant (som spelets egen ruta); pengarna hamnar nästan mitt i.
    bar:SetPoint("BOTTOM", bagFrame, "BOTTOM", 0, 6)
    local left = bar:CreateTexture(nil, "BACKGROUND")
    left:SetAtlas("common-coinbox-left")
    left:SetPoint("TOPLEFT")
    left:SetPoint("BOTTOMLEFT")
    left:SetWidth(8)
    local right = bar:CreateTexture(nil, "BACKGROUND")
    right:SetAtlas("common-coinbox-right")
    right:SetPoint("TOPRIGHT")
    right:SetPoint("BOTTOMRIGHT")
    right:SetWidth(8)
    local center = bar:CreateTexture(nil, "BACKGROUND")
    center:SetAtlas("_common-coinbox-center")
    center:SetPoint("TOPLEFT", left, "TOPRIGHT")
    center:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT")
    local border = bagFrame.MoneyFrame.Border
    if border then
        hooksecurefunc(border, "Show", function(self)
            if moneyRaised then
                self:Hide()
            end
        end)
    end
    -- Pengarna flyttas upp till mitten av den högre raden, efter spelets egen placering. Visar
    -- spelet valutor under pengarna står de kvar, och då används spelets egen låga myntruta.
    local function placeMoney()
        local money = bagFrame.MoneyFrame
        local _, relativeTo = money:GetPoint(1)
        moneyRaised = relativeTo == bagFrame
        if moneyRaised then
            money:ClearAllPoints()
            money:SetPoint("BOTTOMLEFT", bagFrame, "BOTTOMLEFT", 8, 8 + MONEY_RAISE)
            money:SetPoint("BOTTOMRIGHT", bagFrame, "BOTTOMRIGHT", -8, 8 + MONEY_RAISE)
        end
        bar:SetShown(moneyRaised)
        if border then
            border:SetShown(not moneyRaised)
        end
    end
    if bagFrame.UpdateCurrencyFrames then
        hooksecurefunc(bagFrame, "UpdateCurrencyFrames", placeMoney)
    end
    placeMoney()
    freeText:SetPoint("LEFT", bar, "LEFT", 10, 0)
    freeText:Hide()

    -- Väskraden: ryggsäcken och de fyra väskplatserna som små ikoner efter antalet lediga platser
    -- (användarens önskan 2026-11-11, skissen .design/sketch-bag-bar.html). Siffran är antalet
    -- platser. Musen över en väska tonar ner allt som inte ligger i den. En större väska som släpps
    -- på en plats byter ut väskan där (spelet flyttar sakerna); en vanlig sak läggs i den väskan.
    -- Samma funktioner som spelets egen väskrad: PutItemInBag och PutItemInBackpack.
    local BAG_ICON = 22
    local bagButtons = {}
    -- Sakerna i väskan får ett blått sken, och resten tonas ner (bagID nil: allt som vanligt).
    local function dimOthers(bagID)
        for i = 1, entryCount do
            local entry = entries[i]
            if entry.placed and not entry.isEmpty then
                local inBag = entry.bagID == bagID
                entry.button:SetAlpha((bagID == nil or inBag) and 1 or 0.35)
                local extra = extras[entry.button]
                if extra then
                    extra.bagGlow:SetShown(bagID ~= nil and inBag)
                end
            end
        end
    end
    local function onBagDrop(self)
        if GetCursorInfo() ~= "item" then
            return
        end
        if self.bagID == 0 then
            PutItemInBackpack()
        else
            PutItemInBag(C_Container.ContainerIDToInventoryID(self.bagID))
        end
    end
    local function showBagTooltip(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        local size = C_Container.GetContainerNumSlots(self.bagID)
        if self.bagID == 0 then
            GameTooltip_SetTitle(GameTooltip, BACKPACK_TOOLTIP)
        elseif size > 0 then
            GameTooltip:SetInventoryItem("player", C_Container.ContainerIDToInventoryID(self.bagID))
        else
            GameTooltip_SetTitle(GameTooltip, L["Empty bag slot"])
        end
        if size > 0 then
            GameTooltip_AddNormalLine(GameTooltip, L["%d slots · %d free"]:format(size,
                C_Container.GetContainerNumFreeSlots(self.bagID) or 0))
        end
        if self.bagID > 0 then
            GameTooltip_AddInstructionLine(GameTooltip, L["Drop a bag here to swap it."])
        end
        GameTooltip:Show()
        dimOthers(self.bagID)
    end
    for bagID = 0, Constants.InventoryConstants.NumBagSlots do
        local button = CreateFrame("Button", nil, freeHolder)
        button.bagID = bagID
        button:SetSize(BAG_ICON, BAG_ICON)
        if bagID == 0 then
            button:SetPoint("LEFT", freeText, "RIGHT", 12, 0)
        else
            button:SetPoint("LEFT", bagButtons[bagID - 1], "RIGHT", 5, 0)
        end
        button.icon = button:CreateTexture(nil, "ARTWORK")
        button.icon:SetAllPoints()
        button.count = button:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
        button.count:SetPoint("BOTTOMRIGHT", 3, -2)
        button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
        button:RegisterForClicks("LeftButtonUp")
        button:SetScript("OnClick", onBagDrop)
        button:SetScript("OnReceiveDrag", onBagDrop)
        button:SetScript("OnEnter", showBagTooltip)
        button:SetScript("OnLeave", function()
            GameTooltip_Hide()
            dimOthers(nil)
        end)
        bagButtons[bagID] = button
    end
    label:SetPoint("LEFT", bagButtons[#bagButtons], "RIGHT", 10, 0)

    function ns.UpdateBagBar()
        for bagID, button in pairs(bagButtons) do
            local size = C_Container.GetContainerNumSlots(bagID)
            local texture
            if bagID == 0 then
                texture = "Interface\\Icons\\INV_Misc_Bag_08"
            else
                texture = GetInventoryItemTexture("player", C_Container.ContainerIDToInventoryID(bagID))
            end
            if texture then
                button.icon:SetTexture(texture)
                button.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
                button.icon:SetAlpha(1)
            else
                button.icon:SetTexture("Interface\\Buttons\\UI-EmptySlot")
                button.icon:SetTexCoord(0.140625, 0.84375, 0.140625, 0.84375)
                button.icon:SetAlpha(0.7)
            end
            button.count:SetText(size > 0 and size or "")
        end
    end

    -- Medan du håller en väska lyser de fyra väskplatserna.
    function ns.SetBagBarSwapHint(on)
        for bagID, button in pairs(bagButtons) do
            if on and bagID > 0 then
                button:LockHighlight()
            else
                button:UnlockHighlight()
            end
        end
    end
    local watcher = CreateFrame("Frame")
    watcher:Hide()
    local sinceCheck = 0
    watcher:SetScript("OnUpdate", function(_, elapsed)
        -- Tio gånger i sekunden räcker, och bara medan du håller en sak.
        sinceCheck = sinceCheck + elapsed
        if sinceCheck < 0.1 then
            return
        end
        sinceCheck = 0
        local show = bagFrame:IsShown() and inset:IsShown() and bagFrame:IsMouseOver()
        glow:SetShown(show)
        label:SetShown(show)

    end)
    ns.RegisterEvent("CURSOR_CHANGED", function()
        local holding = GetCursorInfo() == "item"
        watcher:SetShown(holding)
        if not holding then
            glow:Hide()
            label:Hide()
        end
        -- Håller du en väska: väskraden lyser där den kan bytas in, och raden säger det.
        local _, itemID = GetCursorInfo()
        local classID = holding and itemID and select(6, C_Item.GetItemInfoInstant(itemID))
        local holdingBag = classID == Enum.ItemClass.Container
        label.text:SetText(holdingBag and L["Drop on one of your bags to swap it"]
            or L["Drop anywhere to put it in your bags"])
        label:SetWidth(label.text:GetStringWidth() + 16)
        if ns.SetBagBarSwapHint then
            ns.SetBagBarSwapHint(holdingBag)
        end
    end)

    -- Osynlig text som mäter hur breda rubrikerna är, för att kunna räkna ut höjden utan att
    -- lägga ut något (se flow).
    measurer = overlay:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    measurer:SetAlpha(0)

    -- Raden som ersätter quest-sakerna när de är dolda i väskan (inställningen). Ett klick
    -- öppnar fliken Quests.
    -- En ruta med spelets tomma ruta, en gul ram och antalet, som öppnar fliken Quests.
    questNote = CreateFrame("Button", nil, overlay)
    questNote:SetSize(BUTTON, BUTTON)
    questNote.bg = questNote:CreateTexture(nil, "BACKGROUND")
    questNote.bg:SetAllPoints()
    questNote.bg:SetTexture("Interface\\Buttons\\UI-EmptySlot")
    questNote.bg:SetTexCoord(0.140625, 0.84375, 0.140625, 0.84375)
    questNote.border = questNote:CreateTexture(nil, "OVERLAY")
    -- Samma gula ram som spelet ger quest-saker i väskan (TEXTURE_ITEM_QUEST_BORDER, ContainerFrame.lua).
    questNote.border:SetTexture(TEXTURE_ITEM_QUEST_BORDER)
    questNote.border:SetAllPoints()
    questNote.count = questNote:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    questNote.count:SetPoint("CENTER", 0, 1)
    questNote:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    questNote:SetScript("OnClick", function()
        ns.SetView("quests")
    end)
    questNote:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip_SetTitle(GameTooltip, ns.groupNames.QuestItems)
        GameTooltip_AddNormalLine(GameTooltip, (self.slots == 1 and L["1 slot holds quest items."]
            or L["%d slots hold quest items."]:format(self.slots or 0)))
        GameTooltip_AddInstructionLine(GameTooltip, L["Click to see them in the Quests tab."])
        GameTooltip:Show()
    end)
    questNote:SetScript("OnLeave", GameTooltip_Hide)
    questNote:Hide()

    -- Ingen sökruta och ingen väskikon (användarens önskan 2026-11-10): mer plats för sakerna.
    -- Spelet visar sökrutan igen varje gång fönstret uppdateras, så den döljs direkt efteråt.
    -- Väskikonen byts mot spelets ram utan ikon (samma ramar som spelets andra fönster).
    if BagItemSearchBox then
        BagItemSearchBox:SetText("")
        hooksecurefunc(BagItemSearchBox, "Show", function(self)
            if self:GetParent() == bagFrame then
                self:Hide()
            end
        end)
        BagItemSearchBox:Hide()
    end
    if bagFrame.PortraitContainer then
        bagFrame.PortraitContainer:Hide()
    end
    -- Antalet lediga platser vid ikonen står redan i rutan "Add to bag".
    if bagFrame.CountContainer then
        bagFrame.CountContainer:Hide()
        hooksecurefunc(bagFrame.CountContainer, "Show", bagFrame.CountContainer.Hide)
    end
    if bagFrame.PortraitButton then
        bagFrame.PortraitButton:Hide()
        hooksecurefunc(bagFrame.PortraitButton, "Show", bagFrame.PortraitButton.Hide)
    end
    -- Spelets ram utan ikon (ButtonFrameTemplateNoPortrait) lägger vänster kant 5 enheter längre in
    -- än ramen med ikon som väskfönstret är byggt för (hörnen på x -8 i stället för -13,
    -- NineSliceLayouts.lua). Då täckte kanten raden med pengar och bakgrunden till vänster
    -- (skärmbild 2026-11-11). Därför samma ram utan ikon, men med vänster kant där den satt.
    if bagFrame.NineSlice and NineSliceUtil and NineSliceUtil.GetLayout and NineSliceUtil.ApplyLayout then
        local base = NineSliceUtil.GetLayout("ButtonFrameTemplateNoPortrait")
        if base then
            local layout = CopyTable(base)
            layout.TopLeftCorner.x = -13
            layout.BottomLeftCorner.x = -13
            NineSliceUtil.ApplyLayout(bagFrame.NineSlice, layout)
        end
    end

    -- Medan Alt hålls ner visas märket "..." på varje sak (och försvinner när Alt släpps).
    ns.RegisterEvent("MODIFIER_STATE_CHANGED", function(key)
        if (key == "LALT" or key == "RALT") and bagFrame:IsShown() then
            local show = IsAltKeyDown()
            for i = 1, entryCount do
                local entry = entries[i]
                local extra = extras[entry.button]
                if extra then
                    local visible = show and entry.button:IsShown() and not entry.isEmpty
                        and not lockedButtons[entry.button]
                    extra.alt:SetShown(visible == true)
                    extra.altBg:SetShown(visible == true)
                end
            end
        end
    end)

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

    -- Reagensväskan (väskplats 5) visar spelet i ett eget fönster med mus; Tidy Pack kan inte sortera
    -- in den utan att ändra spelets egna värden, vilket kan blockera att saker används. I stället fästs
    -- dess fönster direkt till vänster om Tidy Pack, med nederkanterna i linje (användarens önskan
    -- 2026-11-11). Spelet placerar sina väskfönster i UpdateContainerFrameAnchors; Tidy Pack flyttar
    -- reagensväskans fönster direkt efteråt, och när Tidy Packs fönster byter storlek.
    local REAGENT_BAG = Constants.InventoryConstants.NumBagSlots + 1
    local function dockReagentBag()
        if not ContainerFrameUtil_GetShownFrameForID or not bagFrame:IsShown() then
            return
        end
        local reagentFrame = ContainerFrameUtil_GetShownFrameForID(REAGENT_BAG)
        if reagentFrame and reagentFrame ~= bagFrame then
            reagentFrame:ClearAllPoints()
            reagentFrame:SetPoint("BOTTOMRIGHT", bagFrame, "BOTTOMLEFT", -2, 0)
        end
    end
    ns.DockReagentBag = dockReagentBag
    if UpdateContainerFrameAnchors then
        hooksecurefunc("UpdateContainerFrameAnchors", dockReagentBag)
    end

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
