-- TidyPack – Options.lua
-- Inställningarna i spelets eget fönster: Esc → Options → AddOns → Tidy Pack, med egna
-- sidor för skräplistan och seten. Sidan öppnas också med /tidypack, från addonmenyn vid minikartan
-- (## AddonCompartmentFunc i TOC-filen) och från ★ i väskfönstret (Marks.lua).
-- Huvudsidan använder spelets vanliga rader (vertical layout), så att den ser ut som spelets
-- egna sidor. Skräplistans sida är en egen ram (canvas layout) byggd av spelets mallar.
-- Varje kryssruta sparas direkt i ns.db.

local addonName, ns = ...
local L = ns.L

local ROW_HEIGHT = 30
local HINT_TEXT -- sätts när L är klar, se createJunkPage

local category, junkCategory, setsCategory
local junkPage, junkScrollBox, junkEmptyText, junkInput, junkHint
local setsPage, setsScrollBox, setsEmptyText

-- Öppnar Tidy Packs sida, eller skräplistans sida med page = "junk".
function ns.OpenSettings(page)
    if InCombatLockdown() then
        ns.Print(L["The settings can't be opened in combat."])
        return
    end
    local target = (page == "junk" and junkCategory) or (page == "sets" and setsCategory) or category
    if target then
        Settings.OpenToCategory(target:GetID())
    end
end

---------------------------------------------------------------------------
-- Skräplistans sida
---------------------------------------------------------------------------

-- Skräplistan sorterad efter namn.
local function sortedJunkList()
    local list = {}
    for itemID in pairs(ns.db.junk) do
        list[#list + 1] = itemID
    end
    table.sort(list, function(a, b)
        local nameA, nameB = C_Item.GetItemNameByID(a) or "", C_Item.GetItemNameByID(b) or ""
        if nameA ~= nameB then
            return nameA < nameB
        end
        return a < b
    end)
    return list
end

-- Ritar om listan om sidan syns. Marks.lua anropar den när listan ändras.
function ns.RefreshJunkListPage()
    if not junkPage or not junkPage:IsVisible() then
        return
    end
    junkScrollBox:SetDataProvider(CreateDataProvider(sortedJunkList()), ScrollBoxConstants.RetainScrollPosition)
    junkEmptyText:SetShown(next(ns.db.junk) == nil)
end

local function showItemTooltip(row)
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    GameTooltip:SetItemByID(row.itemID)
    GameTooltip:Show()
end

-- En rad i listan: ikon, namn i kvalitetens färg och ett rött kryss som tar bort saken.
-- Raderna återanvänds av listan, så delarna skapas bara första gången.
local function initRow(row, itemID)
    if not row.icon then
        row:EnableMouse(true)
        row:SetScript("OnEnter", showItemTooltip)
        row:SetScript("OnLeave", GameTooltip_Hide)
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(24, 24)
        row.icon:SetPoint("LEFT", 4, 0)
        row.name = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        row.name:SetPoint("LEFT", row.icon, "RIGHT", 8, 0)
        row.name:SetPoint("RIGHT", -40, 0)
        row.name:SetJustifyH("LEFT")
        row.name:SetWordWrap(false)
        -- Samma röda kryss som spelets egna frågor stängs med.
        row.remove = CreateFrame("Button", nil, row)
        row.remove:SetSize(22, 22)
        row.remove:SetPoint("RIGHT", -6, 0)
        row.remove:SetNormalAtlas("RedButton-Exit")
        row.remove:SetPushedAtlas("RedButton-exit-pressed")
        row.remove:SetHighlightAtlas("RedButton-Exit", "ADD")
        row.remove:SetScript("OnClick", function(self)
            ns.SetJunk(self:GetParent().itemID, false)
        end)
        row.remove:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip_SetTitle(GameTooltip, L["Remove from the junk list"])
            GameTooltip:Show()
        end)
        row.remove:SetScript("OnLeave", GameTooltip_Hide)
    end
    row.itemID = itemID
    row.icon:SetTexture(C_Item.GetItemIconByID(itemID))
    local name = C_Item.GetItemNameByID(itemID)
    if name then
        local r, g, b = C_Item.GetItemQualityColor(C_Item.GetItemQualityByID(itemID) or Enum.ItemQuality.Common)
        row.name:SetText(name)
        row.name:SetTextColor(r, g, b)
    else
        -- Spelet har inte sakens data än: visa numret och rita om när datan kommit.
        row.name:SetText(L["Item %d"]:format(itemID))
        row.name:SetTextColor(GRAY_FONT_COLOR:GetRGB())
        Item:CreateFromItemID(itemID):ContinueOnItemLoad(ns.RefreshJunkListPage)
    end
end

-- Sakens id ur en länk, ett nummer eller ett namn (ett namn bara om spelet känner till
-- saken). Nil om det inte är en riktig sak.
local function itemIDFromText(text)
    text = strtrim(text or "")
    if text == "" then
        return nil
    end
    local id = tonumber(text:match("item:(%d+)") or text:match("^#?(%d+)$"))
    if not id then
        id = C_Item.GetItemInfoInstant(text)
    end
    if id and C_Item.GetItemInfoInstant(id) then
        return id
    end
    return nil
end

local function setHint(text, color)
    junkHint:SetText(text)
    junkHint:SetTextColor(color:GetRGB())
end

local function addFromInput()
    local itemID = itemIDFromText(junkInput:GetText())
    if itemID then
        ns.SetJunk(itemID, true)
        junkInput:SetText("")
        setHint(HINT_TEXT, GRAY_FONT_COLOR)
    else
        setHint(L["Couldn't find that item. Try Shift-clicking its link instead."], RED_FONT_COLOR)
    end
end

-- En sak som släpps på sidan (eller klickas dit) hamnar på listan.
local function addFromCursor()
    local kind, itemID = GetCursorInfo()
    if kind == "item" and itemID then
        ClearCursor() -- saken går tillbaka till sin plats
        ns.SetJunk(itemID, true)
    end
end

local function createJunkPage()
    HINT_TEXT = L["Shift-click an item link, type an item name or ID, or drop an item here."]

    local page = CreateFrame("Frame")
    page:EnableMouse(true)
    page:SetScript("OnReceiveDrag", addFromCursor)
    page:SetScript("OnMouseUp", addFromCursor)

    -- Rubrik och förklaring, som på spelets egna sidor.
    local title = page:CreateFontString(nil, "ARTWORK", "GameFontHighlightHuge")
    title:SetPoint("TOPLEFT", 10, -15)
    title:SetText(L["Junk List"])

    local intro = page:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    intro:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
    intro:SetPoint("RIGHT", page, "RIGHT", -20, 0)
    intro:SetJustifyH("LEFT")
    intro:SetText(L["Items on your junk list are suggested for deletion when you loot them, sorted last in Junk and sold by Sell Junk. Alt-right-click an item in your bags, or drop it on the star, to add or remove it."])

    -- Lägg till en sak utan att ha den: länk, namn eller nummer.
    junkInput = CreateFrame("EditBox", nil, page, "InputBoxTemplate")
    junkInput:SetSize(300, 22)
    junkInput:SetAutoFocus(false)
    junkInput:SetPoint("TOPLEFT", intro, "BOTTOMLEFT", 6, -16)
    junkInput:SetScript("OnEnterPressed", addFromInput)

    local addButton = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
    addButton:SetSize(90, 22)
    addButton:SetText(L["Add"])
    addButton:SetPoint("LEFT", junkInput, "RIGHT", 10, 0)
    addButton:SetScript("OnClick", addFromInput)

    junkHint = page:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    junkHint:SetPoint("TOPLEFT", junkInput, "BOTTOMLEFT", -6, -8)
    setHint(HINT_TEXT, GRAY_FONT_COLOR)

    -- Listan, med spelets egen rullning (samma mallar som lootfönstret).
    junkScrollBox = CreateFrame("Frame", nil, page, "WowScrollBoxList")
    junkScrollBox:SetPoint("TOPLEFT", junkHint, "BOTTOMLEFT", 0, -12)
    junkScrollBox:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -36, 16)
    local scrollBar = CreateFrame("EventFrame", nil, page, "MinimalScrollBar")
    scrollBar:SetPoint("TOPLEFT", junkScrollBox, "TOPRIGHT", 8, 0)
    scrollBar:SetPoint("BOTTOMLEFT", junkScrollBox, "BOTTOMRIGHT", 8, 0)
    local view = CreateScrollBoxListLinearView()
    view:SetElementExtent(ROW_HEIGHT)
    view:SetElementInitializer("Frame", initRow)
    ScrollUtil.InitScrollBoxListWithScrollBar(junkScrollBox, scrollBar, view)
    -- Rullningslisten syns bara när listan inte får plats, som på spelets egna sidor.
    ScrollUtil.AddManagedScrollBarVisibilityBehavior(junkScrollBox, scrollBar)

    junkEmptyText = page:CreateFontString(nil, "ARTWORK", "GameFontDisable")
    junkEmptyText:SetPoint("TOPLEFT", junkScrollBox, "TOPLEFT", 4, -8)
    junkEmptyText:SetText(L["Your junk list is empty."])

    page:SetScript("OnShow", ns.RefreshJunkListPage)
    page:SetScript("OnHide", function()
        junkInput:ClearFocus()
    end)

    -- Shift-klick på en länk medan rutan är aktiv. Spelet lägger själv bara länkar i chatten
    -- och några egna fält (ChatFrameUtil.InsertLink), så Tidy Pack lyssnar efteråt.
    if ChatFrameUtil and ChatFrameUtil.InsertLink then
        hooksecurefunc(ChatFrameUtil, "InsertLink", function(text)
            if junkInput:HasFocus() and type(text) == "string" and text:find("item:", 1, true) then
                junkInput:SetText(text)
                addFromInput()
            end
        end)
    end
    return page
