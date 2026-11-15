-- TidyPack – Groups.lua
-- Own groups: groups with a name the player creates, e.g. "Potions". At most MAX_GROUPS,
-- saved per account in TidyPackDB.groups (like favorites and the junk list).
-- What goes into a group is decided two ways:
--   - single items (itemID), through the gear menu "Add to Group"
--   - whole kinds (class and subclass, e.g. all potions), through "Add All ... Items to Group"
-- An item or kind is in at most one group, so it is always clear where it belongs.
-- Comes before the game's normal kinds (Categories.lua), but after Favorites, New, Quest Items and
-- Junk. Among the own groups a single item comes before a kind rule, and then the group
-- highest up. The groups come after Favorites and "Add to bag" (Layout.lua reads
-- ns.groupOrder, which RebuildGroupOrder rebuilds).
-- The groups are managed in the bags (Panels.lua), which the gear menu opens.
-- The game's dialogs (StaticPopup) aren't used; the name is asked in Tidy Pack's own dialog
-- (ns.ShowDialog below).

local _, ns = ...
local L = ns.L

local MAX_GROUPS = 8
ns.MAX_GROUPS = MAX_GROUPS

-- { { id = 1, name = "Potions", items = { [itemID] = true }, types = { ["0:1"] = true } }, ... }
-- id never changes (it gives the group's key in Layout.lua), while name and order can change.
local function groups()
    return ns.db and ns.db.groups or {}
end

function ns.GetCustomGroups()
    return groups()
end

local function keyOf(group)
    return "custom" .. group.id
end

-- A kind's key: "class:subclass", e.g. "0:1" for potions.
local function typeKey(classID, subClassID)
    return classID .. ":" .. subClassID
end

function ns.ParseTypeKey(key)
    local classID, subClassID = key:match("^(%d+):(%d+)$")
    return tonumber(classID), tonumber(subClassID)
end

-- The kind's name in the game (in the game's language), e.g. "Potion": the subclass if it has a
-- name, otherwise the class.
function ns.GetTypeName(classID, subClassID)
    local name = C_Item.GetItemSubClassInfo(classID, subClassID)
    if not name or name == "" then
        name = C_Item.GetItemClassInfo(classID)
    end
    return name or "?"
end

---------------------------------------------------------------------------
-- Order and headings
---------------------------------------------------------------------------

local customKeys = {} -- the keys put into ns.groupNames, so they can be removed again

