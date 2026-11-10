-- TidyPack – GroupsPage.lua
-- Sidan "Groups" i inställningarna (Esc → Options → AddOns → Tidy Pack → Groups): här ser du
-- dina egna grupper (Groups.lua), ändrar ordning, byter namn och tar bort dem, och ser och
-- ändrar vad varje grupp innehåller. En grupp väljs genom att klicka på dess rad; under
-- raderna visas då dess regler ("All Potion items") och enskilda saker, med ett rött kryss
-- för att ta bort var och en, och en ruta för att lägga till fler (länk, namn, nummer eller en
-- sak som släpps på sidan), som på skräplistans sida (Options.lua).
-- Sidan är en egen ram (canvas layout) byggd av spelets mallar. Options.lua registrerar den.

local addonName, ns = ...
local L = ns.L

local ROW_HEIGHT = 32     -- en rad i listan med grupper
local ENTRY_HEIGHT = 28   -- en rad i listan med det gruppen innehåller
local MAX_GROUPS = ns.MAX_GROUPS or 8

local page, rowsHolder, emptyText, newButton, countText
local detailTitle, detailInput, detailHint, detailScroll, detailEmpty, detailAddButton
local rows = {}
local selected = 1 -- platsen i listan för den valda gruppen

local HINT_TEXT

local function groups()
    return ns.GetCustomGroups()
end

-- Det röda krysset som spelets egna frågor stängs med.
local function createRemoveButton(parent, size)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(size, size)
    button:SetNormalAtlas("RedButton-Exit")
    button:SetPushedAtlas("RedButton-exit-pressed")
    button:SetHighlightAtlas("RedButton-Exit", "ADD")
    return button
end

