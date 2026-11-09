-- TidyPack – Marks.lua
-- Två märken som du sätter själv. De sparas per sorts sak (itemID) och gäller alla dina
-- karaktärer:
--   ★ Favorit: saken hamnar i gruppen Favorites överst.
--   Skräplistan: saken hamnar sist i Junk med spelets eget skräpmynt. Tidy Pack frågar om
--   den ska raderas när du lootar den (MakeRoom.lua), den säljs av Sell Junk (Junk.lua) och
--   föreslås först när väskorna är fulla.
-- Så märker du:
--   - Mus: Alt-vänsterklick = favorit, Alt-högerklick = skräplistan. Spelets klick gör
--     ingenting med Alt nedtryckt (i Forever är Alt bara kopplat till besvärjelser och
--     utrustningsmenyer, se Bindings_Camelot.xml i spelets kod).
--   - Mus och handkontroll: släpp saken på ★ uppe till höger. Spelets egen meny frågar då
--     om saken ska bli favorit eller hamna på skräplistan.
--   - Skräplistan har också en egen sida i inställningarna (Options.lua).
-- Samma sak en gång till tar bort märket. En sak kan inte vara både favorit och på
-- skräplistan.
-- ★ är den enda knapp Tidy Pack lägger i väskfönstret. Den sitter där spelets
-- sorteringsknapp satt. Utan en sak på markören öppnar den skräplistan och inställningarna.

local addonName, ns = ...
local L = ns.L

-- Knappens bild: spelets kugghjul för inställningar (questlog-icon-setting, samma som
-- spelets UIPanelIconDropdownButtonTemplate). Stjärnan passade när knappen bara gjorde
-- favoriter; nu öppnar den också skräplistan, seten och inställningarna.
local BUTTON_ATLAS = "questlog-icon-setting"
local BUTTON_SIZE = 26
local ICON_SIZE = 20

local starButton
local starHovered = false -- markören (mus eller handkontroll) står på ★
local hookedButtons = setmetatable({}, { __mode = "k" })

function ns.IsFavorite(itemID)
    return ns.db ~= nil and ns.db.favorites[itemID] == true
end

function ns.IsJunkMarked(itemID)
    return ns.db ~= nil and ns.db.junk[itemID] == true
end

-- Sätter eller tar bort ett märke. Ett nytt märke tar bort det andra, så att en sak aldrig
-- är både favorit och på skräplistan.
local function toggleMark(list, otherList, itemID)
    if not itemID then
        return
    end
    if list[itemID] then
        list[itemID] = nil
    else
        list[itemID] = true
        otherList[itemID] = nil
    end
    if ns.JunkListChanged then
        ns.JunkListChanged(itemID) -- MakeRoom.lua räknar saken från och med nu
    end
    if ns.RefreshJunkListPage then
        ns.RefreshJunkListPage()
    end
    if ns.Refresh then
        ns.Refresh()
    end
end

function ns.ToggleFavorite(itemID)
    toggleMark(ns.db.favorites, ns.db.junk, itemID)
end

function ns.ToggleJunk(itemID)
    toggleMark(ns.db.junk, ns.db.favorites, itemID)
end

-- Lägger till (true) eller tar bort (false) en sak på skräplistan. Används av
-- inställningarna.
function ns.SetJunk(itemID, onList)
    if itemID and (ns.db.junk[itemID] == true) ~= onList then
        ns.ToggleJunk(itemID)
    end
end

-- Körs efter spelets eget klick på en ruta i väskorna (HookScript).
local function onItemButtonClick(button, mouseButton)
    if not IsAltKeyDown() then
        return
    end
    local info = C_Container.GetContainerItemInfo(button:GetBagID(), button:GetID())
    if not info then
        return
    end
    if mouseButton == "LeftButton" then
        ns.ToggleFavorite(info.itemID)
    elseif mouseButton == "RightButton" then
        ns.ToggleJunk(info.itemID)
    end
end

-- Layout.lua anropar den här för varje ruta det visar. Varje ruta får Alt-klicken en gång.
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

-- ★ är svag tills du håller en sak, pekar på den eller har dess meny öppen. När du håller
-- en sak lyser den också upp, eftersom du kan släppa saken där.
local function updateStarButton()
    if not starButton then
        return
    end
    local holding = cursorItemID() ~= nil
    local active = holding or starHovered or starButton:IsMenuOpen()
    starButton:SetAlpha(active and 1 or 0.35)
    if holding then
        starButton:LockHighlight()
    else
        starButton:UnlockHighlight()
    end
end

