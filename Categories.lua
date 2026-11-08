-- TidyPack – Categories.lua
-- Bestämmer vilken grupp en sak hör till, och i vilken ordning grupperna och sakerna
-- kommer. Ordningen är fast – det finns inga inställningar för den.

local addonName, ns = ...
local L = ns.L

-- Sektionerna och grupperna, uppifrån och ned. En sektion utan title har ingen rubrik,
-- bara en tunn linje ovanför. Grupper utan saker visas inte.
ns.sections = {
    { groups = { "Potions", "FoodDrink", "Consumables" } },
    { title = L["Equipment"], groups = { "Weapons", "Armor", "Ammo" } },
    { title = L["Crafting"], groups = { "TradeGoods", "Recipes" } },
    { groups = { "QuestItems", "Keys", "Bags", "Miscellaneous", "Junk", "Empty" } },
}

-- Gruppernas rubriker i spelet.
ns.groupNames = {
    Potions = L["Potions"],
    FoodDrink = L["Food & Drink"],
    Consumables = L["Consumables"],
    Weapons = L["Weapons"],
    Armor = L["Armor"],
    Ammo = L["Ammo"],
    TradeGoods = L["Trade Goods"],
    Recipes = L["Recipes"],
    QuestItems = L["Quest Items"],
    Keys = L["Keys"],
    Bags = L["Bags"],
    Miscellaneous = L["Miscellaneous"],
    Junk = L["Junk"],
    Empty = L["Empty"],
}

local ItemClass = Enum.ItemClass
local ConsumableSubclass = Enum.ItemConsumableSubclass

-- Grupp efter typ av sak (Enum.ItemClass). Typer som inte står här hamnar i Miscellaneous.
local groupByClass = {
    [ItemClass.Weapon] = "Weapons",
    [ItemClass.Armor] = "Armor",
    [ItemClass.Projectile] = "Ammo",
    [ItemClass.Tradegoods] = "TradeGoods",
    [ItemClass.Gem] = "TradeGoods",
    [ItemClass.ItemEnhancement] = "TradeGoods",
    [ItemClass.Recipe] = "Recipes",
    [ItemClass.Reagent] = "Consumables", -- reagenser som besvärjelser förbrukar
    [ItemClass.Questitem] = "QuestItems",
    [ItemClass.Key] = "Keys",
    [ItemClass.Container] = "Bags",
    [ItemClass.Quiver] = "Bags",
}

-- Förbrukningsvaror delas upp efter undertyp (Enum.ItemConsumableSubclass).
local groupByConsumableSubclass = {
    [ConsumableSubclass.Potion] = "Potions",
    [ConsumableSubclass.Elixir] = "Potions",
    [ConsumableSubclass.Flasksphials] = "Potions",
    [ConsumableSubclass.Fooddrink] = "FoodDrink",
}

-- Vilken grupp en sak i väskorna hör till. info kommer från C_Container.GetContainerItemInfo.
function ns.GetGroup(bagID, slot, info)
    -- Gråa saker är skräp, oavsett vad de är.
    if info.quality == Enum.ItemQuality.Poor then
        return "Junk"
    end
    -- Allt på nyckelringen är nycklar.
    if bagID == KEYRING_CONTAINER then
        return "Keys"
    end
    local questInfo = C_Container.GetContainerItemQuestInfo(bagID, slot)
    if questInfo and (questInfo.isQuestItem or questInfo.questID) then
        return "QuestItems"
    end
    local _, _, _, _, _, classID, subClassID = C_Item.GetItemInfoInstant(info.itemID)
    if classID == ItemClass.Consumable then
        return groupByConsumableSubclass[subClassID] or "Consumables"
    end
    return groupByClass[classID] or "Miscellaneous"
end

-- Sakens namn, ur länken: |cff...|Hitem:...|h[Namn]|h|r
function ns.GetItemName(link)
    return link and link:match("%[(.-)%]") or ""
end

-- Ordningen inom en grupp: bäst kvalitet först, sedan namn och sedan störst hög. Sist
-- väska och plats, så att två likadana saker aldrig byter plats med varandra.
-- Tomma platser kommer sist, vanliga väskor före specialväskor (t.ex. koger).
function ns.CompareEntries(a, b)
    if a.isEmpty or b.isEmpty then
        if a.isEmpty and b.isEmpty then
            return a.family < b.family
        end
        return b.isEmpty == true
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
