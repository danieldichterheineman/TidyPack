-- TidyPack – BottomRow.lua
-- The row at the bottom of the bag window: the free-slot count ("18 free") and its tooltip, the taller
-- money row with the money in its middle, the bag row (your bags as small icons), the bank's row in
-- the Bank tab, and the yellow border with a line while you hold an item over the bags. Moved out of
-- Layout.lua unchanged 2026-11-17 (the split of Layout.lua, step 3). Layout.lua calls
-- ns.UpdateFreeText after each layout and draws the blue glow on a bag's items (ns.DimBag); the
-- shared numbers are in ns.layout. This file loads after Layout.lua, so its start runs after the
-- bag window's.

local _, ns = ...
local L = ns.L

local layout = ns.layout
local BUTTON, MONEY_RAISE, LOW_SPACE = layout.BUTTON, layout.MONEY_RAISE, layout.LOW_SPACE
local BAG_GLOW_ATLAS, BAG_GLOW_COLOR = layout.BAG_GLOW_ATLAS, layout.BAG_GLOW_COLOR
local NUM_BAGS, REAGENT_BAG, LAST_BAG = layout.NUM_BAGS, layout.REAGENT_BAG, layout.LAST_BAG
-- The money row is made taller, with "17 free" and the bag row on its left and the money on its
-- right (the owner's wish 2026-11-11). The game's low money box (MoneyFrame.Border) is hidden and
-- replaced by a taller one with the same images; the money stays in the game's place, mid-row.
local BAR_HEIGHT = 46       -- the taller row's height (38 was too low: the bags touched the edges)

local freeText -- the free-slot count at the bottom left (with the mouse, instead of "Add to bag")
local moneyRaised = false -- the money is moved (not when the game shows currencies under it)

-- Layout.lua makes the window taller by MONEY_RAISE while the money is moved.
function ns.IsMoneyRaised()
    return moneyRaised
end

-- "10 free" at the bottom left, red when few are left. With a controller the slot "Add to bag" shows
-- the same, so then the text isn't shown.
function ns.UpdateFreeText()
    if not freeText then
        return
    end
    if InputUtil.IsGamepadUIEnabled() then
        freeText:Hide()
        return
    end
    if ns.UpdateBagBar then
        ns.UpdateBagBar()
    end
    local free = C_Container.CalculateTotalNumberOfFreeBagSlots()
    -- In the Bank tab: the bank's free slots (Bank.lua).
    if ns.GetView and ns.GetView() == "bank" and ns.GetBankFreeSlots then
        free = ns.GetBankFreeSlots()
    end
    freeText:SetText(L["%d free"]:format(free))
    freeText:SetTextColor((free <= LOW_SPACE and RED_FONT_COLOR or HIGHLIGHT_FONT_COLOR):GetRGB())
    freeText:Show()
    -- The row after the count: your bags, or in the Bank tab the bank's own slots.
    if ns.UpdateBottomRow then
        ns.UpdateBottomRow(ns.GetView and ns.GetView() == "bank")
    end
end

ns.OnLoad(function()
    local bagFrame, inset = ns.bagFrame, ns.layout.inset
    if not bagFrame then
        return
    end

    -- A yellow border and a line at the bottom while you hold an item over the bags. Checked only while
    -- the cursor holds something (CURSOR_CHANGED), so it costs nothing otherwise.
    -- In the layer HIGH, like the gear: neither +1 nor +20 in level was enough to show on top of
    -- the background's frame (screenshots 2026-11-11). The lines lie at the edge, outside the buttons.
    local glow = CreateFrame("Frame", nil, bagFrame)
    glow:SetAllPoints(inset)
    glow:SetFrameStrata("HIGH")
    for _, edge in ipairs({
        { "TOPLEFT", "TOPRIGHT", nil, 2 }, { "BOTTOMLEFT", "BOTTOMRIGHT", nil, 2 },
        { "TOPLEFT", "BOTTOMLEFT", 2, nil }, { "TOPRIGHT", "BOTTOMRIGHT", 2, nil },
    }) do
        local line = glow:CreateTexture(nil, "OVERLAY")
        line:SetColorTexture(1, 0.82, 0, 0.9)
        line:SetPoint(edge[1])
        line:SetPoint(edge[2])
        if edge[3] then
            line:SetWidth(edge[3])
        else
            line:SetHeight(edge[4])
        end
    end
    local label = CreateFrame("Frame", nil, bagFrame)
    label:SetFrameStrata("HIGH")
    -- In the money row, after the free-slot count and the bag row (anchored further down).
    label.bg = label:CreateTexture(nil, "BACKGROUND")
    label.bg:SetAllPoints()
    label.bg:SetColorTexture(0, 0, 0, 0.8)
    label.text = label:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label.text:SetPoint("CENTER")
    label.text:SetText(L["Drop anywhere to put it in your bags"])
    label:SetSize(label.text:GetStringWidth() + 16, 18)
    glow:Hide()
    label:Hide()

    -- In an own frame in the layer HIGH, like the line "Drop anywhere": directly in the window the text was
    -- drawn under the money row and didn't show (screenshot 2026-11-11).
    local freeHolder = CreateFrame("Frame", nil, bagFrame)
    freeHolder:SetFrameStrata("HIGH")
    freeHolder:SetAllPoints()
    freeText = freeHolder:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    -- The taller row with the game's images for the money box (the same as MoneyFrame.Border).
    local bar = CreateFrame("Frame", nil, bagFrame)
    bar:SetFrameLevel(math.max(bagFrame:GetFrameLevel() + 1, bagFrame.MoneyFrame:GetFrameLevel() - 1))
    bar:SetHeight(BAR_HEIGHT)
    -- As wide as the background above, so they stand like two cards in a column.
    bar:SetPoint("LEFT", inset, "LEFT")
    bar:SetPoint("RIGHT", inset, "RIGHT")
    -- The bottom near the window's edge (like the game's own box); the money ends up almost in the middle.
    bar:SetPoint("BOTTOM", bagFrame, "BOTTOM", 0, 6)
    local left = bar:CreateTexture(nil, "BACKGROUND")
    left:SetAtlas("common-coinbox-left")
    left:SetPoint("TOPLEFT")
    left:SetPoint("BOTTOMLEFT")
    left:SetWidth(8)
    local right = bar:CreateTexture(nil, "BACKGROUND")
    right:SetAtlas("common-coinbox-right")
    right:SetPoint("TOPRIGHT")
    right:SetPoint("BOTTOMRIGHT")
    right:SetWidth(8)
    local center = bar:CreateTexture(nil, "BACKGROUND")
    center:SetAtlas("_common-coinbox-center")
    center:SetPoint("TOPLEFT", left, "TOPRIGHT")
    center:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT")
    local border = bagFrame.MoneyFrame.Border
    if border then
        hooksecurefunc(border, "Show", function(self)
            if moneyRaised then
                self:Hide()
            end
        end)
    end
    -- The money moves up to the middle of the taller row, after the game's own placing. If the
    -- game shows currencies under the money it stays, and then the game's own low money box is used.
    local function placeMoney()
        local money = bagFrame.MoneyFrame
        local _, relativeTo = money:GetPoint(1)
        moneyRaised = relativeTo == bagFrame
        if moneyRaised then
            money:ClearAllPoints()
            money:SetPoint("BOTTOMLEFT", bagFrame, "BOTTOMLEFT", 8, 8 + MONEY_RAISE)
            money:SetPoint("BOTTOMRIGHT", bagFrame, "BOTTOMRIGHT", -8, 8 + MONEY_RAISE)
        end
        bar:SetShown(moneyRaised)
        if border then
            border:SetShown(not moneyRaised)
        end
    end
    if bagFrame.UpdateCurrencyFrames then
        hooksecurefunc(bagFrame, "UpdateCurrencyFrames", placeMoney)
    end
    placeMoney()
    -- 2 lower than the row's middle: the money's digits are bigger and reach further down, and this
    -- puts the two at the same height (the owner's screenshot 2026-11-15: the money looked lower).
    freeText:SetPoint("LEFT", bar, "LEFT", 10, -2)
    freeText:Hide()

    -- The bag row: the backpack and the four bag slots as small icons after the free-slot count
    -- (the owner's wish 2026-11-11, sketch .design/sketch-bag-bar.html). The number is the bag's
    -- slots. The mouse over a bag dims everything not in it. A bigger bag dropped
    -- on a slot replaces the bag there (the game moves the items); a normal item goes into that bag.
    -- The same functions as the game's own bag bar: PutItemInBag and PutItemInBackpack.
    local BAG_ICON = 22
    local bagButtons = {}
    -- The blue glow on a bag's items is drawn by Layout.lua, which owns the item buttons (ns.DimBag).
    local function dimOthers(bagID, inBank)
        ns.DimBag(bagID, inBank)
    end
    local function onBagDrop(self)
        if GetCursorInfo() ~= "item" then
            return
        end
        if self.bagID == 0 then
            PutItemInBackpack()
        else
            PutItemInBag(C_Container.ContainerIDToInventoryID(self.bagID))
        end
    end
    local function showBagTooltip(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        local size = C_Container.GetContainerNumSlots(self.bagID)
        if self.bagID == 0 then
            GameTooltip_SetTitle(GameTooltip, BACKPACK_TOOLTIP)
        elseif size > 0 then
            GameTooltip:SetInventoryItem("player", C_Container.ContainerIDToInventoryID(self.bagID))
        elseif self.bagID == REAGENT_BAG then
            GameTooltip_SetTitle(GameTooltip, L["Empty reagent bag slot"])
        else
            GameTooltip_SetTitle(GameTooltip, L["Empty bag slot"])
        end
        if size > 0 then
            GameTooltip_AddNormalLine(GameTooltip, L["%d slots · %d free"]:format(size,
                C_Container.GetContainerNumFreeSlots(self.bagID) or 0))
        end
        if self.bagID > 0 then
            GameTooltip_AddInstructionLine(GameTooltip, L["Drop a bag here to swap it."])
        end
        GameTooltip:Show()
        dimOthers(self.bagID)
        -- The bag itself gets the same blue glow as the items in it (the owner's wish 2026-11-12).
        self.glow:Show()
    end
    for bagID = 0, LAST_BAG do
        local button = CreateFrame("Button", nil, freeHolder)
        button.bagID = bagID
        button:SetSize(BAG_ICON, BAG_ICON)
        if bagID == 0 then
            button:SetPoint("LEFT", freeText, "RIGHT", 12, 0)
        else
            button:SetPoint("LEFT", bagButtons[bagID - 1], "RIGHT", 5, 0)
        end
        button.icon = button:CreateTexture(nil, "ARTWORK")
        button.icon:SetAllPoints()
        button.count = button:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
        button.count:SetPoint("BOTTOMRIGHT", 3, -2)
        button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
        -- The same glow as on the items (BAG_GLOW_ATLAS). The image is made for a 37-unit button, so
        -- it shrinks as much as the bag icon is smaller than a button.
        button.glow = button:CreateTexture(nil, "OVERLAY", nil, 7)
        button.glow:SetAtlas(BAG_GLOW_ATLAS, true)
        local glowWidth, glowHeight = button.glow:GetSize()
        button.glow:SetSize(glowWidth * BAG_ICON / BUTTON, glowHeight * BAG_ICON / BUTTON)
        button.glow:SetPoint("CENTER")
        button.glow:SetBlendMode("ADD")
        button.glow:SetVertexColor(unpack(BAG_GLOW_COLOR))
        button.glow:Hide()
        button:RegisterForClicks("LeftButtonUp")
        button:SetScript("OnClick", onBagDrop)
        button:SetScript("OnReceiveDrag", onBagDrop)
        button:SetScript("OnEnter", showBagTooltip)
        button:SetScript("OnLeave", function(self)
            GameTooltip_Hide()
            dimOthers(nil)
            self.glow:Hide()
        end)
        bagButtons[bagID] = button
    end
    label:SetPoint("LEFT", bagButtons[#bagButtons], "RIGHT", 10, 0)

    -- The bank's row (the owner's wish 2026-11-15, sketch .design/sketch-bank-slots.html): in the Bank
    -- tab the row shows the bank's own slots instead of your bags – the main bank, then the bank's bag
    -- slots: a bag (icon and size), a bought empty slot, "+" for the next slot to buy, and a lock for the
    -- rest. The data comes from Bank.lua (ns.GetBankSlots), at a banker live and away as saved.
    local bankButtons = {}
    local bankNextCost
    local function showBankSlotTooltip(self)
        local slot, kind = self.slot, self.kind
        local atBank = ns.IsAtBank and ns.IsAtBank()
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        if kind == "main" then
            GameTooltip_SetTitle(GameTooltip, L["Bank"])
        elseif kind == "bag" then
            if not (ns.SetBankBagTooltip and ns.SetBankBagTooltip(GameTooltip, slot)) then
                GameTooltip_SetTitle(GameTooltip, slot.name or L["Bank"])
            end
        elseif kind == "empty" then
            GameTooltip_SetTitle(GameTooltip, L["Empty bank bag slot"])
        else
            GameTooltip_SetTitle(GameTooltip, L["Bank bag slot %d"]:format(slot.index - 1))
        end
        if kind == "main" or kind == "bag" then
            GameTooltip_AddNormalLine(GameTooltip, L["%d slots · %d free"]:format(slot.slots, slot.free))
        end
        if kind == "buy" then
            if bankNextCost then
                GameTooltip_AddNormalLine(GameTooltip, L["Costs %s."]:format(GetMoneyString(bankNextCost)))
            end
            GameTooltip_AddInstructionLine(GameTooltip, atBank
                and L["Click to open the game's bank window, where you buy it."] or L["Visit a banker to buy it."])
        elseif kind == "lock" then
            GameTooltip_AddNormalLine(GameTooltip, L["Buy the slots before it first."])
        elseif atBank and kind == "empty" then
            GameTooltip_AddInstructionLine(GameTooltip, L["Drop a bag here to put it in your bank."])
        elseif atBank and kind == "bag" then
            GameTooltip_AddInstructionLine(GameTooltip, L["Drop a bag here to swap it."])
        end
        GameTooltip:Show()
        if (kind == "main" or kind == "bag") and slot.id then
            dimOthers(slot.id, true)
            self.glow:Show()
        end
    end
    -- A click or a drop on a bank slot. Buying goes through the game's bank window (Bank.lua).
    local function onBankSlotClick(self)
        local kind, slot = self.kind, self.slot
        if GetCursorInfo() == "item" then
            if (kind == "main" or kind == "bag" or kind == "empty") and ns.DropOnBankSlot then
                ns.DropOnBankSlot(slot.index)
            end
        elseif kind == "buy" then
            if ns.IsAtBank and ns.IsAtBank() and not ns.IsGameBankFrameShown() then
                ns.ToggleGameBankFrame()
            end
        elseif kind == "bag" and ns.PickupBankBag then
            ns.PickupBankBag(slot.index)
        end
    end
    local function bankButtonFor(index)
        local button = bankButtons[index]
        if button then
            return button
        end
        button = CreateFrame("Button", nil, freeHolder)
        button:SetSize(BAG_ICON, BAG_ICON)
        if index == 1 then
            button:SetPoint("LEFT", freeText, "RIGHT", 12, 0)
        else
            button:SetPoint("LEFT", bankButtons[index - 1], "RIGHT", 5, 0)
        end
        button.icon = button:CreateTexture(nil, "ARTWORK")
        button.icon:SetAllPoints()
        button.count = button:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
        button.count:SetPoint("BOTTOMRIGHT", 3, -2)
        button.plus = button:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        button.plus:SetPoint("CENTER", 0, 1)
        button.plus:SetText("+")
        button.lock = button:CreateTexture(nil, "OVERLAY")
        button.lock:SetAtlas("LFG-lock")
        button.lock:SetSize(12, 14)
        button.lock:SetPoint("CENTER")
        button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
        button.glow = button:CreateTexture(nil, "OVERLAY", nil, 7)
        button.glow:SetAtlas(BAG_GLOW_ATLAS, true)
        local glowWidth, glowHeight = button.glow:GetSize()
        button.glow:SetSize(glowWidth * BAG_ICON / BUTTON, glowHeight * BAG_ICON / BUTTON)
        button.glow:SetPoint("CENTER")
        button.glow:SetBlendMode("ADD")
        button.glow:SetVertexColor(unpack(BAG_GLOW_COLOR))
        button.glow:Hide()
        button:RegisterForClicks("LeftButtonUp")
        button:SetScript("OnClick", onBankSlotClick)
        button:SetScript("OnReceiveDrag", onBankSlotClick)
        button:SetScript("OnEnter", showBankSlotTooltip)
        button:SetScript("OnLeave", function(self)
            GameTooltip_Hide()
            dimOthers(nil)
            self.glow:Hide()
        end)
        bankButtons[index] = button
        return button
    end

    -- Shows your bags or the bank's slots after the free count (updateFreeText calls this).
    function ns.UpdateBottomRow(isBank)
        for _, button in pairs(bagButtons) do
            button:SetShown(not isBank)
        end
        local slots, nextCost = {}, nil
        if isBank and ns.GetBankSlots then
            slots, nextCost = ns.GetBankSlots()
        end
        bankNextCost = nextCost
        local firstUnbought = true
        for index, slot in ipairs(slots) do
            local button = bankButtonFor(index)
            local kind
            if index == 1 then
                kind = "main"
            elseif slot.bought then
                kind = (slot.slots or 0) > 0 and "bag" or "empty"
            elseif firstUnbought then
                kind, firstUnbought = "buy", false
            else
                kind = "lock"
            end
            button.slot, button.kind = slot, kind
            local texture = kind == "main" and "Interface\\Icons\\INV_Box_02"
                or kind == "bag" and (slot.icon or "Interface\\Icons\\INV_Misc_Bag_08") or nil
            if texture then
                button.icon:SetTexture(texture)
                button.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
                button.icon:SetAlpha(1)
            else
                button.icon:SetTexture("Interface\\Buttons\\UI-EmptySlot")
                button.icon:SetTexCoord(0.140625, 0.84375, 0.140625, 0.84375)
                button.icon:SetAlpha(kind == "empty" and 0.7 or 0.35)
            end
            button.count:SetText((kind == "main" or kind == "bag") and slot.slots or "")
            button.plus:SetShown(kind == "buy")
            button.lock:SetShown(kind == "lock")
            button:Show()
        end
        for index = #slots + 1, #bankButtons do
            bankButtons[index]:Hide()
        end
        -- The line "Drop anywhere ..." stands after the last button in the row.
        label:ClearAllPoints()
        label:SetPoint("LEFT", isBank and bankButtons[#slots] or bagButtons[#bagButtons], "RIGHT", 10, 0)
    end

    -- Point at the free count: how full each bag is, and in the Bank tab the bank's whole picture (how
    -- many bag slots are bought and filled, and what the next one costs).
    local function showFreeTooltip(self)
        if not freeText:IsShown() then
            return -- with a controller the count isn't shown
        end
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        local white, gold, grey = HIGHLIGHT_FONT_COLOR, NORMAL_FONT_COLOR, GRAY_FONT_COLOR
        if ns.GetView and ns.GetView() == "bank" and ns.GetBankSlots then
            local slots, nextCost = ns.GetBankSlots()
            local total, free, bought, withBag = 0, 0, 0, 0
            for index, slot in ipairs(slots) do
                if slot.bought then
                    total, free = total + (slot.slots or 0), free + (slot.free or 0)
                    if index > 1 then
                        bought = bought + 1
                        if (slot.slots or 0) > 0 then
                            withBag = withBag + 1
                        end
                    end
                end
            end
            GameTooltip_SetTitle(GameTooltip, L["Bank"])
            GameTooltip:AddLine(L["%d free of %d"]:format(free, total), gold:GetRGB())
            for index, slot in ipairs(slots) do
                if slot.bought and (slot.slots or 0) > 0 then
                    GameTooltip:AddLine(L["%s: %d free of %d"]:format(index == 1 and L["Bank"] or (slot.name or ""),
                        slot.free or 0, slot.slots), white:GetRGB())
                end
            end
            if #slots > 1 then
                GameTooltip:AddLine(L["Bag slots: %d of %d bought, %d with a bag"]:format(bought, #slots - 1, withBag),
                    grey:GetRGB())
            end
            if nextCost then
                GameTooltip:AddLine(L["Next bag slot: %s"]:format(GetMoneyString(nextCost)), GREEN_FONT_COLOR:GetRGB())
            end
            local age = not (ns.IsAtBank and ns.IsAtBank()) and ns.SavedBankAge and ns.SavedBankAge()
            if age then
                GameTooltip:AddLine(L["Last seen %s"]:format(age), grey:GetRGB())
            end
        else
            -- The same shape as the bank's: the total in gold (the same count as "N free", which only
            -- counts normal bags), then each bag. Special bags (e.g. a mining bag) are grey.
            GameTooltip_SetTitle(GameTooltip, L["Bags"])
            local lines, total = {}, 0
            for bagID = 0, LAST_BAG do
                local size = C_Container.GetContainerNumSlots(bagID)
                if size > 0 then
                    local bagFree, family = C_Container.GetContainerNumFreeSlots(bagID)
                    local special = family ~= nil and family ~= 0
                    if not special then
                        total = total + size
                    end
                    local name = C_Container.GetBagName(bagID) or (bagID == 0 and BACKPACK_TOOLTIP) or ""
                    lines[#lines + 1] = { L["%s: %d free of %d"]:format(name, bagFree or 0, size), special }
                end
            end
            GameTooltip:AddLine(L["%d free of %d"]:format(C_Container.CalculateTotalNumberOfFreeBagSlots(), total),
                gold:GetRGB())
            for _, line in ipairs(lines) do
                GameTooltip:AddLine(line[1], (line[2] and grey or white):GetRGB())
            end
        end
        GameTooltip:Show()
    end
    local freeHover = CreateFrame("Frame", nil, freeHolder)
    freeHover:SetPoint("TOPLEFT", freeText, "TOPLEFT", -4, 4)
    freeHover:SetPoint("BOTTOMRIGHT", freeText, "BOTTOMRIGHT", 4, -4)
    freeHover:EnableMouse(true)
    freeHover:SetScript("OnEnter", showFreeTooltip)
    freeHover:SetScript("OnLeave", GameTooltip_Hide)

    function ns.UpdateBagBar()
        for bagID, button in pairs(bagButtons) do
            local size = C_Container.GetContainerNumSlots(bagID)
            local texture
            if bagID == 0 then
                texture = "Interface\\Icons\\INV_Misc_Bag_08"
            else
                texture = GetInventoryItemTexture("player", C_Container.ContainerIDToInventoryID(bagID))
            end
            if texture then
                button.icon:SetTexture(texture)
                button.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
                button.icon:SetAlpha(1)
            else
                button.icon:SetTexture("Interface\\Buttons\\UI-EmptySlot")
                button.icon:SetTexCoord(0.140625, 0.84375, 0.140625, 0.84375)
                button.icon:SetAlpha(0.7)
            end
            button.count:SetText(size > 0 and size or "")
        end
    end

    -- While you hold a bag, the bag slots where it fits light up (normal bag → 1–4,
    -- reagent bag → 5).
    function ns.SetBagBarSwapHint(on, reagent)
        for bagID, button in pairs(bagButtons) do
            local match = reagent and (bagID == REAGENT_BAG) or (not reagent and bagID > 0 and bagID <= NUM_BAGS)
            if on and match then
                button:LockHighlight()
            else
                button:UnlockHighlight()
            end
        end
    end
    local watcher = CreateFrame("Frame")
    watcher:Hide()
    local sinceCheck = 0
    watcher:SetScript("OnUpdate", function(_, elapsed)
        -- Ten times a second is enough, and only while you hold an item.
        sinceCheck = sinceCheck + elapsed
        if sinceCheck < 0.1 then
            return
        end
        sinceCheck = 0
        local show = bagFrame:IsShown() and inset:IsShown() and bagFrame:IsMouseOver()
        -- In the Bank tab items can be put in only at a banker.
        local inBank = ns.GetView and ns.GetView() == "bank"
        if inBank and not (ns.IsAtBank and ns.IsAtBank()) then
            show = false
        end
        if show then
            label.text:SetText(inBank and L["Drop anywhere to put it in your bank"] or label.bagText)
            label:SetWidth(label.text:GetStringWidth() + 16)
        end
        glow:SetShown(show)
        label:SetShown(show)

    end)
    ns.RegisterEvent("CURSOR_CHANGED", function()
        local holding = GetCursorInfo() == "item"
        watcher:SetShown(holding)
        if not holding then
            glow:Hide()
            label:Hide()
        end
        -- Holding a bag: the bag row lights up where it can be swapped in, and the line says so.
        local _, itemID = GetCursorInfo()
        local classID, subClassID
        if holding and itemID then
            classID, subClassID = select(6, C_Item.GetItemInfoInstant(itemID))
        end
        local holdingBag = classID == Enum.ItemClass.Container
        local holdingReagentBag = holdingBag and subClassID == Enum.ItemContainerSubclass.Reagent
        -- The text for Bags; in the Bank tab the watcher above swaps it for the bank's.
        label.bagText = holdingBag and L["Drop on one of your bags to swap it"]
            or L["Drop anywhere to put it in your bags"]
        label.text:SetText(label.bagText)
        label:SetWidth(label.text:GetStringWidth() + 16)
        if ns.SetBagBarSwapHint then
            ns.SetBagBarSwapHint(holdingBag, holdingReagentBag)
        end
    end)
end)
