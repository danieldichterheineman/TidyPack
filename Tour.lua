-- TidyPack – Tour.lua
-- En kort guide första gången väskan öppnas, med spelets egna tipsrutor (HelpTip, samma gula ruta
-- med pil som i spelets egen guide för HUD Edit Mode, Blizzard_SharedXML/HelpTip.lua). Fyra steg
-- med knappen Next: en sak (Alt-klick), kugghjulet, fliken Sets och fliken Quests. Guiden visas
-- en gång; Tidy Pack sparar själv att den är klar (TidyPackDB.tourDone), inte i spelets
-- inställningar. Inställningssidan kan visa den igen (ns.ResetTour).
-- ⚠️ Spelet visar inga tipsrutor med handkontroll eller när spelaren stängt av spelets tips
--    (HelpTip:AreHelpTipsEnabled), och då visas inte guiden heller.

local _, ns = ...
local L = ns.L

local SYSTEM = "TidyPackTour"
local step

-- Stegen: vad rutan pekar på, texten, och var rutan står i förhållande till det den pekar på.
local function steps()
    return {
        {
            target = ns.GetFirstItemButton,
            text = ns.KeyText(L["Alt-click an item for its options: favorite, junk list, sets and groups."]),
            point = HelpTip.Point.BottomEdgeCenter, alignment = HelpTip.Alignment.Left,
        },
        {
            target = function() return ns.gearButton end,
            text = L["The gear button has your junk list, your own groups and the settings."],
            point = HelpTip.Point.BottomEdgeCenter, alignment = HelpTip.Alignment.Right,
        },
        {
            target = function() return ns.GetTabButton(2) end,
            text = L["Sets: save what you wear and put it on with one click."],
            point = HelpTip.Point.TopEdgeCenter, alignment = HelpTip.Alignment.Left,
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
        -- Inget att peka på (t.ex. en tom väska): hoppa till nästa steg.
        showStep(index + 1)
        return
    end
    step = index
    HelpTip:Show(ns.bagFrame, {
        text = info.text,
        buttonStyle = index < #list and HelpTip.ButtonStyle.Next or HelpTip.ButtonStyle.GotIt,
        targetPoint = info.point,
        alignment = info.alignment,
        system = SYSTEM,
        autoHideWhenTargetHides = true,
        onAcknowledgeCallback = function()
            showStep(index + 1)
        end,
    }, target)
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

-- Visar guiden nästa gång väskan öppnas (knappen på inställningssidan).
function ns.ResetTour()
    ns.db.tourDone = false
    step = nil
    HelpTip:HideAllSystem(SYSTEM)
end

ns.OnLoad(function()
    local bagFrame = ns.bagFrame
    if not bagFrame or not HelpTip then
        return
    end
    -- Lite efter att fönstret öppnats, så att sakerna hunnit läggas ut.
    bagFrame:HookScript("OnShow", function()
        C_Timer.After(0.3, start)
    end)
    -- Stängs väskan mitt i guiden börjar den om nästa gång.
    bagFrame:HookScript("OnHide", function()
        if step then
            step = nil
            HelpTip:HideAllSystem(SYSTEM)
        end
    end)
end)
