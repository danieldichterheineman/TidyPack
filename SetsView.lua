-- TidyPack – SetsView.lua
-- Flikarna Bags och Sets i väskfönstret, och listan med set som fliken Sets visar i
-- fönstret i stället för sakerna. Flikarna är spelets egna flikar (TabSystemTemplate med
-- TabSystemTopButtonTemplate), samma som i Forevers trollbok. Mallen är gjord för flikar
-- som hänger ovanpå en ram, så de sitter utanför fönstret, på dess övre kant, till höger
-- om väskans ikon (användarens önskan). Klick på ett set tar på det (Sets.lua).
-- Layout.lua lägger ut listan: den anropar ns.LayoutSetsView när fliken Sets är vald.
-- Väskfönstret öppnas alltid på fliken Bags.
-- ⚠️ Med handkontroll: raderna är vanliga knappar i väskfönstret och ska nås med markören,
-- och kugghjulets meny kan också byta flik (Marks.lua). Måste provas i spelet.

local _, ns = ...
local L = ns.L

local ROW_HEIGHT = 50
local ROW_GAP = 4
local TAB_WIDTH = 90    -- båda flikarna är lika breda
local TAB_LEFT = 14     -- fönstret har ingen väskikon, så flikarna börjar nära kanten
local TAB_OVERLAP = 2   -- flikarnas nederkant går in 2 enheter i fönstrets kant
local TAB_GAP = 2
local WARNING_ICON = "Interface\\DialogFrame\\UI-Dialog-Icon-AlertNew"

local view = "bags"
local tabSystem, tabHost
local rows = {}
local emptyRows = {} -- de tomma platserna med "+"

function ns.IsSetsView()
    return view == "sets"
end

-- Vilken flik som visas: "bags", "sets" eller "quests".
function ns.GetView()
    return view
end

-- Numret på varje flik i flikraden.
local TAB_OF = { bags = 1, sets = 2, quests = 3 }

-- Pricken på fliken Quests lyser när minst en quest med saker är klar att lämna in.
-- Layout.lua anropar den efter varje genomgång.
function ns.UpdateQuestsNotice()
    if tabSystem then
        tabSystem:SetTabNotification(3, ns.HasReadyQuest ~= nil and ns.HasReadyQuest())
    end
end

-- Pricken på fliken Sets (spelets egen, TabSystemButtonMixin:SetTabNotification) lyser
-- när ett set saknar en sak. Layout.lua anropar den efter varje genomgång.
function ns.UpdateSetsNotice()
    if not tabSystem then
        return
    end
    local anyMissing = false
    for index in ipairs(ns.GetSets()) do
        local _, missing = ns.GetSetStatus(index)
        if #missing > 0 then
            anyMissing = true
            break
        end
    end
    tabSystem:SetTabNotification(2, anyMissing)
end

-- Byter mellan "bags", "sets" och "quests".
function ns.SetView(newView)
    view = TAB_OF[newView] and newView or "bags"
    if tabSystem then
        tabSystem:SetTabVisuallySelected(TAB_OF[view])
    end
    for _, row in ipairs(rows) do
        row:Hide()
    end
    for _, row in ipairs(emptyRows) do
        row:Hide()
    end
    if ns.Refresh then
        ns.Refresh()
    end
end

---------------------------------------------------------------------------
-- Raderna
---------------------------------------------------------------------------
-- En rad per set: setets ikon och namn, dess saker som små rutor (grå = saknas) och till
-- höger "Equipped", en varning eller antalet saker. Allt om set görs här:
--   klick                = ta på setet
--   släpp en sak på raden = lägg saken i setet
--   högerklick           = Edit, Delete och Remove item (spelets egen meny)

local MINI_SIZE = 22
local MINI_GAP = 3
local MAX_MINI = 12     -- fler än så visas som "+3"
local EMPTY_SLOT = "Interface\\Buttons\\UI-EmptySlot" -- spelets tomma ruta

local STATE_TEXT = {
    equipped = { L["Equipped"], GREEN_FONT_COLOR },
    bags = { L["In your bags"], HIGHLIGHT_FONT_COLOR },
    missing = { L["Missing"], RED_FONT_COLOR },
}

local function cursorItemID()
    local kind, itemID = GetCursorInfo()
    return kind == "item" and itemID or nil
