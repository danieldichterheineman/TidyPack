-- TidyPack – SetsView.lua
-- Flikarna Bags och Sets ovanför väskfönstret, och listan med set som fliken Sets visar i
-- fönstret i stället för sakerna. Flikarna är spelets egna (PanelTopTabButtonTemplate, samma
-- som i Forevers samlingsfönster). Klick på ett set tar på det (Sets.lua).
-- Layout.lua lägger ut listan: den anropar ns.LayoutSetsView när fliken Sets är vald.
-- Väskfönstret öppnas alltid på fliken Bags.
-- ⚠️ Med handkontroll: raderna är vanliga knappar i väskfönstret och ska nås med markören,
-- och ★-menyn kan också byta flik (Marks.lua). Måste provas i spelet.

local addonName, ns = ...
local L = ns.L

local ROW_HEIGHT = 44
local ROW_GAP = 4
local HINT_HEIGHT = 22
local MIN_HEIGHT = 120  -- listan är minst så här hög, så att fönstret inte krymper ihop
local TAB_WIDTH = 80    -- båda flikarna är alltid lika breda
local WARNING_ICON = "Interface\\DialogFrame\\UI-Dialog-Icon-AlertNew"

local view = "bags"
local tabHost, topHint, bottomHint
local rows = {}

function ns.IsSetsView()
    return view == "sets"
end

-- Byter mellan "bags" och "sets".
-- Spelets flikar gör den valda fliken högre än de andra och flyttar ned texten på de
-- andra. Tidy Packs två flikar ska alltid vara lika stora (användarens önskan), så båda
-- använder den valda flikens bilder; den flik som inte är vald är bara lite mörkare.
local function styleTabs()
    for _, tab in ipairs(tabHost.Tabs) do
        local selected = tab:GetID() == tabHost.selectedTab
        for _, part in ipairs({ tab.Left, tab.Middle, tab.Right }) do
            part:Hide()
        end
        for _, part in ipairs({ tab.LeftActive, tab.MiddleActive, tab.RightActive }) do
            part:Show()
            local shade = selected and 1 or 0.6
            part:SetVertexColor(shade, shade, shade)
        end
        tab.Text:SetPoint("CENTER", tab, "CENTER", 0, -4)
        tab:SetNormalFontObject(selected and GameFontHighlightSmall or GameFontNormalSmall)
        PanelTemplates_TabResize(tab, 0, TAB_WIDTH)
    end
end

local function selectTab(id)
    PanelTemplates_SetTab(tabHost, id)
    styleTabs()
end

function ns.SetView(newView)
    view = newView == "sets" and "sets" or "bags"
    if tabHost then
        selectTab(view == "sets" and 2 or 1)
    end
    for _, row in ipairs(rows) do
        row:Hide()
    end
    if topHint then
        topHint:SetShown(view == "sets")
        bottomHint:SetShown(view == "sets")
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

local STATE_TEXT = {
    equipped = { L["Equipped"], GREEN_FONT_COLOR },
    bags = { L["In your bags"], HIGHLIGHT_FONT_COLOR },
    missing = { L["Missing"], RED_FONT_COLOR },
}

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
    if #set.items == 0 then
        GameTooltip_AddNormalLine(GameTooltip, L["Drop an item on the gear button to add it to a set."])
    end
    GameTooltip_AddBlankLineToTooltip(GameTooltip)
    GameTooltip_AddInstructionLine(GameTooltip, L["Click to put it on. Right-click to edit your sets."])
    GameTooltip:Show()
end