-- Kort sammanfattning av en grupp: "All Potion items, 2 items". Det andra värdet är sant när
-- gruppen är tom.
local function summary(group)
    local parts = {}
    local keys = {}
    for key in pairs(group.types) do
        keys[#keys + 1] = key
    end
    if #keys == 1 then
        local classID, subClassID = ns.ParseTypeKey(keys[1])
        parts[#parts + 1] = L["All %s items"]:format(ns.GetTypeName(classID, subClassID))
    elseif #keys > 1 then
        parts[#parts + 1] = L["%d types"]:format(#keys)
    end
    local itemCount = 0
    for _ in pairs(group.items) do
        itemCount = itemCount + 1
    end
    if itemCount == 1 then
        parts[#parts + 1] = L["1 item"]
    elseif itemCount > 1 then
        parts[#parts + 1] = L["%d items"]:format(itemCount)
    end
    if #parts == 0 then
        return L["Empty"], true
    end
    return table.concat(parts, ", "), false
end

---------------------------------------------------------------------------
-- Raderna med grupper
---------------------------------------------------------------------------

local function createRow(index)
    local row = CreateFrame("Button", nil, rowsHolder)
    row.index = index
    row:SetHeight(ROW_HEIGHT)
    row:SetPoint("TOPLEFT", rowsHolder, "TOPLEFT", 0, -(index - 1) * ROW_HEIGHT)
    row:SetPoint("TOPRIGHT", rowsHolder, "TOPRIGHT", 0, -(index - 1) * ROW_HEIGHT)
    row:SetHighlightAtlas("Options_List_Hover", "ADD")
    row.selectedTexture = row:CreateTexture(nil, "BACKGROUND")
    row.selectedTexture:SetAllPoints()
    row.selectedTexture:SetColorTexture(1, 0.82, 0, 0.12)
    row:SetScript("OnClick", function(self)
        selected = self.index
        ns.RefreshGroupsPage()
    end)

    -- Upp och ned, ovanpå varandra.
    row.up = CreateFrame("Button", nil, row, "UIPanelScrollUpButtonTemplate")
    row.up:SetPoint("TOPLEFT", 8, -2)
    row.up:SetScript("OnClick", function(self)
        selected = ns.MoveGroup(self:GetParent().index, -1)
        ns.RefreshGroupsPage()
    end)
    row.down = CreateFrame("Button", nil, row, "UIPanelScrollDownButtonTemplate")
    row.down:SetPoint("BOTTOMLEFT", 8, 2)
    row.down:SetScript("OnClick", function(self)
        selected = ns.MoveGroup(self:GetParent().index, 1)
        ns.RefreshGroupsPage()
    end)

    row.name = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    row.name:SetPoint("LEFT", 40, 0)
    row.name:SetWidth(170)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    row.meta = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    row.meta:SetPoint("LEFT", row.name, "RIGHT", 10, 0)
    row.meta:SetPoint("RIGHT", row, "RIGHT", -120, 0)
    row.meta:SetJustifyH("LEFT")
    row.meta:SetWordWrap(false)

    row.remove = createRemoveButton(row, 22)
    row.remove:SetPoint("RIGHT", -6, 0)
    row.remove:SetScript("OnClick", function(self)
        ns.AskDeleteGroup(self:GetParent().index)
    end)
    row.remove:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip_SetTitle(GameTooltip, L["Delete Group..."])
        GameTooltip:Show()
    end)
    row.remove:SetScript("OnLeave", GameTooltip_Hide)

    row.rename = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.rename:SetSize(80, 22)
    row.rename:SetPoint("RIGHT", row.remove, "LEFT", -6, 0)
    row.rename:SetText(L["Rename"])
    row.rename:SetScript("OnClick", function(self)
        ns.AskRenameGroup(self:GetParent().index)
    end)
    return row
end

---------------------------------------------------------------------------
-- Det gruppen innehåller
---------------------------------------------------------------------------

-- Reglerna (hela typer) först, sedan de enskilda sakerna i namnordning.
local function buildEntries(group)
    local entries = {}
    local keys = {}
    for key in pairs(group.types) do
        keys[#keys + 1] = key
    end
    table.sort(keys)
    for _, key in ipairs(keys) do
        local classID, subClassID = ns.ParseTypeKey(key)
        entries[#entries + 1] = { kind = "type", classID = classID, subClassID = subClassID }
    end
    local ids = {}
    for itemID in pairs(group.items) do
        ids[#ids + 1] = itemID
    end
    table.sort(ids, function(a, b)
        local nameA, nameB = C_Item.GetItemNameByID(a) or "", C_Item.GetItemNameByID(b) or ""
        if nameA ~= nameB then
            return nameA < nameB
        end
        return a < b
    end)
    for _, itemID in ipairs(ids) do
        entries[#entries + 1] = { kind = "item", itemID = itemID }
    end
    return entries
end

local function showEntryTooltip(row)
    if row.itemID then
        GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
        GameTooltip:SetItemByID(row.itemID)
        GameTooltip:Show()
    end
end

-- En rad: ikon, namn och ett rött kryss. Raderna återanvänds av listan, så delarna skapas
-- bara första gången.
local function initEntry(row, entry)
    if not row.icon then
        row:EnableMouse(true)
        row:SetScript("OnEnter", showEntryTooltip)
        row:SetScript("OnLeave", GameTooltip_Hide)
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(24, 24)
        row.icon:SetPoint("LEFT", 4, 0)
        row.name = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        row.name:SetPoint("LEFT", row.icon, "RIGHT", 8, 0)
        row.name:SetPoint("RIGHT", -40, 0)
        row.name:SetJustifyH("LEFT")
        row.name:SetWordWrap(false)
        row.remove = createRemoveButton(row, 22)
        row.remove:SetPoint("RIGHT", -6, 0)
        row.remove:SetScript("OnClick", function(self)
            local parent = self:GetParent()
            local data = parent.entry
            if data.kind == "type" then
                ns.SetTypeInGroup(selected, data.classID, data.subClassID, false)
            else
                ns.SetItemInGroup(selected, data.itemID, false)
            end
        end)
        row.remove:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip_SetTitle(GameTooltip, L["Remove from the group"])
            GameTooltip:Show()
        end)
        row.remove:SetScript("OnLeave", GameTooltip_Hide)
    end
    row.entry = entry
    if entry.kind == "type" then
        row.itemID = nil
        row.icon:SetAtlas("bags-icon-multiple")
        row.name:SetText(L["All %s items"]:format(ns.GetTypeName(entry.classID, entry.subClassID)))
        row.name:SetTextColor(HIGHLIGHT_FONT_COLOR:GetRGB())
        return
    end
    local itemID = entry.itemID
    row.itemID = itemID
    row.icon:SetTexture(C_Item.GetItemIconByID(itemID))
    row.icon:SetTexCoord(0, 1, 0, 1)
    local name = C_Item.GetItemNameByID(itemID)
    if name then
        local r, g, b = C_Item.GetItemQualityColor(C_Item.GetItemQualityByID(itemID) or Enum.ItemQuality.Common)
        row.name:SetText(name)
        row.name:SetTextColor(r, g, b)
    else
        -- Spelet har inte sakens data än: visa numret och rita om när datan kommit.
        row.name:SetText(L["Item %d"]:format(itemID))
        row.name:SetTextColor(GRAY_FONT_COLOR:GetRGB())
        Item:CreateFromItemID(itemID):ContinueOnItemLoad(ns.RefreshGroupsPage)
    end
end

local function setHint(text, color)
    detailHint:SetText(text)
    detailHint:SetTextColor(color:GetRGB())
end

local function addFromInput()
    local group = groups()[selected]
    if not group then
        return
    end
    local itemID = ns.ItemIDFromText and ns.ItemIDFromText(detailInput:GetText())
    if itemID then
        ns.SetItemInGroup(selected, itemID, true)
        detailInput:SetText("")
        setHint(HINT_TEXT, GRAY_FONT_COLOR)
    else
        setHint(L["Couldn't find that item. Try Shift-clicking its link instead."], RED_FONT_COLOR)
    end
end

-- En sak som släpps på sidan (eller klickas dit) hamnar i den valda gruppen.
local function addFromCursor()
    local kind, itemID = GetCursorInfo()
    if kind == "item" and itemID and groups()[selected] then
        ClearCursor() -- saken går tillbaka till sin plats
        ns.SetItemInGroup(selected, itemID, true)
    end
end

---------------------------------------------------------------------------
-- Sidan
---------------------------------------------------------------------------

-- Ritar om sidan om den syns. Groups.lua anropar den när grupperna ändras.
function ns.RefreshGroupsPage()
    if not page or not page:IsVisible() then
        return
    end
    local list = groups()
    if selected > #list then
        selected = #list
    end
    if selected < 1 and #list > 0 then
        selected = 1
    end
    for index = 1, MAX_GROUPS do
        local row = rows[index]
        local group = list[index]
        if group then
            local text, isEmpty = summary(group)
            row.name:SetText(group.name)
            row.meta:SetText(text)
            row.meta:SetTextColor((isEmpty and GRAY_FONT_COLOR or HIGHLIGHT_FONT_COLOR):GetRGB())
            row.selectedTexture:SetShown(index == selected)
            row.up:SetEnabled(index > 1)
            row.down:SetEnabled(index < #list)
            row:Show()
        else
            row:Hide()
        end
    end
    emptyText:SetShown(#list == 0)
    -- "New Group" står direkt under den sista raden.
    newButton:ClearAllPoints()
    newButton:SetPoint("TOPLEFT", rowsHolder, "TOPLEFT", 0, -(math.max(#list, 1) * ROW_HEIGHT) - 12)
    newButton:SetEnabled(#list < MAX_GROUPS)
    countText:SetText(L["%d of %d groups used."]:format(#list, MAX_GROUPS))

    local group = list[selected]
    detailTitle:SetShown(group ~= nil)
    detailInput:SetShown(group ~= nil)
    detailAddButton:SetShown(group ~= nil)
    detailHint:SetShown(group ~= nil)
    detailScroll:SetShown(group ~= nil)
    if not group then
        detailEmpty:Hide()
        return
    end
    detailTitle:SetText(L["In %s"]:format(group.name))
    local entries = buildEntries(group)
    detailScroll:SetDataProvider(CreateDataProvider(entries), ScrollBoxConstants.RetainScrollPosition)
    detailEmpty:SetShown(#entries == 0)
end

-- Skapar sidan och returnerar den. Options.lua registrerar den som en undersida.
function ns.CreateGroupsPage()
    HINT_TEXT = L["Shift-click an item link, type an item name or ID, or drop an item here."]

    page = CreateFrame("Frame")
    page:EnableMouse(true)
    page:SetScript("OnReceiveDrag", addFromCursor)
    page:SetScript("OnMouseUp", addFromCursor)

    local title = page:CreateFontString(nil, "ARTWORK", "GameFontHighlightHuge")
    title:SetPoint("TOPLEFT", 10, -15)
    title:SetText(L["Groups"])

    local intro = page:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    intro:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
    intro:SetPoint("RIGHT", page, "RIGHT", -20, 0)
    intro:SetJustifyH("LEFT")
    intro:SetText(L["Collect items under your own names. Groups come after Favorites and \"Add to bag\". Drop an item on the gear button in your bags to add it, or choose Add all ... items to Group to add a whole type."])

    rowsHolder = CreateFrame("Frame", nil, page)
    rowsHolder:SetPoint("TOPLEFT", intro, "BOTTOMLEFT", 0, -14)
    rowsHolder:SetPoint("TOPRIGHT", intro, "BOTTOMRIGHT", 0, -14)
    rowsHolder:SetHeight(MAX_GROUPS * ROW_HEIGHT)
    for index = 1, MAX_GROUPS do
        rows[index] = createRow(index)
    end

    emptyText = page:CreateFontString(nil, "ARTWORK", "GameFontDisable")
    emptyText:SetPoint("TOPLEFT", rowsHolder, "TOPLEFT", 4, -8)
    emptyText:SetText(L["You have no groups yet."])

    newButton = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
    newButton:SetSize(120, 22)
    newButton:SetText(L["New Group"])
    newButton:SetScript("OnClick", function()
        ns.AskNewGroup(function(index)
            selected = index
        end)
    end)
    countText = page:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    countText:SetPoint("LEFT", newButton, "RIGHT", 12, 0)
    countText:SetTextColor(GRAY_FONT_COLOR:GetRGB())

    -- Det den valda gruppen innehåller, under "New Group".
    detailTitle = page:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    detailTitle:SetPoint("TOPLEFT", newButton, "BOTTOMLEFT", 0, -22)

    detailInput = CreateFrame("EditBox", nil, page, "InputBoxTemplate")
    detailInput:SetSize(300, 22)
    detailInput:SetAutoFocus(false)
    detailInput:SetPoint("TOPLEFT", detailTitle, "BOTTOMLEFT", 6, -10)
    detailInput:SetScript("OnEnterPressed", addFromInput)

    detailAddButton = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
    detailAddButton:SetSize(90, 22)
    detailAddButton:SetText(L["Add"])
    detailAddButton:SetPoint("LEFT", detailInput, "RIGHT", 10, 0)
    detailAddButton:SetScript("OnClick", addFromInput)

    detailHint = page:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    detailHint:SetPoint("TOPLEFT", detailInput, "BOTTOMLEFT", -6, -8)
    setHint(HINT_TEXT, GRAY_FONT_COLOR)

    detailScroll = CreateFrame("Frame", nil, page, "WowScrollBoxList")
    detailScroll:SetPoint("TOPLEFT", detailHint, "BOTTOMLEFT", 0, -10)
    detailScroll:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -36, 16)
    local scrollBar = CreateFrame("EventFrame", nil, page, "MinimalScrollBar")
    scrollBar:SetPoint("TOPLEFT", detailScroll, "TOPRIGHT", 8, 0)
    scrollBar:SetPoint("BOTTOMLEFT", detailScroll, "BOTTOMRIGHT", 8, 0)
    local view = CreateScrollBoxListLinearView()
    view:SetElementExtent(ENTRY_HEIGHT)
    view:SetElementInitializer("Frame", initEntry)
    ScrollUtil.InitScrollBoxListWithScrollBar(detailScroll, scrollBar, view)
    ScrollUtil.AddManagedScrollBarVisibilityBehavior(detailScroll, scrollBar)

    detailEmpty = page:CreateFontString(nil, "ARTWORK", "GameFontDisable")
    detailEmpty:SetPoint("TOPLEFT", detailScroll, "TOPLEFT", 4, -8)
    detailEmpty:SetText(L["Nothing in this group yet."])

    page:SetScript("OnShow", ns.RefreshGroupsPage)
    page:SetScript("OnHide", function()
        detailInput:ClearFocus()
    end)

    -- Shift-klick på en länk medan rutan är aktiv (samma som på skräplistans sida).
    if ChatFrameUtil and ChatFrameUtil.InsertLink then
        hooksecurefunc(ChatFrameUtil, "InsertLink", function(text)
            if detailInput:HasFocus() and type(text) == "string" and text:find("item:", 1, true) then
                detailInput:SetText(text)
                addFromInput()
            end
        end)
    end
    return page
end
