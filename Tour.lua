-- TidyPack – Tour.lua
-- A short guide the first time the bags open, in an own frame from the game's HelpTipTemplate
-- (outside the game's shared pool HelpTip.framePool, so the addon's tips can never taint the
-- game's own tips, Blizzard_SharedXML/HelpTip.lua). Four steps with the Next/Got it button:
-- an item (Alt-click), the gear, the Bank tab (review 2026-11-15) and the Quests tab. Shown once;
-- Tidy Pack saves itself that it's done (TidyPackDB.tourDone), not in the game's settings.
-- The options page and the gear can show it again (ns.ResetTour).
-- ⚠️ The game shows no tips with a controller or when the player has turned the game's tips off
--    (HelpTip:AreHelpTipsEnabled), and then the guide doesn't show either.

local _, ns = ...
local L = ns.L

local step
local tip

local function hideTip()
    if tip then
        tip:Hide()
    end
end

-- The steps: what the tip points at, the text, and where the tip sits relative to its target.
local function steps()
    return {
        {
            target = ns.GetFirstItemButton,
            text = ns.KeyText(L["Alt-click an item for its options: favorite, junk list and groups."]),
            point = HelpTip.Point.BottomEdgeCenter, alignment = HelpTip.Alignment.Left,
        },
        {
            target = function() return ns.gearButton end,
            text = L["The gear button has your junk list, your own groups and the settings."],
            point = HelpTip.Point.BottomEdgeCenter, alignment = HelpTip.Alignment.Right,
        },
        {
            target = function() return ns.GetTabButton(2) end,
            text = L["Bank: your bank, sorted the same way – also when you're away from a banker."],
            point = HelpTip.Point.TopEdgeCenter, alignment = HelpTip.Alignment.Center,
        },
        {
            target = function() return ns.GetTabButton(3) end,
            text = L["Quests: see what your quests need and what is ready to turn in."],
            point = HelpTip.Point.TopEdgeCenter, alignment = HelpTip.Alignment.Center,
        },
    }
end

local showStep

local function finish()
    step = nil
    ns.db.tourDone = true
end

showStep = function(index)
    local list = steps()
    local info = list[index]
    if not info then
        finish()
        return
    end
    local target = info.target()
    if not target or not target:IsVisible() then
        -- Nothing to point at (e.g. an empty bag): go to the next step.
        showStep(index + 1)
        return
    end
    step = index
    if not tip then
        tip = CreateFrame("Frame", nil, UIParent, "HelpTipTemplate")
    end
    tip:Hide()
    tip:Reset() -- the game's pool does this for the game's own tips
    tip.width = HelpTip.width
    tip:SetWidth(tip.width)
    -- No system/cvar/autoHideWhenTargetHides: those go through the game's shared system.
    tip:Init(ns.bagFrame, {
        text = info.text,
        buttonStyle = index < #list and HelpTip.ButtonStyle.Next or HelpTip.ButtonStyle.GotIt,
        targetPoint = info.point,
        alignment = info.alignment,
        onAcknowledgeCallback = function()
            if index >= #list then
                finish()
                return
            end
            -- HelpTipTemplateMixin:Close runs the callback before it hides the tip, so the same frame
            -- must wait a frame before it shows again (otherwise the next step hides at once).
            C_Timer.After(0, function()
                if step == index and ns.bagFrame and ns.bagFrame:IsShown() then
                    showStep(index + 1)
                end
            end)
        end,
    }, target)
    tip:Show()
end

local function start()
    if ns.db.tourDone or step or InCombatLockdown() or not HelpTip:AreHelpTipsEnabled() then
        return
    end
    if ns.GetView and ns.GetView() ~= "bags" then
        return
    end
    showStep(1)
end

-- Shows the guide the next time the bags open (the button on the options page).
function ns.ResetTour()
    ns.db.tourDone = false
    step = nil
    hideTip()
end

ns.OnLoad(function()
    local bagFrame = ns.bagFrame
    if not bagFrame or not HelpTip then
        return
    end
    -- A little after the window opens, so the items have been laid out.
    bagFrame:HookScript("OnShow", function()
        C_Timer.After(0.3, start)
    end)
    -- If the bags close in the middle of the guide, it starts over next time.
    bagFrame:HookScript("OnHide", function()
        if step then
            step = nil
            hideTip()
        end
    end)
end)