local function onRowClick(row, mouseButton)
    if mouseButton == "RightButton" then
        if ns.OpenSettings then
            ns.OpenSettings("sets")
        end
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
    row:SetScript("OnEnter", showRowTooltip)
    row:SetScript("OnLeave", GameTooltip_Hide)

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(37, 37)
    row.icon:SetPoint("LEFT", 4, 0)
    row.name = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 9, -4)
    row.info = row:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    row.info:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -5)
    row.worn = row:CreateFontString(nil, "ARTWORK", "GameFontGreenSmall")
    row.worn:SetPoint("RIGHT", -10, 0)
    row.worn:SetText(CreateAtlasMarkup("common-icon-checkmark", 12, 12) .. " " .. L["Equipped"])
    rows[index] = row
    return row
end

-- Fyller en rad med setets namn, ikon och läge.
local function fillRow(row, index, set)
    row.setIndex = index
    row.name:SetText(set.name)
    row.icon:SetTexture(ns.GetSetIcon(index))
    local count, missing, worn = ns.GetSetStatus(index)
    if #missing > 0 then
        local first = C_Item.GetItemNameByID(missing[1]) or L["Item %d"]:format(missing[1])
        local text = #missing == 1 and L["1 missing: %s"]:format(first) or L["%d missing, e.g. %s"]:format(#missing, first)
        -- Spelets egen varningsikon, samma som i spelets frågerutor.
        row.info:SetText(CreateTextureMarkup(WARNING_ICON, 64, 64, 12, 12, 0, 1, 0, 1) .. " " .. text)
        row.info:SetTextColor(ORANGE_FONT_COLOR:GetRGB())
    else
        row.info:SetText(count == 1 and L["1 item"] or L["%d items"]:format(count))
        row.info:SetTextColor(GRAY_FONT_COLOR:GetRGB())
    end
    row.worn:SetShown(worn and #missing == 0)
end

-- Lägger ut listan. place(region, x, y) placerar en del i väskfönstret, width är
-- rutornas bredd. Returnerar höjden och raderna (för handkontrollen).
function ns.LayoutSetsView(place, width)
    local shown = {}
    local sets = ns.GetSets()
    local y = 0
    topHint:SetText(#sets > 0 and L["Click a set to put it on."]
        or L["You have no sets yet. Drop an item on the gear button and choose Add to Set."])
    place(topHint, 2, y)
    topHint:Show()
    y = y + HINT_HEIGHT
    for index, set in ipairs(sets) do
        local row = acquireRow(index, topHint:GetParent())
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
    if #sets > 0 then
        y = y + 4
        place(bottomHint, 2, y)
        bottomHint:Show()
        y = y + HINT_HEIGHT - 6
    else
        bottomHint:Hide()
    end
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

    -- En egen ram håller flikarna, så att spelets fönster inte får några nya fält.
    tabHost = CreateFrame("Frame", nil, bagFrame)
    tabHost:SetAllPoints()
    -- Spelets flikar läser bredden härifrån när de visas (PanelTabButtonMixin:OnShow).
    tabHost.minTabWidth, tabHost.maxTabWidth = TAB_WIDTH, TAB_WIDTH

    local function onTabClick(tab)
        PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
        ns.SetView(tab:GetID() == 2 and "sets" or "bags")
    end
    local labels = { L["Bags"], L["Sets"] }
    for id, label in ipairs(labels) do
        local tab = CreateFrame("Button", nil, tabHost, "PanelTopTabButtonTemplate")
        tab:SetID(id)
        tab:SetText(label)
        tab:SetScript("OnClick", onTabClick)
    end
    -- Till höger om väskans ikon uppe till vänster, så att flikarna inte täcker den.
    tabHost.Tabs[1]:SetPoint("BOTTOMLEFT", bagFrame, "TOPLEFT", 60, -3)
    PanelTemplates_SetNumTabs(tabHost, #labels)
    selectTab(1)

    topHint = tabHost:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    topHint:SetJustifyH("LEFT")
    topHint:Hide()
    bottomHint = tabHost:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    bottomHint:SetJustifyH("LEFT")
    bottomHint:SetText(L["Drop an item on the gear button to add it to a set. Right-click a set to edit."])
    bottomHint:Hide()

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