end

---------------------------------------------------------------------------
-- Setens sida
---------------------------------------------------------------------------
-- Varje set är en rubrikrad med Rename och Delete, följd av en rad per sak som visar var
-- saken finns hos den här karaktären: på dig, i väskorna eller saknas.

local SET_STATE = {
    equipped = { L["Equipped"], GREEN_FONT_COLOR },
    bags = { L["In your bags"], HIGHLIGHT_FONT_COLOR },
    missing = { L["Missing"], RED_FONT_COLOR },
}

function ns.RefreshSetsPage()
    if not setsPage or not setsPage:IsVisible() then
        return
    end
    local data = {}
    for index, set in ipairs(ns.GetSets()) do
        data[#data + 1] = { kind = "set", index = index }
        for _, itemID in ipairs(set.items) do
            data[#data + 1] = { kind = "item", index = index, itemID = itemID }
        end
    end
    setsScrollBox:SetDataProvider(CreateDataProvider(data), ScrollBoxConstants.RetainScrollPosition)
    setsEmptyText:SetShown(#data == 0)
end

local function smallButton(parent, label, width, onClick)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width, 22)
    button:SetText(label)
    button:SetScript("OnClick", onClick)
    return button
end

-- En rad, antingen ett set eller en sak i ett set. Delarna skapas första gången och
-- visas efter vad raden är.
local function initSetsRow(row, data)
    if not row.icon then
        row:EnableMouse(true)
        row.title = row:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
        row.title:SetPoint("LEFT", 4, 0)
        row.count = row:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
        row.count:SetPoint("LEFT", row.title, "RIGHT", 10, -1)
        row.delete = smallButton(row, L["Delete"], 80, function(self)
            ns.AskDeleteSet(self:GetParent().data.index)
        end)
        row.delete:SetPoint("RIGHT", -6, 0)
        row.rename = smallButton(row, L["Rename"], 80, function(self)
            ns.AskRenameSet(self:GetParent().data.index)
        end)
        row.rename:SetPoint("RIGHT", row.delete, "LEFT", -6, 0)

        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(22, 22)
        row.icon:SetPoint("LEFT", 24, 0)
        row.name = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        row.name:SetPoint("LEFT", row.icon, "RIGHT", 8, 0)
        row.name:SetPoint("RIGHT", -170, 0)
        row.name:SetJustifyH("LEFT")
        row.name:SetWordWrap(false)
        row.state = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        row.state:SetPoint("RIGHT", -40, 0)
        row.remove = CreateFrame("Button", nil, row)
        row.remove:SetSize(22, 22)
        row.remove:SetPoint("RIGHT", -6, 0)
        row.remove:SetNormalAtlas("RedButton-Exit")
        row.remove:SetPushedAtlas("RedButton-exit-pressed")
        row.remove:SetHighlightAtlas("RedButton-Exit", "ADD")
        row.remove:SetScript("OnClick", function(self)
            local rowData = self:GetParent().data
            ns.SetInSet(rowData.index, rowData.itemID, false)
        end)
        row.remove:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip_SetTitle(GameTooltip, L["Remove from the set"])
            GameTooltip:Show()
        end)
        row.remove:SetScript("OnLeave", GameTooltip_Hide)
        row:SetScript("OnEnter", function(self)
            if self.data and self.data.kind == "item" then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetItemByID(self.data.itemID)
                GameTooltip:Show()
            end
        end)
        row:SetScript("OnLeave", GameTooltip_Hide)
    end
    row.data = data
    local isSet = data.kind == "set"
    for _, part in ipairs({ row.title, row.count, row.rename, row.delete }) do
        part:SetShown(isSet)
    end
    for _, part in ipairs({ row.icon, row.name, row.state, row.remove }) do
        part:SetShown(not isSet)
    end
    local set = ns.GetSets()[data.index]
    if not set then
        return
    end
    if isSet then
        row.title:SetText(set.name)
        row.count:SetText(#set.items == 1 and L["1 item"] or L["%d items"]:format(#set.items))
        return
    end
    local itemID = data.itemID
    row.icon:SetTexture(C_Item.GetItemIconByID(itemID))
    local name = C_Item.GetItemNameByID(itemID)
    if name then
        local r, g, b = C_Item.GetItemQualityColor(C_Item.GetItemQualityByID(itemID) or Enum.ItemQuality.Common)
        row.name:SetText(name)
        row.name:SetTextColor(r, g, b)
    else
        row.name:SetText(L["Item %d"]:format(itemID))
        row.name:SetTextColor(GRAY_FONT_COLOR:GetRGB())
        Item:CreateFromItemID(itemID):ContinueOnItemLoad(ns.RefreshSetsPage)
    end
    local state = SET_STATE[ns.GetItemState(itemID)]
    row.state:SetText(state[1])
    row.state:SetTextColor(state[2]:GetRGB())
end

local function createSetsPage()
    local page = CreateFrame("Frame")

    local title = page:CreateFontString(nil, "ARTWORK", "GameFontHighlightHuge")
    title:SetPoint("TOPLEFT", 10, -15)
    title:SetText(L["Sets"])

    local intro = page:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    intro:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
    intro:SetPoint("RIGHT", page, "RIGHT", -20, 0)
    intro:SetJustifyH("LEFT")
    intro:SetText(L["Your sets on this character. To add an item, drop it on the star in your bags and choose Add to Set. In the bag window's Sets tab, click a set to put it on."])

    local newButton = smallButton(page, L["New Set"], 120, function()
        ns.AskNewSet()
    end)
    newButton:SetPoint("TOPLEFT", intro, "BOTTOMLEFT", 0, -14)

    setsScrollBox = CreateFrame("Frame", nil, page, "WowScrollBoxList")
    setsScrollBox:SetPoint("TOPLEFT", newButton, "BOTTOMLEFT", 0, -12)
    setsScrollBox:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -36, 16)
    local scrollBar = CreateFrame("EventFrame", nil, page, "MinimalScrollBar")
    scrollBar:SetPoint("TOPLEFT", setsScrollBox, "TOPRIGHT", 8, 0)
    scrollBar:SetPoint("BOTTOMLEFT", setsScrollBox, "BOTTOMRIGHT", 8, 0)
    local view = CreateScrollBoxListLinearView()
    view:SetElementExtent(ROW_HEIGHT)
    view:SetElementInitializer("Frame", initSetsRow)
    ScrollUtil.InitScrollBoxListWithScrollBar(setsScrollBox, scrollBar, view)
    ScrollUtil.AddManagedScrollBarVisibilityBehavior(setsScrollBox, scrollBar)

    setsEmptyText = page:CreateFontString(nil, "ARTWORK", "GameFontDisable")
    setsEmptyText:SetPoint("TOPLEFT", setsScrollBox, "TOPLEFT", 4, -8)
    setsEmptyText:SetText(L["You have no sets yet."])

    page:SetScript("OnShow", ns.RefreshSetsPage)
    return page
end

-- Var sakerna finns ändras när du lootar, säljer eller byter utrustning.
ns.RegisterEvent("BAG_UPDATE_DELAYED", ns.RefreshSetsPage)
ns.RegisterEvent("PLAYER_EQUIPMENT_CHANGED", ns.RefreshSetsPage)

---------------------------------------------------------------------------
-- Huvudsidan
---------------------------------------------------------------------------

-- En kryssruta kopplad till ns.db[key]. onChange körs när spelaren ändrar den.
local function addCheckbox(key, name, tooltip, onChange)
    local setting = Settings.RegisterAddOnSetting(category, addonName .. "_" .. key, key, ns.db,
        Settings.VarType.Boolean, name, ns.defaults[key])
    if onChange then
        setting:SetValueChangedCallback(onChange)
    end
    return Settings.CreateCheckbox(category, setting, tooltip)
end

ns.OnLoad(function()
    local layout
    category, layout = Settings.RegisterVerticalLayoutCategory(L["Tidy Pack"])
    layout = layout or SettingsPanel:GetLayout(category)

    -- Etiketterna hålls korta. Spelet kortar av en etikett som är längre än ungefär
    -- "Show item level and BoE on gear" med "...", så förklaringen står i tooltipen.
    layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(L["Junk"]))
    addCheckbox("suggestOnLoot", L["Ask to delete junk list loot"],
        L["When you loot an item on your junk list, Tidy Pack asks right away whether to delete it. Nothing is deleted until you press Delete."])
    addCheckbox("suggestWhenFull", L["Suggest a deletion when full"],
        L["When your bags are full and something can't be looted, a panel under the loot window suggests an item to delete: your junk list first, then your cheapest grey item if the new loot is worth more. Nothing is deleted until you press Delete."])
    addCheckbox("sellJunkButton", L["Show Sell Junk button"],
        L["At merchants, a button above your bags sells your grey items and your junk list, 12 at a time. Never starred or locked items."],
        function()
            if ns.UpdateJunkButton then
                ns.UpdateJunkButton()
            end
        end)
    layout:AddInitializer(CreateSettingsButtonInitializer(L["Junk List"], L["Open"], function()
        ns.OpenSettings("junk")
    end, L["See, add and remove the items on your junk list."], true))

    -- Raden visar om Questie finns. Utan Questie går kryssrutan inte att ändra.
    local hasQuestie = ns.HasQuestie ~= nil and ns.HasQuestie()
    layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(
        hasQuestie and L["Quests – Questie is installed"] or L["Quests – Questie is not installed"]))
    local questCheckbox = addCheckbox("questHints", L["Mark items for later quests"],
        L["Requires the addon Questie. Items needed for quests you can take now or within 5 levels get a yellow exclamation mark and a line in their tooltip."],
        function()
            if ns.QuestHintsChanged then
                ns.QuestHintsChanged()
            end
        end)
    questCheckbox:AddModifyPredicate(function()
        return ns.HasQuestie ~= nil and ns.HasQuestie()
    end)

    layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(L["Bag window"]))
    addCheckbox("itemLevelAndBoE", L["Show item level and BoE"],
        L["On uncommon or better weapons and armor."],
        function()
            if ns.Refresh then
                ns.Refresh()
            end
        end)

    junkPage = createJunkPage()
    junkCategory = Settings.RegisterCanvasLayoutSubcategory(category, junkPage, L["Junk List"])
    setsPage = createSetsPage()
    setsCategory = Settings.RegisterCanvasLayoutSubcategory(category, setsPage, L["Sets"])
    Settings.RegisterAddOnCategory(category)
end)

---------------------------------------------------------------------------
-- /tidypack och addonmenyn vid minikartan
---------------------------------------------------------------------------

SLASH_TIDYPACK1 = "/tidypack"
SlashCmdList.TIDYPACK = function()
    ns.OpenSettings()
end

-- Addonmenyn vid minikartan anropar den här (## AddonCompartmentFunc i TOC-filen).
function TidyPack_OnAddonCompartmentClick()
    ns.OpenSettings()
end
