-- TidyPack – Layout.lua
-- Rearranges the buttons in the game's bag window, the one with all bags in one
-- (ContainerFrameCombinedBags), into groups with headings. The game first lays the buttons out in
-- its own grid, and right after that Tidy Pack moves them to its groups. The buttons, the
-- search box and the money are the game's own, so right-click, drag and drop and the controller's
-- buttons work as usual.
--
-- Tidy Pack never overwrites the game's functions. It uses hooksecurefunc, which runs
-- our code after the game's, mainly on three functions in the game's window:
--   UpdateFrameSize  – the game has worked out the window's size
--   UpdateItemLayout – the game has laid the buttons out in its grid
--   UpdateItems      – the game has updated what is in the buttons
-- ⚠️ With the mouse the game shows the keyring in its own window, which Tidy Pack doesn't change.
-- With a controller the keys are in the bag window and go to the group Keys.
-- The sizes started from the sketch in .design/sketch.html and were tuned after screenshots.

local _, ns = ...
local L = ns.L

-- Sizes in units, as in the sketch.
local BUTTON = 37          -- one slot, the same as the game's template ContainerFrameItemButtonTemplate
local SPACING = 5          -- the gap between slots, the same as in the game's own grid
-- Columns: 14 by default, and more (up to 20) when the items would otherwise make the
-- window taller than the screen (see chooseColumns). The window then gets wider instead of taller.
local MIN_COLUMNS, MAX_COLUMNS, COLUMN_STEP = 14, 20, 2
local CELL = BUTTON + SPACING
ns.ITEM_BUTTON_SIZE = BUTTON -- QuestsView.lua makes the slots smaller in the Quests tab
local function widthOf(cols)
    return cols * BUTTON + (cols - 1) * SPACING
