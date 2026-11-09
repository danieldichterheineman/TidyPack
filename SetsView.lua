-- TidyPack – SetsView.lua
-- Flikarna Bags och Sets i väskfönstret, och listan med set som fliken Sets visar i
-- fönstret i stället för sakerna. Flikarna är spelets egna flikar (TabSystemTemplate med
-- TabSystemTopButtonTemplate), samma som i Forevers trollbok: under titelraden, till
-- höger om väskans ikon, med sökrutan till höger om dem. Klick på ett set tar på det
-- (Sets.lua).
-- Layout.lua lägger ut listan: den anropar ns.LayoutSetsView när fliken Sets är vald.
-- Väskfönstret öppnas alltid på fliken Bags.
-- ⚠️ Med handkontroll: raderna är vanliga knappar i väskfönstret och ska nås med markören,
-- och ★-menyn kan också byta flik (Marks.lua). Måste provas i spelet.

local addonName, ns = ...
local L = ns.L

local ROW_HEIGHT = 44
local ROW_GAP = 4
local EMPTY_HEIGHT = 24
local MIN_HEIGHT = 120  -- listan är minst så här hög, så att fönstret inte krymper ihop
local TAB_WIDTH = 90    -- båda flikarna är lika breda
local TAB_LEFT = 62     -- där spelets sökruta började, till höger om väskans ikon
local TAB_TOP = -26     -- som trollbokens flikar (Camelot/SpellBook/Blizzard_SpellBookTemplates.xml)
local TAB_GAP = 2
-- Sökrutan börjar till höger om flikarna (Marks.lua flyttar den hit).
ns.SEARCH_BOX_LEFT = TAB_LEFT + 2 * TAB_WIDTH + TAB_GAP + 12
local WARNING_ICON = "Interface\\DialogFrame\\UI-Dialog-Icon-AlertNew"

local view = "bags"
local tabSystem, tabHost, emptyText, newSetButton
local rows = {}

function ns.IsSetsView()
    return view == "sets"
end

