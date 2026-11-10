-- TidyPack – Categories.lua
-- Bestämmer vilken grupp en sak hör till, och i vilken ordning grupperna och sakerna
-- kommer. Ordningen är fast – det finns inga inställningar för den.

local addonName, ns = ...
local L = ns.L

-- Grupperna, i den ordning de visas. Grupper utan saker visas inte. Empty (rutan där du
-- släpper en sak för att lägga den i väskorna) står näst först, så att den delar översta
-- raden med Favorites i stället för att ta en egen rad längst ned.
ns.groupOrder = {
    "Favorites", "Empty", "New", "Consumables", "Equipment", "TradeGoods",
    "QuestItems", "Keys", "Bags", "Miscellaneous", "Junk",
}

-- Gruppernas rubriker i spelet.
ns.groupNames = {
    Favorites = L["Favorites"],
    New = L["New"],
    Consumables = L["Consumables"],
    Equipment = L["Equipment"],
    TradeGoods = L["Trade Goods"],
    QuestItems = L["Quest Items"],
    Keys = L["Keys"],
    Bags = L["Spare Bags"], -- inte "Bags", som fliken ovanför fönstret heter
    Miscellaneous = L["Miscellaneous"],
    Junk = L["Junk"],
    Empty = L["Add to bag"], -- rutan visar antalet lediga platser, och en sak som släpps dit hamnar i väskorna
}

local ItemClass = Enum.ItemClass
local ConsumableSubclass = Enum.ItemConsumableSubclass

-- Grupp och plats inom gruppen efter typ av sak (Enum.ItemClass). Platsen gör att lika
-- saker ligger bredvid varandra utan egna rubriker: vapen (1) före rustning (2) och
-- ammunition (3) i Equipment, handelsvaror (1) före recept (4) i Trade Goods.
-- Typer som inte står här hamnar i Miscellaneous.
local byClass = {
    [ItemClass.Weapon] = { "Equipment", 1 },
    [ItemClass.Armor] = { "Equipment", 2 },
    [ItemClass.Projectile] = { "Equipment", 3 },
    [ItemClass.Tradegoods] = { "TradeGoods", 1 },
    [ItemClass.Gem] = { "TradeGoods", 2 },
    [ItemClass.ItemEnhancement] = { "TradeGoods", 3 },
    [ItemClass.Recipe] = { "TradeGoods", 4 },
    [ItemClass.Reagent] = { "Consumables", 6 }, -- reagenser som besvärjelser förbrukar
    [ItemClass.Questitem] = { "QuestItems", 1 },
    [ItemClass.Key] = { "Keys", 1 },
    [ItemClass.Container] = { "Bags", 1 },
    [ItemClass.Quiver] = { "Bags", 2 },
}

-- Plats inom Consumables efter undertyp (Enum.ItemConsumableSubclass): drycker först,
-- sedan mat, förband, skriftrullar och sist annat.
local consumableOrder = {
    [ConsumableSubclass.Potion] = 1,
    [ConsumableSubclass.Elixir] = 1,
    [ConsumableSubclass.Flasksphials] = 1,
    [ConsumableSubclass.Fooddrink] = 2,
    [ConsumableSubclass.Bandage] = 3,
    [ConsumableSubclass.Scroll] = 4,
}

-- Vilken grupp en sak i väskorna hör till, och sakens plats inom gruppen (lägre först).
-- info kommer från C_Container.GetContainerItemInfo, classID och subClassID från
-- C_Item.GetItemInfoInstant. isQuestItem kommer från ns.IsQuestItem (QuestLock.lua);
-- Layout.lua frågar en gång per sak, eftersom låset behöver samma svar.
function ns.GetGroup(bagID, slot, info, classID, subClassID, isQuestItem)
    -- Det spelaren själv har valt eller just har fått går först.
    if ns.IsFavorite(info.itemID) then
        return "Favorites", 0
    end
    if ns.IsNew(bagID, slot, info.itemID) then
        return "New", 0
    end
    -- Quest-saker, även vanliga saker som en pågående quest kräver.
    if isQuestItem then
        return "QuestItems", 0
    end
    -- Gråa saker är skräp, oavsett vad de är, och så är det du själv markerat som skräp
    -- (Marks.lua). Markerat skräp ligger efter det gråa.
    if info.quality == Enum.ItemQuality.Poor then
        return "Junk", 0
    end
    if ns.IsJunkMarked(info.itemID) then
        return "Junk", 1
    end
    -- Allt på nyckelringen är nycklar.
    if bagID == KEYRING_CONTAINER then
        return "Keys", 0
    end
    if classID == ItemClass.Consumable then
        return "Consumables", consumableOrder[subClassID] or 5
    end
    local group = byClass[classID]
    if group then
        return group[1], group[2]
    end
    return "Miscellaneous", 0
end

-- Sakens namn, ur länken: |cff...|Hitem:...|h[Namn]|h|r
function ns.GetItemName(link)
    return link and link:match("%[(.-)%]") or ""
end

-- Ordningen inom en grupp: först sakens plats inom gruppen (t.ex. vapen före rustning),
-- sedan bäst kvalitet, namn och störst hög. Sist väska och plats, så att två likadana
-- saker aldrig byter plats med varandra. Bland tomma platser kommer vanliga väskor före
-- specialväskor (t.ex. koger).
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
