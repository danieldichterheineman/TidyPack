-- TidyPack – Marks.lua
-- Två märken som du sätter själv. De sparas per sorts sak (itemID) och gäller alla dina
-- karaktärer:
--   Favorit (stjärna): saken hamnar i gruppen Favorites överst.
--   Skräplistan: saken hamnar sist i Junk med spelets eget skräpmynt. Tidy Pack frågar om
--   den ska raderas när du lootar den (MakeRoom.lua), och den föreslås först när
--   väskorna är fulla.
-- Så märker du:
--   - Mus: Alt-vänsterklick = favorit, Alt-högerklick = skräplistan. Spelets klick gör
--     ingenting med Alt nedtryckt (i Forever är Alt bara kopplat till besvärjelser och
--     utrustningsmenyer, se Bindings_Camelot.xml i spelets kod).
--   - Mus och handkontroll: släpp saken på kugghjulet uppe till höger. Spelets egen meny
--     frågar då om saken ska bli favorit, hamna på skräplistan eller läggas i ett set eller
--     en egen grupp.
--   - Skräplistan har också en egen sida i inställningarna (Options.lua).
-- Samma sak en gång till tar bort märket. En sak kan inte vara både favorit och på
-- skräplistan.
-- Kugghjulet är den enda knapp Tidy Pack lägger i väskfönstret. Den sitter där spelets
-- sorteringsknapp satt. Utan en sak på markören öppnar den skräplistan, de egna grupperna och
-- inställningarna.

local _, ns = ...
local L = ns.L

-- Knappens bild: spelets kugghjul för inställningar (questlog-icon-setting, samma som
-- spelets UIPanelIconDropdownButtonTemplate).
local BUTTON_ATLAS = "questlog-icon-setting"
local BUTTON_SIZE = 20
local ICON_SIZE = 15
local GOLD_R, GOLD_G, GOLD_B = 1, 0.82, 0 -- spelets gula textfärg

local gearButton
local gearHovered = false -- markören (mus eller handkontroll) står på kugghjulet
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

local showItemMenu -- definieras längre ner, efter menyn

-- Körs efter spelets eget klick på en ruta i väskorna (HookScript). Alt-klick öppnar menyn för saken
-- (favorit, skräplista, set, grupp). Spelet kan ha plockat upp saken på markören; den läggs då tillbaka.
local function onItemButtonClick(button, mouseButton)
    if not IsAltKeyDown() or mouseButton ~= "LeftButton" then
        return
    end
    local info = C_Container.GetContainerItemInfo(button:GetBagID(), button:GetID())
    if not info then
        return
    end
    ClearCursor()
    showItemMenu(button, info.itemID)
end

-- Layout.lua anropar den här för varje ruta det visar. Varje ruta får Alt-klicken en gång.
-- Öppnar kugghjulets meny (Options.lua: /tidypack, addonmenyn och loggan).
function ns.OpenGearMenu()
    if gearButton and gearButton:IsVisible() then
        gearButton:OpenMenu()
    end
end

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

-- Kugghjulet är svagt tills du håller en sak, pekar på den eller har dess meny öppen. När du håller
-- en sak lyser den också upp, eftersom du kan släppa saken där.
local gearLabel -- "Drop here for options" under kugghjulet medan du håller en sak

local function updateGearButton()
    if not gearButton then
        return
    end
    local holding = cursorItemID() ~= nil
    if gearLabel then
        gearLabel:SetShown(holding)
    end
    local active = holding or gearHovered or gearButton:IsMenuOpen()
    gearButton:SetAlpha(active and 1 or 0.85)
    if holding then
        gearButton:LockHighlight()
    else
        gearButton:UnlockHighlight()
    end
end