-- Byter mellan "bags" och "sets".
function ns.SetView(newView)
    view = newView == "sets" and "sets" or "bags"
    if tabSystem then
        tabSystem:SetTabVisuallySelected(view == "sets" and 2 or 1)
    end
    for _, row in ipairs(rows) do
        row:Hide()
    end
    if newSetButton then
        newSetButton:SetShown(view == "sets")
        emptyText:SetShown(view == "sets" and #ns.GetSets() == 0)
    end
    -- Sökrutan söker bara bland sakerna, så den visas inte i fliken Sets.
    if BagItemSearchBox and ns.bagFrame and BagItemSearchBox:GetParent() == ns.bagFrame then
        BagItemSearchBox:SetShown(view == "bags")
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

local MINI_SIZE = 18
local MINI_GAP = 3
local MAX_MINI = 14     -- fler än så visas som "+3"

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
    GameTooltip_AddInstructionLine(GameTooltip, L["Right-click to edit or delete the set."])
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

-- Högerklick: spelets egen meny med det man kan göra med setet.
local function showRowMenu(row)
    local index = row.setIndex
    local set = ns.GetSets()[index]
    if not set then
        return
    end
    MenuUtil.CreateContextMenu(row, function(_, rootDescription)
        rootDescription:CreateTitle(set.name)
        rootDescription:CreateButton(L["Edit Name and Icon..."], function()
            ns.AskEditSet(index)
        end)
        if #set.items > 0 then
            local removeMenu = rootDescription:CreateButton(L["Remove Item"])
            for _, itemID in ipairs(set.items) do
                local name = C_Item.GetItemNameByID(itemID) or L["Item %d"]:format(itemID)
                local icon = C_Item.GetItemIconByID(itemID)
                removeMenu:CreateButton((icon and ("|T%s:14:14|t "):format(icon) or "") .. name, function()
                    ns.SetInSet(index, itemID, false)
                end)
            end
        end
        rootDescription:CreateButton(L["Delete Set..."], function()
            ns.AskDeleteSet(index)
        end)
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

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(37, 37)
    row.icon:SetPoint("LEFT", 4, 0)
    row.name = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 9, -1)
    row.minis = {}
    row.more = row:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    row.status = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    row.status:SetPoint("RIGHT", -10, 0)
    rows[index] = row
    return row
end

-- Fyller en rad med setets ikon, namn, saker och läge.
local function fillRow(row, index, set)
    row.setIndex = index
    row.name:SetText(set.name)
    row.icon:SetTexture(ns.GetSetIcon(index))

    -- Sakerna som små rutor under namnet. Saker som saknas är grå och svaga.
    local shownCount = math.min(#set.items, MAX_MINI)
    for k = 1, shownCount do
        local mini = row.minis[k]
        if not mini then
            mini = row:CreateTexture(nil, "ARTWORK")
            mini:SetSize(MINI_SIZE, MINI_SIZE)
            mini:SetPoint("BOTTOMLEFT", row.icon, "BOTTOMRIGHT", 9 + (k - 1) * (MINI_SIZE + MINI_GAP), 0)
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
    if #set.items > MAX_MINI then
        row.more:SetText("+" .. (#set.items - MAX_MINI))
        row.more:SetPoint("LEFT", row.minis[MAX_MINI], "RIGHT", 4, 0)
        row.more:Show()
    else
        row.more:Hide()
    end

    -- Till höger: på dig, varning för det som saknas, eller hur många saker setet har.
    local count, missing, worn = ns.GetSetStatus(index)
    if #missing > 0 then
        -- Spelets egen varningsikon, samma som i spelets frågerutor.
        row.status:SetText(CreateTextureMarkup(WARNING_ICON, 64, 64, 12, 12, 0, 1, 0, 1) .. " "
            .. L["%d missing"]:format(#missing))
        row.status:SetTextColor(ORANGE_FONT_COLOR:GetRGB())
    elseif worn then
        row.status:SetText(CreateAtlasMarkup("common-icon-checkmark", 12, 12) .. " " .. L["Equipped"])
        row.status:SetTextColor(GREEN_FONT_COLOR:GetRGB())
    elseif count == 0 then
        row.status:SetText(L["Drop items here"])
        row.status:SetTextColor(GRAY_FONT_COLOR:GetRGB())
    else
        row.status:SetText(count == 1 and L["1 item"] or L["%d items"]:format(count))
        row.status:SetTextColor(GRAY_FONT_COLOR:GetRGB())
    end
end

-- Lägger ut listan. place(region, x, y) placerar en del i väskfönstret, width är
-- rutornas bredd. Returnerar höjden och knapparna (för handkontrollen).
function ns.LayoutSetsView(place, width)
    local shown = {}
    local sets = ns.GetSets()
    local y = 4
    if #sets == 0 then
        place(emptyText, 2, y)
        emptyText:Show()
        y = y + EMPTY_HEIGHT
    else
        emptyText:Hide()
    end
    for index, set in ipairs(sets) do
        local row = acquireRow(index, newSetButton:GetParent())
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
    y = y + 6
    place(newSetButton, 2, y)
    newSetButton:Show()
    shown[#shown + 1] = newSetButton
    y = y + newSetButton:GetHeight() + 4
    return math.max(y, MIN_HEIGHT), shown
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
    tabSystem:SetPoint("TOPLEFT", bagFrame, "TOPLEFT", TAB_LEFT, TAB_TOP)
    tabSystem:SetTabSelectedCallback(function(tabID)
        ns.SetView(tabID == 2 and "sets" or "bags")
        return true -- ns.SetView har redan markerat fliken
    end)
    for _, label in ipairs({ L["Bags"], L["Sets"] }) do
        local tabID = tabSystem:AddTab(label)
        -- Lite större text än spelets standard, som i trollboken.
        local tab = tabSystem:GetTabButton(tabID)
        tab.selectedFontObject, tab.unselectedFontObject = GameFontHighlight, GameFontNormal
        tab:UpdateTabWidth()
    end
    tabSystem:SetTabVisuallySelected(1)

    emptyText = tabHost:CreateFontString(nil, "ARTWORK", "GameFontDisable")
    emptyText:SetJustifyH("LEFT")
    emptyText:SetText(L["You have no sets yet."])
    emptyText:Hide()

    -- "New Set" under listan. Håller du en sak hamnar den i det nya setet.
    newSetButton = CreateFrame("Button", nil, tabHost, "UIPanelButtonTemplate")
    newSetButton:SetSize(120, 22)
    newSetButton:SetText(L["New Set"])
    newSetButton:Hide()
    local function newSet()
        local itemID = cursorItemID()
        if itemID then
            ClearCursor()
        end
        ns.AskNewSet(itemID)
    end
    newSetButton:SetScript("OnClick", newSet)
    newSetButton:SetScript("OnReceiveDrag", newSet)

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
