-- TidyPack – Characters.lua
-- Counts on your other characters (the owner's wish 2026-11-15, sketch .design/sketch-characters.html).
--
-- Every character saves how many of each item it has in its bags (the reagent bag too) and in its
-- saved bank (Bank.lua) in TidyPackDB.characters, which the whole account shares. An item's tooltip
-- then lists the characters on this realm (and realms connected to it, which can mail each other)
-- that have the item. A character's bank is as it was at its last visit to a banker. Not counted:
-- mail, worn items, the auction house and the account bank.
--
-- The tooltip: the character you play first, then the others with the most first, each name in its
-- class color, at most MAX_LINES lines and then "+N more characters", and a total. When no other
-- character has the item, the single line from before shows ("Bags 12 · Bank 40 · Total 52"), and
-- only when the item is in the bank. Options: showCounts (all of it) and showOtherCharacters.
-- Gear → Bag and bank → Forget a Character removes a character you deleted or don't play.
--
-- Money (the owner's wish 2026-11-15, sketch .design/sketch-money.html): each character also saves its
-- money, and pointing at the money in the bag window shows Money, the total in gold, each character on
-- this realm (you first, then the most first) and the account bank when it holds some. No tooltip with
-- only one character and an empty account bank. The game's own click on the money (picking it up)
-- still works: Tidy Pack only adds to the coins' OnEnter and OnLeave with HookScript.

local _, ns = ...
local L = ns.L

local MAX_LINES = 8 -- character lines in the tooltip, the one you play included
local COUNT_COLOR = CreateColor(0.44, 0.71, 1) -- light blue, like Tidy Pack's other lines about slots
local LAST_BAG = Constants.InventoryConstants.NumBagSlots + Constants.InventoryConstants.NumReagentBagSlots

local myKey, myName, myRealm, myClass -- the character you play, known from PLAYER_LOGIN
local sameRealm = {}                   -- realm → true for this realm and the realms connected to it

---------------------------------------------------------------------------
-- Counting
---------------------------------------------------------------------------

-- itemID → count in the bags (backpack, bags and reagent bag), or nil when the game has no bags yet
-- (e.g. at the very end of a logout): then nothing is saved, so the old counts stay.
local function countBags()
    if C_Container.GetContainerNumSlots(0) == 0 then
        return nil
    end
    local counts = {}
    for bagID = 0, LAST_BAG do
        for slot = 1, C_Container.GetContainerNumSlots(bagID) do
            local info = C_Container.GetContainerItemInfo(bagID, slot)
            if info and info.itemID then
                counts[info.itemID] = (counts[info.itemID] or 0) + (info.stackCount or 1)
            end
        end
    end
    return counts
end

-- itemID → count in the saved bank (Bank.lua), or nil when this character has never visited a banker.
local function countSavedBank(saved)
    if not (saved and saved.items) then
        return nil
    end
    local counts = {}
    for _, item in ipairs(saved.items) do
        local itemID = item.link and C_Item.GetItemInfoInstant(item.link)
        if itemID then
            counts[itemID] = (counts[itemID] or 0) + (item.count or 1)
        end
    end
    return counts
end

-- The bank counts of the character you play, counted again only when the saved bank changes.
local countedBank, bankCounts
local function myBankCounts()
    local saved = ns.GetSavedBank and ns.GetSavedBank()
    if saved ~= countedBank then
        countedBank, bankCounts = saved, countSavedBank(saved)
    end
    return bankCounts
end

---------------------------------------------------------------------------
-- Saving the character you play
---------------------------------------------------------------------------

local function saveMe()
    if not (myKey and ns.db and ns.db.characters) then
        return
    end
    local bags = countBags()
    if not bags then
        return
    end
    local entry = ns.db.characters[myKey] or {}
    entry.name, entry.realm, entry.class = myName, myRealm, myClass
    entry.time = time()
    entry.bags = bags
    entry.bank = myBankCounts()
    entry.money = GetMoney()
    ns.db.characters[myKey] = entry
end

-- The bags change often (looting, moving), so the count waits until they have been still for a moment.
local savePending = false
local function saveSoon()
    if savePending then
        return
    end
    savePending = true
    C_Timer.After(2, function()
        savePending = false
        saveMe()
    end)
end

ns.RegisterEvent("PLAYER_LOGIN", function()
    myName = UnitName("player")
    myRealm = GetNormalizedRealmName()
    myClass = UnitClassBase("player")
    if not (myName and myRealm) then
        return
    end
    myKey = myName .. "-" .. myRealm
    sameRealm[myRealm] = true
    for _, realm in ipairs(GetAutoCompleteRealms() or {}) do
        sameRealm[realm] = true
    end
    saveSoon()
end)
ns.RegisterEvent("BAG_UPDATE_DELAYED", saveSoon)
ns.RegisterEvent("PLAYER_MONEY", saveSoon)
ns.RegisterEvent("BANKFRAME_CLOSED", saveSoon)
-- The saved data is written when you log out or reload, so the last change is counted then too.
ns.RegisterEvent("PLAYER_LOGOUT", saveMe)

---------------------------------------------------------------------------
-- The tooltip
---------------------------------------------------------------------------

local function classColored(name, class)
    local color = class and C_ClassColor.GetClassColor(class)
    return color and color:WrapTextInColorCode(name) or name
end

-- "Bags 12 · Bank 40", "Bags 3" or "Bank 20".
local function countsText(bags, bank)
    if bags > 0 and bank > 0 then
        return L["Bags %d"]:format(bags) .. " · " .. L["Bank %d"]:format(bank)
    end
    return bags > 0 and L["Bags %d"]:format(bags) or L["Bank %d"]:format(bank)
end

local function byMostFirst(a, b)
    if a.total ~= b.total then
        return a.total > b.total
    end
    return a.name < b.name
end

TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
    if not data or type(data.id) ~= "number" or ns.db == nil or ns.db.showCounts == false then
        return
    end
    local itemID = data.id
    local bank = (myBankCounts() or {})[itemID] or 0
    local bags = C_Item.GetItemCount(itemID) or 0
    local others = {}
    if ns.db.showOtherCharacters ~= false and myKey then
        for key, character in pairs(ns.db.characters or {}) do
            if key ~= myKey and sameRealm[character.realm] then
                local theirBags = character.bags and character.bags[itemID] or 0
                local theirBank = character.bank and character.bank[itemID] or 0
                if theirBags + theirBank > 0 then
                    others[#others + 1] = { name = character.name or key, class = character.class,
                        bags = theirBags, bank = theirBank, total = theirBags + theirBank }
                end
            end
        end
    end
    local r, g, b = COUNT_COLOR:GetRGB()
    if #others == 0 then
        -- Only you: the line from before, and only when the item is in the bank (the slot shows the rest).
        if bank > 0 then
            tooltip:AddLine(L["Bags %d · Bank %d · Total %d"]:format(bags, bank, bags + bank), r, g, b)
        end
        return
    end
    table.sort(others, byMostFirst)
    local total, lines = 0, 0
    if bags + bank > 0 then
        tooltip:AddDoubleLine(classColored(myName, myClass), countsText(bags, bank), 1, 1, 1, r, g, b)
        total, lines = bags + bank, 1
    end
    local hidden = 0
    for _, other in ipairs(others) do
        total = total + other.total
        if lines < MAX_LINES then
            tooltip:AddDoubleLine(classColored(other.name, other.class), countsText(other.bags, other.bank),
                1, 1, 1, r, g, b)
            lines = lines + 1
        else
            hidden = hidden + 1
        end
    end
    if hidden > 0 then
        tooltip:AddLine(hidden == 1 and L["+1 more character"] or L["+%d more characters"]:format(hidden), r, g, b)
    end
    if lines + hidden > 1 then
        tooltip:AddDoubleLine(L["Total"], tostring(total), r, g, b, r, g, b)
    end
end)

---------------------------------------------------------------------------
-- The money's tooltip
---------------------------------------------------------------------------

local function accountBankMoney()
    if C_Bank and C_Bank.FetchDepositedMoney and Enum.BankType and Enum.BankType.Account then
        return C_Bank.FetchDepositedMoney(Enum.BankType.Account) or 0
    end
    return 0
end

local function byMostMoney(a, b)
    if a.money ~= b.money then
        return a.money > b.money
    end
    return (a.name or "") < (b.name or "")
end

local function showMoneyTooltip(owner)
    if not (ns.db and ns.db.showCounts ~= false and ns.db.showOtherCharacters ~= false and myKey) then
        return
    end
    local others = {}
    for key, character in pairs(ns.db.characters or {}) do
        if key ~= myKey and sameRealm[character.realm] and (character.money or 0) > 0 then
            others[#others + 1] = character
        end
    end
    local account = accountBankMoney()
    if #others == 0 and account == 0 then
        return -- only you: the money row already says it all
    end
    table.sort(others, byMostMoney)
    local mine = GetMoney()
    local total = mine + account
    for _, other in ipairs(others) do
        total = total + other.money
    end
    GameTooltip:SetOwner(owner, "ANCHOR_TOP")
    GameTooltip_SetTitle(GameTooltip, L["Money"])
    GameTooltip:AddLine(L["Total: %s"]:format(GetMoneyString(total, true)), NORMAL_FONT_COLOR:GetRGB())
    GameTooltip:AddDoubleLine(classColored(myName, myClass), GetMoneyString(mine, true), 1, 1, 1, 1, 1, 1)
    local lines, hidden = 1, 0
    for _, other in ipairs(others) do
        if lines < MAX_LINES then
            GameTooltip:AddDoubleLine(classColored(other.name or "", other.class), GetMoneyString(other.money, true),
                1, 1, 1, 1, 1, 1)
            lines = lines + 1
        else
            hidden = hidden + 1
        end
    end
    if hidden > 0 then
        GameTooltip:AddLine(hidden == 1 and L["+1 more character"] or L["+%d more characters"]:format(hidden),
            GRAY_FONT_COLOR:GetRGB())
    end
    if account > 0 then
        GameTooltip:AddDoubleLine(L["Account bank"], GetMoneyString(account, true), 1, 1, 1, 1, 1, 1)
    end
    GameTooltip:Show()
end

ns.OnLoad(function()
    local moneyFrame = ns.bagFrame and ns.bagFrame.MoneyFrame
    if not moneyFrame then
        return
    end
    for _, key in ipairs({ "GoldButton", "SilverButton", "CopperButton" }) do
        local coin = moneyFrame[key]
        if coin then
            coin:HookScript("OnEnter", showMoneyTooltip)
            coin:HookScript("OnLeave", GameTooltip_Hide)
        end
    end
end)

---------------------------------------------------------------------------
-- Gear → Bag and bank → Forget a Character
---------------------------------------------------------------------------

-- Adds the submenu to the gear menu's Bag and bank (Options.lua): your other characters, the one
-- played most recently first. A click asks before anything is removed.
function ns.AddForgetCharacterMenu(submenu)
    submenu:CreateDivider()
    local forget = submenu:CreateButton(L["Forget a Character"])
    local list = {}
    for key, character in pairs(ns.db.characters or {}) do
        if key ~= myKey then
            list[#list + 1] = { key = key, character = character }
        end
    end
    if #list == 0 then
        forget:SetEnabled(false)
        return
    end
    table.sort(list, function(a, b)
        return (a.character.time or 0) > (b.character.time or 0)
    end)
    for _, entry in ipairs(list) do
        local character = entry.character
        local name = character.name or entry.key
        -- A character on another realm gets the realm's name, so two with the same name can be told apart.
        if character.realm and not sameRealm[character.realm] then
            name = name .. " - " .. character.realm
        end
        local age = character.time and ns.AgeText and ns.AgeText(character.time)
        local label = classColored(name, character.class) .. (age and ("  |cff999999" .. age .. "|r") or "")
        forget:CreateButton(label, function()
            ns.ShowDialog(L["Forget %s? Tidy Pack stops showing the character's items until you log in with it again."]
                :format(name), L["Forget"], false, nil, function()
                    ns.db.characters[entry.key] = nil
                end)
            return MenuResponse.CloseAll -- the menu closes, so the question shows
        end)
    end
end