end

-- Tooltipen för ett set: varje sak och var den finns.
local function showRowTooltip(row)
    local set = ns.GetSets()[row.setIndex]
    if not set then
        return
    end
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    GameTooltip_SetTitle(GameTooltip, set.name)
    for _, itemID in ipairs(set.items) do
        local name = C_Item.GetItemNameByID(itemID) or L["Item %d"]:format(itemID)
        local state = STATE_TEXT[ns.GetItemState(itemID)]
        local r, g, b = state[2]:GetRGB()
        GameTooltip:AddDoubleLine(name, state[1], 1, 1, 1, r, g, b)
    end
    GameTooltip_AddBlankLineToTooltip(GameTooltip)
    GameTooltip_AddInstructionLine(GameTooltip, L["Click to put it on. Drop an item here to add it."])
    GameTooltip_AddInstructionLine(GameTooltip, L["Use the ... button to add what you wear, edit or delete the set."])
    GameTooltip:Show()
end

-- En sak som släpps på raden hamnar i setet.
local function dropOnRow(row)
    local itemID = cursorItemID()
    if itemID then
        ClearCursor() -- saken går tillbaka till sin plats
        ns.SetInSet(row.setIndex, itemID, true)
        return true
    end
    return false
end

-- Menyn för ett set, i spelets eget menysystem. Den öppnas från radens kugghjul (syns, och
-- går att nå med handkontroll) och med högerklick på raden.
local FLAT_REMOVE_MAX = 6 -- så många saker visas direkt i menyn "Remove Item"

local function buildRowMenu(row, rootDescription)
    local index = row.setIndex
    local set = ns.GetSets()[index]
    if not set then
        return
    end
    rootDescription:CreateTitle(set.name)
    rootDescription:CreateButton(L["Add What I'm Wearing"], function()
        ns.AddWornToSet(index)
    end)
    rootDescription:CreateButton(L["Edit Name and Icon..."], function()
        ns.AskEditSet(index)
    end)
    -- Få saker: raderna direkt i menyn. Spelet öppnar en undermeny åt vänster när fönstret står vid
    -- skärmens högra kant, trots att pilen pekar åt höger, så en undermeny undviks när det går.
    -- Många saker: en undermeny, så att menyn inte blir för lång.
    if #set.items > 0 then
        local target = rootDescription
        if #set.items > FLAT_REMOVE_MAX then
            target = rootDescription:CreateButton(L["Remove Item"])
        else
            rootDescription:CreateTitle(L["Remove Item"])
        end
        for _, itemID in ipairs(set.items) do
            local name = C_Item.GetItemNameByID(itemID) or L["Item %d"]:format(itemID)
            local icon = C_Item.GetItemIconByID(itemID)
            target:CreateButton((icon and ("|T%s:14:14|t "):format(icon) or "") .. name, function()
                ns.SetInSet(index, itemID, false)
            end)
        end
    end
    rootDescription:CreateButton(L["Delete Set..."], function()
        ns.AskDeleteSet(index)
    end)
end

local function showRowMenu(row)
    MenuUtil.CreateContextMenu(row, function(_, rootDescription)
        buildRowMenu(row, rootDescription)
    end)
end

local function onRowClick(row, mouseButton)
    if dropOnRow(row) then
        return
    end
    if mouseButton == "RightButton" then
        showRowMenu(row)
        return
    end
    ns.EquipSet(row.setIndex)
end

