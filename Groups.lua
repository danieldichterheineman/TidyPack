-- TidyPack – Groups.lua
-- Egna grupper: grupper med ett namn som spelaren skapar själv, t.ex. "Potions". Högst
-- MAX_GROUPS stycken, sparade per konto i TidyPackDB.groups (som favoriter och skräplistan).
-- Vad som hamnar i en grupp bestäms på två sätt:
--   - enskilda saker (itemID), via kugghjulets meny "Add to Group"
--   - hela typer (klass och undertyp, t.ex. alla drycker), via "Add all ... items to Group"
-- En sak eller typ ligger i högst en grupp, så att det alltid är tydligt var den hör hemma.
-- Går före spelets vanliga typer (Categories.lua), men efter Favorites, New, Quest Items och
-- Junk. Bland de egna grupperna går en enskild sak före en typregel, och därefter den grupp
-- som står högst upp. Grupperna står efter Favorites och "Add to bag" (Layout.lua läser
-- ns.groupOrder, som RebuildGroupOrder bygger om).
-- Inställningssidan med hantering av grupperna ligger i GroupsPage.lua.
-- Spelets frågerutor (StaticPopup) används inte; namnet frågas i Tidy Packs egen ruta
-- (ns.ShowDialog i Sets.lua).

local _, ns = ...
local L = ns.L

local MAX_GROUPS = 8
ns.MAX_GROUPS = MAX_GROUPS

-- { { id = 1, name = "Potions", items = { [itemID] = true }, types = { ["0:1"] = true } }, ... }
-- id ändras aldrig (den ger gruppens nyckel i Layout.lua), medan namn och ordning kan ändras.
local function groups()
    return ns.db and ns.db.groups or {}
end

function ns.GetCustomGroups()
    return groups()
end

local function keyOf(group)
    return "custom" .. group.id
end

-- En typs nyckel: "klass:undertyp", t.ex. "0:1" för drycker.
local function typeKey(classID, subClassID)
    return classID .. ":" .. subClassID
end

function ns.ParseTypeKey(key)
    local classID, subClassID = key:match("^(%d+):(%d+)$")
    return tonumber(classID), tonumber(subClassID)
end

-- Typens namn i spelet (på spelets språk), t.ex. "Potion": undertypen om den har ett namn,
-- annars klassen.
function ns.GetTypeName(classID, subClassID)
    local name = C_Item.GetItemSubClassInfo(classID, subClassID)
    if not name or name == "" then
        name = C_Item.GetItemClassInfo(classID)
    end
    return name or "?"
end

---------------------------------------------------------------------------
-- Ordning och rubriker
---------------------------------------------------------------------------

local customKeys = {} -- nycklarna som lagts i ns.groupNames, så att de kan tas bort igen

-- Bygger om ns.groupOrder (spelets grupper med de egna efter "Empty", alltså "Add to bag")
-- och rubrikerna. Körs när addonet laddats och efter varje ändring.
function ns.RebuildGroupOrder()
    for key in pairs(customKeys) do
        ns.groupNames[key] = nil
    end
    wipe(customKeys)
    local order = {}
    for _, key in ipairs(ns.baseGroupOrder) do
        -- Råvarorna per undertyp, dina yrken först, före övriga Trade Goods (Categories.lua).
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

-- Alla ändringar går hit: bygg om ordningen, lägg ut väskan och rita om inställningssidan.
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
-- Grupperna
---------------------------------------------------------------------------

-- Namnet utan tecken som spelet läser som formatering (|), och utan blanksteg i kanterna.
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

-- Skapar en grupp. Returnerar dess plats i listan, eller nil och en förklaring.
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

-- Byter namn. Returnerar sant, eller falskt och en förklaring.
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

-- Tar bort en grupp. Sakerna går tillbaka till sina vanliga grupper.
function ns.DeleteGroup(index)
    if groups()[index] then
        table.remove(groups(), index)
        changed()
    end
end

-- Flyttar en grupp ett steg upp (delta = -1) eller ned (1). Returnerar nya platsen.
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
-- Vad som ingår
---------------------------------------------------------------------------

function ns.IsItemInGroup(index, itemID)
    local group = groups()[index]
    return group ~= nil and group.items[itemID] == true
end

-- Lägger en sak i en grupp (inGroup = true) eller tar bort den. En sak ligger i högst en
-- grupp, så den tas först bort ur de andra.
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

-- Samma för en hel typ (alla saker med samma klass och undertyp).
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

-- Gruppens nyckel (för ns.groupOrder) för en sak, eller nil om ingen egen grupp vill ha den.
-- Categories.lua frågar en gång per sak. classID och subClassID kommer från
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
-- Frågor
---------------------------------------------------------------------------

-- Skapar en grupp efter att ha frågat efter namnet. onCreated(index) körs efteråt.
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
-- Kugghjulets meny (Marks.lua anropar den med en sak på markören)
---------------------------------------------------------------------------

-- En undermeny med en bockruta per grupp och "New Group...". isSelected(index) och
-- setSelected(index, vilken) skiljer "den här saken" från "hela typen".
local function addGroupChoices(parent, isSelected, setSelected)
    local list = groups()
    for index, group in ipairs(list) do
        parent:CreateCheckbox(group.name, function()
            return isSelected(index)
        end, function()
            ClearCursor() -- saken går tillbaka till sin plats
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
    -- Favoriter och skräp går före de egna grupperna.
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
        local byType = rootDescription:CreateButton(L["Add all \"%s\" items to Group"]:format(typeName))
        addGroupChoices(byType, function(index)
            return ns.IsTypeInGroup(index, classID, subClassID)
        end, function(index, inGroup)
            ns.SetTypeInGroup(index, classID, subClassID, inGroup)
        end)
    end
end

---------------------------------------------------------------------------
-- Tooltip och start
---------------------------------------------------------------------------

-- En rad i sakens tooltip med den egna gruppen, om saken ligger i en.
TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
    if not data or type(data.id) ~= "number" or ns.db == nil then
        return
    end
    if ns.IsFavorite(data.id) or ns.IsJunkMarked(data.id) then
        return -- ligger kvar i Favorites eller Junk
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

-- Yrkena är kända först efter inloggningen och ändras när du lär dig eller glömmer ett yrke.
local function professionsChanged()
    ns.RebuildGroupOrder()
    if ns.Refresh then
        ns.Refresh()
    end
end
ns.RegisterEvent("PLAYER_LOGIN", professionsChanged)
ns.RegisterEvent("SKILL_LINES_CHANGED", professionsChanged)