-- Menyn under ★, byggd av spelets eget menysystem. Med en sak på markören: favorit,
-- skräplistan eller ett set. Annars: byta flik, skräplistan, seten och inställningarna.
local function buildMenu(_, rootDescription)
    local itemID = cursorItemID()
    if itemID then
        rootDescription:CreateTitle(C_Item.GetItemNameByID(itemID) or L["Item"])
        rootDescription:CreateButton(ns.IsFavorite(itemID) and L["Remove from Favorites"] or L["Add to Favorites"], function()
            ClearCursor() -- saken går tillbaka till sin plats
            ns.ToggleFavorite(itemID)
        end)
        rootDescription:CreateButton(ns.IsJunkMarked(itemID) and L["Remove from Junk List"] or L["Add to Junk List"], function()
            ClearCursor()
            ns.ToggleJunk(itemID)
        end)
        -- Egna set (Sets.lua): en bock för varje set som saken ingår i.
        local setMenu = rootDescription:CreateButton(L["Add to Set"])
        for index, set in ipairs(ns.GetSets()) do
            setMenu:CreateCheckbox(set.name, function()
                return ns.IsInSet(index, itemID)
            end, function()
                ClearCursor()
                ns.SetInSet(index, itemID, not ns.IsInSet(index, itemID))
                return MenuResponse.CloseAll
            end)
        end
        setMenu:CreateButton(L["New Set..."], function()
            ClearCursor()
            ns.AskNewSet(itemID)
        end)
    else
        rootDescription:CreateTitle(L["Tidy Pack"])
        -- Med handkontroll är flikarna kanske inte nåbara, så där finns samma val här.
        -- Med mus räcker flikarna, och menyn hålls kort.
        if InputUtil.IsGamepadUIEnabled() then
            if ns.IsSetsView and ns.IsSetsView() then
                rootDescription:CreateButton(L["Show Bags"], function()
                    ns.SetView("bags")
                end)
            else
                rootDescription:CreateButton(L["Show Sets"], function()
                    ns.SetView("sets")
                end)
            end
        end
        rootDescription:CreateButton(L["Junk List..."], function()
            ns.OpenSettings("junk")
        end)
        rootDescription:CreateButton(L["Settings..."], function()
            ns.OpenSettings()
        end)
    end
end

-- Tooltipen följer hur du spelar: med handkontroll finns inga Alt-klick, men väl knappen A
-- (spelet visar den symbol som din kontroll har).
local function showTooltip(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip_SetTitle(GameTooltip, L["Tidy Pack"])
    if InputUtil.IsGamepadUIEnabled() then
        local icon = ns.GamepadIcon and ns.GamepadIcon(GAMEPAD_FACE_BOTTOM) or ""
        local text = L["Pick up an item, then drop it here to star it, put it on your junk list or add it to a set."]
        GameTooltip_AddNormalLine(GameTooltip, icon ~= "" and (icon .. " " .. text) or text)
    else
        GameTooltip_AddNormalLine(GameTooltip, L["Drop an item here to star it, put it on your junk list or add it to a set."])
    end
    GameTooltip_AddNormalLine(GameTooltip, L["Click for your junk list and settings."])
    if not InputUtil.IsGamepadUIEnabled() then
        GameTooltip_AddBlankLineToTooltip(GameTooltip)
        GameTooltip_AddInstructionLine(GameTooltip, L["Alt-click an item to star it. Alt-right-click to put it on your junk list."])
    end
    GameTooltip:Show()
end

ns.OnLoad(function()
    local bagFrame = ns.bagFrame
    if not bagFrame then
        return
    end

    -- ★ sitter där spelets sorteringsknapp satt (TOPRIGHT -9, -34, i höjd med sökrutan). Den
    -- är spelets egen menyknapp (DropdownButton), så menyn öppnas under den och fungerar
    -- med handkontroll som spelets egna menyer.
    starButton = CreateFrame("DropdownButton", nil, bagFrame)
    starButton:SetSize(BUTTON_SIZE, BUTTON_SIZE)
    starButton:SetPoint("TOPRIGHT", bagFrame, "TOPRIGHT", -9, -34)
    starButton:SetNormalAtlas(BUTTON_ATLAS)
    starButton:SetHighlightAtlas(BUTTON_ATLAS, "ADD")
    -- Bilden lite mindre än knappen, så att kugghjulet inte blir suddigt.
    for _, texture in ipairs({ starButton:GetNormalTexture(), starButton:GetHighlightTexture() }) do
        texture:ClearAllPoints()
        texture:SetPoint("CENTER")
        texture:SetSize(ICON_SIZE, ICON_SIZE)
    end
    starButton:SetupMenu(buildMenu)
    starButton:SetMenuAnchor(CreateAnchor("TOPRIGHT", starButton, "BOTTOMRIGHT", 0, -2))
    -- En sak som dras och släpps på ★ öppnar menyn (ett klick gör det redan).
    starButton:SetScript("OnReceiveDrag", function(self)
        self:OpenMenu()
    end)
    starButton:SetScript("OnEnter", function(self)
        starHovered = true
        updateStarButton()
        showTooltip(self)
    end)
    starButton:SetScript("OnLeave", function()
        starHovered = false
        updateStarButton()
        GameTooltip_Hide()
    end)
    -- Spelets menyknapp meddelar när menyn öppnas och stängs (DropdownButton.lua).
    starButton:RegisterCallback(DropdownButtonMixin.Event.OnMenuOpen, updateStarButton, starButton)
    starButton:RegisterCallback(DropdownButtonMixin.Event.OnMenuClose, updateStarButton, starButton)

    ns.RegisterEvent("CURSOR_CHANGED", updateStarButton)
    updateStarButton()

    -- Med mus ger spelet sökrutan en fast bredd (330), som slutade långt före knappen när
    -- Tidy Packs fönster är bredare. Därför går sökrutan i båda lägena fram till knappen,
    -- med samma avstånd till den som spelets egen sorteringsknapp hade.
    hooksecurefunc(bagFrame, "SetSearchBoxPoint", function(_, searchBox)
        searchBox:SetPoint("TOPRIGHT", bagFrame, "TOPRIGHT", -9 - BUTTON_SIZE - 9, -37)
    end)
end)
