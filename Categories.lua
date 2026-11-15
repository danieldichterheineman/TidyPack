-- TidyPack – Categories.lua
-- Decides which group an item belongs to, and in which order the groups and the items
-- come. The order is fixed – there are no options for it.

local _, ns = ...
local L = ns.L

-- The groups, in the order they show. Groups without items don't show. Empty (the slot where you
-- drop an item to put it in the bags) comes second, so it shares the top line with Favorites
-- instead of taking its own line at the bottom.
ns.baseGroupOrder = {
    "Favorites", "Empty", "New", "Consumables", "Equipment", "TradeGoods",
    "QuestItems", "Keys", "Miscellaneous", "Bags", "Junk",
}

-- The parts of the Bags tab (the owner's wish 2026-11-11). Each part starts on a new line with a
-- thin line above; groups within a part share lines. 1 your own (Favorites, own groups, New),
-- 2 everyday, 3 crafting, 4 quests, 5 the rest. The special bags come last under the game's line.
local SECTION_OF = {
    Favorites = 1, Empty = 1, New = 1, Consumables = 2, Equipment = 2, TradeGoods = 3,
    QuestItems = 4, Keys = 5, Miscellaneous = 5, Bags = 5, Junk = 5,
}

function ns.GetGroupSection(group)
    if SECTION_OF[group] then
        return SECTION_OF[group]
    elseif group:match("^custom") then
        return 1
    elseif group:match("^trade") then
        return 3
    end
    return 5
end
-- What shows: the game's groups with the player's own groups inserted after Empty ("Add to
-- bag"). Groups.lua rebuilds it when the groups change (ns.RebuildGroupOrder).
ns.groupOrder = ns.baseGroupOrder

-- The groups' headings in the game. Filled in again once the language is chosen (ns.OnLoad below),
-- because this file loads before Tidy Pack knows which language the player picked (Locales.lua).
ns.groupNames = {}

local function setBaseGroupNames()
    local names = ns.groupNames
    names.Favorites = L["Favorites"]
    names.New = L["New"]
    names.Consumables = L["Consumables"]
    names.Equipment = L["Equipment"]
    names.TradeGoods = L["Recipes & Gems"] -- crafting materials have their own groups; this holds recipes, gems and enhancements
    names.QuestItems = L["Quest Items"]
    names.Keys = L["Keys"]
    names.Bags = L["Spare Bags"] -- not "Bags", which is the tab above the window
    names.Miscellaneous = L["Miscellaneous"]
    names.Junk = L["Junk"]
    names.Empty = L["Add to bag"] -- the slot shows the free slots, and an item dropped there goes into the bags
end
setBaseGroupNames()
ns.OnLoad(setBaseGroupNames)

local ItemClass = Enum.ItemClass
local ConsumableSubclass = Enum.ItemConsumableSubclass

-- Group and place within the group by kind of item (Enum.ItemClass). The place keeps similar
-- items next to each other without own headings: weapons (1) before armor (2) and
-- ammunition (3) in Equipment, trade goods (1) before recipes (4) in Trade Goods.
-- Kinds not listed here go to Miscellaneous.
local byClass = {
    [ItemClass.Weapon] = { "Equipment", 1 },
    [ItemClass.Armor] = { "Equipment", 2 },
    [ItemClass.Projectile] = { "Equipment", 3 },
    -- Trade goods (crafting materials) get a group per subclass, see tradeGroupKey below.
    [ItemClass.Gem] = { "TradeGoods", 2 },
    [ItemClass.ItemEnhancement] = { "TradeGoods", 3 },
    [ItemClass.Recipe] = { "TradeGoods", 4 },
    [ItemClass.Reagent] = { "Consumables", 6 }, -- reagents that spells use up
    [ItemClass.Questitem] = { "QuestItems", 1 },
    [ItemClass.Key] = { "Keys", 1 },
    [ItemClass.Container] = { "Bags", 1 },
    [ItemClass.Quiver] = { "Bags", 2 },
}

-- Place within Consumables by subclass (Enum.ItemConsumableSubclass): potions first,
-- then food, bandages, scrolls and the rest last.
local consumableOrder = {
    [ConsumableSubclass.Potion] = 1,
    [ConsumableSubclass.Elixir] = 1,
    [ConsumableSubclass.Flasksphials] = 1,
    [ConsumableSubclass.Fooddrink] = 2,
    [ConsumableSubclass.Bandage] = 3,
    [ConsumableSubclass.Scroll] = 4,
}

---------------------------------------------------------------------------
-- Crafting materials per profession (the owner's wish 2026-11-11)
---------------------------------------------------------------------------
-- Trade goods are split by the game's own subclass (Cloth, Leather, Herb ...), the same split
-- as the auction house in Forever (C_AuctionHouse.GetAuctionItemSubClasses). The names come from
-- the game (C_Item.GetItemSubClassInfo). Groups for your professions (GetProfessions/GetProfessionInfo)
-- come first, with the profession's icon and name; the rest follow, in the order below.
-- ⚠️ The subclass numbers and the professions' skillLine numbers aren't in Forever's generated
--    documentation. They are the retail client's values. If they are wrong, only the order and
--    the profession's name in the heading are wrong – the items still land in groups named by the game.
local TRADE_SUBCLASSES = { 5, 6, 7, 9, 8, 12, 10, 1, 3, 2, 17, 4, 16, 13, 11, 0 }
-- Subclass → professions that use it (skillLine): Cloth → Tailoring, Leather → Leatherworking and
-- Skinning, Metal & Stone → Blacksmithing, Mining and Engineering, Meat → Cooking, Herb → Alchemy,
-- Herbalism and Inscription, Enchanting → Enchanting, Parts and Devices → Engineering,
-- Jewelcrafting → Jewelcrafting, Inscription → Inscription.
local PROFESSIONS_FOR = {
    [5] = { 197 }, [6] = { 165, 393 }, [7] = { 164, 186, 202 }, [8] = { 185 },
    [9] = { 171, 182, 773 }, [12] = { 333 }, [1] = { 202 }, [3] = { 202 }, [17] = { 202 },
    [4] = { 755 }, [16] = { 773 },
}

local function tradeGroupKey(subClassID)
    return "trade" .. (subClassID or 0)
end

-- Subclasses that have a group. An item with a subclass missing here would land in a group that
-- never shows, and then the item isn't seen in the bags (review 2026-11-14). So the game's own
-- list is added (C_AuctionHouse.GetAuctionItemSubClasses, the same the auction house uses), and a
-- subclass that still turns up unexpectedly gets a group at once (see ns.GetGroup).
local knownTrade = {}
for _, subClassID in ipairs(TRADE_SUBCLASSES) do
    knownTrade[subClassID] = true
end

-- Adds a subclass last in the order. True if it was new.
local function addTradeSubclass(subClassID)
    if knownTrade[subClassID] then
        return false
    end
    knownTrade[subClassID] = true
    TRADE_SUBCLASSES[#TRADE_SUBCLASSES + 1] = subClassID
    return true
end

local gameSubclassesAdded = false

-- The game's trade goods subclasses that aren't in the list above. Read once; the call is in
-- pcall, so an error there doesn't stop Tidy Pack.
local function addGameTradeSubclasses()
    if gameSubclassesAdded or not (C_AuctionHouse and C_AuctionHouse.GetAuctionItemSubClasses) then
        return
    end
    local ok, subClasses = pcall(C_AuctionHouse.GetAuctionItemSubClasses, ItemClass.Tradegoods)
    if ok and type(subClasses) == "table" then
        gameSubclassesAdded = true
        for _, subClassID in ipairs(subClasses) do
            if type(subClassID) == "number" then
                addTradeSubclass(subClassID)
            end
        end
    end
end

-- The group keys for crafting materials, your professions first. Also sets the headings in
-- ns.groupNames. Groups.lua puts them in Trade Goods' place in ns.groupOrder.
function ns.GetTradeGroupKeys()
    addGameTradeSubclasses()
    local mine = {}
    local professions = { GetProfessions() }
    for _, professionIndex in pairs(professions) do
        local name, icon, _, _, _, _, skillLine = GetProfessionInfo(professionIndex)
        if skillLine then
            mine[skillLine] = { name = name, icon = icon }
        end
    end
    local first, rest = {}, {}
    for _, subClassID in ipairs(TRADE_SUBCLASSES) do
        local key = tradeGroupKey(subClassID)
        local subName = C_Item.GetItemSubClassInfo(ItemClass.Tradegoods, subClassID)
        if not subName or subName == "" then
            subName = L["Trade Goods"]
        end
        local profession
        for _, skillLine in ipairs(PROFESSIONS_FOR[subClassID] or {}) do
            profession = profession or mine[skillLine]
        end
        if profession then
            -- The profession's name only when it differs from the kind's ("Cloth Tailoring", not "Cooking Cooking").
            if profession.name and profession.name ~= subName then
                ns.groupNames[key] = ("|T%s:13:13|t %s %s"):format(profession.icon, subName,
                    GRAY_FONT_COLOR:WrapTextInColorCode(profession.name))
            else
                ns.groupNames[key] = ("|T%s:13:13|t %s"):format(profession.icon, subName)
            end
            first[#first + 1] = key
        else
            ns.groupNames[key] = subName
            rest[#rest + 1] = key
        end
    end
    for _, key in ipairs(rest) do
        first[#first + 1] = key
    end
    return first
end

-- Which group an item in the bags belongs to, and its place within the group (lower first).
-- info comes from C_Container.GetContainerItemInfo, classID and subClassID from
-- C_Item.GetItemInfoInstant. isQuestItem comes from ns.IsQuestItem (QuestLock.lua);
-- Layout.lua asks once per item, because the lock needs the same answer.
function ns.GetGroup(bagID, slot, info, classID, subClassID, isQuestItem)
    -- What the player has chosen or just received comes first.
    if ns.IsFavorite(info.itemID) then
        return "Favorites", 0
    end
    if ns.IsNew(bagID, slot, info.itemID) then
        return "New", 0
    end
    -- Quest items, also normal items an active quest needs.
    if isQuestItem then
        return "QuestItems", 0
    end
    -- Grey items are junk whatever they are, and so is what you marked as junk yourself
    -- (Marks.lua). Marked junk comes after the grey.
    if info.quality == Enum.ItemQuality.Poor then
        return "Junk", 0
    end
    if ns.IsJunkMarked(info.itemID) then
        return "Junk", 1
    end
    -- Everything on the keyring is a key.
    if bagID == KEYRING_CONTAINER then
        return "Keys", 0
    end
    -- The player's own groups (Groups.lua) come before the game's normal kinds.
    local custom = ns.GetCustomGroupFor and ns.GetCustomGroupFor(info.itemID, classID, subClassID)
    if custom then
        return custom, 0
    end
    if classID == ItemClass.Consumable then
        return "Consumables", consumableOrder[subClassID] or 5
    end
    if classID == ItemClass.Tradegoods then
        -- A subclass without a group gets one now, last among the crafting groups, so the item always shows.
        if addTradeSubclass(subClassID or 0) and ns.RebuildGroupOrder then
            ns.RebuildGroupOrder()
        end
        return tradeGroupKey(subClassID), 0
    end
    local group = byClass[classID]
    if group then
        return group[1], group[2]
    end
    return "Miscellaneous", 0
end

-- The item's name, from the link: |cff...|Hitem:...|h[Name]|h|r
function ns.GetItemName(link)
    return link and link:match("%[(.-)%]") or ""
end

-- The order within a group: first the item's place within the group (e.g. weapons before armor),
-- then best quality, name and biggest stack. Last bag and slot, so two identical
-- items never swap places with each other. Among empty slots normal bags come before
-- special bags (e.g. quivers).
function ns.CompareEntries(a, b)
    if a.isEmpty or b.isEmpty then
        if a.isEmpty and b.isEmpty then
            return a.family < b.family
        end
        return b.isEmpty == true
    end
    if a.subOrder ~= b.subOrder then
        return a.subOrder < b.subOrder
    end
    if a.quality ~= b.quality then
        return a.quality > b.quality
    end
    if a.name ~= b.name then
        return a.name < b.name
    end
    if a.count ~= b.count then
        return a.count > b.count
    end
    if a.bagID ~= b.bagID then
        return a.bagID < b.bagID
    end
    return a.slot < b.slot
end
