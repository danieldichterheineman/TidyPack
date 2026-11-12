-- TidyPack – Sets.lua
-- Egna set: samlingar av saker under ett namn som spelaren själv väljer, t.ex. "Fishing"
-- eller "Tanking". Seten sparas per karaktär (TidyPackCharDB), eftersom karaktärer har olika
-- saker och yrken.
-- Så används de:
--   - Släpp en sak på kugghjulet i väskfönstret och välj "Add to Set" (Marks.lua).
--   - Fliken Sets ovanför väskfönstret listar seten. Klick tar på allt i setet som går att
--     ha på sig (SetsView.lua).
--   - I fliken Sets skapas set (New Set), saker släpps på ett set, och högerklick ändrar
--     namn och ikon, tar bort saker eller tar bort setet.
-- Saker i ett set är låsta hos en handlare, precis som saker i spelets utrustningsset, så
-- att de inte säljs av misstag (QuestLock.lua).
-- ⚠️ Spelet låter ingen byta rustning i strid, så ett set tas bara på utanför strid.

local _, ns = ...
local L = ns.L

local MAX_NAME_LENGTH = 32

-- Platser där två likadana sorters saker får plats. Ringar, smycken och enhandsvapen
-- fördelas på båda; resten tar spelet hand om själv.
local PAIRED_SLOTS = {
    INVTYPE_FINGER = { INVSLOT_FINGER1, INVSLOT_FINGER2 },
    INVTYPE_TRINKET = { INVSLOT_TRINKET1, INVSLOT_TRINKET2 },
    INVTYPE_WEAPON = { INVSLOT_MAINHAND, INVSLOT_OFFHAND },
}

local function sets()
    return ns.charDb and ns.charDb.sets or {}
end

-- Seten i den ordning de skapades:
-- { { name = "Fishing", icon = fileID, items = { itemID, ... } }, ... }
-- icon saknas i set som skapades före 2026-11-09 kväll; då används första sakens ikon.
function ns.GetSets()
    return sets()
end

local function findSet(name)
    for index, set in ipairs(sets()) do
        if set.name:lower() == name:lower() then
            return index, set
        end
    end
    return nil
end

local function cleanName(name)
    name = strtrim(name or "")
    if #name > MAX_NAME_LENGTH then
        name = name:sub(1, MAX_NAME_LENGTH)
    end
    return name
end

-- Ändringar i seten ritar om väskfönstret och fliken Sets.
local function changed()
    if ns.Refresh then
        ns.Refresh()
    end
end

-- Setets ikon: den valda, annars första sakens, annars ett frågetecken.
function ns.GetSetIcon(index)
    local set = sets()[index]
    if not set then
        return 134400
    end
    return set.icon or (set.items[1] and C_Item.GetItemIconByID(set.items[1])) or 134400
end

-- Skapar ett nytt set. Returnerar dess plats i listan, eller nil och en förklaring.
-- Fliken Sets visar fem fasta platser (samma som tangentbindningarna Equip set 1–5).
ns.MAX_SETS = 5