-- Menyn under kugghjulet, byggd av spelets eget menysystem. Med en sak på markören: favorit,
-- skräplistan, set eller egen grupp. Annars: skräplistan, grupperna och inställningarna (med
-- handkontroll också byta flik).
local function buildMenu(_, rootDescription, itemOverride)
    local itemID = itemOverride or cursorItemID()
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
        if #ns.GetSets() < ns.MAX_SETS then
            setMenu:CreateButton(L["New Set..."], function()
                ClearCursor()
                ns.AskNewSet(itemID)
            end)
        end
        -- Egna grupper (Groups.lua): den här saken, eller hela typen.
        if ns.AddGroupMenus then
            ns.AddGroupMenus(rootDescription, itemID)
        end
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
        -- Skräplistan och grupperna öppnas i väskan (Panels.lua).
        rootDescription:CreateButton(L["Junk List..."], function()
            ns.OpenPanel("junk")
        end)
        rootDescription:CreateButton(L["Groups..."], function()
            ns.OpenPanel("groups")
        end)
        -- Alla inställningar, i tre undermenyer (ns.optionMenus i Options.lua). Menyn står kvar när
        -- en kryssruta klickas (spelets MenuResponse.Refresh), så ändringen syns direkt i väskan.
        rootDescription:CreateDivider()
        for _, menu in ipairs(ns.optionMenus or {}) do
            local submenu = rootDescription:CreateButton(menu.title)
            for _, option in ipairs(menu.options) do
                local checkbox = submenu:CreateCheckbox(option.name, function()
                    return ns.db[option.key] ~= false
                end, function()
                    ns.db[option.key] = ns.db[option.key] == false
                    if option.onChange then
                        option.onChange()
                    end
                end)
                checkbox:SetTooltip(function(tooltip, elementDescription)
                    GameTooltip_SetTitle(tooltip, MenuUtil.GetElementText(elementDescription))
                    GameTooltip_AddNormalLine(tooltip, option.tooltip)
                end)
                if option.enabled then
                    checkbox:SetEnabled(option.enabled)
                end
            end
            if menu.extra then
                menu.extra(submenu)
            end
        end
        rootDescription:CreateDivider()
        rootDescription:CreateButton(L["Show Tips Again"], function()
            if ns.ResetTour then
                ns.ResetTour()
                ns.Print(L["The tips show the next time you open your bags."])
            end
        end)
    end
end

-- Öppnar menyn för en sak vid rutan (Alt-klick).
showItemMenu = function(button, itemID)
    MenuUtil.CreateContextMenu(button, function(owner, rootDescription)
        buildMenu(owner, rootDescription, itemID)
    end)
end

-- Tooltipen följer hur du spelar: med handkontroll finns inga Alt-klick, men väl knappen A
-- (spelet visar den symbol som din kontroll har).
local function showTooltip(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip_SetTitle(GameTooltip, L["Tidy Pack"])
    if InputUtil.IsGamepadUIEnabled() then
        local icon = ns.GamepadIcon and ns.GamepadIcon(GAMEPAD_FACE_BOTTOM) or ""
        local text = L["Pick up an item, then drop it here to make it a favorite, put it on your junk list or add it to a set or group."]
        GameTooltip_AddNormalLine(GameTooltip, icon ~= "" and (icon .. " " .. text) or text)
    else
        GameTooltip_AddNormalLine(GameTooltip, L["Drop an item here to make it a favorite, put it on your junk list or add it to a set or group."])
    end
    GameTooltip_AddNormalLine(GameTooltip, L["Click for your junk list, groups and settings."])
    if not InputUtil.IsGamepadUIEnabled() then
        GameTooltip_AddBlankLineToTooltip(GameTooltip)
        GameTooltip_AddInstructionLine(GameTooltip, ns.KeyText(L["Alt-click an item for its Tidy Pack options: favorite, junk list, sets and groups."]))
    end
    GameTooltip:Show()
end

-- En rad i tooltipen på varje sak i Tidy Packs väska om Alt-klick (inte med handkontroll, som saknar Alt).
TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
    if tooltip ~= GameTooltip or not data or ns.db == nil or InputUtil.IsGamepadUIEnabled() then
        return
    end
    local owner = tooltip:GetOwner()
    if owner and hookedButtons[owner] and owner:IsShown() then
        tooltip:AddLine(ns.KeyText(L["Alt-click: Tidy Pack options"]), 0.44, 0.71, 1)
    end
end)

