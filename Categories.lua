-- TidyPack – Categories.lua
-- Bestämmer vilken grupp en sak hör till, och i vilken ordning grupperna och sakerna
-- kommer. Ordningen är fast – det finns inga inställningar för den.

local _, ns = ...
local L = ns.L

-- Grupperna, i den ordning de visas. Grupper utan saker visas inte. Empty (rutan där du
-- släpper en sak för att lägga den i väskorna) står näst först, så att den delar översta
-- raden med Favorites i stället för att ta en egen rad längst ned.
ns.baseGroupOrder = {
    "Favorites", "Empty", "New", "Consumables", "Equipment", "TradeGoods",
    "QuestItems", "Keys", "Miscellaneous", "Bags", "Junk",
}

-- Avsnitten i fliken Bags (användarens önskan 2026-11-11). Varje avsnitt börjar på en ny rad med
-- en tunn linje ovanför; grupper inom ett avsnitt delar rad. 1 dina egna (Favorites, egna grupper,
-- New), 2 vardag, 3 råvaror, 4 quests, 5 övrigt. Specialväskorna står sist under spelets linje.
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
-- Det som visas: spelets grupper med spelarens egna grupper insatta efter Empty ("Add to
-- bag"). Groups.lua bygger om den när grupperna ändras (ns.RebuildGroupOrder).
ns.groupOrder = ns.baseGroupOrder

-- Gruppernas rubriker i spelet.
ns.groupNames = {
    Favorites = L["Favorites"],
    New = L["New"],
    Consumables = L["Consumables"],
    Equipment = L["Equipment"],
    TradeGoods = L["Recipes & Gems"], -- råvarorna har egna grupper; här står recept, ädelstenar och förbättringar
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
    -- Handelsvaror (råvaror) får en grupp per undertyp, se tradeGroupKey nedan.
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

---------------------------------------------------------------------------
-- Råvaror per yrke (användarens önskan 2026-11-11)
---------------------------------------------------------------------------
-- Handelsvaror delas upp efter spelets egen undertyp (Cloth, Leather, Herb ...), samma uppdelning
-- som auktionshuset i Forever gör (C_AuctionHouse.GetAuctionItemSubClasses). Namnen kommer från
-- spelet (C_Item.GetItemSubClassInfo). Grupper för dina yrken (GetProfessions/GetProfessionInfo)
-- står först, med yrkets ikon och namn; resten står efter, i ordningen nedan.
-- ⚠️ Undertypernas nummer och yrkenas skillLine-nummer står inte i Forevers genererade
--    dokumentation. De är retail-klientens värden. Stämmer de inte blir bara ordningen och
--    yrkets namn i rubriken fel – sakerna hamnar ändå i grupper med spelets egna namn.
local TRADE_SUBCLASSES = { 5, 6, 7, 9, 8, 12, 10, 1, 3, 2, 17, 4, 16, 13, 11, 0 }
-- Undertyp → yrken som använder den (skillLine): Cloth → Tailoring, Leather → Leatherworking och
-- Skinning, Metal & Stone → Blacksmithing, Mining och Engineering, Meat → Cooking, Herb → Alchemy,
-- Herbalism och Inscription, Enchanting → Enchanting, Parts och Devices → Engineering,
-- Jewelcrafting → Jewelcrafting, Inscription → Inscription.
local PROFESSIONS_FOR = {
    [5] = { 197 }, [6] = { 165, 393 }, [7] = { 164, 186, 202 }, [8] = { 185 },
    [9] = { 171, 182, 773 }, [12] = { 333 }, [1] = { 202 }, [3] = { 202 }, [17] = { 202 },
    [4] = { 755 }, [16] = { 773 },
}

local function tradeGroupKey(subClassID)
    return "trade" .. (subClassID or 0)
end

-- Undertyper som har en grupp. En sak med en undertyp som saknas här skulle hamna i en grupp som
-- aldrig visas, och då syns saken inte i väskan (granskning 2026-11-14). Därför läggs spelets egen
-- lista till (C_AuctionHouse.GetAuctionItemSubClasses, samma som auktionshuset använder), och en
-- undertyp som ändå dyker upp oväntat får en grupp i samma stund (se ns.GetGroup).
local knownTrade = {}
for _, subClassID in ipairs(TRADE_SUBCLASSES) do
    knownTrade[subClassID] = true
end

-- Lägger till en undertyp sist i ordningen. Sant om den var ny.
local function addTradeSubclass(subClassID)
    if knownTrade[subClassID] then
        return false
    end
    knownTrade[subClassID] = true
    TRADE_SUBCLASSES[#TRADE_SUBCLASSES + 1] = subClassID
    return true
end

local gameSubclassesAdded = false

-- Spelets undertyper för handelsvaror som inte står i listan ovan. Läses en gång; anropet ligger i
-- pcall, så att ett fel där inte stoppar Tidy Pack.
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

-- Gruppernas nycklar för råvaror, dina yrken först. Sätter också rubrikerna i ns.groupNames.
-- Groups.lua lägger dem på Trade Goods plats i ns.groupOrder.
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
            -- Yrkets namn bara när det skiljer sig från sortens ("Cloth Tailoring", inte "Cooking Cooking").
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
    -- Spelarens egna grupper (Groups.lua) går före spelets vanliga typer.
    local custom = ns.GetCustomGroupFor and ns.GetCustomGroupFor(info.itemID, classID, subClassID)
    if custom then
        return custom, 0
    end
    if classID == ItemClass.Consumable then
        return "Consumables", consumableOrder[subClassID] or 5
    end
    if classID == ItemClass.Tradegoods then
        -- En undertyp utan grupp får en nu, sist bland råvarorna, så att saken alltid syns.
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
