-- TidyPack – GameWindow.lua
-- What Tidy Pack changes in the game's own windows around the bag window: the reagent bag's separate
-- window is put away, the bags keep their size at a banker, and the game's sort button and bag menu
-- are hidden. Moved out of Layout.lua unchanged 2026-11-17 (the split of Layout.lua, step 2). Layout.lua
-- calls ns.HideReagentBagFrame and ns.KeepBagScaleAtBank after each size change; this file loads after
-- Layout.lua, so its start runs after the bag window's.

local _, ns = ...

local REAGENT_BAG = Enum.BagIndex.ReagentBag or (Constants.InventoryConstants.NumBagSlots + 1)

ns.OnLoad(function()
    local bagFrame = ns.bagFrame
    if not bagFrame then
        return
    end

    -- The reagent bag (bag slot 5) has its own window in the game with the mouse (ContainerFrame6). Tidy Pack
    -- draws its items as its own group at the bottom of the bags instead, so the game's extra window
    -- is put away without being hidden or closed (Hide or CloseBag breaks B / taints the clicks): it
    -- is moved off screen, made invisible and shrunk to 0.01. With a controller the game itself
    -- includes the reagent bag in the combined window, so there Tidy Pack touches nothing.
    local reagentFrameSuppressed = false
    local function hideReagentBagFrame()
        if Constants.InventoryConstants.NumReagentBagSlots == 0 or not ContainerFrameUtil_GetShownFrameForID then
            return
        end
        local reagentFrame = ContainerFrameUtil_GetShownFrameForID(REAGENT_BAG)
        if not reagentFrame or reagentFrame == bagFrame then
            return
        end
        if InputUtil.IsGamepadUIEnabled() then
            if reagentFrameSuppressed then
                reagentFrame:SetAlpha(1)
                reagentFrame:SetScale(1)
                reagentFrameSuppressed = false
            end
            return
        end
        reagentFrameSuppressed = true
        reagentFrame:SetAlpha(0)
        reagentFrame:SetScale(0.01)
        reagentFrame:ClearAllPoints()
        reagentFrame:SetPoint("TOPLEFT", UIParent, "TOPRIGHT", 1000, 1000)
    end
    -- At a banker the game shrinks the bags so they don't overlap its bank window (GetContainerScale in
    -- ContainerFrame.lua: leftLimit = BankFrame:GetRight()), but only when it places the bags – so the
    -- bags got smaller when the bank opened them, and not when they were already open (the owner's
    -- screenshots 2026-11-15). Tidy Pack makes that window invisible (Bank.lua), so the bags get the
    -- size the game's own rule gives without it: as large as possible, at most 1, at least 0.75, and
    -- short enough to fit above CONTAINER_OFFSET_Y. The offsets are kept where the game put them.
    local function keepBagScaleAtBank()
        if not (BankFrame and BankFrame:IsShown() and ns.IsGameBankFrameShown and not ns.IsGameBankFrameShown())
            or not bagFrame:IsShown() then
            return
        end
        local wanted = 1
        while wanted > 0.75 and bagFrame:GetHeight(true) > (GetScreenHeight() - (CONTAINER_OFFSET_Y or 85)) / wanted do
            wanted = wanted - 0.01
        end
        wanted = math.max(wanted, 0.75)
        local old = bagFrame:GetScale()
        if math.abs(wanted - old) < 0.001 then
            return
        end
        local point, relativeTo, relativePoint, x, y = bagFrame:GetPoint(1)
        bagFrame:SetScale(wanted)
        if point then
            bagFrame:ClearAllPoints()
            bagFrame:SetPoint(point, relativeTo, relativePoint, x * old / wanted, y * old / wanted)
        end
    end
    ns.HideReagentBagFrame = hideReagentBagFrame
    ns.KeepBagScaleAtBank = keepBagScaleAtBank
    if UpdateContainerFrameAnchors then
        hooksecurefunc("UpdateContainerFrameAnchors", function()
            hideReagentBagFrame()
            keepBagScaleAtBank()
        end)
    end

    -- The game's button for tidying the bags isn't needed: the items are always shown grouped.
    -- The game shows it again every time the window updates, so it is hidden right after.
    if BagItemAutoSortButton then
        BagItemAutoSortButton:Hide()
        hooksecurefunc(BagItemAutoSortButton, "Show", BagItemAutoSortButton.Hide)
    end

    -- The game's bag menu (click on the bag icon at the top left, with bag filters, tidying and
    -- "Combined Bags") isn't needed either. Without it nobody can turn off Combined Bags by mistake.
    local menuButton = bagFrame.PortraitButton
    if menuButton then
        menuButton:Hide()
        hooksecurefunc(menuButton, "Show", menuButton.Hide)
    end
end)