-- Rebuilds ns.groupOrder (the game's groups with the own ones after "Empty", that is "Add to bag")
-- and the headings. Runs when the addon has loaded and after every change.
function ns.RebuildGroupOrder()
    for key in pairs(customKeys) do
        ns.groupNames[key] = nil
    end
    wipe(customKeys)
    local order = {}
    for _, key in ipairs(ns.baseGroupOrder) do
        -- The crafting materials per subclass, your professions first, before other Trade Goods (Categories.lua).
        if key == "TradeGoods" and ns.GetTradeGroupKeys then
            for _, tradeKey in ipairs(ns.GetTradeGroupKeys()) do
                order[#order + 1] = tradeKey
            end
        end
        order[#order + 1] = key
        if key == "Empty" then
            for _, group in ipairs(groups()) do
                local groupKey = keyOf(group)
                order[#order + 1] = groupKey
                ns.groupNames[groupKey] = group.name
                customKeys[groupKey] = true
            end
        end
    end
    ns.groupOrder = order
end

-- Every change comes here: rebuild the order, lay out the bags and redraw the panel in the bags (Panels.lua).
local function changed()
    ns.RebuildGroupOrder()
    if ns.Refresh then
        ns.Refresh()
    end
    if ns.RefreshGroupsPage then
        ns.RefreshGroupsPage()
    end
end

---------------------------------------------------------------------------
-- The groups
---------------------------------------------------------------------------

-- The name without characters the game reads as formatting (|), and without spaces at the edges.
local function cleanName(name)
    name = (name or ""):gsub("|", "")
    return strtrim(name)
end

local function findByName(name, exceptIndex)
    local lower = name:lower()
    for index, group in ipairs(groups()) do
        if index ~= exceptIndex and group.name:lower() == lower then
            return index
        end
    end
    return nil
end

-- Creates a group. Returns its index in the list, or nil and an explanation.
function ns.CreateGroup(name)
    name = cleanName(name)
    if name == "" then
        return nil, L["Give the group a name."]
    end
    if #groups() >= MAX_GROUPS then
        return nil, L["You can have at most %d groups."]:format(MAX_GROUPS)
    end
    if findByName(name) then
        return nil, L["You already have a group with that name."]
    end
    local id = ns.db.nextGroupID
    ns.db.nextGroupID = id + 1
    local list = groups()
    list[#list + 1] = { id = id, name = name, items = {}, types = {} }
    changed()
    return #list
end

-- Renames. Returns true, or false and an explanation.
function ns.RenameGroup(index, name)
    local group = groups()[index]
    if not group then
        return false
    end
    name = cleanName(name)
    if name == "" then
        return false, L["Give the group a name."]
    end
    if findByName(name, index) then
        return false, L["You already have a group with that name."]
    end
    group.name = name
    changed()
    return true
end

-- Removes a group. The items go back to their normal groups.
function ns.DeleteGroup(index)
    if groups()[index] then
        table.remove(groups(), index)
        changed()
    end
end

-- Moves a group one step up (delta = -1) or down (1). Returns the new index.
function ns.MoveGroup(index, delta)
    local list = groups()
    local target = index + delta
    if not list[index] or not list[target] then
        return index
    end
    list[index], list[target] = list[target], list[index]
    changed()
    return target
end

---------------------------------------------------------------------------
-- What is included
---------------------------------------------------------------------------

function ns.IsItemInGroup(index, itemID)
    local group = groups()[index]
    return group ~= nil and group.items[itemID] == true
end

-- Puts an item in a group (inGroup = true) or removes it. An item is in at most one
-- group, so it is first removed from the others.
function ns.SetItemInGroup(index, itemID, inGroup)
    local group = groups()[index]
    if not group or not itemID then
        return
    end
    if inGroup then
        for _, other in ipairs(groups()) do
            other.items[itemID] = nil
        end
        group.items[itemID] = true
    else
        group.items[itemID] = nil
    end
    changed()
end

function ns.IsTypeInGroup(index, classID, subClassID)
    local group = groups()[index]
    return group ~= nil and group.types[typeKey(classID, subClassID)] == true
end

-- The same for a whole kind (all items with the same class and subclass).
function ns.SetTypeInGroup(index, classID, subClassID, inGroup)
    local group = groups()[index]
    if not group or not classID or not subClassID then
        return
    end
    local key = typeKey(classID, subClassID)
    if inGroup then
        for _, other in ipairs(groups()) do
            other.types[key] = nil
        end
        group.types[key] = true
    else
        group.types[key] = nil
    end
    changed()
end

-- The group's key (for ns.groupOrder) for an item, or nil if no own group wants it.
-- Categories.lua asks once per item. classID and subClassID come from
-- C_Item.GetItemInfoInstant.
function ns.GetCustomGroupFor(itemID, classID, subClassID)
    local list = groups()
    if #list == 0 then
        return nil
    end
    for _, group in ipairs(list) do
        if group.items[itemID] then
            return keyOf(group)
        end
    end
    if classID and subClassID then
        local key = typeKey(classID, subClassID)
        for _, group in ipairs(list) do
            if group.types[key] then
                return keyOf(group)
            end
        end
    end
    return nil
end

---------------------------------------------------------------------------
-- Dialogs
---------------------------------------------------------------------------
-- The game's own dialogs (StaticPopup) aren't used, because an addon that shows its
-- question in them can taint the game's own questions. The dialog is an own frame built from
-- the game's templates, the same as Tidy Pack's panel for full bags.

local MAX_NAME_LENGTH = 20
local dialog

local function createDialog()
    dialog = CreateFrame("Frame", "TidyPackDialog", UIParent, "DefaultPanelFlatTemplate")
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

-- Shows the question. withInput = true gives an input box with defaultText. onAccept(text) runs on
-- a click on the button and can return false and an explanation to keep the dialog open.
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
ns.ShowDialog = showDialog

-- Creates a group after asking for the name. onCreated(index) runs afterwards.
function ns.AskNewGroup(onCreated)
    ns.ShowDialog(L["Name the new group:"], L["Create"], true, "", function(text)
        local index, problem = ns.CreateGroup(text)
        if not index then
            return false, problem
        end
        if onCreated then
            onCreated(index)
        end
        return true
    end)
end

function ns.AskRenameGroup(index)
    local group = groups()[index]
    if not group then
        return
    end
    ns.ShowDialog(L["New name for the group:"], L["Rename"], true, group.name, function(text)
        local ok, problem = ns.RenameGroup(index, text)
        if not ok then
            return false, problem
        end
        return true
    end)
end

function ns.AskDeleteGroup(index)
    local group = groups()[index]
    if not group then
        return
    end
    ns.ShowDialog(L["Delete the group %s? The items stay in your bags."]:format(group.name), L["Delete"], false, nil,
        function()
            ns.DeleteGroup(index)
            return true
        end)
end

---------------------------------------------------------------------------
-- The gear menu (Marks.lua calls it with an item on the cursor)
---------------------------------------------------------------------------

-- A submenu with a checkbox per group and "New Group...". isSelected(index) and
-- setSelected(index, which) tell "this item" from "the whole kind" apart.
local function addGroupChoices(parent, isSelected, setSelected)
    local list = groups()
    for index, group in ipairs(list) do
        parent:CreateCheckbox(group.name, function()
            return isSelected(index)
        end, function()
            ClearCursor() -- the item goes back to its place
            setSelected(index, not isSelected(index))
            return MenuResponse.CloseAll
        end)
    end
    if #list < MAX_GROUPS then
        parent:CreateButton(L["New Group..."], function()
            ClearCursor()
            ns.AskNewGroup(function(index)
                setSelected(index, true)
            end)
        end)
    end
end

function ns.AddGroupMenus(rootDescription, itemID)
    local _, _, _, _, _, classID, subClassID = C_Item.GetItemInfoInstant(itemID)

    local single = rootDescription:CreateButton(L["Add to Group"])
    -- Favorites and junk come before the own groups.
    if ns.IsFavorite(itemID) then
        single:CreateTitle(L["It stays in %s for now."]:format(ns.groupNames.Favorites))
    elseif ns.IsJunkMarked(itemID) then
        single:CreateTitle(L["It stays in %s for now."]:format(ns.groupNames.Junk))
    end
    addGroupChoices(single, function(index)
        return ns.IsItemInGroup(index, itemID)
    end, function(index, inGroup)
        ns.SetItemInGroup(index, itemID, inGroup)
    end)

    if classID and subClassID then
        local typeName = ns.GetTypeName(classID, subClassID)
        local byType = rootDescription:CreateButton(L["Add All \"%s\" Items to Group"]:format(typeName))
        addGroupChoices(byType, function(index)
            return ns.IsTypeInGroup(index, classID, subClassID)
        end, function(index, inGroup)
            ns.SetTypeInGroup(index, classID, subClassID, inGroup)
        end)
    end
end

---------------------------------------------------------------------------
-- Tooltip and start
---------------------------------------------------------------------------

-- A line in the item's tooltip with the own group, if the item is in one.
TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
    -- The option "Group line" (the gear menu's Show ▸ In tooltips).
    if not data or type(data.id) ~= "number" or ns.db == nil or ns.db.tooltipLines == false then
        return
    end
    if ns.IsFavorite(data.id) or ns.IsJunkMarked(data.id) then
        return -- stays in Favorites or Junk
    end
    local _, _, _, _, _, classID, subClassID = C_Item.GetItemInfoInstant(data.id)
    local key = ns.GetCustomGroupFor(data.id, classID, subClassID)
    local name = key and ns.groupNames[key]
    if name then
        tooltip:AddLine(L["Tidy Pack group: %s"]:format(name), NORMAL_FONT_COLOR:GetRGB())
    end
end)

ns.OnLoad(function()
    ns.RebuildGroupOrder()
end)

-- The professions are known only after login and change when you learn or forget a profession.
local function professionsChanged()
    ns.RebuildGroupOrder()
    if ns.Refresh then
        ns.Refresh()
    end
end
ns.RegisterEvent("PLAYER_LOGIN", professionsChanged)
ns.RegisterEvent("SKILL_LINES_CHANGED", professionsChanged)
