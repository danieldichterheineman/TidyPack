-- TidyPack – Gamepad.lua
-- Makes the controller cursor easy in Tidy Pack's groups.
--
-- The game's cursor (SmartNavigation) is built for the game's own grid, where all buttons stand in
-- even rows and the bags come last. With Tidy Pack's groups three things went wrong:
--   1. The cursor started on the backpack's bag button, which Tidy Pack hides.
--   2. LB and RB jump between the bags, that is to the hidden bag buttons. Pressing A
--      there picks up a bag you are wearing.
--   3. The D-pad follows a grid (columns by exact position, rows counted from the bottom) that
--      doesn't fit groups side by side, and doesn't follow when Tidy Pack moves the
--      buttons. After selling, the cursor could stay on a hidden button.
-- Tidy Pack fixes it like this:
--   1. The cursor starts on what you just got (the group New), otherwise on the first button.
--   2. LB and RB jump to the previous or next group.
--   3. The D-pad uses the game's free navigation: the nearest button in the direction you press,
--      from where the buttons are right now. If the button under the cursor is hidden, the cursor
--      moves to the nearest visible one.
-- Also, locked items at a merchant are blocked for the cursor (see ns.SetGamepadClickBlocked).
--
-- The game lets addons call exactly these functions (SetUseGridNavigation,
-- SetTargetButtonForFrame and SmartNavigation_*), but only outside combat. Tidy Pack never
-- changes the game's tables: it listens with hooksecurefunc, which runs our code after the game's,
-- and makes the fix one frame later.
-- ⚠️ In combat the game blocks the functions. Tidy Pack then waits until combat is over, and
--    meanwhile the cursor works as without Tidy Pack.
-- ⚠️ LB and RB build on the game's own bag counting. With the keyring on, LB does nothing
--    on items in the backpack and RB nothing on keys – just as in the game's own window.

local _, ns = ...

local bagFrame
local fixScheduled = false
local wantFreeNavigation = false -- the game has turned on its grid for the bag window
local jumpFrom, jumpStep         -- LB/RB: the button the cursor came from, and 1 (RB) or -1 (LB)
local previousButton             -- the button the cursor was on before the last move
local waitingForCombat = false   -- something had to wait until combat is over

-- Buttons the cursor may not click (locked items at a merchant).
local blockedButtons = setmetatable({}, { __mode = "k" })

-- True when addons may call the cursor's functions. The same check as the game's code does
-- (SecureHelper in Blizzard_GamepadSmartNavigation). In combat the game would block the call
-- and show an error message.
local function canUseNavigation()
    if C_RestrictedActions and C_RestrictedActions.IsAddOnRestrictionActive then
        return not C_RestrictedActions.IsAddOnRestrictionActive(Enum.AddOnRestrictionType.Combat)
    end
    return not InCombatLockdown()
end
ns.CanUseNavigation = canUseNavigation -- also used by MakeRoom.lua

local function isGamepadMode()
    return SmartNavigation ~= nil and InputUtil.IsGamepadUIEnabled()
end