ns.OnLoad(function()
    local bagFrame = ns.bagFrame
    if not bagFrame then
        return
    end

    -- Kugghjulet är Tidy Packs enda knapp i fönstret. Det är spelets egen menyknapp (DropdownButton), så menyn öppnas under den och fungerar
    -- med handkontroll som spelets egna menyer.
    gearButton = CreateFrame("DropdownButton", nil, bagFrame)
    ns.gearButton = gearButton -- guiden i Tour.lua pekar på den
    gearButton:SetSize(BUTTON_SIZE, BUTTON_SIZE)
    -- Fönsterhuvudet (titelraden) är en egen ram ovanpå fönstret; kugghjulet måste ligga över den,
    -- annars döljs det bakom titelraden.
    -- Spelets titelrad ritas över en högre nivå än fönstret i övrigt, så kugghjulet läggs i ett
    -- högre lager (strata) för att säkert synas ovanpå den.
    gearButton:SetFrameStrata("HIGH")
    gearButton:SetFrameLevel(bagFrame:GetFrameLevel() + 30)
    -- Sitter i fönsterhuvudet, till vänster om stängknappen (finns den inte: nära hörnet).
    if bagFrame.CloseButton then
        gearButton:SetPoint("RIGHT", bagFrame.CloseButton, "LEFT", -2, 0)
    else
        gearButton:SetPoint("TOPRIGHT", bagFrame, "TOPRIGHT", -30, -3)
    end
    gearButton:SetNormalAtlas(BUTTON_ATLAS)
    gearButton:SetHighlightAtlas(BUTTON_ATLAS, "ADD")
    -- Bilden lite mindre än knappen, så att kugghjulet inte blir suddigt.
    -- Kugghjulet färgas gult (bilden är grå i sig). Ingen ram runt det (användarens önskan 2026-11-11).
    for _, texture in ipairs({ gearButton:GetNormalTexture(), gearButton:GetHighlightTexture() }) do
        texture:ClearAllPoints()
        texture:SetPoint("CENTER")
        texture:SetSize(ICON_SIZE, ICON_SIZE)
        texture:SetDesaturated(true)
        texture:SetVertexColor(GOLD_R, GOLD_G, GOLD_B)
    end
    gearLabel = CreateFrame("Frame", nil, bagFrame)
    gearLabel:SetFrameStrata("HIGH")
    gearLabel:SetFrameLevel(gearButton:GetFrameLevel() + 1)
    -- Till vänster om kugghjulet, i titelraden (under kugghjulet korsade den fönstrets kant).
    gearLabel:SetPoint("RIGHT", gearButton, "LEFT", -4, 0)
    gearLabel.bg = gearLabel:CreateTexture(nil, "BACKGROUND")
    gearLabel.bg:SetAllPoints()
    gearLabel.bg:SetColorTexture(0, 0, 0, 0.8)
    gearLabel.text = gearLabel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    gearLabel.text:SetPoint("CENTER")
    gearLabel.text:SetText(L["Drop here for options"] .. " |TInterface\\ChatFrame\\ChatFrameExpandArrow:12:12|t")
    gearLabel:SetSize(gearLabel.text:GetStringWidth() + 14, 16)
    gearLabel:Hide()
    gearButton:SetupMenu(buildMenu)
    gearButton:SetMenuAnchor(CreateAnchor("TOPRIGHT", gearButton, "BOTTOMRIGHT", 0, -2))
    -- En sak som dras och släpps på kugghjulet öppnar menyn (ett klick gör det redan).
    gearButton:SetScript("OnReceiveDrag", function(self)
        self:OpenMenu()
    end)
    gearButton:SetScript("OnEnter", function(self)
        gearHovered = true
        updateGearButton()
        showTooltip(self)
    end)
    gearButton:SetScript("OnLeave", function()
        gearHovered = false
        updateGearButton()
        GameTooltip_Hide()
    end)
    -- Spelets menyknapp meddelar när menyn öppnas och stängs (DropdownButton.lua).
    gearButton:RegisterCallback(DropdownButtonMixin.Event.OnMenuOpen, updateGearButton, gearButton)
    gearButton:RegisterCallback(DropdownButtonMixin.Event.OnMenuClose, updateGearButton, gearButton)

    ns.RegisterEvent("CURSOR_CHANGED", updateGearButton)
    updateGearButton()
end)
