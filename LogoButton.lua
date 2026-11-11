-- TidyPack – LogoButton.lua
-- Tidy Packs logga som knapp i stället för spelets väskrad nere till höger (BagsBar: ryggsäcken och
-- fyra väskplatser), användarens önskan 2026-11-11. Klick öppnar väskan, högerklick inställningarna,
-- och en sak som släpps på loggan läggs i väskorna. Siffran är antalet lediga platser. Väskorna
-- byts i stället i väskraden längst ner i väskfönstret (Layout.lua).
-- Inställningen "Replace the game's bag buttons" (replaceBagBar) tar tillbaka spelets väskrad.
-- ⚠️ Spelets väskrad döljs efter varje Show, även i Edit Mode. Den går inte att flytta i Edit Mode
--    så länge loggan ersätter den; loggan står där väskraden står.

local _, ns = ...
local L = ns.L

local LOGO = "Interface\\AddOns\\TidyPack\\Media\\Logo"
local SIZE = 40
local button

local function updateCount()
    if button then
        button.count:SetText(("(%d)"):format(C_Container.CalculateTotalNumberOfFreeBagSlots()))
    end
end

-- Visar loggan och döljer spelets väskrad, eller tvärtom.
function ns.ApplyBagBarSetting()
    if not button or not BagsBar then
        return
    end
    if ns.db.replaceBagBar then
        BagsBar:Hide()
        button:Show()
        updateCount()
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
    button = CreateFrame("Button", "TidyPackBagButton", UIParent)
    button:SetSize(SIZE, SIZE)
    button:SetPoint("RIGHT", BagsBar, "RIGHT", 0, 0)
    button:SetFrameStrata(BagsBar:GetFrameStrata())
    button:SetFrameLevel(BagsBar:GetFrameLevel() + 1)
    button:SetNormalTexture(LOGO)
    button:SetPushedTexture(LOGO)
    button:GetPushedTexture():SetPoint("TOPLEFT", 1, -1)
    button:GetPushedTexture():SetPoint("BOTTOMRIGHT", 1, -1)
    button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    button.count = button:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    button.count:SetPoint("BOTTOM", 0, -2)
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
        GameTooltip_AddInstructionLine(GameTooltip, L["Click to open your bags. Right-click for the settings."])
        GameTooltip_AddInstructionLine(GameTooltip, L["Drop an item here to put it in your bags."])
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
    ns.RegisterEvent("BAG_UPDATE_DELAYED", updateCount)
    ns.ApplyBagBarSetting()
end)
