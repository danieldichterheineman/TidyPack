-- TidyPack – Favorites.lua
-- Stjärnmärkta saker hamnar i gruppen Favorites överst i väskfönstret. Stjärnorna sparas
-- per sorts sak (itemID) och gäller alla dina karaktärer.
-- Så stjärnmärker du:
--   - Mus: Alt-klicka på saken. Spelets klick gör inget med Alt nedtryckt.
--   - Handkontroll (och mus): plocka upp saken och lägg den på ★-knappen uppe till höger.
-- Samma sak en gång till tar bort stjärnan.

local addonName, ns = ...
local L = ns.L

local STAR_ATLAS = "auctionhouse-icon-favorite" -- spelets egen stjärna, från auktionshuset

local starButton
local hookedButtons = setmetatable({}, { __mode = "k" })

function ns.IsFavorite(itemID)
    return ns.db ~= nil and ns.db.favorites[itemID] == true
end

local function toggleFavorite(itemID)
    if not itemID then
        return
    end
    if ns.db.favorites[itemID] then
        ns.db.favorites[itemID] = nil
    else
        ns.db.favorites[itemID] = true
    end
    if ns.Refresh then
        ns.Refresh()
    end
end

-- Körs efter spelets eget klick på en ruta i väskorna (HookScript).
local function onItemButtonClick(button, mouseButton)
    if mouseButton ~= "LeftButton" or not IsAltKeyDown() then
        return
    end
    local info = C_Container.GetContainerItemInfo(button:GetBagID(), button:GetID())
    if info then
        toggleFavorite(info.itemID)
    end
end

-- Layout.lua anropar den här för varje ruta det visar. Varje ruta får Alt-klicket en gång.
function ns.HookItemButton(button)
    if not hookedButtons[button] then
        hookedButtons[button] = true
        button:HookScript("OnClick", onItemButtonClick)
    end
end

-- Saken som just nu hänger på muspekaren (eller handkontrollens markör), om någon.
local function cursorItemID()
    local kind, itemID = GetCursorInfo()
    if kind == "item" then
        return itemID
    end
    return nil
end

-- ★-knappen är svag tills du håller en sak, och lyser upp när du kan släppa den där.
local function updateStarButton()
    if not starButton then
        return
    end
    local holding = cursorItemID() ~= nil
    starButton:SetAlpha(holding and 1 or 0.35)
    if holding then
        starButton:LockHighlight()
    else
        starButton:UnlockHighlight()
    end
end

local function onStarButtonClick()
    local itemID = cursorItemID()
    if itemID then
        ClearCursor() -- saken går tillbaka till sin plats
        toggleFavorite(itemID)
    end
end

ns.OnLoad(function()
    local bagFrame = ns.bagFrame
    if not bagFrame then
        return
    end

    -- ★-knappen uppe till höger, där spelets städknapp satt. Den är en vanlig knapp i
    -- väskfönstret, så handkontrollens markör når den.
    starButton = CreateFrame("Button", nil, bagFrame)
    starButton:SetSize(26, 26)
    starButton:SetPoint("TOPRIGHT", bagFrame, "TOPRIGHT", -9, -34)
    starButton:SetNormalAtlas(STAR_ATLAS)
    starButton:SetHighlightAtlas(STAR_ATLAS, "ADD")
    starButton:RegisterForClicks("LeftButtonUp")
    starButton:SetScript("OnClick", onStarButtonClick)
    starButton:SetScript("OnReceiveDrag", onStarButtonClick)
    starButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip_SetTitle(GameTooltip, L["Favorites"])
        GameTooltip_AddNormalLine(GameTooltip, L["Drop an item here to star or unstar it."])
        GameTooltip_AddNormalLine(GameTooltip, L["Alt-click an item to do the same."])
        GameTooltip:Show()
    end)
    starButton:SetScript("OnLeave", GameTooltip_Hide)
    ns.RegisterEvent("CURSOR_CHANGED", updateStarButton)
    updateStarButton()

    -- Med handkontroll går spelets sökruta ända till högerkanten. Den kortas av så att
    -- ★-knappen får plats.
    hooksecurefunc(bagFrame, "SetSearchBoxPoint", function(_, searchBox)
        if InputUtil.IsGamepadUIEnabled() then
            searchBox:SetPoint("TOPRIGHT", bagFrame, "TOPRIGHT", -44, -37)
        end
    end)
end)
