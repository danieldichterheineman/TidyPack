-- TidyPack – Options.lua
-- All options are under the gear button in the bag window (the owner's wish 2026-11-12, sketch
-- .design/sketch-settings-in-bag.html): ns.optionMenus below becomes the submenus Show, Merchants and loot
-- and Bag and bank (Marks.lua), and the junk list and the groups open in the bag window (Panels.lua).
-- The page in the game's options (Esc → Options → AddOns → Tidy Pack) has no options: it tells what
-- Tidy Pack is and who made it, how to use it and where to find it (CurseForge).
-- Right-click on the logo opens the bags with the gear menu; /tidypack and the addon menu do so too.

local addonName, ns = ...
local L = ns.L

local WEBSITE_FALLBACK = "https://www.curseforge.com/wow/addons/tidy-pack"

local function refresh()
    if ns.Refresh then
        ns.Refresh()
    end
end

---------------------------------------------------------------------------
-- The options in the gear menu
---------------------------------------------------------------------------
-- key is the key in ns.db (Core.lua has the defaults). onChange runs after a change.
-- enabled (a function) greys out the line when it can't be changed. A line with only section is a
-- small heading in the submenu (Show ▸ has eight options in three groups; review 2026-11-15).

-- Built once the language is chosen (ns.OnLoad below), because this file loads before Tidy Pack
-- knows which language the player picked (Locales.lua).
local function buildOptionMenus()
    return {
        {
            title = L["Show"],
            options = {
                { section = L["On items"] },
                { key = "itemLevelAndBoE", name = L["Item level and BoE"],
                    tooltip = L["On uncommon or better weapons and armor."], onChange = refresh },
                { key = "upgradeArrows", name = L["Upgrade arrows"],
                    tooltip = L["A green arrow on weapons and armor you can use that have a higher item level than what you wear in that slot."],
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
                { section = L["In tooltips"] },
                { key = "showCounts", name = L["Bag and bank counts"],
                    tooltip = L["Item tooltips show how many you have in your bags and in your bank, and the total. Only for items in your bank, and only for this character."] },
                { key = "tooltipLines", name = L["Group line"],
                    tooltip = L["The line \"Tidy Pack group: ...\" in the tooltip of items in your own groups. Lines about quests and locks always show."] },
                { section = L["In the window"] },
                { key = "showQuestItemsInBags", name = L["Quest items in Bags"],
                    tooltip = L["Turn off to keep quest items in the Quests tab only. The Bags tab then shows a line saying how many slots they use."],
                    onChange = refresh },
                { key = "junkValue", name = L["Junk value in the header"],
                    tooltip = L["What your junk sells for, next to the Junk header."], onChange = refresh },
                { key = "showSearchBox", name = L["Search box"],
                    tooltip = L["Show the search box in the title bar on the Bags and Bank tabs. Matches glow in blue and everything else dims."],
                    onChange = refresh },
                { key = "groupByBag", name = L["Show by bag"],
                    tooltip = L["Show each bag (and bank tab) in slot order with its empty slots, instead of grouping everything by type. Favorites and your own groups stay at the top."],
                    onChange = refresh },
            },
        },
        {
            title = L["Merchants and loot"],
            options = {
                { key = "lockAtMerchant", name = L["Lock items at merchants"],
                    tooltip = L["At merchants, items your quests need and items in your equipment sets get a lock and can't be clicked, so you can't sell them by mistake. The merchant's own Sell All Junk button doesn't know about these locks."],
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
            -- At a banker: the game's own bank window, e.g. to buy a bank slot (Bank.lua).
            extra = function(submenu)
                if ns.IsAtBank and ns.IsAtBank() and ns.TakesOverBank and ns.TakesOverBank() then
                    submenu:CreateCheckbox(L["Show the game's bank window"], ns.IsGameBankFrameShown,
                        ns.ToggleGameBankFrame)
                end
            end,
        },
    }
end

ns.OnLoad(function()
    ns.optionMenus = buildOptionMenus()
end)

---------------------------------------------------------------------------
-- Open the options: the bags with the gear menu
---------------------------------------------------------------------------

local settingsCategory

-- Tidy Pack's page in the game's options. Outside combat; in combat a line in the chat.
local function openAboutPage()
    if settingsCategory and not InCombatLockdown() then
        Settings.OpenToCategory(settingsCategory:GetID())
    else
        ns.Print(L["Open your bags, then use the gear button for Tidy Pack's options."])
    end
end

-- page = "junk" or "groups" opens that panel in the bags; without page the gear menu opens.
-- ⚠️ The bags are never opened from here with OpenAllBags: opened from addon code, the game then
-- blocks e.g. disenchanting the items in them (LogoButton.lua). If the bags are closed (/tidypack,
-- the addon menu), Tidy Pack's page in the game's options opens instead. A secure "Open Bags"
-- button must not be on that page: it makes the whole page protected in combat (issue #2) and
-- can't be anchored to text lines. The logo opens the bags safely instead.
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
    -- One frame later, when the window and the gear are shown.
    C_Timer.After(0, function()
        if ns.OpenGearMenu then
            ns.OpenGearMenu()
        end
    end)
end

---------------------------------------------------------------------------
-- The page in the game's options: about Tidy Pack
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
        L["• Alt-click an item: favorite, junk list or group."],
        L["• The gear button at the top of the bag window has every option, the junk list and your groups."],
        L["• The tabs above the bags: Bank (sorted at a banker) and Quests."],
    }, "\n")))

    local linkTitle = page:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    linkTitle:SetPoint("TOPLEFT", how, "BOTTOMLEFT", 0, -20)
    linkTitle:SetText(L["Updates and feedback"])
    -- An addon can't open the browser, so the address stands highlighted in a box to copy.
    local website = metadata("X-Website") or WEBSITE_FALLBACK
    local link = CreateFrame("EditBox", nil, page, "InputBoxTemplate")
    link:SetSize(380, 22)
    link:SetAutoFocus(false)
    link:SetPoint("TOPLEFT", linkTitle, "BOTTOMLEFT", 6, -8)
    link:SetText(website)
    link:SetCursorPosition(0)
    -- The box can't be typed in: every change is put back.
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

    -- No secure "Open Bags" button here: the game shows and moves this page in
    -- SettingsPanelMixin:DisplayLayout, and a secure button makes the whole page protected in combat
    -- (issue #2) and fails when anchored to text or to frames anchored to text.
    local bagHint = page:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    bagHint:SetPoint("TOPLEFT", copyHint, "BOTTOMLEFT", 0, -20)
    bagHint:SetPoint("RIGHT", page, "RIGHT", -20, 0)
    bagHint:SetJustifyH("LEFT")
    bagHint:SetText(L["Click the Tidy Pack logo or press B to open your bags, then use the gear button for options."])

    local tips = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
    tips:SetSize(150, 22)
    tips:SetPoint("TOPLEFT", bagHint, "BOTTOMLEFT", 0, -14)
    tips:SetText(L["Show Tips Again"])
    ns.FitButtonText(tips, 150)
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
-- /tidypack and the addon menu at the minimap
---------------------------------------------------------------------------

SLASH_TIDYPACK1 = "/tidypack"
-- "/tidypack equip <name>" was in the sets' macros ("TP <name>") in 1.1.0 and earlier, before the Sets tab was removed.
-- Such a macro on an action bar now says what happened, instead of opening the options.
SlashCmdList.TIDYPACK = function(message)
    local command = (message or ""):match("^%s*(%S+)")
    if command and command:lower() == "equip" then
        ns.Print(L["Tidy Pack no longer has sets. Use the game's Equipment Manager in the character window (C), and delete the old \"TP\" macro (Esc → Macros)."])
        return
    end
    ns.OpenSettings()
end

-- The addon menu at the minimap calls this (## AddonCompartmentFunc in the TOC file).
function TidyPack_OnAddonCompartmentClick()
    ns.OpenSettings()
end
