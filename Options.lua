-- TidyPack – Options.lua
-- Alla inställningar finns under kugghjulet i väskfönstret (användarens önskan 2026-11-12, skissen
-- .design/sketch-settings-in-bag.html): ns.optionMenus nedan blir undermenyerna Show, Merchants and loot
-- och Bag and bank (Marks.lua), och skräplistan och grupperna öppnas i väskan (Panels.lua).
-- Sidan i spelets inställningar (Esc → Options → AddOns → Tidy Pack) har inga val: den berättar vad
-- Tidy Pack är och vem som gjort det, hur man använder det och var det finns (CurseForge).
-- /tidypack, addonmenyn vid minikartan och högerklick på loggan öppnar väskan med kugghjulets meny.

local addonName, ns = ...
local L = ns.L

local WEBSITE_FALLBACK = "https://www.curseforge.com/wow/addons/tidy-pack"

local function refresh()
    if ns.Refresh then
        ns.Refresh()
    end
end

---------------------------------------------------------------------------
-- Inställningarna i kugghjulets meny
---------------------------------------------------------------------------
-- key är nyckeln i ns.db (Core.lua har standardvärdena, alla sanna). onChange körs efter en ändring.
-- enabled (en funktion) gör raden grå när den inte går att ändra.

ns.optionMenus = {
    {
        title = L["Show"],
        options = {
            { key = "itemLevelAndBoE", name = L["Item level and BoE"],
                tooltip = L["On uncommon or better weapons and armor."], onChange = refresh },
            { key = "upgradeArrows", name = L["Upgrade arrows"],
                tooltip = L["A green arrow on weapons and armor you can use that have a higher item level than what you wear in that slot."],
                onChange = refresh },
            { key = "showQuestItemsInBags", name = L["Quest items in Bags"],
                tooltip = L["Turn off to keep quest items in the Quests tab only. The Bags tab then shows a line saying how many slots they use."],
                onChange = refresh },
            { key = "questHints", name = L["Marks for later quests"],
                tooltip = L["Requires the addon Questie. Items needed for quests you can take now or within 5 levels get a yellow exclamation mark and a line in their tooltip."],
                onChange = function()
                    if ns.QuestHintsChanged then
                        ns.QuestHintsChanged()
                    end
                end,
                enabled = function()
                    return ns.HasQuestie ~= nil and ns.HasQuestie()
                end },
            { key = "showCounts", name = L["Bag and bank counts"],
                tooltip = L["Item tooltips show how many you have in your bags and in your bank, and the total. Only for items in your bank, and only for this character."] },
            { key = "tooltipLines", name = L["Tidy Pack lines in tooltips"],
                tooltip = L["The lines \"Tidy Pack set: ...\" and \"Tidy Pack group: ...\" in item tooltips. Lines about quests and locks always show."] },
            { key = "junkValue", name = L["Junk value in the header"],
                tooltip = L["What your junk sells for, next to the Junk header."], onChange = refresh },
        },
    },
    {
        title = L["Merchants and loot"],
        options = {
            { key = "lockAtMerchant", name = L["Lock items at merchants"],
                tooltip = L["At merchants, items your quests need and items in your sets get a lock and can't be clicked, so you can't sell them by mistake. The merchant's own Sell All Junk button doesn't know about these locks."],
                onChange = refresh },
            { key = "suggestOnLoot", name = L["Ask to delete junk list loot"],
                tooltip = L["When you loot an item on your junk list, Tidy Pack asks right away whether to delete it. Nothing is deleted until you press Delete."] },
            { key = "suggestWhenFull", name = L["Suggest a deletion when full"],
                tooltip = L["When your bags are full and something can't be looted, a panel under the loot window suggests an item to delete: your junk list first, then your cheapest grey item if the new loot is worth more. Nothing is deleted until you press Delete."] },
        },
    },
    {
        title = L["Bag and bank"],
        options = {
            { key = "replaceBagBar", name = L["Replace the game's bag buttons"],
                tooltip = L["Shows the Tidy Pack logo instead of the game's backpack and bag buttons at the bottom right. Click it to open your bags; swap bags in the bag row at the bottom of the bag window. Turn off to get the game's buttons back."],
                onChange = function()
                    if ns.ApplyBagBarSetting then
                        ns.ApplyBagBarSetting()
                    end
                end },
            { key = "bankTab", name = L["Use the Bank tab at bankers"],
                tooltip = L["At a banker, your bank is shown sorted in the Bank tab, and the game's bank window is hidden. Turn off to use the game's bank window; the Bank tab still shows what's in your bank."],
                onChange = function()
                    if ns.ApplyBankSetting then
                        ns.ApplyBankSetting()
                    end
                    refresh()
                end },
        },
        -- Hos bankiren: spelets eget bankfönster, t.ex. för att köpa en bankplats (Bank.lua).
        extra = function(submenu)
            if ns.IsAtBank and ns.IsAtBank() and ns.TakesOverBank and ns.TakesOverBank() then
                submenu:CreateCheckbox(L["Show the game's bank window"], ns.IsGameBankFrameShown,
                    ns.ToggleGameBankFrame)
            end
        end,
    },
}

