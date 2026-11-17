-- TidyPack – Search.lua
-- The search box (gear → Show → Search box, off by default): only in the Bags and Bank tabs, in the
-- window's title bar above the tabs. Moved out of Layout.lua unchanged 2026-11-17 (the split of
-- Layout.lua, step 5). The glow on matching items stays in Layout.lua, which owns the item buttons
-- (ns.ApplySearchHighlights); Layout.lua calls ns.SyncSearchBox and ns.PositionSearchBox here.

local _, ns = ...

local function wantSearchBox()
    if not (ns.db and ns.db.showSearchBox) then
        return false
    end
    local view = ns.GetView and ns.GetView() or "bags"
    return view == "bags" or view == "bank"
end

local function positionSearchBox(searchBox)
    local bagFrame = ns.bagFrame
    searchBox = searchBox or BagItemSearchBox
    if not (searchBox and bagFrame and wantSearchBox()) then
        return
    end
    -- Three tabs (3 * 90 + 2 * 2 = 274 wide, from x = 14 to 288). SearchBoxTemplate has
    -- its left edge texture 5 units left of the frame (-5), so x = 19 and width 269
    -- make the search box start at the left edge of Bags (14) and end at the right edge of Quests (288).
    searchBox:SetSize(269, 18)
    searchBox:SetFrameStrata(ns.gearButton and ns.gearButton:GetFrameStrata() or "HIGH")
    searchBox:SetFrameLevel(ns.gearButton and ns.gearButton:GetFrameLevel() or (bagFrame:GetFrameLevel() + 30))
    searchBox:ClearAllPoints()
    searchBox:SetPoint("TOPLEFT", bagFrame, "TOPLEFT", 19, -3)
end

local function syncSearchBox()
    local bagFrame = ns.bagFrame
    if not BagItemSearchBox then
        return
    end
    if bagFrame and bagFrame:IsShown() and wantSearchBox() then
        if BagItemSearchBox:GetParent() ~= bagFrame then
            BagItemSearchBox:SetParent(bagFrame)
        end
        positionSearchBox(BagItemSearchBox)
        BagItemSearchBox:Show()
    else
        if BagItemSearchBox:GetText() ~= "" then
            BagItemSearchBox:SetText("")
        end
        if BagItemSearchBox:GetParent() == bagFrame then
            BagItemSearchBox:Hide()
        end
    end
end

ns.WantSearchBox = wantSearchBox
ns.PositionSearchBox = positionSearchBox
ns.SyncSearchBox = syncSearchBox

ns.RegisterEvent("INVENTORY_SEARCH_UPDATE", function()
    local bagFrame = ns.bagFrame
    if bagFrame and bagFrame:IsShown() and wantSearchBox() then
        ns.ApplySearchHighlights()
    end
end)

ns.OnLoad(function()
    local bagFrame = ns.bagFrame
    if not bagFrame then
        return
    end
    -- The search box is off by default but can be turned on under the gear → Show → Search box,
    -- and then shows only in the Bags and Bank tabs (in the title bar).
    if BagItemSearchBox then
        hooksecurefunc(bagFrame, "SetSearchBoxPoint", function(_, searchBox)
            positionSearchBox(searchBox)
        end)
        hooksecurefunc(BagItemSearchBox, "Show", function(self)
            if self:GetParent() == bagFrame then
                if wantSearchBox() then
                    positionSearchBox(self)
                else
                    self:Hide()
                end
            end
        end)
        syncSearchBox()
    end
end)