local function acquireRow(index, parent)
    local row = rows[index]
    if row then
        return row
    end
    row = CreateFrame("Button", nil, parent)
    row:SetHeight(ROW_HEIGHT)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row:SetHighlightAtlas("Options_List_Hover", "ADD")
    row:SetScript("OnClick", onRowClick)
    row:SetScript("OnReceiveDrag", dropOnRow)
    row:SetScript("OnEnter", showRowTooltip)
    row:SetScript("OnLeave", GameTooltip_Hide)

    -- Platsens nummer, samma som tangentbindningen Equip set 1–5.
    row.number = row:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    row.number:SetPoint("LEFT", 4, 0)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(37, 37)
    row.icon:SetPoint("LEFT", 18, 0)
    row.name = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 9, -1)
    -- Läget direkt efter namnet: "· 1 item", "✔ Equipped" eller "⚠ 1 missing".
    row.status = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    row.status:SetPoint("LEFT", row.name, "RIGHT", 8, 0)
    row.minis = {}
    row.more = row:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    -- En tom ruta med "+" sist bland sakerna: här släpper man en ny sak (hela raden tar
    -- emot den, rutan visar bara var).
    row.plus = row:CreateTexture(nil, "ARTWORK")
    row.plus:SetTexture(EMPTY_SLOT)
    row.plus:SetTexCoord(0.140625, 0.84375, 0.140625, 0.84375)
    row.plus:SetSize(MINI_SIZE, MINI_SIZE)
    row.plusText = row:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    row.plusText:SetPoint("CENTER", row.plus, "CENTER", 0, 1)
    row.plusText:SetText("+")
    -- Equip till höger, så att det syns hur man tar på setet. Klick på raden gör samma sak.
    row.equip = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.equip:SetSize(80, 22)
    row.equip:SetPoint("RIGHT", -8, 0)
    row.equip:SetText(L["Equip"])
    row.equip:SetScript("OnClick", function(self)
        ns.EquipSet(self:GetParent().setIndex)
    end)
    -- Knappen bredvid Equip öppnar setets meny. Den är spelets egen menyknapp, så att den fungerar
    -- med handkontroll.
    row.menu = CreateFrame("DropdownButton", nil, row)
    row.menu:SetSize(22, 22)
    row.menu:SetPoint("RIGHT", row.equip, "LEFT", -6, 0) -- flyttas efter sakerna i fillRow
    -- Tre punkter i stället för ett kugghjul, så att det syns att knappen gäller just den här raden
    -- (kugghjulet i fönsterhuvudet gäller hela Tidy Pack).
    row.menu.dots = row.menu:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    row.menu.dots:SetPoint("CENTER", 0, 4)
    row.menu.dots:SetText("...")
    row.menu.dots:SetAlpha(0.8)
    row.menu:SetupMenu(function(owner, rootDescription)
        buildRowMenu(owner:GetParent(), rootDescription)
    end)
    row.menu:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip_SetTitle(GameTooltip, L["More options"])
        GameTooltip:Show()
        self.dots:SetAlpha(1)
    end)
    row.menu:SetScript("OnLeave", function(self)
        GameTooltip_Hide()
        self.dots:SetAlpha(0.8)
    end)
    rows[index] = row
    return row
end