---------------------------------------------------------------------------
-- Öppna inställningarna: väskan med kugghjulets meny
---------------------------------------------------------------------------

local settingsCategory

-- Tidy Packs sida i spelets inställningar. Utanför strid; i strid står en rad i chatten.
local function openAboutPage()
    if settingsCategory and not InCombatLockdown() then
        Settings.OpenToCategory(settingsCategory:GetID())
    else
        ns.Print(L["Open your bags, then use the gear button for Tidy Pack's options."])
    end
end

-- page = "junk" eller "groups" öppnar den panelen i väskan; utan page öppnas kugghjulets meny.
-- ⚠️ Väskan öppnas aldrig härifrån med OpenAllBags: öppnas den från addonets kod stoppar spelet
-- sedan bland annat disenchant på sakerna i den (LogoButton.lua). Är väskan stängd (/tidypack,
-- addonmenyn) öppnas i stället Tidy Packs sida i spelets inställningar, där knappen "Open Bags"
-- öppnar väskan på ett säkert sätt.
function ns.OpenSettings(page)
    if not ns.bagFrame then
        return
    end
    if not ns.bagFrame:IsShown() then
        openAboutPage()
        return
    end
    if page == "junk" or page == "groups" then
        ns.OpenPanel(page)
        return
    end
    -- En bildruta senare, när fönstret och kugghjulet syns.
    C_Timer.After(0, function()
        if ns.OpenGearMenu then
            ns.OpenGearMenu()
        end
    end)
end

---------------------------------------------------------------------------
-- Sidan i spelets inställningar: om Tidy Pack
---------------------------------------------------------------------------

local function metadata(field)
    local get = C_AddOns and C_AddOns.GetAddOnMetadata
    return get and get(addonName, field) or nil
end

