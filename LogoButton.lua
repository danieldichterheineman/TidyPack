-- TidyPack – LogoButton.lua
-- Tidy Pack's logo as a button instead of the game's bag bar at the bottom right (BagsBar: the
-- backpack and four bag slots), the owner's wish 2026-11-11. Click opens the bags, right-click the
-- options, and an item dropped on the logo goes into the bags. The logo shows no number (the owner's
-- wish); the free slots are in the tooltip and in the bag window. Bags are
-- swapped in the bag row at the bottom of the bag window instead (Layout.lua).
-- The option "Replace the game's bag buttons" (replaceBagBar) brings back the game's bag bar.
-- ⚠️ The logo opens the bags by clicking the game's own backpack button (a secure button with
--    type "click"), never with ToggleAllBags from addon code. The game builds the item buttons when
--    the bags open, and opened from an addon's code the buttons become "the addon's". The game then
--    blocks everything only the game itself may do with them, e.g. disenchanting or using an item on
--    another ("blocked from an action", found 2026-11-12). A secure button can't be shown or
--    hidden in combat, so the option waits until combat is over.
-- ⚠️ The game's bag bar is hidden after every Show, also in Edit Mode. It can't be moved in Edit Mode
--    while the logo replaces it; the logo sits next to the micro menu but is anchored to UIParent (not
--    to MicroMenuContainer) so protected frames don't tie them together, and it moves after combat.

local _, ns = ...
local L = ns.L

local LOGO = "Interface\\AddOns\\TidyPack\\Media\\Logo"
local SIZE = 45
local FRAME_ATLAS = "ui-hud-actionbar-iconframe-bags" -- the game's frame for the bag buttons in Forever
local button

-- Shows the logo and hides the game's bag bar, or the other way round.
local waitingForCombat = false
local waitingForPosition = false

-- Places the logo right of the micro menu, but anchored to UIParent so protected frames
-- aren't tied to MicroMenuContainer (issue #8). Updated only outside combat.
local function updatePosition()
    if not button then
        return
    end
    if InCombatLockdown() then
        waitingForPosition = true
        return
    end
    waitingForPosition = false
    local scale = UIParent:GetEffectiveScale()
    if MicroMenuContainer then
        local left, bottom, width, height = MicroMenuContainer:GetScaledRect()
        if left and width and height then
            button:ClearAllPoints()
            button:SetPoint("LEFT", UIParent, "BOTTOMLEFT", (left + width) / scale + 10, (bottom + height / 2) / scale)
            return
        end
    end
    if BagsBar then
        local left, bottom, width, height = BagsBar:GetScaledRect()
        if left and width and height then
            button:ClearAllPoints()
            button:SetPoint("RIGHT", UIParent, "BOTTOMLEFT", (left + width) / scale, (bottom + height / 2) / scale)
            return
        end
    end
    button:ClearAllPoints()
    button:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -16, 16)
end

function ns.ApplyBagBarSetting()
    if not button or not BagsBar then
        return
    end
    if InCombatLockdown() then
        waitingForCombat = true -- done when combat is over (see the listener at the bottom)
        return
    end
    if ns.db.replaceBagBar then
        BagsBar:Hide()
        button:Show()
    else
        button:Hide()
        BagsBar:Show()
    end
end

