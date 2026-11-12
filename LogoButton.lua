-- TidyPack – LogoButton.lua
-- Tidy Packs logga som knapp i stället för spelets väskrad nere till höger (BagsBar: ryggsäcken och
-- fyra väskplatser), användarens önskan 2026-11-11. Klick öppnar väskan, högerklick inställningarna,
-- och en sak som släpps på loggan läggs i väskorna. Loggan visar ingen siffra (användarens önskan); antalet
-- lediga platser står i tooltipen och i väskfönstret. Väskorna
-- byts i stället i väskraden längst ner i väskfönstret (Layout.lua).
-- Inställningen "Replace the game's bag buttons" (replaceBagBar) tar tillbaka spelets väskrad.
-- ⚠️ Spelets väskrad döljs efter varje Show, även i Edit Mode. Den går inte att flytta i Edit Mode
--    så länge loggan ersätter den; loggan följer mikromenyn (flyttas den, följer loggan med).

local _, ns = ...
local L = ns.L

local LOGO = "Interface\\AddOns\\TidyPack\\Media\\Logo"
local SIZE = 45
local FRAME_ATLAS = "ui-hud-actionbar-iconframe-bags" -- spelets ram för väskknapparna i Forever
local button

-- Visar loggan och döljer spelets väskrad, eller tvärtom.
function ns.ApplyBagBarSetting()
    if not button or not BagsBar then
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
    -- Namngiven, så att andra addons och /fstack kan hitta den. Namnet börjar med addonets.
    -- Ser ut som Forevers egen ryggsäcksknapp (Blizzard_MainMenuBarBagButtons/Camelot): 45×45, ikonen
    -- beskuren av spelets mask, spelets ram för väskknappar ovanpå och actionbarens ram bakom. Den står
    -- direkt till höger om mikromenyn, där spelets väskor började, så att det ser ut som att väskraden
    -- krympt till en väska med Tidy Packs logga.
    button = CreateFrame("Button", "TidyPackBagButton", UIParent)
    button:SetSize(SIZE, SIZE)
    if MicroMenuContainer then
        button:SetPoint("LEFT", MicroMenuContainer, "RIGHT", 10, 0)
    else
        button:SetPoint("RIGHT", BagsBar, "RIGHT", 0, 0)
    end
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
    button:SetScript("OnClick", function(_, mouseButton)
        if GetCursorInfo() == "item" and ns.PutCursorItemInBags then
            ns.PutCursorItemInBags()
        elseif mouseButton == "RightButton" then
            ns.OpenSettings()
        else
            ToggleAllBags()
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
    button:Hide()

    -- Spelet visar sin väskrad igen bland annat när Edit Mode ändrar något.
    hooksecurefunc(BagsBar, "Show", function(self)
        if ns.db.replaceBagBar then
            self:Hide()
        end
    end)
    ns.ApplyBagBarSetting()
end)