local function createAboutPage()
    local page = CreateFrame("Frame")

    local logo = page:CreateTexture(nil, "ARTWORK")
    logo:SetSize(56, 56)
    logo:SetPoint("TOPLEFT", 14, -16)
    logo:SetTexture("Interface\\AddOns\\" .. addonName .. "\\Media\\Logo")

    local title = page:CreateFontString(nil, "ARTWORK", "GameFontHighlightHuge")
    title:SetPoint("TOPLEFT", logo, "TOPRIGHT", 12, -4)
    title:SetText(L["Tidy Pack"])
    local version = page:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    version:SetPoint("BOTTOMLEFT", title, "BOTTOMRIGHT", 8, 2)
    version:SetTextColor(GRAY_FONT_COLOR:GetRGB())
    version:SetText(metadata("Version") or "")
    local author = page:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    author:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
    author:SetText(L["By %s"]:format(metadata("Author") or ""))

    local howTitle = page:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    howTitle:SetPoint("TOPLEFT", logo, "BOTTOMLEFT", 0, -20)
    howTitle:SetText(L["How to use it"])
    local how = page:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    how:SetPoint("TOPLEFT", howTitle, "BOTTOMLEFT", 0, -8)
    how:SetPoint("RIGHT", page, "RIGHT", -20, 0)
    how:SetJustifyH("LEFT")
    how:SetSpacing(4)
    how:SetText(ns.KeyText(table.concat({
        L["• Open your bags (B): your items are sorted into groups."],
        L["• Alt-click an item: favorite, junk list, set or group."],
        L["• The gear button at the top of the bag window has every option, the junk list and your groups."],
        L["• The tabs above the bags: Bank (sorted at a banker), Sets and Quests."],
    }, "\n")))

    local linkTitle = page:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    linkTitle:SetPoint("TOPLEFT", how, "BOTTOMLEFT", 0, -20)
    linkTitle:SetText(L["Updates and feedback"])
    -- Ett addon kan inte öppna webbläsaren, så adressen står markerad i en ruta och kopieras.
    local website = metadata("X-Website") or WEBSITE_FALLBACK
    local link = CreateFrame("EditBox", nil, page, "InputBoxTemplate")
    link:SetSize(380, 22)
    link:SetAutoFocus(false)
    link:SetPoint("TOPLEFT", linkTitle, "BOTTOMLEFT", 6, -8)
    link:SetText(website)
    link:SetCursorPosition(0)
    -- Rutan går inte att skriva i: allt som ändras sätts tillbaka.
    link:SetScript("OnTextChanged", function(self, userInput)
        if userInput then
            self:SetText(website)
            self:HighlightText()
        end
    end)
    link:SetScript("OnEditFocusGained", link.HighlightText)
    link:SetScript("OnMouseUp", function(self)
        self:SetFocus()
        self:HighlightText()
    end)
    link:SetScript("OnEscapePressed", link.ClearFocus)
    local copyHint = page:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    copyHint:SetPoint("TOPLEFT", link, "BOTTOMLEFT", -6, -6)
    copyHint:SetTextColor(GRAY_FONT_COLOR:GetRGB())
    copyHint:SetText((IsMacClient and IsMacClient()) and L["Click the link and press Cmd+C to copy it."]
        or L["Click the link and press Ctrl+C to copy it."])

    -- En säker knapp som klickar på spelets ryggsäcksknapp, som loggan (se LogoButton.lua). Är
    -- väskan redan öppen klickas inte ryggsäcken, så att väskan inte stängs.
    local openBags = CreateFrame("Button", nil, page, "UIPanelButtonTemplate, SecureActionButtonTemplate")
    openBags:SetSize(130, 22)
    openBags:SetPoint("TOPLEFT", copyHint, "BOTTOMLEFT", 0, -20)
    openBags:SetText(L["Open Bags"])
    openBags:RegisterForClicks("LeftButtonUp")
    openBags:SetAttribute("type", "click")
    openBags:SetAttribute("clickbutton", MainMenuBarBackpackButton)
    openBags:SetScript("PreClick", function(self)
        if not InCombatLockdown() then
            self:SetAttribute("type", not (ns.bagFrame and ns.bagFrame:IsShown()) and "click" or nil)
        end
    end)
    openBags:SetScript("PostClick", function()
        C_Timer.After(0, function()
            ns.OpenSettings()
        end)
    end)
    local tips = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
    tips:SetSize(150, 22)
    tips:SetPoint("LEFT", openBags, "RIGHT", 10, 0)
    tips:SetText(L["Show Tips Again"])
    tips:SetScript("OnClick", function()
        if ns.ResetTour then
            ns.ResetTour()
            ns.Print(L["The tips show the next time you open your bags."])
        end
    end)

    page:SetScript("OnHide", function()
        link:ClearFocus()
    end)
    return page
end

ns.OnLoad(function()
    settingsCategory = Settings.RegisterCanvasLayoutCategory(createAboutPage(), L["Tidy Pack"])
    Settings.RegisterAddOnCategory(settingsCategory)
end)

---------------------------------------------------------------------------
-- /tidypack och addonmenyn vid minikartan
---------------------------------------------------------------------------

SLASH_TIDYPACK1 = "/tidypack"
-- "/tidypack equip <namn>" tar på ett set (så fungerar setets makro på actionbaren).
SlashCmdList.TIDYPACK = function(message)
    local command, rest = (message or ""):match("^%s*(%S+)%s*(.-)%s*$")
    if command and command:lower() == "equip" and ns.EquipSetByName then
        ns.EquipSetByName(rest)
        return
    end
    ns.OpenSettings()
end

-- Addonmenyn vid minikartan anropar den här (## AddonCompartmentFunc i TOC-filen).
function TidyPack_OnAddonCompartmentClick()
    ns.OpenSettings()
end
