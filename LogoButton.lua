-- TidyPack – LogoButton.lua
-- Tidy Packs logga som knapp i stället för spelets väskrad nere till höger (BagsBar: ryggsäcken och
-- fyra väskplatser), användarens önskan 2026-11-11. Klick öppnar väskan, högerklick inställningarna,
-- och en sak som släpps på loggan läggs i väskorna. Loggan visar ingen siffra (användarens önskan); antalet
-- lediga platser står i tooltipen och i väskfönstret. Väskorna
-- byts i stället i väskraden längst ner i väskfönstret (Layout.lua).
-- Inställningen "Replace the game's bag buttons" (replaceBagBar) tar tillbaka spelets väskrad.
-- ⚠️ Loggan öppnar väskan genom att klicka på spelets egen ryggsäcksknapp (en säker knapp med
--    type "click"), aldrig med ToggleAllBags från addonets kod. Spelet bygger väskans rutor när den
--    öppnas, och öppnas den från ett addons kod blir rutorna "addonets". Då stoppar spelet allt som
--    bara spelet självt får göra med dem, till exempel att disenchanta eller använda en sak på en
--    annan (rutan "blocked from an action", hittat 2026-11-12). En säker knapp kan inte visas eller
--    döljas i strid, så inställningen väntar tills striden är över.
-- ⚠️ Spelets väskrad döljs efter varje Show, även i Edit Mode. Den går inte att flytta i Edit Mode
--    så länge loggan ersätter den; loggan placeras vid mikromenyn men är ankrad i UIParent (inte
--    i MicroMenuContainer) så att skyddade ramar inte binder ihop dem, och flyttas efter strid.

local _, ns = ...
local L = ns.L

local LOGO = "Interface\\AddOns\\TidyPack\\Media\\Logo"
local SIZE = 45
local FRAME_ATLAS = "ui-hud-actionbar-iconframe-bags" -- spelets ram för väskknapparna i Forever
local button

-- Visar loggan och döljer spelets väskrad, eller tvärtom.
local waitingForCombat = false
local waitingForPosition = false

-- Placerar loggan direkt till höger om mikromenyn, men ankrad i UIParent så att skyddade
-- ramar inte kopplas till MicroMenuContainer (issue #8). Uppdateras bara utanför strid.
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
        waitingForCombat = true -- görs när striden är över (se lyssnaren längst ner)
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
    -- En säker knapp (SecureActionButtonTemplate) som klickar på spelets ryggsäcksknapp, som finns
    -- kvar fast väskraden är dold. Se ⚠️ högst upp.
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
    -- Säkra knappar gör som standard sitt jobb när knappen trycks ned (inställningen
    -- ActionButtonUseKeyDown, SecureActionButton_OnClick), men knappen lyssnar bara på uppsläpp.
    -- useOnKeyDown = false: jobbet görs vid uppsläpp, en gång per klick.
    -- Vänsterklick (type1) klickar alltid på spelets ryggsäcksknapp, även i strid. Högerklick
    -- (type2) har inget säkert klick som standard, så i strid stänger det aldrig en öppen väska
    -- utan öppnar bara kugghjulets meny; utanför strid öppnas väskan först om den är stängd.
    button:SetAttribute("useOnKeyDown", false)
    button:SetAttribute("type1", "click")
    button:SetAttribute("type2", nil)
    button:SetAttribute("clickbutton", MainMenuBarBackpackButton)
    -- Före klicket: med en sak på markören lägger Tidy Pack den i väskorna, och högerklick när
    -- väskan är stängd utanför strid slår tillfälligt på type2 så att ryggsäcken öppnas före
    -- menyn. Attribut kan inte ändras i strid.
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
        -- Återställ standardvärdena direkt så att ett senare klick i strid alltid beter sig likadant.
        if not InCombatLockdown() then
            self:SetAttribute("type1", "click")
            self:SetAttribute("type2", nil)
        end
        if putItem then
            putItem = false
            ns.PutCursorItemInBags()
        elseif mouseButton == "RightButton" then
            -- En bildruta senare, när väskan som ryggsäcksknappen öppnade syns.
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
    -- En säker knapp kan inte döljas i strid (t.ex. /reload mitt i en strid); ApplyBagBarSetting
    -- väntar då tills striden är över.
    if not InCombatLockdown() then
        button:Hide()
    end

    -- Spelet visar sin väskrad igen bland annat när Edit Mode ändrar något.
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
    -- Inställningen eller mikromenyn ändrades i strid: gör det när striden är över.
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
