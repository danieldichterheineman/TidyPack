-- TidyPack – Gamepad.lua
-- Gör handkontrollens markör enkel i Tidy Packs grupper.
--
-- Spelets markör (SmartNavigation) är byggd för spelets eget rutnät, där alla rutor står i
-- jämna rader och väskorna syns sist. Med Tidy Packs grupper blev tre saker fel:
--   1. Markören började på ryggsäckens väskknapp, som Tidy Pack döljer.
--   2. LB och RB hoppar mellan väskorna, alltså till de dolda väskknapparna. Ett tryck på A
--      där plockar upp en väska som du har på dig.
--   3. Styrkorset följer ett rutnät (kolumner efter exakt läge, rader räknade nerifrån) som
--      inte passar grupper sida vid sida, och som inte följer med när Tidy Pack flyttar
--      rutorna. Efter en försäljning kunde markören stanna på en dold ruta.
-- Tidy Pack rättar det så här:
--   1. Markören börjar på det du nyss fått (gruppen New), annars på första rutan.
--   2. LB och RB hoppar till förra eller nästa grupp.
--   3. Styrkorset använder spelets fria navigering: närmaste ruta åt det håll du trycker,
--      utifrån var rutorna ligger just då. Döljs rutan som markören står på, flyttas markören
--      till den närmaste ruta som syns.
-- Dessutom spärras låsta saker hos en handlare för markören (se ns.SetGamepadClickBlocked).
--
-- Spelet låter addons anropa just de här funktionerna (SetUseGridNavigation,
-- SetTargetButtonForFrame och SmartNavigation_*), men bara utanför strid. Tidy Pack ändrar
-- aldrig i spelets tabeller: det lyssnar med hooksecurefunc, som kör vår kod efter spelets,
-- och gör själva rättningen en bildruta senare.
-- ⚠️ I strid blockerar spelet funktionerna. Tidy Pack väntar då tills striden är över, och
--    under tiden fungerar markören som utan Tidy Pack.
-- ⚠️ LB och RB utgår från spelets egen väskräkning. Är nyckelringen påslagen gör LB ingenting
--    på saker i ryggsäcken och RB ingenting på nycklar – precis som i spelets eget fönster.

local addonName, ns = ...

local bagFrame
local fixScheduled = false
local wantFreeNavigation = false -- spelet har slagit på sitt rutnät för väskfönstret
local jumpFrom, jumpStep         -- LB/RB: rutan markören kom från, och 1 (RB) eller -1 (LB)
local previousButton             -- rutan som markören stod på före den senaste flytten
local waitingForCombat = false   -- något fick vänta tills striden är över

-- Rutor som markören inte får klicka på (låsta saker hos en handlare).
local blockedButtons = setmetatable({}, { __mode = "k" })

-- Sant när addons får anropa markörens funktioner. Samma kontroll som spelets kod gör
-- (SecureHelper i Blizzard_GamepadSmartNavigation). I strid skulle spelet blockera anropet
-- och visa ett felmeddelande.
local function canUseNavigation()
    if C_RestrictedActions and C_RestrictedActions.IsAddOnRestrictionActive then
        return not C_RestrictedActions.IsAddOnRestrictionActive(Enum.AddOnRestrictionType.Combat)
    end
    return not InCombatLockdown()
end
ns.CanUseNavigation = canUseNavigation -- används också av MakeRoom.lua

local function isGamepadMode()
    return SmartNavigation ~= nil and InputUtil.IsGamepadUIEnabled()
end

-- Handkontrollens knapp som en bild i en text, t.ex. A på en Xbox-kontroll. Spelet väljer
-- bilden efter vilken kontroll som används (InputIconTexture.lua i spelets kod). Ger tom
-- text om bilden saknas.
function ns.GamepadIcon(key, size)
    local textures = InputIconTextureSetUtility and InputIconTextureSetUtility.GetActiveInputIconButtonTextures(key)
    local atlas = textures and textures[1] -- 1 = InputIconTextureState.Normal i spelets kod
    if not atlas then
        return ""
    end
    size = size or 16
    return CreateAtlasMarkup(atlas, size, size)
end

-- Spelets väskknappar för handkontroll ligger i GamepadBagBar, som Tidy Pack döljer.
local function isBagBarButton(button)
    return GamepadBagBar ~= nil and button:GetParent() == GamepadBagBar
end

-- Väskfönstrets egna rutor och väskknappar.
local function isBagFrameButton(button)
    return button:GetParent() == bagFrame or isBagBarButton(button)
end

-- LB eller RB? Spelet väljer väskan efter (RB) eller före (LB) den som saken ligger i, med
-- samma omslag som i spelets kod (Gamepad_SetCursorToBag i ContainerFrame.lua).
local function jumpDirection(fromBagID, toBagID)
    local nextBagID = fromBagID + 1
    if nextBagID > ENDING_BAG_INDEX then
        nextBagID = STARTING_BAG_INDEX
    end
    return toBagID == nextBagID and 1 or -1