-- Fyller en rad med setets ikon, namn, saker och läge.
local function fillRow(row, index, set)
    row.setIndex = index
    row.number:SetText(index)
    row.name:SetText(set.name)
    row.icon:SetTexture(ns.GetSetIcon(index))

    -- Sakerna som små rutor under namnet. Saker som saknas är grå och svaga.
    local shownCount = math.min(#set.items, MAX_MINI)
    for k = 1, shownCount do
        local mini = row.minis[k]
        if not mini then
            mini = row:CreateTexture(nil, "ARTWORK")
            mini:SetSize(MINI_SIZE, MINI_SIZE)
            mini:SetPoint("BOTTOMLEFT", row.icon, "BOTTOMRIGHT", 9 + (k - 1) * (MINI_SIZE + MINI_GAP), -2)
            row.minis[k] = mini
        end
        local itemID = set.items[k]
        local missing = ns.GetItemState(itemID) == "missing"
        mini:SetTexture(C_Item.GetItemIconByID(itemID))
        mini:SetDesaturated(missing)
        mini:SetAlpha(missing and 0.4 or 1)
        mini:Show()
    end
    for k = shownCount + 1, #row.minis do
        row.minis[k]:Hide()
    end
    local after = 9 + shownCount * (MINI_SIZE + MINI_GAP)
    if #set.items > MAX_MINI then
        row.more:SetText("+" .. (#set.items - MAX_MINI))
        row.more:ClearAllPoints()
        row.more:SetPoint("BOTTOMLEFT", row.icon, "BOTTOMRIGHT", after, 3)
        row.more:Show()
        after = after + row.more:GetStringWidth() + 6
    else
        row.more:Hide()
    end
    row.plus:ClearAllPoints()
    row.plus:SetPoint("BOTTOMLEFT", row.icon, "BOTTOMRIGHT", after, -2)
    -- Menyknappen sitter efter sakerna, inte längst till höger: menyn öppnas under knappen, och
    -- då får en undermeny plats åt höger (längst ut vid skärmens kant öppnas den åt fel håll).
    row.menu:ClearAllPoints()
    row.menu:SetPoint("BOTTOMLEFT", row.icon, "BOTTOMRIGHT", after + MINI_SIZE + 8, -4)

    -- Efter namnet: på dig, varning för det som saknas, eller hur många saker setet har.
    local count, missing, worn = ns.GetSetStatus(index)
    if #missing > 0 then
        -- Spelets egen varningsikon, samma som i spelets frågerutor.
        row.status:SetText("· " .. CreateTextureMarkup(WARNING_ICON, 64, 64, 12, 12, 0, 1, 0, 1) .. " "
            .. L["%d missing"]:format(#missing))
        row.status:SetTextColor(ORANGE_FONT_COLOR:GetRGB())
    elseif worn then
        row.status:SetText("· " .. CreateAtlasMarkup("common-icon-checkmark", 12, 12) .. " " .. L["Equipped"])
        row.status:SetTextColor(GREEN_FONT_COLOR:GetRGB())
    elseif count == 0 then
        row.status:SetText("· " .. L["drop items on this row"])
        row.status:SetTextColor(GRAY_FONT_COLOR:GetRGB())
    else
        row.status:SetText("· " .. (count == 1 and L["1 item"] or L["%d items"]:format(count)))
        row.status:SetTextColor(GRAY_FONT_COLOR:GetRGB())
    end
    -- Equip går inte att trycka på när allt redan sitter på.
    row.equip:SetEnabled(not (worn and #missing == 0))
end

-- Skapar ett nytt set med spelets ruta för namn och ikon. Håller du en sak hamnar den i setet.
-- Används med handkontroll, där det inte går att skriva direkt på raden.
local function newSetWithPopup()
    local itemID = cursorItemID()
    if itemID then
        ClearCursor()
    end
    ns.AskNewSet(itemID)
end

-- Ett nytt set skrivs direkt på den tomma raden (användarens önskan 2026-11-10): klick eller en
-- släppt sak gör raden till en skrivruta, Enter skapar setet och Esc avbryter. Ikonen blir den
-- första sakens, och kan bytas med "..." → Edit Name and Icon.
local editingRow

local function stopNaming(row)
    if not row.edit:IsShown() then
        return
    end
    row.pendingItem = nil
    row.edit:ClearFocus()
    row.edit:Hide()
    row.problem:SetText("")
    row.slot:SetTexture(EMPTY_SLOT)
    row.slot:SetTexCoord(0.140625, 0.84375, 0.140625, 0.84375)
    row.slot:SetAlpha(0.7)
    row.plus:Show()
    row.label:Show()
    if editingRow == row then
        editingRow = nil
    end
end

local function startNaming(row)
    if InputUtil.IsGamepadUIEnabled() then
        newSetWithPopup()
        return
    end
    if editingRow and editingRow ~= row then
        stopNaming(editingRow)
    end
    editingRow = row
    local itemID = cursorItemID()
    if itemID then
        ClearCursor() -- saken går tillbaka till sin plats och läggs i setet när det skapas
        row.pendingItem = itemID
        row.slot:SetTexture(C_Item.GetItemIconByID(itemID))
        row.slot:SetTexCoord(0, 1, 0, 1)
        row.slot:SetAlpha(1)
        row.plus:Hide()
    end
    row.label:Hide()
    row.problem:SetText("")
    row.edit:SetText("")
    row.edit:Show()
    row.edit:SetFocus()
end

local function finishNaming(edit)
    local row = edit:GetParent()
    local itemID = row.pendingItem
    local index, problem = ns.CreateSet(edit:GetText(), nil)
    if not index then
        row.problem:SetText(problem or "")
        return
    end
    stopNaming(row)
    if itemID then
        ns.SetInSet(index, itemID, true)
    end
end

-- En tom plats: spelets tomma ruta med ett +, och en text. Klick eller en släppt sak börjar ett nytt set.
local function acquireEmptyRow(index, parent)
    local row = emptyRows[index]
    if row then
        return row
    end
    row = CreateFrame("Button", nil, parent)
    row:SetHeight(ROW_HEIGHT)
    row:SetHighlightAtlas("Options_List_Hover", "ADD")
    row:SetScript("OnClick", startNaming)
    row:SetScript("OnReceiveDrag", startNaming)
    row:SetScript("OnHide", stopNaming)
    row.number = row:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    row.number:SetPoint("LEFT", 4, 0)
    row.slot = row:CreateTexture(nil, "ARTWORK")
    row.slot:SetTexture(EMPTY_SLOT)
    row.slot:SetTexCoord(0.140625, 0.84375, 0.140625, 0.84375)
    row.slot:SetSize(37, 37)
    row.slot:SetPoint("LEFT", 18, 0)
    row.slot:SetAlpha(0.7)
    row.plus = row:CreateFontString(nil, "OVERLAY", "GameFontDisableLarge")
    row.plus:SetPoint("CENTER", row.slot, "CENTER", 0, 1)
    row.plus:SetText("+")
    row.label = row:CreateFontString(nil, "ARTWORK", "GameFontDisable")
    row.label:SetPoint("LEFT", row.slot, "RIGHT", 9, 0)
    -- Skrivrutan för namnet, på samma plats som texten.
    row.edit = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
    row.edit:SetSize(220, 22)
    row.edit:SetPoint("LEFT", row.slot, "RIGHT", 14, 0)
    row.edit:SetAutoFocus(false)
    row.edit:SetMaxLetters(40)
    row.edit:SetScript("OnEnterPressed", finishNaming)
    row.edit:SetScript("OnEscapePressed", function(self)
        stopNaming(self:GetParent())
    end)
    row.edit:SetScript("OnEditFocusLost", function(self)
        if strtrim(self:GetText()) == "" then
            stopNaming(self:GetParent())
        end
    end)
    row.edit:Hide()
    row.hint = row.edit:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    row.hint:SetPoint("LEFT", row.edit, "RIGHT", 10, 0)
    row.hint:SetText(L["Name the set, then press Enter"])
    row.problem = row:CreateFontString(nil, "ARTWORK", "GameFontRedSmall")
    row.problem:SetPoint("TOPLEFT", row.edit, "BOTTOMLEFT", -4, -1)
    row:SetScript("OnEnter", function(self)
        self.plus:SetFontObject("GameFontHighlightLarge")
        self.label:SetFontObject("GameFontHighlight")
    end)
    row:SetScript("OnLeave", function(self)
        self.plus:SetFontObject("GameFontDisableLarge")
        self.label:SetFontObject("GameFontDisable")
    end)
    emptyRows[index] = row
    return row
end

-- Fliken Sets är alltid så här hög: fem platser (Layout.lua ger alla flikar samma höjd).
ns.SETS_VIEW_HEIGHT = ns.MAX_SETS * (ROW_HEIGHT + ROW_GAP) - ROW_GAP

-- Lägger ut listan: dina set och sedan tomma platser upp till fem, numrerade som
-- tangentbindningarna Equip set 1–5. place(region, x, y) placerar en del i väskfönstret, width är
-- rutornas bredd. Returnerar höjden och raderna (för handkontrollen).
function ns.LayoutSetsView(place, width)
    local shown = {}
    local sets = ns.GetSets()
    local y = 0
    for index, set in ipairs(sets) do
        local row = acquireRow(index, tabHost)
        fillRow(row, index, set)
        row:SetWidth(width)
        place(row, 0, y)
        row:Show()
        shown[#shown + 1] = row
        y = y + ROW_HEIGHT + ROW_GAP
    end
    for index = #sets + 1, #rows do
        rows[index]:Hide()
    end
    local emptyCount = math.max(0, ns.MAX_SETS - #sets)
    for k = 1, emptyCount do
        local row = acquireEmptyRow(k, tabHost)
        local number = #sets + k
        row.number:SetText(number)
        row.label:SetText(k == 1 and L["New set – click, or drop an item here"] or L["New set"])
        row:SetWidth(width)
        place(row, 0, y)
        row:Show()
        shown[#shown + 1] = row
        y = y + ROW_HEIGHT + ROW_GAP
    end
    for k = emptyCount + 1, #emptyRows do
        emptyRows[k]:Hide()
    end
    return math.max(y - ROW_GAP, ns.SETS_VIEW_HEIGHT), shown
end

---------------------------------------------------------------------------
-- Flikarna
---------------------------------------------------------------------------

ns.OnLoad(function()
    local bagFrame = ns.bagFrame
    if not bagFrame then
        return
    end

    -- En egen ram håller listans delar, så att spelets fönster inte får några nya fält.
    tabHost = CreateFrame("Frame", nil, bagFrame)
    tabHost:SetAllPoints()

    -- Spelets flikar (TabSystem), som i trollboken. Mallen läser tabTemplate när den
    -- skapas; en ram som skapas i Lua får därför sin knappmall och sin pool efteråt.
    tabSystem = CreateFrame("Frame", nil, bagFrame, "TabSystemTemplate")
    tabSystem.tabTemplate = "TabSystemTopButtonTemplate"
    tabSystem.tabPool = CreateFramePool("BUTTON", tabSystem, tabSystem.tabTemplate)
    tabSystem.minTabWidth, tabSystem.maxTabWidth = TAB_WIDTH, TAB_WIDTH
    tabSystem.spacing = TAB_GAP
    tabSystem.tabSelectSound = SOUNDKIT.IG_CHARACTER_INFO_TAB
    tabSystem:SetPoint("BOTTOMLEFT", bagFrame, "TOPLEFT", TAB_LEFT, -TAB_OVERLAP)
    tabSystem:SetTabSelectedCallback(function(tabID)
        ns.SetView(tabID == 2 and "sets" or (tabID == 3 and "quests" or "bags"))
        return true -- ns.SetView har redan markerat fliken
    end)
    for _, label in ipairs({ L["Bags"], L["Sets"], L["Quests"] }) do
        local tabID = tabSystem:AddTab(label)
        -- Lite större text än spelets standard, som i trollboken.
        local tab = tabSystem:GetTabButton(tabID)
        tab.selectedFontObject, tab.unselectedFontObject = GameFontHighlight, GameFontNormal
        -- Den valda fliken är avstängd (går inte att klicka på igen), och spelet visar då
        -- knappens text i "disabled"-stilen. Den får samma storlek som de andra.
        tab:SetDisabledFontObject(GameFontHighlight)
        tab:UpdateTabWidth()
    end
    tabSystem:SetTabVisuallySelected(1)

    -- Håller du en sak över fliken Sets byter fönstret till den, så att du kan släppa
    -- saken på ett set – som spelets egna flikar när man drar något över dem.
    tabSystem:GetTabButton(2):HookScript("OnEnter", function()
        if view ~= "sets" and cursorItemID() then
            ns.SetView("sets")
        end
    end)

    -- Väskfönstret öppnas alltid på fliken Bags.
    bagFrame:HookScript("OnHide", function()
        if view ~= "bags" then
            ns.SetView("bags")
        end
    end)

    -- "Equipped" ändras när du byter utrustning.
    ns.RegisterEvent("PLAYER_EQUIPMENT_CHANGED", function()
        if view == "sets" and ns.Refresh then
            ns.Refresh()
        end
    end)
end)

---------------------------------------------------------------------------
-- Snabbtangenter (Bindings.xml)
---------------------------------------------------------------------------
-- Raderna i spelets lista över snabbtangenter. Spelet hittar texterna i globala variabler
-- med de här namnen.
BINDING_HEADER_TIDYPACK = L["Tidy Pack"]
BINDING_NAME_TIDYPACK_OPEN_SETS = L["Open the Sets tab"]
for number = 1, 5 do
    _G["BINDING_NAME_TIDYPACK_EQUIP_SET_" .. number] = L["Equip set %d"]:format(number)
end

-- Den namngivna ramen som Bindings.xml anropar.
local keys = CreateFrame("Frame", "TidyPackKeys")

function keys:OpenSets()
    if not ns.bagFrame then
        return
    end
    if not ns.bagFrame:IsShown() then
        OpenAllBags()
    end
    ns.SetView("sets")
end

-- Set nummer n i listan (uppifrån). Bara utanför strid, som när du klickar (Sets.lua).
function keys:EquipSet(number)
    local set = ns.GetSets()[number]
    if set then
        ns.EquipSet(number)
    else
        ns.Print(L["You have no set number %d."]:format(number))
    end
end