-- The controller's button as an image in a text, e.g. A on an Xbox controller. The game picks
-- the image by the controller in use (InputIconTexture.lua in the game's code). Gives an empty
-- text if the image is missing.
function ns.GamepadIcon(key, size)
    local textures = InputIconTextureSetUtility and InputIconTextureSetUtility.GetActiveInputIconButtonTextures(key)
    local atlas = textures and textures[1] -- 1 = InputIconTextureState.Normal in the game's code
    if not atlas then
        return ""
    end
    size = size or 16
    return CreateAtlasMarkup(atlas, size, size)
end

-- The game's bag buttons for the controller are in GamepadBagBar, which Tidy Pack hides.
local function isBagBarButton(button)
    return GamepadBagBar ~= nil and button:GetParent() == GamepadBagBar
end

-- The bag window's own buttons and bag buttons.
local function isBagFrameButton(button)
    return button:GetParent() == bagFrame or isBagBarButton(button)
end

-- LB or RB? The game picks the bag after (RB) or before (LB) the one the item is in, with the
-- same wrap-around as in the game's code (Gamepad_SetCursorToBag in ContainerFrame.lua).
local function jumpDirection(fromBagID, toBagID)
    local nextBagID = fromBagID + 1
    if nextBagID > ENDING_BAG_INDEX then
        nextBagID = STARTING_BAG_INDEX
    end
    return toBagID == nextBagID and 1 or -1
end

-- The button the cursor should go to when it is on a button that isn't shown.
local function chooseTarget(current, from, step)
    if from and from:IsVisible() then
        return ns.GetGroupJumpTarget(from, step) -- LB or RB
    end
    if isBagBarButton(current) then
        return ns.GetStartButton() -- the bags were opened
    end
    local x, y = current:GetCenter()
    -- The button is hidden, e.g. when the item was sold: the nearest to where it was.
    return x and ns.GetNearestShownButton(x, y) or ns.GetStartButton()
end

-- The fix itself. Runs one frame after something happened, so the game's and Tidy Pack's
-- layout is done.
local function fixCursor()
    fixScheduled = false
    local from, step = jumpFrom, jumpStep
    jumpFrom, jumpStep = nil, nil
    if not (bagFrame:IsShown() and isGamepadMode()) then
        wantFreeNavigation = false
        return
    end
    if not canUseNavigation() then
        waitingForCombat = true
        return
    end

    -- The game's free navigation instead of the grid.
    if wantFreeNavigation then
        wantFreeNavigation = false
        SmartNavigation:SetUseGridNavigation(bagFrame, false)
    end

    -- The cursor must never stand on a button that isn't shown.
    local current = SmartNavigation:GetCurrentButton()
    if current and isBagFrameButton(current) and not current:IsVisible() then
        local target = chooseTarget(current, from, step)
        if target and target:IsVisible() then
            -- Selects the button directly, because the bag window has the cursor.
            SmartNavigation:SetTargetButtonForFrame(bagFrame, target)
        end
    end
end

local function scheduleFix()
    if not fixScheduled then
        fixScheduled = true
        C_Timer.After(0, fixCursor)
    end
end

-- Runs after every cursor move, in every window. Does something only when the cursor has landed on
-- a hidden button in the bag window.
local function onButtonSelected(navigation)
    local current = navigation:GetCurrentButton()
    local previous = previousButton
    previousButton = current
    if not current or current:IsVisible() or not isBagFrameButton(current) then
        return
    end
    -- If the cursor came from a visible item to a hidden bag button, it was LB or RB.
    if isBagBarButton(current) and previous and previous ~= current and previous:IsVisible()
        and previous:GetParent() == bagFrame and previous.GetBagID and current.GetBagID then
        jumpFrom = previous
        jumpStep = jumpDirection(previous:GetBagID(), current:GetBagID())
    end
    scheduleFix()
end

-- Layout.lua calls this after every layout, because buttons may have been hidden.
function ns.OnLayoutChanged()
    if bagFrame and isGamepadMode() then
        scheduleFix()
    end
end

---------------------------------------------------------------------------
-- Locked items at a merchant
---------------------------------------------------------------------------
-- With the mouse Layout.lua disables locked buttons. With a controller that can't be done: when a
-- button under the cursor is disabled, the game runs its button-hint code at the bottom in Tidy
-- Pack's name, and then the game can block Use and Sell ("Interface action failed because of an
-- AddOn"). Instead Tidy Pack tells the cursor not to click the button, with the game's own
-- function for that (SmartNavigation_MarkFrameBlockingSmartNavClick). Then both A and X do
-- nothing on the item.

-- Blocks (true) or releases (false) the cursor's click on a button. Returns false if it
-- had to wait until combat is over.
function ns.SetGamepadClickBlocked(button, block)
    if (blockedButtons[button] == true) == block then
        return true
    end
    if not canUseNavigation() then
        waitingForCombat = true
        return false
    end
    if block then
        SmartNavigation_MarkFrameBlockingSmartNavClick(button)
        blockedButtons[button] = true
    else
        -- The game has only one function that releases the block: the one that removes everything
        -- Tidy Pack and the game have set for the cursor on the button.
        SmartNavigation_ResetData(button)
        blockedButtons[button] = nil
    end
    return true
end

-- Releases all blocks, e.g. when trading is over. A quest item must be usable in combat
-- even if the bags were closed when trading ended.
local function unblockAll()
    for button in pairs(blockedButtons) do
        ns.SetGamepadClickBlocked(button, false)
    end
end

---------------------------------------------------------------------------
-- Start
---------------------------------------------------------------------------

ns.OnLoad(function()
    bagFrame = ns.bagFrame
    if not bagFrame or not SmartNavigation then
        return
    end

    -- The game turns on its grid every time the bag window gets the cursor.
    hooksecurefunc(SmartNavigation, "SetUseGridNavigation", function(_, frame, useGrid)
        if frame == bagFrame and useGrid then
            wantFreeNavigation = true
            scheduleFix()
        end
    end)

    hooksecurefunc(SmartNavigation, "SelectButton", onButtonSelected)

    ns.RegisterEvent("MERCHANT_CLOSED", unblockAll)

    -- Combat is over: do what had to wait. ADDON_RESTRICTION_STATE_CHANGED comes when the
    -- game's restriction for addons turns on or off, PLAYER_REGEN_ENABLED when combat ends.
    local function onCombatEnded()
        if not waitingForCombat or not canUseNavigation() then
            return
        end
        waitingForCombat = false
        if not ns.IsAtMerchant() then
            unblockAll()
        end
        if ns.Refresh then
            ns.Refresh() -- lays out everything again, with the blocks and the cursor
        end
        scheduleFix()
    end
    ns.RegisterEvent("PLAYER_REGEN_ENABLED", onCombatEnded)
    ns.RegisterEvent("ADDON_RESTRICTION_STATE_CHANGED", function(restrictionType)
        if restrictionType == Enum.AddOnRestrictionType.Combat then
            -- During the event itself the game always answers that no restriction applies, so the
            -- check is made one frame later.
            C_Timer.After(0, onCombatEnded)
        end
    end)
end)