function ns.CreateSet(name, icon)
    if #sets() >= ns.MAX_SETS then
        return nil, L["You can have at most %d sets."]:format(ns.MAX_SETS)
    end
    name = cleanName(name)
    if name == "" then
        return nil, L["Give the set a name."]
    end
    if findSet(name) then
        return nil, L["You already have a set with that name."]
    end
    local list = sets()
    list[#list + 1] = { name = name, icon = icon, items = {} }
    changed()
    return #list
end

---------------------------------------------------------------------------
-- Makron: ett set på actionbaren
---------------------------------------------------------------------------
-- Actionbaren tar bara emot spelets egna saker, så ett set läggs dit som ett makro med
-- "/tidypack equip <namn>" (användarens önskan 2026-11-10). Makrot är kontots (inte karaktärens),
-- heter "TP <setets namn>" och har setets ikon. Funktionerna är spelets egna (CreateMacro,
-- EditMacro, PickupMacro, GetNumMacros och C_Macro.GetMacroName, som spelets makrofönster använder).
-- ⚠️ Makron kan inte skapas eller ändras i strid, och kontot har högst 120 makron.
local MACRO_PREFIX = "TP "
local MACRO_NAME_LENGTH = 16 -- så långt kan ett makros namn vara i spelets makrofönster

local function macroName(setName)
    return (MACRO_PREFIX .. setName):sub(1, MACRO_NAME_LENGTH)
end

local function macroBody(setName)
    return "/tidypack equip " .. setName
end

-- Platsen för kontots makro med det här namnet, eller nil.
local function findMacro(name)
    local accountCount = GetNumMacros()
    for macroIndex = 1, accountCount do
        if C_Macro.GetMacroName(macroIndex) == name then
            return macroIndex
        end
    end
    return nil
end

-- Lägger setets makro på markören, så att det kan släppas på actionbaren. Skapar makrot första gången.
function ns.PickupSetMacro(index)
    local set = sets()[index]
    if not set then
        return
    end
    if InCombatLockdown() then
        ns.Print(L["Sets can't be put on an action bar in combat."])
        return
    end
    local name = macroName(set.name)
    local macroIndex = findMacro(name)
    if macroIndex then
        macroIndex = EditMacro(macroIndex, name, ns.GetSetIcon(index), macroBody(set.name))
    else
        if GetNumMacros() >= Constants.MacroConsts.MAX_ACCOUNT_MACROS then
            ns.Print(L["You have no free macro slots. Delete a macro (Esc → Macros) and try again."])
            return
        end
        macroIndex = CreateMacro(name, ns.GetSetIcon(index), macroBody(set.name), false)
    end
    if macroIndex then
        PickupMacro(macroIndex)
    end
end

-- Byter namn, ikon och text på ett sets makro när setet ändras (om makrot finns).
local function updateMacro(oldName, set, index)
    if InCombatLockdown() then
        return
    end
    local macroIndex = findMacro(macroName(oldName))
    if macroIndex then
        EditMacro(macroIndex, macroName(set.name), ns.GetSetIcon(index), macroBody(set.name))
    end
end

-- /tidypack equip <namn> (från makrot): tar på setet med det namnet.
function ns.EquipSetByName(name)
    local index = findSet(strtrim(name or ""))
    if index then
        ns.EquipSet(index)
    else
        ns.Print(L["You have no set called %s."]:format(name or ""))
    end
end

-- Byter namn och ikon på ett set.
function ns.EditSet(index, name, icon)
    local set = sets()[index]
    name = cleanName(name)
    if not set then
        return nil
    end
    if name == "" then
        return nil, L["Give the set a name."]
    end
    local other = findSet(name)
    if other and other ~= index then
        return nil, L["You already have a set with that name."]
    end
    local oldName = set.name
    set.name = name
    if icon then
        set.icon = icon
    end
    updateMacro(oldName, set, index)
    changed()
    return index
end

function ns.DeleteSet(index)
    if sets()[index] then
        table.remove(sets(), index)
        changed()
    end
end

function ns.IsInSet(index, itemID)
    local set = sets()[index]
    if not set then
        return false
    end
    for _, id in ipairs(set.items) do
        if id == itemID then
            return true
        end
    end
    return false
end

-- Lägger till eller tar bort en sak ur ett set.
function ns.SetInSet(index, itemID, inSet)
    local set = sets()[index]
    if not set or not itemID then
        return
    end
    for position, id in ipairs(set.items) do
        if id == itemID then
            if not inSet then
                table.remove(set.items, position)
                changed()
            end
            return
        end
    end
    if inSet then
        set.items[#set.items + 1] = itemID
        changed()
    end
end

-- Platser som "Save What I'm Wearing" inte rör: skjorta, tabard, väskor och yrkesutrustning.
-- Sådant som spelaren själv lagt i setet ligger kvar.
local KEEP_LOCATIONS = {
    INVTYPE_BODY = true,
    INVTYPE_TABARD = true,
    INVTYPE_BAG = true,
    INVTYPE_QUIVER = true,
    INVTYPE_PROFESSION_TOOL = true,
    INVTYPE_PROFESSION_GEAR = true,
    INVTYPE_NON_EQUIP_IGNORE = true,
}

-- Är saken utrustning som byts ut av "Save What I'm Wearing"?
local function isReplacedGear(itemID)
    local equipLocation = select(4, C_Item.GetItemInfoInstant(itemID))
    return equipLocation ~= nil and equipLocation ~= "" and not KEEP_LOCATIONS[equipLocation]
end

-- Gör setets utrustning till det du har på dig just nu, utom skjorta och tabard. Utrustning
-- som du inte längre har på dig tas bort. Annat i setet (t.ex. Hearthstone) ligger kvar.
-- Returnerar hur många saker som kom till och hur många som togs bort.
function ns.SaveWornToSet(index)
    local set = sets()[index]
    if not set then
        return 0, 0
    end
    local worn, wornSet = {}, {}
    for slot = INVSLOT_FIRST_EQUIPPED, INVSLOT_LAST_EQUIPPED do
        local itemID = slot ~= INVSLOT_BODY and slot ~= INVSLOT_TABARD and GetInventoryItemID("player", slot)
        if itemID and not wornSet[itemID] then
            worn[#worn + 1] = itemID
            wornSet[itemID] = true
        end
    end
    -- Det du har på dig först, i platsernas ordning, sedan det övriga som ligger kvar.
    local items, before, removed = {}, {}, 0
    for _, itemID in ipairs(worn) do
        items[#items + 1] = itemID
    end
    for _, itemID in ipairs(set.items) do
        before[itemID] = true
        if not wornSet[itemID] then
            if isReplacedGear(itemID) then
                removed = removed + 1
            else
                items[#items + 1] = itemID
            end
        end
    end
    local added = 0
    for _, itemID in ipairs(worn) do
        if not before[itemID] then
            added = added + 1
        end
    end
    if added == 0 and removed == 0 then
        ns.Print(L["%s already matches what you wear."]:format(set.name))
        return 0, 0
    end
    set.items = items
    changed()
    ns.Print(L["%s now has what you wear: %d added, %d removed."]:format(set.name, added, removed))
    return added, removed
end

-- Namnen på seten som en sak ingår i, eller nil.
function ns.GetSetNamesForItem(itemID)
    local names
    for _, set in ipairs(sets()) do
        for _, id in ipairs(set.items) do
            if id == itemID then
                names = names or {}
                names[#names + 1] = set.name
                break
            end
        end
    end
    return names
end

function ns.IsInAnySet(itemID)
    return ns.GetSetNamesForItem(itemID) ~= nil
end

-- Var en sak finns hos den här karaktären: "equipped", "bags" eller "missing".
function ns.GetItemState(itemID)
    if C_Item.IsEquippedItem(itemID) then
        return "equipped"
    end
    if C_Item.GetItemCount(itemID) > 0 then
        return "bags"
    end
    return "missing"
end

-- Hur det står till med ett set: antal saker, saker som saknas och om allt som går att ha
-- på sig redan sitter på.
function ns.GetSetStatus(index)
    local set = sets()[index]
    local missing, wearable, worn = {}, 0, 0
    if not set then
        return 0, missing, false
    end
    for _, itemID in ipairs(set.items) do
        local state = ns.GetItemState(itemID)
        if state == "missing" then
            missing[#missing + 1] = itemID
        end
        if C_Item.IsEquippableItem(itemID) then
            wearable = wearable + 1
            if state == "equipped" then
                worn = worn + 1
            end
        end
    end
    return #set.items, missing, wearable > 0 and worn == wearable
end

-- Platsen en sak sitter på just nu, om den sitter på en av de angivna platserna.
local function wornSlot(itemID, slots)
    for _, slot in ipairs(slots) do
        if GetInventoryItemID("player", slot) == itemID then
            return slot
        end
    end
    return nil
end

-- Tar på allt i setet som går att ha på sig och som ligger i väskorna.
function ns.EquipSet(index)
    local set = sets()[index]
    if not set then
        return
    end
    if InCombatLockdown() then
        ns.Print(L["Sets can't be put on in combat."])
        return
    end
    ClearCursor()
    -- Platser som setets egna saker redan använder, så att två ringar inte hamnar på samma.
    local taken = {}
    for _, itemID in ipairs(set.items) do
        local equipLocation = select(4, C_Item.GetItemInfoInstant(itemID))
        local slots = PAIRED_SLOTS[equipLocation]
        if slots then
            local slot = wornSlot(itemID, slots)
            if slot then
                taken[slot] = true
            end
        end
    end
    local equipped = 0
    for _, itemID in ipairs(set.items) do
        if C_Item.IsEquippableItem(itemID) and ns.GetItemState(itemID) == "bags" then
            local equipLocation = select(4, C_Item.GetItemInfoInstant(itemID))
            local slots = PAIRED_SLOTS[equipLocation]
            local target
            if slots then
                for _, slot in ipairs(slots) do
                    if not taken[slot] then
                        target = slot
                        break
                    end
                end
                if target then
                    taken[target] = true
                end
            end
            C_Item.EquipItemByName(itemID, target)
            equipped = equipped + 1
        end
    end
    local _, missing = ns.GetSetStatus(index)
    if #missing > 0 then
        ns.Print(L["%s: %d items are missing."]:format(set.name, #missing))
    elseif equipped == 0 and not select(3, ns.GetSetStatus(index)) then
        ns.Print(L["%s has nothing you can put on."]:format(set.name))
    end
end

---------------------------------------------------------------------------
-- Rutan för namn och frågor
---------------------------------------------------------------------------
-- Spelets egna frågerutor (StaticPopup) används inte, eftersom ett addon som visar sin
-- fråga i dem kan smitta spelets egna frågor (taint). Rutan är en egen ram byggd av
-- spelets mallar, samma som Tidy Packs panel för fulla väskor.

local dialog

local function createDialog()
    dialog = CreateFrame("Frame", "TidyPackSetDialog", UIParent, "DefaultPanelFlatTemplate")
    dialog:SetSize(320, 130)
    dialog:SetPoint("TOP", UIParent, "TOP", 0, -135)
    dialog:SetFrameStrata("DIALOG")
    dialog:SetToplevel(true)
    dialog:EnableMouse(true)
    dialog:Hide()
    dialog:SetTitle(L["Tidy Pack"])

    dialog.text = dialog:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    dialog.text:SetPoint("TOPLEFT", 16, -34)
    dialog.text:SetPoint("TOPRIGHT", -16, -34)
    dialog.text:SetJustifyH("CENTER")

    dialog.input = CreateFrame("EditBox", nil, dialog, "InputBoxTemplate")
    dialog.input:SetSize(220, 22)
    dialog.input:SetPoint("TOP", dialog.text, "BOTTOM", 0, -8)
    dialog.input:SetAutoFocus(false)
    dialog.input:SetMaxLetters(MAX_NAME_LENGTH)

    dialog.accept = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
    dialog.accept:SetSize(100, 22)
    dialog.accept:SetPoint("BOTTOMRIGHT", dialog, "BOTTOM", -4, 12)
    dialog.cancel = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
    dialog.cancel:SetSize(100, 22)
    dialog.cancel:SetPoint("BOTTOMLEFT", dialog, "BOTTOM", 4, 12)
    dialog.cancel:SetText(L["Cancel"])

    local function accept()
        local onAccept = dialog.onAccept
        local ok, problem = onAccept(dialog.input:GetText())
        if ok == false then
            dialog.text:SetText(problem or "")
            dialog.text:SetTextColor(RED_FONT_COLOR:GetRGB())
            return
        end
        dialog:Hide()
    end
    dialog.accept:SetScript("OnClick", accept)
    dialog.input:SetScript("OnEnterPressed", accept)
    dialog.cancel:SetScript("OnClick", function()
        dialog:Hide()
    end)
    dialog.input:SetScript("OnEscapePressed", function()
        dialog:Hide()
    end)
    dialog:SetScript("OnHide", function()
        dialog.input:ClearFocus()
    end)
end

-- Visar frågan (används för att ta bort ett set). withInput = true ger en textruta med defaultText. onAccept(text) körs vid
-- klick på knappen och kan returnera false och en förklaring för att hålla rutan öppen.
local function showDialog(text, acceptLabel, withInput, defaultText, onAccept)
    if not dialog then
        createDialog()
    end
    dialog.text:SetText(text)
    dialog.text:SetTextColor(HIGHLIGHT_FONT_COLOR:GetRGB())
    dialog.accept:SetText(acceptLabel)
    dialog.onAccept = onAccept
    dialog.input:SetShown(withInput)
    dialog.input:SetText(defaultText or "")
    dialog:SetHeight(withInput and 130 or 104)
    dialog:Show()
    if withInput then
        dialog.input:SetFocus()
        dialog.input:HighlightText()
    end
end
-- Samma ruta används för namnet på en egen grupp (Groups.lua).
ns.ShowDialog = showDialog

---------------------------------------------------------------------------
-- Rutan för namn och ikon
---------------------------------------------------------------------------
-- Spelets egen ruta för namn och ikon (IconSelectorPopupFrameTemplate), samma som
-- Forever använder när man sparar ett utrustningsset (GearManagerPopupFrameMixin i
-- Camelot/PaperDollFrame.lua): namn överst, vald ikon till höger, alla ikoner i ett
-- rutnät, och Okay/Cancel längst ned. Utrustningens ikoner kommer först i rutnätet.

local iconPopup

local function createIconPopup()
    iconPopup = CreateFrame("Frame", "TidyPackSetIconPopup", UIParent, "IconSelectorPopupFrameTemplate")
    iconPopup:Hide()
    iconPopup:ClearAllPoints()
    iconPopup:SetPoint("TOP", UIParent, "TOP", 0, -100)
    iconPopup:SetFrameStrata("DIALOG")
    iconPopup:SetToplevel(true)
    iconPopup:EnableMouse(true)
    iconPopup.BorderBox.EditBoxHeaderText:SetText(L["Set name:"])
    iconPopup.BorderBox.IconSelectorEditBox:SetMaxLetters(MAX_NAME_LENGTH)
    -- Spelets mall lägger ikonlistan i lagret HIGH, och rutan här ligger i DIALOG (ovanför väskan).
    -- Då ritades ikonerna bakom rutans bakgrund och listan såg tom ut (skärmbild 2026-11-10).
    iconPopup.IconSelector:SetFrameStrata("DIALOG")
    iconPopup.IconSelector:SetFrameLevel(iconPopup:GetFrameLevel() + 10)

    -- Spelets mall anropar de här när rutan visas, döljs och när Okay trycks.
    function iconPopup:OnShow()
        IconSelectorPopupFrameTemplateMixin.OnShow(self)
        self.BorderBox.IconSelectorEditBox:SetFocus()
        PlaySound(SOUNDKIT.IG_CHARACTER_INFO_OPEN)
        self.iconDataProvider = CreateAndInitFromMixin(IconDataProviderMixin, IconDataProviderExtraType.Equipment)
        self:SetIconFilter(IconSelectorPopupFrameIconFilterTypes.All)
        self:Update()
        self.BorderBox.IconSelectorEditBox:OnTextChanged()
        local area = self.BorderBox.SelectedIconArea
        self.IconSelector:SetSelectedCallback(function(_, icon)
            area.SelectedIconButton:SetIconTexture(icon)
            area.SelectedIconText.SelectedIconDescription:SetText(ICON_SELECTION_CLICK)
            area.SelectedIconText.SelectedIconDescription:SetFontObject(GameFontHighlightSmall)
        end)
    end

    function iconPopup:OnHide()
        IconSelectorPopupFrameTemplateMixin.OnHide(self)
        if self.iconDataProvider then
            self.iconDataProvider:Release()
            self.iconDataProvider = nil
        end
    end

    function iconPopup:Update()
        local box = self.BorderBox
        box.IconSelectorEditBox:SetText(self.startName or "")
        box.IconSelectorEditBox:HighlightText()
        local index = self.startIcon and self:GetIndexOfIcon(self.startIcon) or 1
        self.IconSelector:SetSelectedIndex(index)
        box.SelectedIconArea.SelectedIconButton:SetIconTexture(self.startIcon or self:GetIconByIndex(1))
        self.IconSelector:SetSelectionsDataProvider(GenerateClosure(self.GetIconByIndex, self),
            GenerateClosure(self.GetNumIcons, self))
        self.IconSelector:ScrollToSelectedIndex()
        self:SetSelectedIconText()
    end

    function iconPopup:OkayButton_OnClick()
        local box = self.BorderBox
        local ok, problem = self.onAccept(box.IconSelectorEditBox:GetText(),
            box.SelectedIconArea.SelectedIconButton:GetIconTexture())
        if not ok then
            -- Som spelets egen ruta: felet visas mitt på skärmen och rutan står kvar.
            UIErrorsFrame:AddMessage(problem or "", 1.0, 0.1, 0.1, 1.0)
            return
        end
        IconSelectorPopupFrameTemplateMixin.OkayButton_OnClick(self)
    end
end

local function showIconPopup(name, icon, onAccept)
    if not iconPopup then
        createIconPopup()
    end
    iconPopup:Hide()
    iconPopup.startName, iconPopup.startIcon, iconPopup.onAccept = name, icon, onAccept
    iconPopup:Show()
    if InputUtil.IsGamepadUIEnabled() then
        iconPopup:GiveGamepadFocus()
    end
end

-- Ett nytt set: namn och ikon. Saken (itemID) läggs i setet, och dess ikon är förvald.
function ns.AskNewSet(itemID)
    showIconPopup("", itemID and C_Item.GetItemIconByID(itemID) or nil, function(name, icon)
        local index, problem = ns.CreateSet(name, icon)
        if not index then
            return false, problem
        end
        if itemID then
            ns.SetInSet(index, itemID, true)
        end
        return true
    end)
end

-- Ändra namn och ikon på ett set.
function ns.AskEditSet(index)
    local set = sets()[index]
    if not set then
        return
    end
    showIconPopup(set.name, ns.GetSetIcon(index), function(name, icon)
        return ns.EditSet(index, name, icon)
    end)
end

function ns.AskDeleteSet(index)
    local set = sets()[index]
    if not set then
        return
    end
    showDialog(L["Delete the set %s? The items stay in your bags."]:format(set.name), L["Delete"], false, nil,
        function()
            ns.DeleteSet(index)
            return true
        end)
end

---------------------------------------------------------------------------
-- Tooltip
---------------------------------------------------------------------------

-- En rad i sakens tooltip med seten den ingår i.
TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
    -- Inställningen "Tidy Pack lines in tooltips" (kugghjulets Show ▸).
    if not data or type(data.id) ~= "number" or (ns.db and ns.db.tooltipLines == false) then
        return
    end
    local names = ns.GetSetNamesForItem(data.id)
    if names then
        tooltip:AddLine(L["Tidy Pack set: %s"]:format(table.concat(names, ", ")), NORMAL_FONT_COLOR:GetRGB())
    end
end)
