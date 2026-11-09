-- TidyPack – Junk.lua
-- Vad som räknas som skräp, och knappen Sell Junk. Knappen syns ovanför väskfönstret när du
-- handlar och det finns skräp som går att sälja (se ns.GetJunkKind). Ett klick säljer högst
-- 12, så att allt går att köpa tillbaka i handlarens Buyback-flik. Klicka igen för fler.
--
-- Spelet låter inte addons sälja saker på egen hand (att använda en sak är skyddat).
-- Knappen är därför en säker knapp (SecureActionButtonTemplate) som kör spelets eget
-- kommando "/use väska plats" för varje sak – precis som ett högerklick på saken.
-- ⚠️ En säker knapp kan inte ändras i strid, och den får inte ligga inne i spelets
-- väskfönster: då skulle väskorna inte gå att öppna i strid. Därför ligger den ovanför
-- fönstret, och handkontrollens markör når den inte. Med handkontroll används spelets egen
-- knapp "Sell All Junk" i handlarfönstret.

local addonName, ns = ...
local L = ns.L

local MAX_PER_CLICK = 12 -- handlarens Buyback-flik rymmer de 12 senast sålda sakerna
local NUM_BAGS = Constants.InventoryConstants.NumBagSlots

local button
local lines = {} -- återanvänds för knappens kommandon

-- Vad för sorts skräp en sak är: "marked" (du har markerat den som skräp i Marks.lua),
-- "grey" (grå) eller nil (inte skräp). Stjärnmärkta och låsta saker, quest-saker och saker
-- som spelet håller på med är aldrig skräp, och inte heller grå saker som en quest behöver
-- senare (QuestHints.lua). Det du själv markerat räknas även om en quest behöver det senare:
-- där har du bestämt dig. Används av Sell Junk och av förslagen vid fulla väskor (MakeRoom.lua).
function ns.GetJunkKind(bagID, slot, info)
    if not info or info.isLocked or ns.IsFavorite(info.itemID) or ns.IsLocked(bagID, slot, info) then
        return nil
    end
    if ns.IsJunkMarked(info.itemID) then
        return "marked"
    end
    if info.quality == Enum.ItemQuality.Poor and not (ns.IsNeededLater and ns.IsNeededLater(info.itemID, true)) then
        return "grey"
    end
    return nil
end

-- Hittar skräpet som Sell Junk får sälja. Returnerar kommandona för de första 12, hur många
-- saker det finns och vad de är värda tillsammans (i koppar).
local function findJunk()
    wipe(lines)
    local count, value = 0, 0
    for bagID = 0, NUM_BAGS do
        for slot = 1, C_Container.GetContainerNumSlots(bagID) do
            local info = C_Container.GetContainerItemInfo(bagID, slot)
            if info and not info.hasNoValue and ns.GetJunkKind(bagID, slot, info) then
                local sellPrice = select(11, C_Item.GetItemInfo(info.hyperlink)) or 0
                count = count + 1
                value = value + sellPrice * (info.stackCount or 1)
                if #lines < MAX_PER_CLICK then
                    lines[#lines + 1] = ("/use %d %d"):format(bagID, slot)
                end
            end
        end
    end
    return table.concat(lines, "\n"), count, value
end

-- Lägger knappen ovanför väskfönstrets högra del, så att den inte krockar med flikarna
-- Bags och Sets till vänster (SetsView.lua). Knappen hänger i UIParent, inte i
-- väskfönstret, så platsen räknas om till UIParents skala.
local function place(bagFrame)
    local right, top = bagFrame:GetRight(), bagFrame:GetTop()
    if not right or not top then
        return false
    end
    local scale = bagFrame:GetEffectiveScale() / UIParent:GetEffectiveScale()
    button:ClearAllPoints()
    button:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMLEFT", right * scale - 8, top * scale + 6)
    return true
end

-- Visar, uppdaterar eller döljer knappen.
local function update()
    if InCombatLockdown() then
        return -- säkra knappar kan inte ändras i strid; görs när striden är slut
    end
    local bagFrame = ns.bagFrame
    -- Knappen går att stänga av i inställningarna (Options.lua).
    local show = ns.db.sellJunkButton and ns.IsAtMerchant() and bagFrame:IsShown()
    if show then
        local text, count, value = findJunk()
        show = count > 0 and place(bagFrame)
        if show then
            button:SetAttribute("macrotext", text)
            button:SetText(L["Sell Junk"] .. "  " .. GetMoneyString(value))
            button:SetWidth(math.ceil(button:GetFontString():GetStringWidth()) + 24)
        end
    end
    button:SetShown(show)
end

-- Ber om en uppdatering. Den görs en bildruta senare och bara en gång, även om flera saker
-- ber om den samtidigt: när handeln börjar och slutar, när väskorna ändras, efter varje
-- utläggning i Layout.lua och när väskfönstret stängs.
local updateScheduled = false

function ns.UpdateJunkButton()
    if not button or updateScheduled then
        return
    end
    updateScheduled = true
    C_Timer.After(0, function()
        updateScheduled = false
        update()
    end)
end

ns.OnLoad(function()
    if not ns.bagFrame then
        return
    end
    -- Namnet gör knappen lätt att hitta med /fstack. Det börjar med addonets namn.
    button = CreateFrame("Button", "TidyPackSellJunkButton", UIParent, "SecureActionButtonTemplate, UIPanelButtonTemplate")
    button:SetHeight(22)
    button:SetAttribute("type", "macro")
    -- Både ned och upp: spelets säkra knappar agerar på det som inställningen
    -- "ActionButtonUseKeyDown" säger.
    button:RegisterForClicks("AnyUp", "AnyDown")
    button:Hide()

    ns.RegisterEvent("MERCHANT_SHOW", ns.UpdateJunkButton)
    ns.RegisterEvent("MERCHANT_CLOSED", ns.UpdateJunkButton)
    ns.RegisterEvent("BAG_UPDATE_DELAYED", ns.UpdateJunkButton)
    ns.RegisterEvent("PLAYER_REGEN_ENABLED", ns.UpdateJunkButton)
end)