end
local HEADER = 18          -- a group's heading, including the space under it
local GROUP_GAP = 12       -- the gap between groups sharing a line
local SHELF_GAP = 10       -- the gap between lines of groups (space above the next heading)
-- Space between the frame and the slots. The game's own grid is only 7–8 units from the frame
-- and 4 units above the money. Tidy Pack adds a little more, so the groups don't
-- crowd the edges (the owner's wish 2026-11-09).
local BLIZZARD_MONEY_GAP = 4 -- the game's gap between the slots and the money row
-- The dark background lies close to the window's edge, and the items have INSET_PAD space inside
-- it (the owner's wish 2026-11-10: the space had disappeared).
local PADDING_SIDE = 16      -- from the window's inner edge to the items (including the space); 14 gave too little at the sides
local INSET_PAD = 12         -- space between the background's edge and the items, top and bottom
-- The background (and the money row) reaches a little closer to the window's sides than the items
-- (the owner's wish 2026-11-11): the space at the sides inside the background is larger than top and bottom.
local INSET_PAD_X = 15
local PADDING_TOP = 20       -- between the title bar and the first heading (6 to the background + the space); 16 was too little
-- The money row is made taller, with "17 free" and the bag row on its left and the money on its
-- right (the owner's wish 2026-11-11). The game's low money box (MoneyFrame.Border) is hidden and
-- replaced by a taller one with the same images; the money stays in the game's place, mid-row.
local BAR_HEIGHT = 46       -- the taller row's height (38 was too low: the bags touched the edges)
-- The game puts the money 8 from the bottom (UpdateCurrencyFrames). It is moved up this much, so it
-- sits in the middle of the taller row: (6 + 46 / 2) - (8 + 16 / 2) = 13. The window gets as much taller.
local MONEY_RAISE = 13
local BAG_ROW = 17          -- space between the background and the taller row
local moneyRaised = false   -- the money is moved (not when the game shows currencies under it)
local MONEY_GAP = 16 + BAG_ROW -- between the last line of slots and the money row
local TARGET_SCALE = 0.85    -- how much the game may shrink the window to make it fit
local TAB_ROOM = 30          -- the tabs above the window
local MIN_QUESTS_HEIGHT = 120 -- the Quests tab is at least this tall
-- The search box is off by default (the owner's wish 2026-11-10, optional since 2026-11-14), so the
-- line the game leaves for it is used by the items. The game counts 12 units less for that line with
-- a controller (ContainerFrameCombinedBagsMixin:GetPaddingHeight, 75 with mouse, 63 with controller). Tuned after a screenshot.
local function searchRoom()
    -- 30 and then 40 left a band between the title bar and the background where the world shone through
    -- (screenshots 2026-11-10), hence 55.
    return InputUtil.IsGamepadUIEnabled() and 43 or 55
end
local LOW_SPACE = 5        -- this few free slots turns the free-slot number red
local SECTION_GAP = 8      -- space above and below the line between two parts
-- The line before the special bags is the same thin yellow line as between the parts (review 2026-11-12:
-- there were two different lines, the game's wider bank-divider here and a thin one between the parts).
local LINE_COLOR = { 1, 0.82, 0, 0.18 }
local DIVIDER_GAP = 8      -- space above and below the line before the special bags (like SECTION_GAP)
-- Bag slots that can hold a special bag: the four normal ones and the reagent bag. With the mouse the
-- game shows the reagent bag in its own window, and then it isn't in this one.
local NUM_BAGS = Constants.InventoryConstants.NumBagSlots
local REAGENT_BAG = Enum.BagIndex.ReagentBag or (NUM_BAGS + 1)
local LAST_BAG = NUM_BAGS + Constants.InventoryConstants.NumReagentBagSlots

-- Gear where the item level says nothing shows without a level (shirts and tabards).
local NO_LEVEL = { INVTYPE_BODY = true, INVTYPE_TABARD = true, INVTYPE_NON_EQUIP_IGNORE = true }

-- The blue glow while the mouse is on a bag in the bag row: on the items in the bag and on the bag itself.
local BAG_GLOW_ATLAS = "bags-glow-white" -- the game's glow for new items, colored blue
local BAG_GLOW_COLOR = { 0.25, 0.6, 1 }

-- The star before the heading Favorites.
local FAVORITE_ICON = "|A:auctionhouse-icon-favorite:13:13|a "

local bagFrame                    -- the game's window with all bags in one
local overlay                     -- our own frame in the game's window, for the headings
local inset                       -- the dark, inset background behind the items
local contentHeight               -- the height of what Tidy Pack lays out
local sharedHeight                -- the same height in all three tabs (Bags, Bank, Quests)
local gridCols = MIN_COLUMNS      -- columns right now
local gridWidth = widthOf(MIN_COLUMNS) -- the grid's width right now
local measurer                    -- invisible text that measures how wide the headings are
local questNote                   -- the line that replaces the quest items when they are hidden in the bags
local questNoteState              -- where the line is and what it says, or nil
local bankNote                    -- the text in the Bank tab away from the bank (Bank.lua)
local BANK_NOTE_HEIGHT = 34       -- room for the text, above the bank's items
local chromeWidth, chromeHeight   -- the window's edges, title bar, search box and money
local location = ItemLocation:CreateEmpty() -- reused to read an item's level

-- Shared buttons for containers the game's combined bag window doesn't draw itself (the reagent bag
-- with the mouse and the bank's buttons in Bank.lua). The game's template reads the bag number from the
-- parent frame's ID and the slot number from the button's ID, so normal clicks work without taint.
function ns.CreateLiveSlotHolder(containerID)
    local holder = CreateFrame("Frame", nil, bagFrame)
    holder:SetAllPoints()
    holder:SetFrameLevel(bagFrame:GetFrameLevel() + 5)
    -- The game's template reads the bag number here (GetParent():GetID()).
    holder:SetID(containerID)
    return holder
end

function ns.CreateLiveSlotButton(holder, slot)
    local button = CreateFrame("ItemButton", nil, holder, "ContainerFrameItemButtonTemplate")
    button:SetFrameLevel(math.max(10, holder:GetFrameLevel() + 1))
    button:SetID(slot)
    -- The template shows the shop's blue highlight (BattlepayItemTexture) from the start, and only the
    -- game's UpdateNewItem or pointing at the button hides it (ContainerFrame.lua). The bank's buttons
    -- don't mark new items, so without this every slot had a blue frame the first time (seen 2026-11-15).
    button.BattlepayItemTexture:Hide()
    button.NewItemTexture:Hide()
    return button
end

-- The same steps the game's bag window does for each button (ContainerFrameMixin:UpdateItems).
function ns.UpdateLiveSlotButton(button, containerID, slot, info, showNew)
    local texture = info and info.iconFileID
    ClearItemButtonOverlay(button)
    button:SetHasItem(texture)
    button:SetItemButtonTexture(texture)
    button:SyncAppearanceWithHasItem()
    SetItemButtonQuality(button, info and info.quality, info and info.hyperlink, false, info and info.isBound)
    SetItemButtonCount(button, info and info.stackCount)
    SetItemButtonDesaturated(button, info and info.isLocked)
    local questInfo = C_Container.GetContainerItemQuestInfo(containerID, slot)
    button:UpdateQuestItem(questInfo and questInfo.isQuestItem, questInfo and questInfo.questID,
        questInfo and questInfo.isActive)
    button:UpdateJunkItem(info and info.quality, info and info.hasNoValue)
    button:UpdateCooldown(texture)
    button:SetReadable(info and info.isReadable)
    button:SetMatchesSearch(not (info and info.isFiltered))
    if showNew and button.UpdateNewItem then
        button:UpdateNewItem(info and info.quality)
    end
end

local reagentHolder
local reagentButtons = {}

local function reagentButtonFor(slot)
    local button = reagentButtons[slot]
    if not button then
        if not reagentHolder then
            reagentHolder = ns.CreateLiveSlotHolder(REAGENT_BAG)
        end
        button = ns.CreateLiveSlotButton(reagentHolder, slot)
        reagentButtons[slot] = button
    end
    return button
end

---------------------------------------------------------------------------
-- The group New
---------------------------------------------------------------------------
-- The game marks items you just got, but removes the mark as soon as you hold the mouse
-- over the item. So Tidy Pack remembers which items were new while the window was
-- open, and forgets them when the window closes.

local newItems = {} -- bagID * 1000 + slot → itemID

function ns.IsNew(bagID, slot, itemID)
    return newItems[bagID * 1000 + slot] == itemID
end

local function rememberNew(bagID, slot, itemID)
    if C_NewItems.IsNewItem(bagID, slot) then
        newItems[bagID * 1000 + slot] = itemID
    end
end

---------------------------------------------------------------------------
-- Reused tables and text lines
---------------------------------------------------------------------------
-- The bags change often, e.g. when you loot. To avoid creating new tables and
-- text lines every time, they are reused.

local entries = {}         -- a table per item, or per kind of empty slots
local entryCount = 0
local groupLists = {}      -- the group's name → the items in the group
local emptyByFamily = {}   -- bag type → empty slots of that type (0 = normal bag), or
                           -- "bag3" → empty slots in the special bag in slot 3
local specialBags = {}     -- bagID → true for special bags (quiver, soul bag, profession bag …)
local divider              -- the line above the special bags
local shownButtons = {}    -- the buttons shown after the last pass
local lockedButtons = setmetatable({}, { __mode = "k" }) -- buttons locked at the merchant
local disabledButtons = setmetatable({}, { __mode = "k" }) -- buttons Tidy Pack disabled
local emptyFree = setmetatable({}, { __mode = "k" })     -- empty slot → free slots, for the tooltip

-- For the controller (Gamepad.lua): the first button of each group, in the order the groups
-- show, and which group each button belongs to.
local groupFirst = {}                                    -- 1, 2, 3 … → the group's first button
local groupOfButton = setmetatable({}, { __mode = "k" }) -- button → index in groupFirst
local newGroupIndex                                      -- the group New, if it shows
local startGroupIndex                                    -- the first group with a real item (not the empty slot)

local function newEntry()
    entryCount = entryCount + 1
    local entry = entries[entryCount]
    if not entry then
        entry = {}
        entries[entryCount] = entry
    end
    entry.placed = false
    entry.scale = nil -- smaller slot in the Quests tab (QuestsView.lua)
    return entry
end

local function addToGroup(group, entry)
    local list = groupLists[group]
    if not list then
        list = {}
        groupLists[group] = list
    end
    list[#list + 1] = entry
end

local headers = { objects = {}, used = 0 }

-- The tooltip on a group's heading: how many items, how many slots they take and what they're worth
-- at a merchant (review 2026-11-12). The headings themselves stay short.
local function showHeaderTooltip(hover)
    local list = hover.group and groupLists[hover.group]
    if not list then
        return
    end
    local slots, items, value = 0, 0, 0
    for _, entry in ipairs(list) do
        if not entry.isEmpty then
            slots = slots + 1
            items = items + (entry.count or 1)
            local sellPrice = entry.link and select(11, C_Item.GetItemInfo(entry.link))
            value = value + (sellPrice or 0) * (entry.count or 1)
        end
    end
    GameTooltip:SetOwner(hover, "ANCHOR_TOPLEFT")
    GameTooltip_SetTitle(GameTooltip, ns.groupNames[hover.group] or hover.text:GetText())
    local countText
    if items == 1 then
        countText = L["1 item in 1 slot"]
    elseif slots == 1 then
        countText = L["%d items in 1 slot"]:format(items)
    else
        countText = L["%d items in %d slots"]:format(items, slots)
    end
    GameTooltip_AddNormalLine(GameTooltip, countText)
    if value > 0 then
        GameTooltip_AddNormalLine(GameTooltip, L["Worth %s at a merchant"]:format(GetMoneyString(value)))
    end
    GameTooltip:Show()
end

local function acquireHeader(group)
    headers.used = headers.used + 1
    local header = headers.objects[headers.used]
    if not header then
        header = overlay:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        headers.objects[headers.used] = header
        -- An invisible frame over the heading takes the mouse. An item dropped there goes into the bags,
        -- as on empty space (Layout.lua, dropAnywhere).
        local hover = CreateFrame("Frame", nil, overlay)
        hover:SetAllPoints(header)
        hover:EnableMouse(true)
        hover.text = header
        hover:SetScript("OnEnter", showHeaderTooltip)
        hover:SetScript("OnLeave", GameTooltip_Hide)
        hover:SetScript("OnReceiveDrag", function()
            if ns.PutCursorItemInBags then
                ns.PutCursorItemInBags()
            end
        end)
        hover:SetScript("OnMouseUp", function(_, mouseButton)
            if mouseButton == "LeftButton" and ns.PutCursorItemInBags then
                ns.PutCursorItemInBags()
            end
        end)
        header.hover = hover
    end
    header.hover.group = group
    header:Show()
    header.hover:Show()
    return header
end

local function releaseHeaders()
    for _, header in ipairs(headers.objects) do
        header:Hide()
        header.hover:Hide()
    end
    headers.used = 0
end

-- The headings' places are set only when the whole height is known.
local headerX, headerY = {}, {}

---------------------------------------------------------------------------
-- Marks on the buttons: item level, BoE, locks and empty-slot counts
---------------------------------------------------------------------------

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

-- Our text lines and images per button. The buttons are the game's own, so Tidy Pack saves nothing in
-- them – only here, in a table that lets go of the button if the game stops using it.
local extras = setmetatable({}, { __mode = "k" })

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

---------------------------------------------------------------------------
-- The layout
---------------------------------------------------------------------------

-- Puts a button or heading in place. x and y count from the top left corner of what
-- Tidy Pack lays out. Everything hangs from the game's money row, just like the game's own
-- grid, so the search box, the money and the game's other parts end up where they usually do.
-- Everything hangs from the money row, but it sits further from the window's right edge than the frame is
-- thick on the left. So the content is shifted to make the space equal on both sides (the owner's
-- wish 2026-11-11: the background was closer to the left edge than the right). Measured in measureShift.
local contentShift = 0

-- If the button has another scale (the Quests tab shows small slots), the distance counts in its own units.
local function anchor(region, x, y, scale)
    scale = scale or 1
    region:ClearAllPoints()
    region:SetPoint("TOPLEFT", bagFrame.MoneyFrame, "TOPRIGHT", (x - gridWidth - PADDING_SIDE + contentShift) / scale,
        (MONEY_GAP + contentHeight - y) / scale)
end

local updateFreeText -- further down; applySize updates the free-slot count
local hideReagentBagFrame -- further down; hides the game's separate reagent window with the mouse
local hoveredBagID -- the bag the mouse points at in the bag row, otherwise nil

local function wantSearchBox()
    if not (ns.db and ns.db.showSearchBox) then
        return false
    end
    local view = ns.GetView and ns.GetView() or "bags"
    return view == "bags" or view == "bank"
end

local function positionSearchBox(searchBox)
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

-- True for Tidy Pack's own buttons from the game's template (the reagent bag and the bank at a banker).
-- The game's own buttons (parent bagFrame) get their search state from the game itself, when the search
-- box changes the game's search (C_Container.SetItemSearch → UpdateSearchResults). Tidy Pack never writes
-- values into the game's buttons: values the addon's code wrote can make the game block clicks on the item.
local function isOwnLiveButton(entry)
    return not entry.offline and entry.button.SetMatchesSearch ~= nil
        and entry.button:GetParent() ~= bagFrame
end

-- Marks matches from the search box with the same blue glow as the bag row and dims the rest.
-- Also works in the Bank tab away from the banker, by matching the item's name.
local function applySearchHighlights()
    if hoveredBagID ~= nil then
        return
    end
    local query = ""
    if wantSearchBox() and BagItemSearchBox and BagItemSearchBox:IsShown() then
        query = (BagItemSearchBox:GetText() or ""):match("^%s*(.-)%s*$"):lower()
    end
    local searching = query ~= ""
    for i = 1, entryCount do
        local entry = entries[i]
        if entry.placed then
            local extra = extras[entry.button]
            if not searching then
                entry.button:SetAlpha(entry.offline and entry.isEmpty and 0.65 or 1)
                if extra then
                    extra.bagGlow:Hide()
                end
                if isOwnLiveButton(entry) then
                    entry.button:SetMatchesSearch(true)
                end
            elseif entry.isEmpty then
                entry.button:SetAlpha(0.35)
                if extra then
                    extra.bagGlow:Hide()
                end
            else
                local matches
                if entry.offline then
                    matches = entry.name ~= nil and entry.name:lower():find(query, 1, true) ~= nil
                else
                    local info = C_Container.GetContainerItemInfo(entry.bagID, entry.slot)
                    matches = not (info and info.isFiltered)
                    if isOwnLiveButton(entry) then
                        entry.button:SetMatchesSearch(matches)
                    end
                end
                entry.button:SetAlpha(matches and 1 or 0.35)
                if extra then
                    extra.bagGlow:SetShown(matches)
                end
            end
        end
    end
end

-- Gives the game's window Tidy Pack's size: the edges, the title bar and the money row the
-- game worked out, plus what Tidy Pack lays out.
local function applySize()
    if not contentHeight or not chromeWidth then
        return
    end
    local height = contentHeight + chromeHeight - searchRoom() + PADDING_TOP + (MONEY_GAP - BLIZZARD_MONEY_GAP)
        + (moneyRaised and MONEY_RAISE or 0)
    bagFrame:SetSize(gridWidth + chromeWidth + 2 * PADDING_SIDE, height)
    -- The background follows what Tidy Pack lays out, and hangs from the money row like everything else.
    if inset then
        inset:ClearAllPoints()
        inset:SetPoint("TOPLEFT", bagFrame.MoneyFrame, "TOPRIGHT", -gridWidth - PADDING_SIDE - INSET_PAD_X + contentShift,
            MONEY_GAP + contentHeight + INSET_PAD)
        inset:SetPoint("BOTTOMRIGHT", bagFrame.MoneyFrame, "TOPRIGHT", -PADDING_SIDE + INSET_PAD_X + contentShift,
            MONEY_GAP - INSET_PAD)
        inset:Show()
    end
    NineSliceUtil.UpdateCornerCropping(bagFrame, height)
    updateFreeText()
    positionSearchBox()
    if hideReagentBagFrame then
        hideReagentBagFrame()
    end
end

-- Runs after the game's UpdateFrameSize. The game has then sized the window after its own
-- grid (GetColumns columns, GetRows rows). What is left when the grid is subtracted is
-- edges, title bar, search box and money.
-- How far right the content is shifted: the gap between the money row's right edge and the window's,
-- minus half the frame's width (the frame counts equally on both sides). True if the value changed.
local function measureShift()
    local right, moneyRight = bagFrame:GetRight(), bagFrame.MoneyFrame:GetRight()
    if not (right and moneyRight and chromeWidth) then
        return false
    end
    local shift = math.floor((right - moneyRight) - chromeWidth / 2 + 0.5)
    if shift ~= contentShift then
        contentShift = shift
        return true
    end
    return false
end

local function onFrameSizeUpdated()
    local columns, rows = bagFrame:GetColumns(), math.max(bagFrame:GetRows(), 1)
    chromeWidth = bagFrame:GetWidth() - (columns * BUTTON + (columns - 1) * SPACING)
    chromeHeight = bagFrame:GetHeight() - (rows * BUTTON + (rows - 1) * SPACING)
    applySize()
    -- The first time the gap is known, everything is laid out again with the right shift.
    if measureShift() and ns.Refresh then
        ns.Refresh()
    end
end

-- The heading for a group. Favorites gets a star and Junk shows what the junk is worth.
local function headerText(group, junkValue)
    -- A group without a heading (see the safety net in flow) is called "Other".
    local text = ns.groupNames[group] or L["Other"]
    if group == "Favorites" then
        return FAVORITE_ICON .. text
    elseif group == "Junk" and junkValue > 0 and ns.db.junkValue ~= false then
        return text .. "  " .. GetMoneyString(junkValue)
    end
    return text
end

-- The heading for a bag: the bag's own icon and name.
local function bagHeaderText(bagID)
    if bagID == 0 then
        local name = C_Container.GetBagName(0) or BACKPACK_TOOLTIP
        return ("|TInterface\\Icons\\INV_Misc_Bag_08:13:13|t %s"):format(name)
    elseif bagID == KEYRING_CONTAINER then
        return L["Keys"]
    end
    local icon = GetInventoryItemTexture("player", C_Container.ContainerIDToInventoryID(bagID))
    local name = C_Container.GetBagName(bagID) or ""
    return icon and ("|T%s:13:13|t %s"):format(icon, name) or name
end

-- True if the bag in the slot is a special bag: it takes only certain kinds of items
-- (bagFamily isn't 0), or it is the reagent bag.
local function isSpecialBag(bagID)
    if C_Container.GetContainerNumSlots(bagID) == 0 then
        return false
    end
    if bagID == Enum.BagIndex.ReagentBag then
        return true
    end
    local _, family = C_Container.GetContainerNumFreeSlots(bagID)
    return family ~= nil and family ~= 0
end

-- The lines between the parts in the Bags tab. flow fills sectionYs, placeSectionLines draws them.
local sectionYs = {}
local sectionLines = {}
local bankFlow = false -- true while flow lays out the bank's items (the Bank tab)
local listedGroups = {}   -- groups flow has gone through (reused)
local unlistedGroups = {} -- groups with items that aren't in ns.groupOrder (reused)
local freeText -- the free-slot count at the bottom left (with the mouse, instead of "Add to bag")

local function hideSectionLines()
    for _, line in ipairs(sectionLines) do
        line:Hide()
    end
end

local function placeSectionLines()
    hideSectionLines()
    for index, lineY in ipairs(sectionYs) do
        local line = sectionLines[index]
        if not line then
            line = overlay:CreateTexture(nil, "ARTWORK")
            line:SetColorTexture(unpack(LINE_COLOR))
            sectionLines[index] = line
        end
        line:SetSize(gridWidth + 8, 1)
        anchor(line, -4, lineY)
        line:Show()
    end
end

-- "10 free" at the bottom left, red when few are left. With a controller the slot "Add to bag" shows
-- the same, so then the text isn't shown.
updateFreeText = function()
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

-- Hides Tidy Pack's own buttons (Bank.lua and the reagent bag) that don't show after this pass.
local function hideExtraButtons()
    if ns.EnumerateBankButtons then
        for _, button in ns.EnumerateBankButtons() do
            if not shownButtons[button] then
                button:Hide()
            end
        end
    end
    for _, button in pairs(reagentButtons) do
        if not shownButtons[button] then
            if lockedButtons[button] or disabledButtons[button] then
                setLocked(button, false)
            end
            button:Hide()
        end
    end
end

-- Lays out the groups line by line with cols columns: a group shares the line with the previous one if
-- it fits, otherwise a new line starts. With apply = false only the height is worked out (to
-- choose the number of columns), with apply = true the places are set too. Returns the height and where
-- the line above the special bags goes (nil if there is none).
local function flow(cols, apply, junkValue)
    local width = widthOf(cols)
    local x, y, shelfHeight = 0, 0, 0
    local dividerY
    if apply then
        wipe(sectionYs)
    end
    local function place(group, text)
        local list = groupLists[group]
        if not (list and #list > 0) then
            return
        end
        -- If the quest items are hidden in the bags (the option), a line stands instead of the buttons. Not
        -- in the bank: there they aren't in the Quests tab.
        local hideQuests = group == "QuestItems" and ns.db.showQuestItemsInBags == false and not bankFlow
        measurer:SetText(text)
        local headerWidth = math.ceil(measurer:GetStringWidth())
        local groupWidth, height
        if hideQuests then
            -- A single slot with the count, in the style of "Add to bag" (the owner's wish 2026-11-10).
            groupWidth = math.max(headerWidth, BUTTON)
            height = HEADER + BUTTON
        else
            local groupCols = math.min(#list, cols)
            local rows = math.ceil(#list / cols)
            -- The group is at least as wide as its heading, so the headings don't collide.
            groupWidth = math.max(widthOf(groupCols), headerWidth)
            height = HEADER + rows * BUTTON + (rows - 1) * SPACING
        end
        local left = (x == 0) and 0 or (x + GROUP_GAP)
        if x > 0 and left + groupWidth > width then
            -- Doesn't fit on the line: start a new one.
            y = y + shelfHeight + SHELF_GAP
            left, shelfHeight = 0, 0
        end
        if apply then
            local header = acquireHeader(group)
            header:SetText(text)
            headerX[headers.used], headerY[headers.used] = left, y
            if hideQuests then
                questNoteState = { x = left, y = y + HEADER, count = #list }
            else
                local groupIndex = #groupFirst + 1
                groupFirst[groupIndex] = list[1].button
                if group == "New" then
                    newGroupIndex = groupIndex
                end
                if not startGroupIndex and (not list[1].isEmpty or group ~= "Empty") then
                    startGroupIndex = groupIndex
                end
                for index, entry in ipairs(list) do
                    entry.x = left + ((index - 1) % cols) * CELL
                    entry.y = y + HEADER + math.floor((index - 1) / cols) * CELL
                    entry.placed = true
                    groupOfButton[entry.button] = groupIndex
                end
            end
        end
        x = left + groupWidth
        shelfHeight = math.max(shelfHeight, height)
    end
    -- With the mouse the slot "Add to bag" isn't needed: the whole bag takes items, and the free-slot
    -- count is at the bottom left. With a controller it stays as the place to drop an item.
    local byBag = ns.db and ns.db.groupByBag == true
    local showEmpty = InputUtil.IsGamepadUIEnabled()
    local lastSection
    local placedAny = false
    wipe(listedGroups)
    local function visit(group)
        listedGroups[group] = true
        local list = groupLists[group]
        if list and #list > 0 and (group ~= "Empty" or showEmpty) then
            -- A new part starts on a new line, with a thin line above.
            local section = ns.GetGroupSection(group)
            if lastSection and section ~= lastSection then
                y = y + shelfHeight + SECTION_GAP
                if apply then
                    sectionYs[#sectionYs + 1] = y
                end
                y = y + 1 + SECTION_GAP
                x, shelfHeight = 0, 0
            end
            lastSection = section
            placedAny = true
            place(group, headerText(group, junkValue))
        end
    end
    for _, group in ipairs(ns.groupOrder) do
        visit(group)
    end
    -- Safety net: a group that has items but isn't in the order (e.g. a new kind of item after a
    -- patch) shows last instead of being hidden. No item may become invisible because it landed in a
    -- group missing from the list. The special bags' and the by-bag mode's groups ("bagN") are laid out
    -- separately further down.
    wipe(unlistedGroups)
    for group, list in pairs(groupLists) do
        if #list > 0 and not listedGroups[group] and not group:match("^bag%-?%d+$") then
            unlistedGroups[#unlistedGroups + 1] = group
        end
    end
    if #unlistedGroups > 0 then
        table.sort(unlistedGroups) -- the same order every time
        for _, group in ipairs(unlistedGroups) do
            visit(group)
        end
    end

    local function placeBagSection(bagKey, title)
        local list = groupLists[bagKey]
        if list and #list > 0 then
            if placedAny then
                y = y + shelfHeight + SECTION_GAP
                if apply then
                    sectionYs[#sectionYs + 1] = y
                end
                y = y + 1 + SECTION_GAP
                x, shelfHeight = 0, 0
            end
            placedAny = true
            place(bagKey, title)
        end
    end

    if byBag then
        -- "By bag" mode: a part on its own line with a thin line for each bag (or bank tab).
        if bankFlow then
            for _, tab in ipairs(ns.GetBankTabs and ns.GetBankTabs() or {}) do
                local title = tab.icon and ("|T%s:13:13|t %s"):format(tab.icon, tab.name or "") or (tab.name or "")
                if tab.free and (tab.slots or 0) > 0 then
                    title = ("%s |cff999999· %s|r"):format(title, L["%d free"]:format(tab.free))
                end
                placeBagSection("bag" .. tab.id, title)
            end
        else
            for bagID = 0, LAST_BAG do
                placeBagSection("bag" .. bagID, bagHeaderText(bagID))
            end
            placeBagSection("bag" .. KEYRING_CONTAINER, bagHeaderText(KEYRING_CONTAINER))
        end
        return y + shelfHeight, dividerY
    end

    -- The special bags at the bottom, under the game's line, in the bag slots' order.
    for bagID = 1, LAST_BAG do
        local list = specialBags[bagID] and groupLists["bag" .. bagID]
        if list and #list > 0 then
            if not dividerY then
                y = y + shelfHeight + DIVIDER_GAP
                dividerY = y
                y = y + divider:GetHeight() + DIVIDER_GAP
                x, shelfHeight = 0, 0
            end
            place("bag" .. bagID, bagHeaderText(bagID))
        end
    end
    return y + shelfHeight, dividerY
end

-- How tall what Tidy Pack lays out may be. The game shrinks the window (to 75 % at most) so it
-- fits on the screen, but Tidy Pack rather keeps to TARGET_SCALE and makes the window
-- wider instead (see chooseColumns). Nil if the window's sizes aren't known yet.
local function maxContentHeight()
    if not chromeHeight then
        return nil
    end
    -- Under the window is the game's own margin (CONTAINER_OFFSET_Y), above it the tabs.
    local room = (GetScreenHeight() - (CONTAINER_OFFSET_Y or 85) - TAB_ROOM) / TARGET_SCALE
    return room - (chromeHeight - searchRoom() + PADDING_TOP + (MONEY_GAP - BLIZZARD_MONEY_GAP) + MONEY_RAISE)
end

-- Columns: as few as possible, but the window mustn't get too tall for the screen nor
-- too wide (at most three quarters of the screen's width).
local function chooseColumns(junkValue)
    local limit = maxContentHeight()
    local maxWidth = GetScreenWidth() * 0.75
    local chosen = MIN_COLUMNS
    for cols = MIN_COLUMNS, MAX_COLUMNS, COLUMN_STEP do
        if cols > MIN_COLUMNS and widthOf(cols) > maxWidth then
            break
        end
        chosen = cols
        if not limit or flow(cols, false, junkValue) <= limit then
            break
        end
    end
    return chosen
end

-- Empties the groups before a new pass.
local function resetGroups()
    entryCount = 0
    for _, list in pairs(groupLists) do
        wipe(list)
    end
    wipe(emptyByFamily)
end

local function groupInBagMode(bagID, info, classID, subClassID)
    if ns.IsFavorite(info.itemID) then
        return "Favorites", 0
    end
    local custom = ns.GetCustomGroupFor and ns.GetCustomGroupFor(info.itemID, classID, subClassID)
    if custom then
        return custom, 0
    end
    return "bag" .. bagID, 0
end

-- Sorts an item into its group. Returns what it is worth as junk (0 if it isn't junk).
-- isQuestItem can be given (saved items in the bank, Bank.lua); otherwise the game is asked. offline = true for
-- an item in the saved bank: the button shows only image and tooltip, and the slot doesn't exist right now.
local function addItem(button, bagID, slot, info, isQuestItem, offline)
    local _, _, _, equipLocation, _, classID, subClassID = C_Item.GetItemInfoInstant(info.itemID)
    local entry = newEntry()
    entry.button, entry.bagID, entry.slot = button, bagID, slot
    entry.isEmpty, entry.offline = false, offline == true
    if isQuestItem == nil then
        isQuestItem = ns.IsQuestItem(bagID, slot, info)
    end
    entry.isQuestItem = isQuestItem == true
    entry.isContainer = classID == Enum.ItemClass.Container
    if ns.db and ns.db.groupByBag then
        entry.group, entry.subOrder = groupInBagMode(bagID, info, classID, subClassID)
    elseif specialBags[bagID] then
        -- Everything in a special bag stays in the bag's own group.
        entry.group, entry.subOrder = "bag" .. bagID, 0
    else
        entry.group, entry.subOrder = ns.GetGroup(bagID, slot, info, classID, subClassID, isQuestItem)
    end
    entry.quality = info.quality or 0
    entry.name = ns.GetItemName(info.hyperlink)
    entry.count = info.stackCount or 1
    entry.itemID, entry.link, entry.isBound = info.itemID, info.hyperlink, info.isBound
    entry.isGear = classID == Enum.ItemClass.Weapon or classID == Enum.ItemClass.Armor
    entry.equipLocation = equipLocation
    entry.locked = isQuestItem or ns.IsInEquipmentSet(info.itemID)
    entry.junkMarked = ns.IsJunkMarked(info.itemID)
    entry.noValue = info.hasNoValue
    entry.neededLater = ns.IsNeededLater ~= nil and ns.IsNeededLater(info.itemID)
    -- What a quest needs of the item (count you have and need), for the number on the button.
    entry.questRecord = isQuestItem and ns.GetQuestRecord(entry.name) or nil
    entry.hideProgress = false
    addToGroup(entry.group, entry)
    if ns.GetGroup(bagID, slot, info, classID, subClassID, isQuestItem) == "Junk" and not info.hasNoValue then
        local sellPrice = select(11, C_Item.GetItemInfo(info.hyperlink))
        return (sellPrice or 0) * entry.count
    end
    return 0
end

local function initEmptyEntry(entry, button, bagID, slot, group, family, offline)
    entry.button, entry.bagID, entry.slot = button, bagID, slot
    entry.isEmpty, entry.offline, entry.group, entry.family, entry.free = true, offline == true, group, family, nil
    -- The table may have been used for an item before, so everything the marks read is reset.
    entry.locked, entry.isGear, entry.junkMarked, entry.neededLater = false, false, false, false
    entry.isQuestItem, entry.isContainer = false, false
    entry.quality, entry.noValue = 0, true
    entry.questRecord, entry.hideProgress = nil, false
end

-- Counts an empty slot. Only one button per bag type shows: the first free slot.
local function addEmpty(button, bagID, slot, key, group, family)
    local empty = emptyByFamily[key]
    if not empty then
        empty = newEntry()
        initEmptyEntry(empty, button, bagID, slot, group, family, false)
        empty.free = 0
        emptyByFamily[key] = empty
        addToGroup(group, empty)
    elseif bagID < empty.bagID or (bagID == empty.bagID and slot < empty.slot) then
        -- The button that shows is the first free slot, where the game puts new items.
        empty.button, empty.bagID, empty.slot = button, bagID, slot
    end
    empty.free = empty.free + 1
end

-- Shows a single empty slot right in the bag's grid ("by bag" mode).
local function addEmptySlot(button, bagID, slot, group, offline)
    local empty = newEntry()
    initEmptyEntry(empty, button, bagID, slot, group, 0, offline)
    addToGroup(group, empty)
end

local function sortBySlot(a, b)
    return a.slot < b.slot
end

local function sortGroups()
    local byBag = ns.db and ns.db.groupByBag == true
    for group, list in pairs(groupLists) do
        if byBag and group:match("^bag%-?%d+$") then
            table.sort(list, sortBySlot)
        else
            table.sort(list, ns.CompareEntries)
        end
    end
end

-- Sorts every item into its group and works out what the junk is worth (the first step of a
-- pass of the Bags or Quests tab).
local function classify()
    local byBag = ns.db and ns.db.groupByBag == true
    -- Which bag slots have a special bag? Their items and empty slots get their own groups
    -- at the bottom, with the bag's name.
    wipe(specialBags)
    if not byBag then
        for bagID = 1, LAST_BAG do
            specialBags[bagID] = isSpecialBag(bagID) or nil
        end
    end

    -- Which stacks of a quest item are needed and which are extra (QuestLock.lua).
    ns.UpdateQuestStacks()

    -- Sort every item into its group. Empty slots are counted per bag type (or one button per slot).
    resetGroups()
    local junkValue = 0
    local function classifySlot(button, bagID, slot, info)
        if info then
            rememberNew(bagID, slot, info.itemID)
            junkValue = junkValue + addItem(button, bagID, slot, info)
        elseif bagID ~= KEYRING_CONTAINER then -- empty keyring slots don't show
            if byBag then
                addEmptySlot(button, bagID, slot, "bag" .. bagID, false)
                return
            end
            -- With the mouse no empty slots show ("+ N"), not for special bags either: the group shows
            -- only when the bag holds something (the owner's wish 2026-11-14). With a controller the
            -- slot is needed to drop items into the bag.
            if specialBags[bagID] and not InputUtil.IsGamepadUIEnabled() then
                return
            end
            local _, family = C_Container.GetContainerNumFreeSlots(bagID)
            family = family or 0
            -- A special bag's empty slots are counted separately, in the bag's own group.
            local key = specialBags[bagID] and ("bag" .. bagID) or family
            local group = specialBags[bagID] and ("bag" .. bagID) or "Empty"
            addEmpty(button, bagID, slot, key, group, family)
        end
    end
    for _, button in bagFrame:EnumerateValidItems() do
        local bagID, slot = button:GetBagID(), button:GetID()
        classifySlot(button, bagID, slot, C_Container.GetContainerItemInfo(bagID, slot))
    end
    -- With the mouse the game doesn't include the reagent bag in ContainerFrameCombinedBags (ENDING_BAG_INDEX = 4).
    -- To avoid changing the game's values and causing taint, Tidy Pack makes its own buttons from the game's template.
    if Constants.InventoryConstants.NumReagentBagSlots > 0 and not InputUtil.IsGamepadUIEnabled() then
        for slot = 1, C_Container.GetContainerNumSlots(REAGENT_BAG) or 0 do
            local button = reagentButtonFor(slot)
            local info = C_Container.GetContainerItemInfo(REAGENT_BAG, slot)
            ns.UpdateLiveSlotButton(button, REAGENT_BAG, slot, info, true)
            classifySlot(button, REAGENT_BAG, slot, info)
        end
    end
    sortGroups()
    return junkValue
end

-- The same for the bank (Bank.lua): at a banker the bank's slots, otherwise what was saved last.
-- The bank has no special bags in Tidy Pack: everything is sorted into the normal groups, and the free
-- slots are counted together.
local function classifyBank()
    local byBag = ns.db and ns.db.groupByBag == true
    wipe(specialBags)
    ns.UpdateQuestStacks()
    resetGroups()
    local junkValue = 0
    if ns.ForEachBankSlot then
        ns.ForEachBankSlot(function(button, bagID, slot, info, offline, isQuestItem)
            if info then
                junkValue = junkValue + addItem(button, bagID, slot, info, isQuestItem, offline)
            elseif byBag then
                addEmptySlot(button, bagID, slot, "bag" .. bagID, offline)
            else
                addEmpty(button, bagID, slot, "bank", "Empty", 0)
            end
        end)
    end
    sortGroups()
    return junkValue
end

-- Moves the game's buttons and the headings to their places (the last step of a pass). Buttons
-- that aren't needed (empty slots except one per bag type) are hidden.
local function commit(atMerchant)
    for i = 1, headers.used do
        anchor(headers.objects[i], headerX[i], headerY[i])
    end
    wipe(shownButtons)
    for i = 1, entryCount do
        local entry = entries[i]
        if entry.placed then
            entry.button:SetScale(entry.scale or 1)
            anchor(entry.button, entry.x, entry.y, entry.scale)
            entry.button:Show()
            updateExtras(entry, atMerchant)
            shownButtons[entry.button] = true
        end
    end
    for _, button in bagFrame:EnumerateValidItems() do
        if not shownButtons[button] then
            button:Hide()
        end
    end
    hideExtraButtons()

    -- The line that replaces the quest items when they are hidden in the bags. A click opens the Quests tab.
    if questNoteState then
        questNote.count:SetText(questNoteState.count)
        questNote.slots = questNoteState.count
        anchor(questNote, questNoteState.x, questNoteState.y)
        questNote:Show()
    else
        questNote:Hide()
    end

    -- With a controller the game puts the bags you wear in the grid. They shouldn't show
    -- among the items, so Tidy Pack hides them.
    if GamepadBagBar and GamepadBagBar:IsShown() then
        GamepadBagBar:Hide()
    end

    applySize()
    applySearchHighlights()
    if ns.UpdateQuestsNotice then
        ns.UpdateQuestsNotice()
    end

    -- The controller's cursor may be on a button that was just hidden (see Gamepad.lua).
    if ns.OnLayoutChanged then
        ns.OnLayoutChanged()
    end
end

-- The Quests tab (QuestsView.lua): the quest items ordered per quest, with the real buttons.
local function layoutQuestsView(atMerchant)
    releaseHeaders()
    hideSectionLines()
    if divider then
        divider:Hide()
    end
    questNoteState = nil
    wipe(groupFirst)
    wipe(groupOfButton)
    newGroupIndex, startGroupIndex = nil, nil
    -- Which buttons belong to which item (by name), and which are quest items without a quest.
    local byName, others = {}, {}
    for i = 1, entryCount do
        local entry = entries[i]
        entry.hideProgress = true
        if not entry.isEmpty then
            -- Also a quest item that lies in New or Favorites in the bags belongs here.
            if entry.questRecord then
                local stacks = byName[entry.name]
                if not stacks then
                    stacks = {}
                    byName[entry.name] = stacks
                end
                stacks[#stacks + 1] = entry
            elseif entry.isQuestItem then
                others[#others + 1] = entry
            end
        end
    end
    -- Everything hangs from the money row and counts from the top, so the height must be known before
    -- anything is placed: the texts and the bars are gathered first.
    local placements = {}
    -- The Quests tab may not get taller than the others.
    local height, _, firsts = ns.BuildQuestsView(byName, others, gridWidth, sharedHeight,
        function(entry, x, y)
            entry.x, entry.y, entry.placed = x, y, true
        end,
        function(region, x, y)
            placements[#placements + 1] = { region, x, y }
        end)
    -- The window is equally tall in all tabs: at least as tall as the Bags tab.
    -- The Quests tab never grows: what doesn't fit is scrolled to (QuestsView.lua).
    contentHeight = sharedHeight or math.max(height, MIN_QUESTS_HEIGHT)
    for _, placement in ipairs(placements) do
        anchor(placement[1], placement[2], placement[3])
    end
    for index, first in ipairs(firsts) do
        groupFirst[index] = first
        groupOfButton[first] = index
    end
    commit(atMerchant)
end

-- The junk list or the own groups (Panels.lua) instead of the items.
local function layoutPanelView(view)
    releaseHeaders()
    hideSectionLines()
    if divider then
        divider:Hide()
    end
    questNoteState = nil
    questNote:Hide()
    for _, button in bagFrame:EnumerateValidItems() do
        if lockedButtons[button] or disabledButtons[button] then
            setLocked(button, false)
        end
        button:Hide()
    end
    wipe(shownButtons)
    hideExtraButtons()
    bankNote:Hide()
    wipe(groupFirst)
    wipe(groupOfButton)
    newGroupIndex, startGroupIndex = nil, nil
    -- As tall as the other tabs; the list scrolls if it is longer.
    contentHeight = math.max(sharedHeight or 0, ns.PANEL_MIN_HEIGHT or 0)
    if ns.LayoutPanel then
        ns.LayoutPanel(view, function(region)
            anchor(region, 0, 0)
        end, gridWidth, contentHeight)
    end
    applySize()
    if ns.OnLayoutChanged then
        ns.OnLayoutChanged()
    end
end

-- The Bank tab (Bank.lua): the bank's items in the same groups and parts as in Bags. At a banker the
-- buttons are real; away, a line at the top says when the bank was saved, and the buttons only show the item.
local function layoutBankView(atMerchant, cols)
    releaseHeaders()
    hideSectionLines()
    if divider then
        divider:Hide()
    end
    wipe(groupFirst)
    wipe(groupOfButton)
    newGroupIndex, startGroupIndex = nil, nil
    questNoteState = nil

    local junkValue = classifyBank()
    bankFlow = true
    local ok, height = pcall(flow, cols, true, junkValue)
    bankFlow = false
    if not ok then
        error(height, 0)
    end

    -- Away from the bank: a line at the top, and the items move down under it.
    local noteText
    if not ns.IsAtBank() then
        local age = ns.SavedBankAge and ns.SavedBankAge()
        noteText = age and L["You're not at a banker – this is what your bank held %s. Visit a banker to move items."]:format(age)
            or L["Visit a banker once, and Tidy Pack shows your bank here."]
    end
    local offset = noteText and BANK_NOTE_HEIGHT or 0
    if offset > 0 then
        for i = 1, headers.used do
            headerY[i] = headerY[i] + offset
        end
        for i = 1, entryCount do
            local entry = entries[i]
            if entry.placed then
                entry.y = entry.y + offset
            end
        end
        for index, lineY in ipairs(sectionYs) do
            sectionYs[index] = lineY + offset
        end
    end

    -- At a banker all tabs are equally tall (see relayout); away, the Bank tab can get taller.
    contentHeight = math.max(height + offset, sharedHeight or 0)
    if noteText then
        bankNote:SetText(noteText)
        bankNote:SetWidth(gridWidth)
        anchor(bankNote, 0, 0)
        bankNote:Show()
    else
        bankNote:Hide()
    end
    placeSectionLines()
    commit(atMerchant)
    if ns.SetBankLayoutOk then
        ns.SetBankLayoutOk(true)
    end
end

-- The window's title: empty on the three tabs (the tab shows where you are), a name only for the
-- panels that have no tab of their own.
local function updateTitle()
    if not bagFrame then
        return
    end
    local titles = {
        junk = L["Junk List"], groups = L["Groups"],
    }
    local view = ns.GetView and ns.GetView() or "bags"
    bagFrame:SetTitle(titles[view] or "")
end

-- The whole pass: sort the items into groups, lay out the groups and give the window the right
-- size. Runs after the game's own layout and every time the content changes.
local function relayout()
    if not bagFrame:IsShown() then
        return -- done when the window opens
    end
    local atMerchant = ns.IsAtMerchant()
    local view = ns.GetView and ns.GetView() or "bags"
    updateTitle()
    syncSearchBox()

    -- 1. Sort every item into its group, and work out the Bags tab's size. All three tabs
    -- get the same width and height: the larger of the Bags tab and the Quests minimum. So the window
    -- changes size only when the bags' content does, never when you switch tabs (the owner's
    -- wish 2026-11-10).
    local junkValue = classify()
    gridCols = chooseColumns(junkValue)
    -- The bank (Bank.lua) counts when the Bank tab shows or you stand at a banker: the tabs are equally
    -- wide, and at a banker equally tall, even when the bank holds more than the bags.
    local atBank = ns.IsAtBank ~= nil and ns.IsAtBank()
    local bankJunk, bankHeight
    if view == "bank" or atBank then
        bankJunk = classifyBank()
        bankFlow = true
        gridCols = math.max(gridCols, chooseColumns(bankJunk))
        bankHeight = flow(gridCols, false, bankJunk)
        bankFlow = false
        junkValue = classify()
    end
    gridWidth = widthOf(gridCols)
    local bagsHeight = flow(gridCols, false, junkValue)
    sharedHeight = math.max(bagsHeight, MIN_QUESTS_HEIGHT,
        atBank and bankHeight or 0)
    if view ~= "bank" then
        bankNote:Hide()
    end
    if view == "junk" or view == "groups" then
        if ns.HideQuestsView then
            ns.HideQuestsView()
        end
        layoutPanelView(view)
        return
    end
    if ns.HidePanel then
        ns.HidePanel()
    end

    if view == "bank" then
        if ns.HideQuestsView then
            ns.HideQuestsView()
        end
        layoutBankView(atMerchant, gridCols)
        return
    end
    if view == "quests" then
        layoutQuestsView(atMerchant)
        return
    end
    if ns.HideQuestsView then
        ns.HideQuestsView()
    end

    -- 2. Choose the number of columns and lay out the groups (see flow).
    releaseHeaders()
    wipe(groupFirst)
    wipe(groupOfButton)
    newGroupIndex, startGroupIndex = nil, nil
    questNoteState = nil
    local dividerY
    -- The height must be known before anything is placed, because everything counts from the top but
    -- hangs from the money row (see anchor). The line used to be placed before the height: right after
    -- login or /reload the height was then unknown (nil) and the pass stopped with an error
    -- when you carried a special bag.
    contentHeight = sharedHeight
    dividerY = select(2, flow(gridCols, true, junkValue))
    placeSectionLines()
    if dividerY then
        anchor(divider, -4, dividerY)
        divider:SetWidth(gridWidth + 8)
        divider:Show()
    else
        divider:Hide()
    end

    -- 3. Move the headings and the game's buttons there.
    commit(atMerchant)
end

-- If an error stops the pass, the game shows its own grid. The error is then written once in
-- the chat, so testers without the game's error windows (scriptErrors) can pass it on.
-- The error is also sent to the game's normal error handling.
local errorReported = false

local function safeRelayout()
    local ok, problem = pcall(relayout)
    if not ok then
        if ns.SetBankLayoutOk then
            ns.SetBankLayoutOk(false)
        end
        if not errorReported then
            errorReported = true
            ns.Print(L["Couldn't sort your bags because of an error. Please send this line to the author: %s"]
                :format(tostring(problem)))
        end
        geterrorhandler()(problem)
    end
end

-- The first real item in the bags (not "Add to bag"), for the guide in Tour.lua. Nil if the bags are empty.
function ns.GetFirstItemButton()
    local first = startGroupIndex and groupFirst[startGroupIndex]
    if first and first:IsVisible() then
        return first
    end
    return nil
end

-- Other files (e.g. Marks.lua and QuestLock.lua) ask for a new pass here.
function ns.Refresh()
    if bagFrame and bagFrame:IsShown() then
        safeRelayout()
    end
end

-- True if the button is locked right now, at a merchant. QuestLock.lua gives it a red line in
-- the tooltip.
function ns.IsLockedButton(button)
    return button ~= nil and lockedButtons[button] == true and ns.IsAtMerchant()
end

-- The button the controller's cursor starts on: the first item in New, otherwise the first item in the first
-- group that has a real item (not the empty slot "Add to bag", which comes second).
function ns.GetStartButton()
    return groupFirst[newGroupIndex or startGroupIndex or 1]
end

-- The first button in the group before (step = -1) or after (step = 1) the button's own group. After
-- the last group the first comes again.
function ns.GetGroupJumpTarget(button, step)
    local count = #groupFirst
    local index = groupOfButton[button]
    if count == 0 or not index then
        return ns.GetStartButton()
    end
    return groupFirst[(index - 1 + step) % count + 1]
end

-- The visible button nearest a point in the bag window.
function ns.GetNearestShownButton(x, y)
    local nearest, nearestDistance
    for button in pairs(shownButtons) do
        local buttonX, buttonY = button:GetCenter()
        if buttonX then
            local distance = (buttonX - x) ^ 2 + (buttonY - y) ^ 2
            if not nearestDistance or distance < nearestDistance then
                nearest, nearestDistance = button, distance
            end
        end
    end
    return nearest
end

---------------------------------------------------------------------------
-- Warning when the bags get full
---------------------------------------------------------------------------

-- Shown once in the middle of the screen, like the game's own error messages, when the last free
-- slot fills.
local lastFree

ns.RegisterEvent("PLAYER_ENTERING_WORLD", function()
    lastFree = C_Container.CalculateTotalNumberOfFreeBagSlots()
end)

ns.RegisterEvent("BAG_UPDATE_DELAYED", function()
    local free = C_Container.CalculateTotalNumberOfFreeBagSlots()
    if free == 0 and lastFree and lastFree > 0 then
        UIErrorsFrame:AddMessage(L["Your bags are full."], 1.0, 0.1, 0.1, 1.0)
    end
    lastFree = free
    -- The game's combined bag window doesn't listen to the reagent bag with the mouse, so we update
    -- the layout when it or something in it may have changed.
    if bagFrame and bagFrame:IsShown() and Constants.InventoryConstants.NumReagentBagSlots > 0
        and not InputUtil.IsGamepadUIEnabled() and (C_Container.GetContainerNumSlots(REAGENT_BAG) or 0) > 0 then
        safeRelayout()
    end
end)

ns.RegisterEvent("INVENTORY_SEARCH_UPDATE", function()
    if bagFrame and bagFrame:IsShown() and wantSearchBox() then
        applySearchHighlights()
    end
end)

ns.RegisterEvent("ITEM_LOCK_CHANGED", function(bagID)
    if bagID == REAGENT_BAG and bagFrame and bagFrame:IsShown()
        and Constants.InventoryConstants.NumReagentBagSlots > 0 and not InputUtil.IsGamepadUIEnabled() then
        safeRelayout()
    end
end)

ns.RegisterEvent("BAG_CONTAINER_UPDATE", function()
    if bagFrame and bagFrame:IsShown() and Constants.InventoryConstants.NumReagentBagSlots > 0
        and not InputUtil.IsGamepadUIEnabled() then
        if ns.UpdateBagBar then
            ns.UpdateBagBar()
        end
        safeRelayout()
    end
end)

---------------------------------------------------------------------------
-- Start
---------------------------------------------------------------------------

ns.OnLoad(function()
    bagFrame = ContainerFrameCombinedBags
    if not (bagFrame and bagFrame.UpdateItemLayout and bagFrame.UpdateItems and bagFrame.UpdateFrameSize) then
        ns.Print(L["Couldn't find the game's bag window, so the bags look as usual."])
        return
    end
    ns.bagFrame = bagFrame

    overlay = CreateFrame("Frame", nil, bagFrame)
    overlay:SetAllPoints()

    -- The outer window's background (ContainerFrameCombinedBags.Bg) uses the game's half-transparent
    -- PANEL_BACKGROUND_COLOR. Make it fully opaque (alpha 1) with the same color.
    if bagFrame.SetBackgroundColor and PANEL_BACKGROUND_COLOR and CreateColor then
        local r, g, b = PANEL_BACKGROUND_COLOR:GetRGB()
        bagFrame:SetBackgroundColor(CreateColor(r, g, b, 1))
    end

    -- A whole, dark background behind the items (the owner's wish 2026-11-09). The game's window
    -- is half-transparent, and when Tidy Pack hides the empty slots the world and the
    -- quest list shine through. The template is the game's inset surface (InsetFrameTemplate, as in the
    -- merchant's window), with its marble darker.
    inset = CreateFrame("Frame", nil, bagFrame, "InsetFrameTemplate")
    if inset.Bg then
        inset.Bg:SetVertexColor(0.7, 0.7, 0.7)
    end
    inset:Hide()

    -- InsetFrameTemplate has useParentLevel="true", so the background lands on the window's own level
    -- where the game's window (enableMouse="true") takes clicks and drag and drop. An own invisible
    -- drop area above the background but under the headings and buttons catches the mouse instead.
    local dropArea = CreateFrame("Frame", nil, inset)
    dropArea:SetAllPoints()
    dropArea:SetFrameLevel(bagFrame:GetFrameLevel() + 1)
    overlay:SetFrameLevel(bagFrame:GetFrameLevel() + 2)

    -- Drop anywhere (the owner's wish 2026-11-11): the background lies under the buttons, so it
    -- only takes an item dropped on empty space. The item goes into the first free slot of a normal
    -- bag, like the game's "Add to bag" slot. Dropped on another item, the game swaps them.
    local function dropAnywhere()
        local kind = GetCursorInfo()
        if kind ~= "item" then
            return
        end
        -- In the Bank tab the item goes into the bank (only at a banker, Bank.lua).
        if ns.GetView and ns.GetView() == "bank" then
            if ns.PutCursorItemInBank then
                ns.PutCursorItemInBank()
            end
            return
        end
        for bagID = 0, Constants.InventoryConstants.NumBagSlots do
            local free, family = C_Container.GetContainerNumFreeSlots(bagID)
            if free and free > 0 and (family == nil or family == 0) then
                for slot = 1, C_Container.GetContainerNumSlots(bagID) do
                    if not C_Container.GetContainerItemInfo(bagID, slot) then
                        C_Container.PickupContainerItem(bagID, slot)
                        return
                    end
                end
            end
        end
        UIErrorsFrame:AddMessage(ERR_INV_FULL, 1.0, 0.1, 0.1, 1.0)
    end
    ns.PutCursorItemInBags = dropAnywhere -- also the logo button (LogoButton.lua)
    dropArea:EnableMouse(true)
    -- A short transition when the content changes (tab, panel or icon choice): a dark veil over the
    -- background that fades out in a tenth of a second, instead of everything jumping into place (review
    -- 2026-11-12). It doesn't take the mouse, so nothing gets harder to click.
    local curtain = CreateFrame("Frame", nil, bagFrame)
    curtain:SetFrameStrata("HIGH")
    curtain:SetAllPoints(inset)
    curtain.shade = curtain:CreateTexture(nil, "OVERLAY")
    curtain.shade:SetAllPoints()
    curtain.shade:SetColorTexture(0, 0, 0, 1)
    curtain:SetAlpha(0)
    curtain:Hide()
    local fade = curtain:CreateAnimationGroup()
    local alpha = fade:CreateAnimation("Alpha")
    alpha:SetFromAlpha(0.6)
    alpha:SetToAlpha(0)
    alpha:SetDuration(0.12)
    alpha:SetSmoothing("OUT")
    fade:SetScript("OnFinished", function()
        curtain:SetAlpha(0)
        curtain:Hide()
    end)
    function ns.PlayViewTransition()
        if not bagFrame:IsShown() then
            return
        end
        fade:Stop()
        curtain:Show()
        fade:Play()
    end

    -- The mouse wheel scrolls the list in the Quests tab.
    dropArea:EnableMouseWheel(true)
    dropArea:SetScript("OnMouseWheel", function(_, delta)
        if ns.GetView and ns.GetView() == "quests" and ns.ScrollQuests then
            ns.ScrollQuests(delta)
        end
    end)
    dropArea:SetScript("OnReceiveDrag", dropAnywhere)
    dropArea:SetScript("OnMouseUp", function(_, mouseButton)
        if mouseButton == "LeftButton" then
            dropAnywhere()
        end
    end)

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
    -- The items in the bag get a blue glow, and the rest dims (bagID nil: everything as usual).
    -- inBank: the bag is one of the bank's (the bank row below), which dims in the Bank tab instead.
    local function dimOthers(bagID, inBank)
        local bankView = ns.GetView and ns.GetView() == "bank"
        if bagID ~= nil and bankView ~= (inBank == true) then
            return
        end
        hoveredBagID = bagID
        if bagID == nil then
            applySearchHighlights()
            return
        end
        for i = 1, entryCount do
            local entry = entries[i]
            if entry.placed and (not entry.isEmpty or entry.free == nil) then
                local inBag = entry.bagID == bagID
                entry.button:SetAlpha(inBag and 1 or 0.35)
                local extra = extras[entry.button]
                if extra then
                    extra.bagGlow:SetShown(inBag and not entry.isEmpty)
                end
            end
        end
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

    -- Invisible text that measures how wide the headings are, to work out the height without
    -- laying anything out (see flow).
    measurer = overlay:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    measurer:SetAlpha(0)

    -- The line that replaces the quest items when they are hidden in the bags (the option). A click
    -- opens the Quests tab.
    -- A button with the game's empty slot, a yellow border and the count, that opens the Quests tab.
    questNote = CreateFrame("Button", nil, overlay)
    questNote:SetSize(BUTTON, BUTTON)
    questNote.bg = questNote:CreateTexture(nil, "BACKGROUND")
    questNote.bg:SetAllPoints()
    questNote.bg:SetTexture("Interface\\Buttons\\UI-EmptySlot")
    questNote.bg:SetTexCoord(0.140625, 0.84375, 0.140625, 0.84375)
    questNote.border = questNote:CreateTexture(nil, "OVERLAY")
    -- The same yellow border the game gives quest items in the bags (TEXTURE_ITEM_QUEST_BORDER, ContainerFrame.lua).
    questNote.border:SetTexture(TEXTURE_ITEM_QUEST_BORDER)
    questNote.border:SetAllPoints()
    questNote.count = questNote:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    questNote.count:SetPoint("CENTER", 0, 1)
    questNote:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    questNote:SetScript("OnClick", function()
        ns.SetView("quests")
    end)
    questNote:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip_SetTitle(GameTooltip, ns.groupNames.QuestItems)
        GameTooltip_AddNormalLine(GameTooltip, (self.slots == 1 and L["1 slot holds quest items."]
            or L["%d slots hold quest items."]:format(self.slots or 0)))
        GameTooltip_AddInstructionLine(GameTooltip, L["Click to see them in the Quests tab."])
        GameTooltip:Show()
    end)
    questNote:SetScript("OnLeave", GameTooltip_Hide)
    questNote:Hide()

    -- The line at the top of the Bank tab when you aren't at a banker (layoutBankView).
    bankNote = overlay:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bankNote:SetJustifyH("LEFT")
    bankNote:SetJustifyV("TOP")
    bankNote:SetWordWrap(true)
    bankNote:SetTextColor(1, 0.85, 0.63)
    bankNote:Hide()

    -- The search box is off by default but can be turned on under the gear → Show → Search box,
    -- and then shows only in the Bags and Bank tabs (in the title bar).
    -- The bag icon is swapped for the game's frame without an icon (the same frames as the game's other windows).
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
    if bagFrame.PortraitContainer then
        bagFrame.PortraitContainer:Hide()
    end
    -- The free-slot count at the icon is already in the slot "Add to bag".
    if bagFrame.CountContainer then
        bagFrame.CountContainer:Hide()
        hooksecurefunc(bagFrame.CountContainer, "Show", bagFrame.CountContainer.Hide)
    end
    if bagFrame.PortraitButton then
        bagFrame.PortraitButton:Hide()
        hooksecurefunc(bagFrame.PortraitButton, "Show", bagFrame.PortraitButton.Hide)
    end
    -- The game's frame without an icon (ButtonFrameTemplateNoPortrait) puts the left edge 5 units further in
    -- than the frame with an icon the bag window is built for (the corners at x -8 instead of -13,
    -- NineSliceLayouts.lua). The edge then covered the money row and the background on the left
    -- (screenshot 2026-11-11). So the same frame without an icon, but with the left edge where it was.
    if bagFrame.NineSlice and NineSliceUtil and NineSliceUtil.GetLayout and NineSliceUtil.ApplyLayout then
        local base = NineSliceUtil.GetLayout("ButtonFrameTemplateNoPortrait")
        if base then
            local layout = CopyTable(base)
            layout.TopLeftCorner.x = -13
            layout.BottomLeftCorner.x = -13
            NineSliceUtil.ApplyLayout(bagFrame.NineSlice, layout)
        end
    end

    -- While Alt is held, the mark "..." shows on every item (and disappears when Alt is released).
    ns.RegisterEvent("MODIFIER_STATE_CHANGED", function(key)
        if (key == "LALT" or key == "RALT") and bagFrame:IsShown() then
            local show = IsAltKeyDown()
            for i = 1, entryCount do
                local entry = entries[i]
                local extra = extras[entry.button]
                if extra then
                    local visible = show and entry.button:IsShown() and not entry.isEmpty
                        and not lockedButtons[entry.button]
                    extra.alt:SetShown(visible == true)
                    extra.altBg:SetShown(visible == true)
                end
            end
        end
    end)

    -- The line above the special bags, as wide as the buttons and a little more (the width is set at
    -- every layout, since the number of columns can change).
    divider = overlay:CreateTexture(nil, "ARTWORK")
    divider:SetColorTexture(unpack(LINE_COLOR))
    divider:SetSize(gridWidth + 8, 1)
    divider:Hide()

    hooksecurefunc(bagFrame, "UpdateFrameSize", onFrameSizeUpdated)
    hooksecurefunc(bagFrame, "UpdateItemLayout", safeRelayout)
    hooksecurefunc(bagFrame, "UpdateItems", safeRelayout)

    -- The reagent bag (bag slot 5) has its own window in the game with the mouse (ContainerFrame6). Tidy Pack
    -- draws its items as its own group at the bottom of the bags instead, so the game's extra window
    -- is put away without being hidden or closed (Hide or CloseBag breaks B / taints the clicks): it
    -- is moved off screen, made invisible and shrunk to 0.01. With a controller the game itself
    -- includes the reagent bag in the combined window, so there Tidy Pack touches nothing.
    local reagentFrameSuppressed = false
    hideReagentBagFrame = function()
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
    if UpdateContainerFrameAnchors then
        hooksecurefunc("UpdateContainerFrameAnchors", hideReagentBagFrame)
    end

    -- When the window closes, the group New is forgotten and any search text is cleared.
    bagFrame:HookScript("OnHide", function()
        wipe(newItems)
        if BagItemSearchBox and BagItemSearchBox:GetText() ~= "" then
            BagItemSearchBox:SetText("")
        end
    end)

    -- The window's title (updateTitle above): empty on the tabs, a name only for the panels.
    -- The game sets its title in UpdateName, so Tidy Pack changes it right after. Names come from
    -- the translations (Locales.lua), so they follow the language.
    hooksecurefunc(bagFrame, "UpdateName", updateTitle)
    updateTitle()

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

---------------------------------------------------------------------------
-- The tabs (Bags, Bank, Quests)
---------------------------------------------------------------------------

local TAB_WIDTH = 90
local TAB_LEFT = 14
local TAB_OVERLAP = 2
local TAB_GAP = 2

local view = "bags"
local tabSystem

local TAB_OF = { bags = 1, bank = 2, quests = 3 }
local VIEW_OF = { "bags", "bank", "quests" }
local PANEL_VIEWS = { junk = true, groups = true }

-- The tab's button (1 Bags, 2 Bank, 3 Quests), for the guide in Tour.lua.
function ns.GetTabButton(tabID)
    return tabSystem and tabSystem:GetTabButton(tabID)
end

-- Which view shows: "bags", "bank", "quests", "junk" or "groups".
function ns.GetView()
    return view
end

-- The dot on the Quests tab lights up when at least one quest with items is ready to turn in.
function ns.UpdateQuestsNotice()
    if tabSystem then
        tabSystem:SetTabNotification(TAB_OF.quests, ns.HasReadyQuest ~= nil and ns.HasReadyQuest())
    end
end

-- Switches between "bags", "bank" and "quests", or the panel views "junk" and "groups".
-- instant: no fade between the tabs (the Bank tab when the bank opens, Bank.lua).
function ns.SetView(newView, instant)
    local oldView = view
    view = (TAB_OF[newView] or PANEL_VIEWS[newView]) and newView or "bags"
    if view ~= oldView then
        if PANEL_VIEWS[view] and not PANEL_VIEWS[oldView] then
            PlaySound(SOUNDKIT.IG_CHARACTER_INFO_OPEN)
        elseif PANEL_VIEWS[oldView] and not PANEL_VIEWS[view] then
            PlaySound(SOUNDKIT.IG_CHARACTER_INFO_CLOSE)
        end
        if ns.PlayViewTransition and not instant then
            ns.PlayViewTransition()
        end
    end
    if tabSystem then
        tabSystem:SetTabVisuallySelected(TAB_OF[view] or 0)
    end
    if ns.Refresh then
        ns.Refresh()
    end
end

ns.OnLoad(function()
    if not bagFrame then
        return
    end
    tabSystem = CreateFrame("Frame", nil, bagFrame, "TabSystemTemplate")
    tabSystem.tabTemplate = "TabSystemTopButtonTemplate"
    tabSystem.tabPool = CreateFramePool("BUTTON", tabSystem, tabSystem.tabTemplate)
    tabSystem.minTabWidth, tabSystem.maxTabWidth = TAB_WIDTH, TAB_WIDTH
    tabSystem.spacing = TAB_GAP
    tabSystem.tabSelectSound = SOUNDKIT.IG_CHARACTER_INFO_TAB
    tabSystem:SetPoint("BOTTOMLEFT", bagFrame, "TOPLEFT", TAB_LEFT, -TAB_OVERLAP)
    tabSystem:SetTabSelectedCallback(function(tabID)
        ns.SetView(VIEW_OF[tabID] or "bags")
        return true
    end)
    for _, label in ipairs({ L["Bags"], L["Bank"], L["Quests"] }) do
        local tabID = tabSystem:AddTab(label)
        local tab = tabSystem:GetTabButton(tabID)
        tab.selectedFontObject, tab.unselectedFontObject = GameFontHighlight, GameFontNormal
        tab:SetDisabledFontObject(GameFontHighlight)
        tab:UpdateTabWidth()
    end
    tabSystem:SetTabVisuallySelected(1)

    for tabID, tabView in ipairs(VIEW_OF) do
        tabSystem:GetTabButton(tabID):HookScript("OnEnter", function()
            local kind = GetCursorInfo()
            if view ~= tabView and kind == "item" then
                ns.SetView(tabView)
            end
        end)
    end

    bagFrame:HookScript("OnHide", function()
        if view ~= "bags" then
            ns.SetView("bags")
        end
    end)
end)