ns.OnLoad(function()
    if not BagsBar then
        return
    end
    -- Named, so other addons and /fstack can find it. The name starts with the addon's.
    -- Looks like Forever's own backpack button (Blizzard_MainMenuBarBagButtons/Camelot): 45×45, the icon
    -- cropped by the game's mask, the game's bag-button frame on top and the action bar frame behind. It
    -- sits right of the micro menu, where the game's bags started, so it looks as if the bag bar
    -- shrank to one bag with Tidy Pack's logo.
    -- A secure button (SecureActionButtonTemplate) that clicks the game's backpack button, which
    -- remains although the bag bar is hidden. See ⚠️ at the top.
    button = CreateFrame("Button", "TidyPackBagButton", UIParent, "SecureActionButtonTemplate")
    button:SetSize(SIZE, SIZE)
    updatePosition()
    button:SetFrameStrata(BagsBar:GetFrameStrata())
    button:SetFrameLevel(BagsBar:GetFrameLevel() + 1)
    button.border = button:CreateTexture(nil, "BACKGROUND", nil, -3)
    button.border:SetAtlas("UI-HUD-ActionBar-Frame")
    button.border:SetPoint("TOPLEFT", -6, 6)
    button.border:SetPoint("BOTTOMRIGHT", 5, -5)
    button.icon = button:CreateTexture(nil, "BORDER")
    button.icon:SetTexture(LOGO)
    button.icon:SetAllPoints()
    button.mask = button:CreateMaskTexture()
    button.mask:SetAtlas("UI-HUD-ActionBar-IconFrame-Mask")
    button.mask:SetAllPoints(button.icon)
    button.icon:AddMaskTexture(button.mask)
    button:SetNormalAtlas(FRAME_ATLAS)
    button:SetPushedAtlas(FRAME_ATLAS)
    button:SetHighlightAtlas(FRAME_ATLAS, "ADD")
    button:GetHighlightTexture():SetAlpha(0.4)
    for _, texture in ipairs({ button:GetNormalTexture(), button:GetPushedTexture() }) do
        texture:ClearAllPoints()
        texture:SetPoint("TOPLEFT")
        texture:SetSize(46, 46)
    end
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    -- By default secure buttons do their job when the button is pressed down (the setting
    -- ActionButtonUseKeyDown, SecureActionButton_OnClick), but this button listens only for release.
    -- useOnKeyDown = false: the job is done on release, once per click.
    -- Left-click (type1) always clicks the game's backpack button, also in combat. Right-click
    -- (type2) has no secure click by default, so in combat it never closes open bags but only
    -- opens the gear menu; outside combat the bags open first if they are closed.
    button:SetAttribute("useOnKeyDown", false)
    button:SetAttribute("type1", "click")
    button:SetAttribute("type2", nil)
    button:SetAttribute("clickbutton", MainMenuBarBackpackButton)
    -- Before the click: with an item on the cursor Tidy Pack puts it in the bags, and a right-click
    -- with closed bags outside combat turns on type2 for a moment so the backpack opens before
    -- the menu. Attributes can't change in combat.
    local putItem = false
    button:SetScript("PreClick", function(self, mouseButton)
        putItem = false
        if InCombatLockdown() then
            return
        end
        putItem = GetCursorInfo() == "item" and ns.PutCursorItemInBags ~= nil
        local bagOpen = ns.bagFrame and ns.bagFrame:IsShown()
        if putItem then
            self:SetAttribute("type1", nil)
            self:SetAttribute("type2", nil)
        elseif mouseButton == "RightButton" and not bagOpen then
            self:SetAttribute("type1", "click")
            self:SetAttribute("type2", "click")
        else
            self:SetAttribute("type1", "click")
            self:SetAttribute("type2", nil)
        end
    end)
    button:SetScript("PostClick", function(self, mouseButton)
        -- Restore the defaults at once, so a later click in combat always behaves the same.
        if not InCombatLockdown() then
            self:SetAttribute("type1", "click")
            self:SetAttribute("type2", nil)
        end
        if putItem then
            putItem = false
            ns.PutCursorItemInBags()
        elseif mouseButton == "RightButton" then
            -- One frame later, when the bags the backpack button opened are shown.
            C_Timer.After(0, function()
                ns.OpenSettings()
            end)
        end
    end)
    button:SetScript("OnReceiveDrag", function()
        if ns.PutCursorItemInBags then
            ns.PutCursorItemInBags()
        end
    end)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip_SetTitle(GameTooltip, L["Tidy Pack"])
        GameTooltip_AddNormalLine(GameTooltip, L["Free slots: %d"]:format(C_Container.CalculateTotalNumberOfFreeBagSlots()))
        GameTooltip_AddInstructionLine(GameTooltip, L["Click to open your bags, right-click for options."])
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", GameTooltip_Hide)
    -- A secure button can't be hidden in combat (e.g. /reload in the middle of combat);
    -- ApplyBagBarSetting then waits until combat is over.
    if not InCombatLockdown() then
        button:Hide()
    end

    -- The game shows its bag bar again, e.g. when Edit Mode changes something.
    hooksecurefunc(BagsBar, "Show", function(self)
        if ns.db.replaceBagBar then
            self:Hide()
        end
    end)
    if MicroMenuContainer then
        hooksecurefunc(MicroMenuContainer, "SetPoint", updatePosition)
        hooksecurefunc(MicroMenuContainer, "Layout", updatePosition)
    end
    ns.RegisterEvent("PLAYER_ENTERING_WORLD", updatePosition)
    ns.RegisterEvent("UI_SCALE_CHANGED", updatePosition)
    -- The option or the micro menu changed in combat: do it when combat is over.
    ns.RegisterEvent("PLAYER_REGEN_ENABLED", function()
        if waitingForCombat then
            waitingForCombat = false
            ns.ApplyBagBarSetting()
        end
        if waitingForPosition then
            waitingForPosition = false
            updatePosition()
        end
    end)
    ns.ApplyBagBarSetting()
end)
