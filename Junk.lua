-- TidyPack – Junk.lua
-- Knappen Sell Junk. Den syns ovanför väskfönstret när du handlar och det finns skräp:
-- gråa saker som går att sälja, utom stjärnmärkta och låsta. Ett klick säljer högst 12, så
-- att allt går att köpa tillbaka i handlarens Buyback-flik. Klicka igen för fler.
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

-- Hittar skräpet som Sell Junk får sälja. Returnerar kommandona för de första 12, hur många
-- saker det finns och vad de är värda tillsammans (i koppar).
local function findJunk()
    wipe(lines)
    local count, value = 0, 0
    for bagID = 0, NUM_BAGS do
        for slot = 1, C_Container.GetContainerNumSlots(bagID) do
            local info = C_Container.GetContainerItemInfo(bagID, slot)
            if info and info.quality == Enum.ItemQuality.Poor and not info.hasNoValue and not info.isLocked
                and not ns.IsFavorite(info.itemID) and not ns.IsLocked(bagID, slot, info) then
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

-- Lägger knappen ovanför väskfönstrets vänstra del. Knappen hänger i UIParent, inte i
-- väskfönstret, så platsen räknas om till UIParents skala.
local function place(bagFrame)
    local left, top = bagFrame:GetLeft(), bagFrame:GetTop()
    if not left or not top then
        return false
    end
    local scale = bagFrame:GetEffectiveScale() / UIParent:GetEffectiveScale()
    button:ClearAllPoints()
    button:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left * scale + 60, top * scale + 6)
    return true
end

-- Visar, uppdaterar eller döljer knappen. Körs när handeln börjar och slutar, när väskorna
-- ändras och när väskfönstret flyttas eller stängs.
function ns.UpdateJunkButton()
    if not button or InCombatLockdown() then
        return -- säkra knappar kan inte ändras i strid; görs när striden är slut
    end
    local bagFrame = ns.bagFrame
    local show = ns.IsAtMerchant() and bagFrame:IsShown()
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
