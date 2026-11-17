-- TidyPack – ItemMarks.lua
-- Marks on the item buttons: item level and BoE, the green upgrade arrow, locks at merchants, the "..."
-- for Alt-click and the empty slots' counts and tooltips. Moved out of Layout.lua unchanged 2026-11-17
-- (the split of Layout.lua, step 4). Layout.lua calls ns.UpdateItemMarks for each button it places
-- and ns.SetButtonLocked to undo a lock; the tables of marks and locked buttons are shared in ns.layout.

local _, ns = ...
local L = ns.L

local layout = ns.layout
local BAG_GLOW_ATLAS, BAG_GLOW_COLOR, LOW_SPACE = layout.BAG_GLOW_ATLAS, layout.BAG_GLOW_COLOR, layout.LOW_SPACE
local extras, lockedButtons, disabledButtons = layout.extras, layout.lockedButtons, layout.disabledButtons
local emptyFree = setmetatable({}, { __mode = "k" })     -- empty slot → free slots, for the tooltip
local location = ItemLocation:CreateEmpty() -- reused to read an item's level
-- Gear where the item level says nothing shows without a level (shirts and tabards).
local NO_LEVEL = { INVTYPE_BODY = true, INVTYPE_TABARD = true, INVTYPE_NON_EQUIP_IGNORE = true }

