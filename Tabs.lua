-- TidyPack – Tabs.lua
-- The tabs above the bag window (Bags, Bank, Quests) and the switch between the views, also the
-- panel views "junk" and "groups" (Panels.lua). Moved out of Layout.lua unchanged 2026-11-17 (the
-- split of Layout.lua, step 1). Layout.lua reads the view with ns.GetView and lays it out in
-- ns.Refresh; this file must load right after Layout.lua, so its start runs after the bag window's.

local _, ns = ...
local L = ns.L

local TAB_WIDTH = 90
local TAB_LEFT = 14
local TAB_OVERLAP = 2
local TAB_GAP = 2

local view = "bags"
local tabSystem

local TAB_OF = { bags = 1, bank = 2, quests = 3 }
local VIEW_OF = { "bags", "bank", "quests" }
local PANEL_VIEWS = { junk = true, groups = true }

-- The tab's button (1 Bags, 2 Bank, 3 Quests), for the guide in Tour.lua.
function ns.GetTabButton(tabID)
    return tabSystem and tabSystem:GetTabButton(tabID)
end

-- Which view shows: "bags", "bank", "quests", "junk" or "groups".
function ns.GetView()
    return view
end

-- The dot on the Quests tab lights up when at least one quest with items is ready to turn in.
function ns.UpdateQuestsNotice()
    if tabSystem then
        tabSystem:SetTabNotification(TAB_OF.quests, ns.HasReadyQuest ~= nil and ns.HasReadyQuest())
    end
end

-- Switches between "bags", "bank" and "quests", or the panel views "junk" and "groups".
-- instant: no fade between the tabs (the Bank tab when the bank opens, Bank.lua).
function ns.SetView(newView, instant)
    local oldView = view
    view = (TAB_OF[newView] or PANEL_VIEWS[newView]) and newView or "bags"
    if view ~= oldView then
        if PANEL_VIEWS[view] and not PANEL_VIEWS[oldView] then
            PlaySound(SOUNDKIT.IG_CHARACTER_INFO_OPEN)
        elseif PANEL_VIEWS[oldView] and not PANEL_VIEWS[view] then
            PlaySound(SOUNDKIT.IG_CHARACTER_INFO_CLOSE)
        end
        if ns.PlayViewTransition and not instant then
            ns.PlayViewTransition()
        end
    end
    if tabSystem then
        tabSystem:SetTabVisuallySelected(TAB_OF[view] or 0)
    end
    if ns.Refresh then
        ns.Refresh()
    end
end

ns.OnLoad(function()
    local bagFrame = ns.bagFrame
    if not bagFrame then
        return
    end
    tabSystem = CreateFrame("Frame", nil, bagFrame, "TabSystemTemplate")
    tabSystem.tabTemplate = "TabSystemTopButtonTemplate"
    tabSystem.tabPool = CreateFramePool("BUTTON", tabSystem, tabSystem.tabTemplate)
    tabSystem.minTabWidth, tabSystem.maxTabWidth = TAB_WIDTH, TAB_WIDTH
    tabSystem.spacing = TAB_GAP
    tabSystem.tabSelectSound = SOUNDKIT.IG_CHARACTER_INFO_TAB
    tabSystem:SetPoint("BOTTOMLEFT", bagFrame, "TOPLEFT", TAB_LEFT, -TAB_OVERLAP)
    tabSystem:SetTabSelectedCallback(function(tabID)
        ns.SetView(VIEW_OF[tabID] or "bags")
        return true
    end)
    for _, label in ipairs({ L["Bags"], L["Bank"], L["Quests"] }) do
        local tabID = tabSystem:AddTab(label)
        local tab = tabSystem:GetTabButton(tabID)
        tab.selectedFontObject, tab.unselectedFontObject = GameFontHighlight, GameFontNormal
        tab:SetDisabledFontObject(GameFontHighlight)
        tab:UpdateTabWidth()
    end
    tabSystem:SetTabVisuallySelected(1)

    for tabID, tabView in ipairs(VIEW_OF) do
        tabSystem:GetTabButton(tabID):HookScript("OnEnter", function()
            local kind = GetCursorInfo()
            if view ~= tabView and kind == "item" then
                ns.SetView(tabView)
            end
        end)
    end

    bagFrame:HookScript("OnHide", function()
        if view ~= "bags" then
            ns.SetView("bags")
        end
    end)
end)
