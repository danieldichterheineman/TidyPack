-- TidyPack – Marks.lua
-- Two marks you set yourself. They are saved per kind of item (itemID) and apply to all your
-- characters:
--   Favorite (star): the item goes to the group Favorites at the top.
--   Junk list: the item goes last in Junk with the game's own junk coin. Tidy Pack asks whether
--   to delete it when you loot it (MakeRoom.lua), and it is suggested first when the bags
--   are full.
-- How to mark:
--   - Mouse: Alt-click an item for its menu (favorite, junk list, own groups). The game's click
--     does nothing with Alt held (in Forever Alt is only bound to spells and equipment
--     menus, see Bindings_Camelot.xml in the game's code).
--   - Mouse and controller: drop the item on the gear at the top right. The game's own menu
--     then asks whether it should be a favorite, go on the junk list or into an own group.
--   - The junk list also has its own view in the bags (Panels.lua).
-- The same choice again removes the mark. An item can't be both a favorite and on the junk
-- list.
-- The gear is the only button Tidy Pack puts in the bag window. It sits where the game's
-- sort button was. Without an item on the cursor it opens the junk list, the own groups and
-- the options.

local _, ns = ...
local L = ns.L

-- The button's image: the game's gear for settings (questlog-icon-setting, the same as the
-- game's UIPanelIconDropdownButtonTemplate).
local BUTTON_ATLAS = "questlog-icon-setting"
local BUTTON_SIZE = 20
local ICON_SIZE = 15
local GOLD_R, GOLD_G, GOLD_B = 1, 0.82, 0 -- the game's yellow text color

local gearButton
local gearHovered = false -- the cursor (mouse or controller) is on the gear
local hookedButtons = setmetatable({}, { __mode = "k" })

function ns.IsFavorite(itemID)
    return ns.db ~= nil and ns.db.favorites[itemID] == true
end

function ns.IsJunkMarked(itemID)
    return ns.db ~= nil and ns.db.junk[itemID] == true
end

-- Sets or removes a mark. A new mark removes the other, so an item is never both a favorite
-- and on the junk list.
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
        ns.JunkListChanged(itemID) -- MakeRoom.lua counts the item from now on
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

-- Adds (true) or removes (false) an item on the junk list. Used by the
-- options.
function ns.SetJunk(itemID, onList)
    if itemID and (ns.db.junk[itemID] == true) ~= onList then
        ns.ToggleJunk(itemID)
    end
end

local showItemMenu -- defined further down, after the menu

-- Runs after the game's own click on an item button (HookScript). Alt-click opens the item's menu
-- (favorite, junk list, group). The game may have picked the item up; it is then put back.
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

-- Layout.lua calls this for every button it shows. Each button gets the Alt-click once.
-- Opens the gear menu (Options.lua: /tidypack, the addon menu and the logo).
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

-- The item on the mouse cursor (or the controller's cursor) right now, if any.
local function cursorItemID()
    local kind, itemID = GetCursorInfo()
    if kind == "item" then
        return itemID
    end
    return nil
end

-- The gear is faint until you hold an item, point at it or have its menu open. While you hold
-- an item it lights up too, because you can drop the item there.
local gearLabel -- "Drop here for options" under the gear while you hold an item

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

-- The Language submenu (Locales.lua): Automatic follows the game's language, and each language has
-- its own name. The choice is saved at once but applies after /reload, because tabs and buttons
-- already have their texts; the bottom button does /reload (C_UI.Reload) and is only clickable when the choice changes the language.
local function languageName(code)
    for _, language in ipairs(ns.LANGUAGES) do
        if language.code == code then
            return language.name
        end
    end
    return code
end

local function addLanguageMenu(rootDescription)
    local menu = rootDescription:CreateButton(L["Language"])
    local function isSelected(choice)
        return (ns.db.language or "auto") == choice
    end
    local function setSelected(choice)
        ns.db.language = choice
        if ns.ResolveLanguage(choice) ~= ns.language then
            ns.Print(L["Tidy Pack switches language after a reload of the interface (/reload)."])
        end
        return MenuResponse.Refresh -- the menu stays open, so the button below can be clicked
    end
    menu:CreateRadio(L["Automatic (%s)"]:format(languageName(ns.ResolveLanguage("auto"))),
        isSelected, setSelected, "auto")
    for _, language in ipairs(ns.LANGUAGES) do
        menu:CreateRadio(language.name, isSelected, setSelected, language.code)
    end
    menu:CreateDivider()
    local reload = menu:CreateButton(L["Reload Now"], function()
        C_UI.Reload()
    end)
    reload:SetEnabled(function()
        return ns.ResolveLanguage(ns.db.language) ~= ns.language
    end)
end

-- The menu under the gear, built with the game's own menu system. With an item on the cursor:
-- favorite, junk list or own group. Otherwise: the junk list, the groups and the options.
local function buildMenu(_, rootDescription, itemOverride)
    local itemID = itemOverride or cursorItemID()
    if itemID then
        rootDescription:CreateTitle(C_Item.GetItemNameByID(itemID) or L["Item"])
        rootDescription:CreateButton(ns.IsFavorite(itemID) and L["Remove from Favorites"] or L["Add to Favorites"], function()
            ClearCursor() -- the item goes back to its place
            ns.ToggleFavorite(itemID)
        end)
        rootDescription:CreateButton(ns.IsJunkMarked(itemID) and L["Remove from Junk List"] or L["Add to Junk List"], function()
            ClearCursor()
            ns.ToggleJunk(itemID)
        end)
        -- Own groups (Groups.lua): this item, or the whole type.
        if ns.AddGroupMenus then
            ns.AddGroupMenus(rootDescription, itemID)
        end
    else
        rootDescription:CreateTitle(L["Tidy Pack"])
        -- The junk list and the groups open in the bags (Panels.lua).
        rootDescription:CreateButton(L["Junk List..."], function()
            ns.OpenPanel("junk")
        end)
        rootDescription:CreateButton(L["Groups..."], function()
            ns.OpenPanel("groups")
        end)
        -- All options, in three submenus (ns.optionMenus in Options.lua). The menu stays open when
        -- a checkbox is clicked (the game's MenuResponse.Refresh), so the change shows in the bags at once.
        rootDescription:CreateDivider()
        for _, menu in ipairs(ns.optionMenus or {}) do
            local submenu = rootDescription:CreateButton(menu.title)
            for index, option in ipairs(menu.options) do
                if option.section then
                    -- A small heading, with a line above except at the top.
                    if index > 1 then
                        submenu:CreateDivider()
                    end
                    submenu:CreateTitle(option.section)
                else
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
            end
            if menu.extra then
                menu.extra(submenu)
            end
        end
        if ns.LANGUAGES then
            addLanguageMenu(rootDescription)
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

-- Opens the item's menu at its button (Alt-click).
showItemMenu = function(button, itemID)
    MenuUtil.CreateContextMenu(button, function(owner, rootDescription)
        buildMenu(owner, rootDescription, itemID)
    end)
end

-- The tooltip follows how you play: with a controller there is no Alt-click, but there is the A
-- button (the game shows the symbol your controller has).
local function showTooltip(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    -- The same style as Tidy Pack's other buttons: a title, a line about what it is, a line about how.
    GameTooltip_SetTitle(GameTooltip, L["Tidy Pack"])
    GameTooltip_AddNormalLine(GameTooltip, L["Options, your junk list and your own groups."])
    if InputUtil.IsGamepadUIEnabled() then
        local icon = ns.GamepadIcon and ns.GamepadIcon(GAMEPAD_FACE_BOTTOM) or ""
        local text = L["Pick up an item and drop it here for its options."]
        GameTooltip_AddInstructionLine(GameTooltip, icon ~= "" and (icon .. " " .. text) or text)
    else
        GameTooltip_AddInstructionLine(GameTooltip, ns.KeyText(L["Drop an item here, or Alt-click one, for its options."]))
    end
    GameTooltip:Show()
end

-- A line in the tooltip of every item in Tidy Pack's bags about Alt-click (not with a controller, which has no Alt).
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

    -- The gear is Tidy Pack's only button in the window. It is the game's own menu button (DropdownButton), so the menu opens under it and works
    -- with a controller like the game's own menus.
    gearButton = CreateFrame("DropdownButton", nil, bagFrame)
    ns.gearButton = gearButton -- the guide in Tour.lua points at it
    gearButton:SetSize(BUTTON_SIZE, BUTTON_SIZE)
    -- The window header (title bar) is its own frame on top of the window; the gear must be above it,
    -- otherwise it hides behind the title bar.
    -- The game draws its title bar at a higher level than the rest of the window, so the gear goes in a
    -- higher layer (strata) to be sure to show on top of it.
    gearButton:SetFrameStrata("HIGH")
    gearButton:SetFrameLevel(bagFrame:GetFrameLevel() + 30)
    -- Sits in the window header, left of the close button (if there is none: near the corner).
    if bagFrame.CloseButton then
        gearButton:SetPoint("RIGHT", bagFrame.CloseButton, "LEFT", -2, 0)
    else
        gearButton:SetPoint("TOPRIGHT", bagFrame, "TOPRIGHT", -30, -3)
    end
    gearButton:SetNormalAtlas(BUTTON_ATLAS)
    gearButton:SetHighlightAtlas(BUTTON_ATLAS, "ADD")
    -- The image a little smaller than the button, so the gear doesn't blur.
    -- The gear is colored yellow (the image itself is grey). No frame around it (the owner's wish 2026-11-11).
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
    -- Left of the gear, in the title bar (below the gear it crossed the window's edge).
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
    -- An item dragged and dropped on the gear opens the menu (a click already does).
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
    -- The game's menu button reports when the menu opens and closes (DropdownButton.lua).
    gearButton:RegisterCallback(DropdownButtonMixin.Event.OnMenuOpen, updateGearButton, gearButton)
    gearButton:RegisterCallback(DropdownButtonMixin.Event.OnMenuClose, updateGearButton, gearButton)

    ns.RegisterEvent("CURSOR_CHANGED", updateGearButton)
    updateGearButton()
end)