---------------------------------------------------------------------------
-- Upgrade arrow (the owner's wish 2026-11-11)
---------------------------------------------------------------------------
-- A green arrow (the game's bags-greenarrow) on gear with a higher level than what you wear in the
-- same slot, and that you can use. Rings, trinkets and one-handed weapons are compared with the worse of
-- the two slots; an empty slot counts as level 0.
local SLOTS_FOR = {
    INVTYPE_HEAD = { INVSLOT_HEAD }, INVTYPE_NECK = { INVSLOT_NECK }, INVTYPE_SHOULDER = { INVSLOT_SHOULDER },
    INVTYPE_CHEST = { INVSLOT_CHEST }, INVTYPE_ROBE = { INVSLOT_CHEST }, INVTYPE_WAIST = { INVSLOT_WAIST },
    INVTYPE_LEGS = { INVSLOT_LEGS }, INVTYPE_FEET = { INVSLOT_FEET }, INVTYPE_WRIST = { INVSLOT_WRIST },
    INVTYPE_HAND = { INVSLOT_HAND }, INVTYPE_FINGER = { INVSLOT_FINGER1, INVSLOT_FINGER2 },
    INVTYPE_TRINKET = { INVSLOT_TRINKET1, INVSLOT_TRINKET2 }, INVTYPE_CLOAK = { INVSLOT_BACK },
    INVTYPE_WEAPON = { INVSLOT_MAINHAND, INVSLOT_OFFHAND }, INVTYPE_2HWEAPON = { INVSLOT_MAINHAND },
    INVTYPE_WEAPONMAINHAND = { INVSLOT_MAINHAND }, INVTYPE_WEAPONOFFHAND = { INVSLOT_OFFHAND },
    INVTYPE_SHIELD = { INVSLOT_OFFHAND }, INVTYPE_HOLDABLE = { INVSLOT_OFFHAND },
    INVTYPE_RANGED = { INVSLOT_RANGED }, INVTYPE_RANGEDRIGHT = { INVSLOT_RANGED },
    INVTYPE_THROWN = { INVSLOT_RANGED }, INVTYPE_RELIC = { INVSLOT_RANGED },
}
local equipLocation = ItemLocation:CreateEmpty()
local usableCache = {} -- link → true/false; cleared when you level up or learn something

local function equippedLevel(slot)
    if not slot then
        return nil
    end
    equipLocation:SetEquipmentSlot(slot)
    if not C_Item.DoesItemExist(equipLocation) then
        return 0
    end
    return C_Item.GetCurrentItemLevel(equipLocation) or 0
end

-- Can you use the item? The game writes what you lack (wrong armor type, too low level) in red in
-- the item's tooltip, so it is read from there (C_TooltipInfo.GetBagItem).
local function canUse(entry)
    local cached = usableCache[entry.link]
    if cached ~= nil then
        return cached
    end
    -- A saved item in the bank (Bank.lua) has no slot right now; its tooltip is read from the link.
    local data
    if entry.offline then
        data = C_TooltipInfo and C_TooltipInfo.GetHyperlink(entry.link)
    else
        data = C_TooltipInfo and C_TooltipInfo.GetBagItem(entry.bagID, entry.slot)
    end
    if not data or not data.lines then
        return false -- not known yet; asked again next time
    end
    local usable = true
    for _, line in ipairs(data.lines) do
        local color = line.leftColor
        if color and color.r > 0.9 and color.g < 0.2 and color.b < 0.2 then
            usable = false
            break
        end
    end
    usableCache[entry.link] = usable
    return usable
end

local function isUpgrade(entry, level)
    local slots = level and entry.equipLocation and SLOTS_FOR[entry.equipLocation]
    if not slots or not canUse(entry) then
        return false
    end
    local lowest
    for _, slot in ipairs(slots) do
        local equipped = equippedLevel(slot)
        if equipped then
            lowest = lowest and math.min(lowest, equipped) or equipped
        end
    end
    return lowest ~= nil and level > lowest
end

for _, event in ipairs({ "PLAYER_LEVEL_UP", "SKILL_LINES_CHANGED", "PLAYER_EQUIPMENT_CHANGED" }) do
    ns.RegisterEvent(event, function()
        wipe(usableCache)
        if ns.Refresh then
            ns.Refresh()
        end
    end)
end


-- Tooltip on the empty slot: how many slots are free and what the slot is for.
local function showEmptyTooltip(button)
    local free = emptyFree[button]
    if not free then
        return
    end
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    GameTooltip_SetTitle(GameTooltip, L["Free slots: %d"]:format(free))
    GameTooltip_AddInstructionLine(GameTooltip, L["Drop an item here to put it in your bags."])
    GameTooltip:Show()
end

local function getExtras(button)
    local extra = extras[button]
    if not extra then
        -- The layer ARTWORK is under the game's dark search layer, so the text dims
        -- together with the button when it doesn't match the search.
        extra = {
            level = button:CreateFontString(nil, "ARTWORK", "NumberFontNormalSmall"),
            bind = button:CreateFontString(nil, "ARTWORK", "NumberFontNormalSmall"),
            free = button:CreateFontString(nil, "ARTWORK", "NumberFontNormal"),
            lock = button:CreateTexture(nil, "OVERLAY", nil, 6),
            later = button:CreateTexture(nil, "OVERLAY", nil, 6),
            -- A + in the middle of the empty slot: drop an item here.
            plus = button:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge"),
            -- Count you have / count a quest item needs ("3/7"), where the level is on gear.
            quest = button:CreateFontString(nil, "ARTWORK", "NumberFontNormalSmall"),
            -- The mark "..." shown on every item while Alt is held: the items can be Alt-clicked.
            altBg = button:CreateTexture(nil, "OVERLAY", nil, 5),
            -- Blue glow around the items in the bag the mouse is on in the bag row (the game's glow for new
            -- items, bags-glow-white, colored blue).
            bagGlow = button:CreateTexture(nil, "OVERLAY", nil, 7),
            upgrade = button:CreateTexture(nil, "OVERLAY", nil, 6),
            alt = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"),
        }
        extra.upgrade:SetAtlas("bags-greenarrow")
        extra.upgrade:SetSize(14, 16)
        extra.upgrade:SetPoint("TOPRIGHT", -1, -1)
        extra.upgrade:Hide()
        extra.bagGlow:SetAtlas(BAG_GLOW_ATLAS, true)
        extra.bagGlow:SetPoint("CENTER")
        extra.bagGlow:SetBlendMode("ADD")
        extra.bagGlow:SetVertexColor(unpack(BAG_GLOW_COLOR))
        extra.bagGlow:Hide()
        extra.altBg:SetColorTexture(0, 0, 0, 0.75)
        extra.altBg:SetSize(18, 11)
        extra.altBg:SetPoint("TOPRIGHT", -1, -1)
        extra.alt:SetPoint("CENTER", extra.altBg, "CENTER", 0, 2)
        extra.alt:SetText("...")
        extra.altBg:Hide()
        extra.alt:Hide()
        extra.quest:SetPoint("TOPLEFT", 2, -2)
        extra.plus:SetPoint("CENTER", 0, 1)
        extra.plus:SetText("+")
        extra.level:SetPoint("TOPLEFT", 2, -2)
        extra.bind:SetPoint("BOTTOMLEFT", 2, 2)
        extra.bind:SetText(L["BoE"])
        -- The same place and font as the game's own count (Count in ItemButtonTemplate).
        extra.free:SetPoint("BOTTOMRIGHT", -5, 2)
        extra.lock:SetAtlas("LFG-lock")
        extra.lock:SetSize(12, 14)
        extra.lock:SetPoint("TOPRIGHT", -1, -1)
        -- The map's yellow exclamation mark for quests you can take (QuestNormal), in the lock's place.
        extra.later:SetAtlas("QuestNormal")
        extra.later:SetSize(10, 14)
        extra.later:SetPoint("TOPRIGHT", -1, -1)
        extras[button] = extra
        -- The game's yellow border around quest items isn't needed: they're already in Quest Items (the
        -- owner's wish 2026-11-11). The game sets it in UpdateQuestItem; Tidy Pack hides it right after.
        -- The yellow exclamation mark on items that start a quest stays.
        if button.UpdateQuestItem and button.IconQuestTexture then
            hooksecurefunc(button, "UpdateQuestItem", function(self, _, questID, isActive)
                if not (questID and not isActive) then
                    self.IconQuestTexture:Hide()
                end
            end)
        end
        -- A disabled button otherwise shows no tooltip. Locked items at a merchant must show
        -- theirs, with the line about why they are locked.
        button:SetMotionScriptsWhileDisabled(true)
        button:HookScript("OnEnter", showEmptyTooltip)
    end
    return extra
end

-- Locks or releases a button at a merchant, so the item can't be sold by mistake.
-- With the mouse the button is disabled. With a controller the cursor may not click it instead,
-- because when the game's cursor is on a button that gets disabled, the game's button-hint code runs in
-- Tidy Pack's name, and then the game can block Use and Sell (see Gamepad.lua).
local function setLocked(button, locked)
    lockedButtons[button] = locked or nil
    local gamepad = InputUtil.IsGamepadUIEnabled() and ns.SetGamepadClickBlocked ~= nil
    if gamepad then
        ns.SetGamepadClickBlocked(button, locked)
    end
    local disable = locked and not gamepad
    if disable then
        button:Disable()
        disabledButtons[button] = true
    elseif disabledButtons[button] then
        button:Enable()
        disabledButtons[button] = nil
    end
end

local function updateExtras(entry, atMerchant)
    local button = entry.button
    local extra = getExtras(button)

    -- The empty-slot count on the merged empty slot (category mode). Red when few are left.
    local showFree = entry.isEmpty == true and entry.free ~= nil
    extra.plus:SetShown(showFree)
    emptyFree[button] = showFree and entry.free or nil
    if showFree then
        extra.free:SetText(entry.free)
        local color = entry.free <= LOW_SPACE and RED_FONT_COLOR or HIGHLIGHT_FONT_COLOR
        extra.free:SetTextColor(color:GetRGB())
        extra.free:Show()
    else
        extra.free:Hide()
    end

    -- Level at the top left and BoE at the bottom left, only on uncommon or better weapons and
    -- armor – on simpler items they rarely say anything.
    -- Marked junk gets no level: the junk coin sits there. Level and BoE can be turned off in
    -- the options (Options.lua).
    local level, boe, upgrade
    -- The item's level: from the slot, or from the link for a saved item in the bank (Bank.lua), which
    -- isn't in any slot right now.
    local function itemLevel()
        if entry.offline then
            return (C_Item.GetDetailedItemLevelInfo(entry.link))
        end
        location:SetBagAndSlot(entry.bagID, entry.slot)
        return C_Item.GetCurrentItemLevel(location)
    end
    -- The upgrade arrow applies to all gear that isn't junk (also white items).
    if ns.db.upgradeArrows and entry.isGear and not entry.isEmpty and not entry.junkMarked
        and entry.quality > Enum.ItemQuality.Poor and entry.equipLocation and SLOTS_FOR[entry.equipLocation] then
        upgrade = isUpgrade(entry, itemLevel())
    end
    if ns.db.itemLevelAndBoE and entry.isGear and entry.quality >= Enum.ItemQuality.Uncommon
        and not entry.junkMarked then
        if entry.equipLocation and entry.equipLocation ~= "" and not NO_LEVEL[entry.equipLocation] then
            level = itemLevel()
        end
        -- The binding is the 14th value from GetItemInfo. If the item's data is still missing it is
        -- nil, and then BoE shows the next time the bags update.
        local bindType = select(14, C_Item.GetItemInfo(entry.link))
        boe = bindType == Enum.ItemBind.OnEquip and not entry.isBound
    end
    if level and level > 1 then
        extra.level:SetText(level)
        extra.level:Show()
    else
        extra.level:Hide()
    end
    extra.bind:SetShown(boe == true)
    extra.upgrade:SetShown(upgrade == true)

    -- Count you have / count needed for a quest item, green when enough. The item is then
    -- no gear to show a level on. In the Quests tab the numbers are in the line instead.
    local record = entry.questRecord
    if record and record.need > 0 and not entry.hideProgress and not entry.isEmpty then
        extra.quest:SetText(("%d/%d"):format(record.have, record.need))
        extra.quest:SetTextColor((record.have >= record.need and GREEN_FONT_COLOR or HIGHLIGHT_FONT_COLOR):GetRGB())
        extra.quest:Show()
        extra.level:Hide()
    else
        extra.quest:Hide()
    end

    -- The lock shows only at a merchant, and then locked items can't be clicked – neither
    -- with mouse nor controller – so they can't be sold by mistake (see QuestLock.lua).
    -- The locks can be turned off in the options (Options.lua).
    local locked = atMerchant and entry.locked == true and ns.db.lockAtMerchant
    extra.lock:SetShown(locked)
    if locked then
        extra.upgrade:Hide() -- the lock is in the same place
    end
    setLocked(button, locked)
    local showAlt = IsAltKeyDown() and not entry.isEmpty and not locked
    extra.alt:SetShown(showAlt)
    extra.altBg:SetShown(showAlt)

    -- The exclamation mark: a quest you haven't taken yet needs the item (QuestHints.lua).
    -- The lock goes first, because it sits in the same place.
    extra.later:SetShown(entry.neededLater == true and not locked)

    -- The game's junk coin. The game shows it itself on grey items at a merchant
    -- (UpdateJunkItem), and Tidy Pack also shows it on items you have marked as junk.
    -- The condition includes the game's own, so the game's coin stays.
    if button.JunkIcon then
        local gameShowsCoin = entry.quality == Enum.ItemQuality.Poor and not entry.noValue and atMerchant
        button.JunkIcon:SetShown(entry.junkMarked == true or gameShowsCoin)
    end

    -- Green arrow on bags bigger than one of your bags (see BagSwap.lua). The arrow
    -- is already in the game's button but the game doesn't use it in the bags.
    if button.UpgradeIcon then
        local isUpgrade = entry.isContainer == true and ns.IsBagUpgrade ~= nil
            and ns.IsBagUpgrade(entry.bagID, entry.slot, entry.itemID)
        button.UpgradeIcon:SetShown(isUpgrade == true)
    end

    -- Alt-click for favorites and junk (see Marks.lua). Not on saved items in the bank: they have
    -- no slot to read the item from.
    if ns.HookItemButton and not entry.offline then
        ns.HookItemButton(button)
    end
end

ns.UpdateItemMarks = updateExtras
ns.SetButtonLocked = setLocked