end

-- Den ruta som markören ska till när den står på en ruta som inte syns.
local function chooseTarget(current, from, step)
    if from and from:IsVisible() then
        return ns.GetGroupJumpTarget(from, step) -- LB eller RB
    end
    if isBagBarButton(current) then
        return ns.GetStartButton() -- väskan öppnades
    end
    local x, y = current:GetCenter()
    -- Rutan döljs, t.ex. när saken sålts: närmast den plats där den låg.
    return x and ns.GetNearestShownButton(x, y) or ns.GetStartButton()
end

-- Själva rättningen. Körs en bildruta efter att något hänt, så att spelets och Tidy Packs
-- utläggning är klar.
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

    -- Spelets fria navigering i stället för rutnätet.
    if wantFreeNavigation then
        wantFreeNavigation = false
        SmartNavigation:SetUseGridNavigation(bagFrame, false)
    end

    -- Markören får aldrig stå på en ruta som inte syns.
    local current = SmartNavigation:GetCurrentButton()
    if current and isBagFrameButton(current) and not current:IsVisible() then
        local target = chooseTarget(current, from, step)
        if target and target:IsVisible() then
            -- Väljer rutan direkt, eftersom väskfönstret har markören.
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

-- Körs efter varje flytt av markören, i alla fönster. Gör bara något när markören hamnat på
-- en dold ruta i väskfönstret.
local function onButtonSelected(navigation)
    local current = navigation:GetCurrentButton()
    local previous = previousButton
    previousButton = current
    if not current or current:IsVisible() or not isBagFrameButton(current) then
        return
    end
    -- Kom markören från en synlig sak till en dold väskknapp var det LB eller RB.
    if isBagBarButton(current) and previous and previous ~= current and previous:IsVisible()
        and previous:GetParent() == bagFrame and previous.GetBagID and current.GetBagID then
        jumpFrom = previous
        jumpStep = jumpDirection(previous:GetBagID(), current:GetBagID())
    end
    scheduleFix()
end

-- Layout.lua anropar den här efter varje utläggning, eftersom rutor kan ha dolts.
function ns.OnLayoutChanged()
    if bagFrame and isGamepadMode() then
        scheduleFix()
    end
end

---------------------------------------------------------------------------
-- Låsta saker hos en handlare
---------------------------------------------------------------------------
-- Med mus stänger Layout.lua av låsta rutor. Med handkontroll går det inte: när en ruta som
-- markören står på stängs av, kör spelet sin kod för knapptipsen längst ned i Tidy Packs
-- namn, och sedan kan spelet blockera Use och Sell ("Interface action failed because of an
-- AddOn"). I stället säger Tidy Pack åt markören att inte klicka på rutan, med spelets egen
-- funktion för det (SmartNavigation_MarkFrameBlockingSmartNavClick). Då gör både A och X
-- ingenting på saken.

-- Spärrar (true) eller släpper (false) markörens klick på en ruta. Returnerar false om det
-- fick vänta tills striden är över.
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
        -- Spelet har bara en funktion som släpper spärren: den som tar bort allt Tidy Pack
        -- och spelet ställt in för markören på rutan.
        SmartNavigation_ResetData(button)
        blockedButtons[button] = nil
    end
    return true
end

-- Släpper alla spärrar, t.ex. när handeln är slut. En quest-sak måste gå att använda i strid
-- även om väskan var stängd när handeln slutade.
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

    -- Spelet slår på sitt rutnät varje gång väskfönstret får markören.
    hooksecurefunc(SmartNavigation, "SetUseGridNavigation", function(_, frame, useGrid)
        if frame == bagFrame and useGrid then
            wantFreeNavigation = true
            scheduleFix()
        end
    end)

    hooksecurefunc(SmartNavigation, "SelectButton", onButtonSelected)

    ns.RegisterEvent("MERCHANT_CLOSED", unblockAll)

    -- Striden är över: gör det som fick vänta. ADDON_RESTRICTION_STATE_CHANGED kommer när
    -- spelets spärr för addons slås på eller släpps, PLAYER_REGEN_ENABLED när striden tar slut.
    local function onCombatEnded()
        if not waitingForCombat or not canUseNavigation() then
            return
        end
        waitingForCombat = false
        if not ns.IsAtMerchant() then
            unblockAll()
        end
        if ns.Refresh then
            ns.Refresh() -- lägger ut allt igen, med spärrarna och markören
        end
        scheduleFix()
    end
    ns.RegisterEvent("PLAYER_REGEN_ENABLED", onCombatEnded)
    ns.RegisterEvent("ADDON_RESTRICTION_STATE_CHANGED", function(restrictionType)
        if restrictionType == Enum.AddOnRestrictionType.Combat then
            -- Under själva eventet svarar spelet alltid att ingen spärr gäller, så kontrollen
            -- görs en bildruta senare.
            C_Timer.After(0, onCombatEnded)
        end
    end)
end)
