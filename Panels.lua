-- TidyPack – Panels.lua
-- The junk list and the own groups in the bag window itself (the owner's wish 2026-11-12, sketch
-- .design/sketch-settings-in-bag.html, 3a and 3b), instead of own pages in the game's options.
-- The gear menu opens them (Marks.lua): the window then shows the panel instead of the items.
-- Done, or a tab, goes back.
-- Layout.lua puts the panel in place (ns.LayoutPanel) when the view is "junk" or "groups".
-- Long lists scroll with the mouse wheel (the game's ScrollFrameTemplate), so the window keeps its size.
-- ⚠️ Not tried in the game. With a controller the panel's buttons aren't hooked into the cursor yet.

local _, ns = ...
local L = ns.L

local HEAD = 40          -- the top line: icon, title, count and Done
local CELL = 42          -- a slot (37) and the gap to the next (5), as in the bags
local SMALL = 26         -- small slots for the items in a group
local SMALL_CELL = SMALL + 4
local ROW = 34           -- a group's line
local JUNK_FOOT = 112    -- the input box, the explanation and the two checkboxes under the junk list
local SCROLLBAR = 18     -- room for the scroll bar on the right
ns.PANEL_MIN_HEIGHT = HEAD + 2 * CELL + JUNK_FOOT

local panel, head, scroll, child, junkFoot
local which              -- "junk", "groups" or nil
local openGroup          -- the index of the opened group, or nil
local junkInput, junkHint, groupInput, groupHint
local junkChecks = {}

---------------------------------------------------------------------------
-- Shared parts
---------------------------------------------------------------------------

-- The item's id from a link, a number or a name (a name only if the game knows the
-- item). Nil if it isn't a real item.
local function itemIDFromText(text)
    text = strtrim(text or "")
    if text == "" then
        return nil
    end
    local id = tonumber(text:match("item:(%d+)") or text:match("^#?(%d+)$"))
    if not id then
        id = C_Item.GetItemInfoInstant(text)
    end
    if id and C_Item.GetItemInfoInstant(id) then
        return id
    end
    return nil
end

local function cursorItemID()
    local kind, itemID = GetCursorInfo()
    if kind == "item" then
        return itemID
    end
    return nil
end

local function sortByName(ids)
    table.sort(ids, function(a, b)
        local nameA, nameB = C_Item.GetItemNameByID(a) or "", C_Item.GetItemNameByID(b) or ""
        if nameA ~= nameB then
            return nameA < nameB
        end
        return a < b
    end)
    return ids
end

-- The red cross the game's own dialogs are closed with.
local function createRemoveButton(parent, size)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(size, size)
    button:SetNormalAtlas("RedButton-Exit")
    button:SetPushedAtlas("RedButton-exit-pressed")
    button:SetHighlightAtlas("RedButton-Exit", "ADD")
    return button
end

local function setHint(fontString, text, color)
    fontString:SetText(text)
    fontString:SetTextColor(color:GetRGB())
end

local refresh -- further down

-- A slot with an item (image, quality border and tooltip) and a red cross while hovered.
-- onRemove(itemID) runs when the cross is clicked; onDrop() when an item is dropped on the slot.
local function createItemCell(size, onRemove, onDrop)
    local cell = CreateFrame("ItemButton", nil, child)
    cell:SetSize(37, 37)
    cell:SetScale(size / 37)
    cell.remove = createRemoveButton(cell, 18)
    cell.remove:SetPoint("TOPRIGHT", 5, 5)
    cell.remove:Hide()
    local function hideRemoveLater()
        C_Timer.After(0, function()
            if not (cell:IsMouseOver() or cell.remove:IsMouseOver()) then
                cell.remove:Hide()
            end
        end)
    end
    cell:SetScript("OnEnter", function(self)
        self.remove:Show()
        if self.itemID then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetItemByID(self.itemID)
            GameTooltip:Show()
        end
    end)
    cell:SetScript("OnLeave", function()
        GameTooltip_Hide()
        hideRemoveLater()
    end)
    cell.remove:SetScript("OnLeave", hideRemoveLater)
    cell.remove:SetScript("OnClick", function()
        if cell.itemID then
            onRemove(cell.itemID)
        end
    end)
    cell:SetScript("OnReceiveDrag", onDrop)
    cell:SetScript("OnClick", function(self)
        if cursorItemID() then
            onDrop()
        elseif self.itemID and IsModifiedClick("CHATLINK") then
            local _, link = C_Item.GetItemInfo(self.itemID)
            if link then
                HandleModifiedItemClick(link)
            end
        end
    end)
    return cell
end

local function setItemCell(cell, itemID)
    cell.itemID = itemID
    SetItemButtonTexture(cell, C_Item.GetItemIconByID(itemID))
    SetItemButtonQuality(cell, C_Item.GetItemQualityByID(itemID), itemID)
    -- The game may not have the item's data yet: redraw when it has arrived.
    if not C_Item.GetItemNameByID(itemID) then
        Item:CreateFromItemID(itemID):ContinueOnItemLoad(function()
            refresh()
        end)
    end
end

-- An empty slot with "+": click with an item, or drop it here.
local function createPlusCell(size, tooltipText, onDrop)
    local cell = CreateFrame("Button", nil, child)
    cell:SetSize(size, size)
    cell.bg = cell:CreateTexture(nil, "BACKGROUND")
    cell.bg:SetAllPoints()
    cell.bg:SetTexture("Interface\\Buttons\\UI-EmptySlot")
    cell.bg:SetTexCoord(0.140625, 0.84375, 0.140625, 0.84375)
    cell.plus = cell:CreateFontString(nil, "OVERLAY", size > 30 and "GameFontNormalLarge" or "GameFontNormal")
    cell.plus:SetPoint("CENTER", 0, 1)
    cell.plus:SetText("+")
    cell:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    cell:SetScript("OnClick", onDrop)
    cell:SetScript("OnReceiveDrag", onDrop)
    cell:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip_SetTitle(GameTooltip, tooltipText)
        GameTooltip:Show()
    end)
    cell:SetScript("OnLeave", GameTooltip_Hide)
    return cell
end

-- An input box with the button Add and a line below. onAdd(itemID) runs for an item that is found.
local function createInput(parent, width, onAdd)
    local input = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    input:SetSize(width, 22)
    input:SetAutoFocus(false)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(70, 22)
    button:SetText(L["Add"])
    ns.FitButtonText(button, 70)
    -- A longer button (translations) takes its room from the input box, so the line keeps its width.
    input:SetWidth(width - (button:GetWidth() - 70))
    button:SetPoint("LEFT", input, "RIGHT", 8, 0)
    local hint = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    hint:SetPoint("TOPLEFT", input, "BOTTOMLEFT", -4, -4)
    hint:SetPoint("RIGHT", button, "RIGHT")
    hint:SetJustifyH("LEFT")
    local function add()
        local itemID = itemIDFromText(input:GetText())
        if itemID then
            input:SetText("")
            setHint(hint, L["Name, link or item number. Shift-click a link while typing."], GRAY_FONT_COLOR)
            onAdd(itemID)
        else
            setHint(hint, L["Couldn't find that item. Try Shift-clicking its link instead."], RED_FONT_COLOR)
        end
    end
    input:SetScript("OnEnterPressed", add)
    input:SetScript("OnEscapePressed", input.ClearFocus)
    button:SetScript("OnClick", add)
    setHint(hint, L["Name, link or item number. Shift-click a link while typing."], GRAY_FONT_COLOR)
    input.button, input.hint, input.add = button, hint, add
    return input, hint
end

---------------------------------------------------------------------------
-- The junk list
---------------------------------------------------------------------------

local junkCells = {}
local junkPlus
local junkEmpty

local function addJunkFromCursor()
    local itemID = cursorItemID()
    if itemID then
        ClearCursor() -- the item goes back to its place
        ns.SetJunk(itemID, true)
    end
end

local function buildJunk(width)
    local list = {}
    for itemID in pairs(ns.db.junk) do
        list[#list + 1] = itemID
    end
    sortByName(list)
    local cols = math.max(1, math.floor((width + 5) / CELL))
    for index, itemID in ipairs(list) do
        local cell = junkCells[index]
        if not cell then
            cell = createItemCell(37, function(id)
                ns.SetJunk(id, false)
            end, addJunkFromCursor)
            junkCells[index] = cell
        end
        setItemCell(cell, itemID)
        cell:ClearAllPoints()
        cell:SetPoint("TOPLEFT", ((index - 1) % cols) * CELL, -math.floor((index - 1) / cols) * CELL)
        cell:Show()
    end
    for index = #list + 1, #junkCells do
        junkCells[index]:Hide()
    end
    local plusIndex = #list
    junkPlus:ClearAllPoints()
    junkPlus:SetPoint("TOPLEFT", (plusIndex % cols) * CELL, -math.floor(plusIndex / cols) * CELL)
    junkPlus:Show()
    junkEmpty:ClearAllPoints()
    junkEmpty:SetPoint("LEFT", junkPlus, "RIGHT", 10, 0)
    junkEmpty:SetShown(#list == 0)
    child:SetHeight((math.floor(plusIndex / cols) + 1) * CELL)

    head.icon:SetAtlas("bags-junkcoin")
    head.title:SetText(L["Junk List"])
    head.count:SetText(#list == 1 and L["1 item"] or L["%d items"]:format(#list))
    for _, check in ipairs(junkChecks) do
        check:SetChecked(ns.db[check.key] ~= false)
    end
end

---------------------------------------------------------------------------
-- The groups
---------------------------------------------------------------------------

local groupRows = {}
local chips = {}
local groupCells = {}
local groupPlus, newRow, groupInputHolder

-- Short summary of a group: "1 rule · 2 items". The second value is true when the group is empty.
local function summary(group)
    local rules, items = 0, 0
    for _ in pairs(group.types) do
        rules = rules + 1
    end
    for _ in pairs(group.items) do
        items = items + 1
    end
    local parts = {}
    if rules > 0 then
        parts[#parts + 1] = rules == 1 and L["1 rule"] or L["%d rules"]:format(rules)
    end
    if items > 0 then
        parts[#parts + 1] = items == 1 and L["1 item"] or L["%d items"]:format(items)
    end
    if #parts == 0 then
        return L["Empty"], true
    end
    return table.concat(parts, " · "), false
end

local function addToGroupFromCursor(index)
    local itemID = cursorItemID()
    if itemID and ns.GetCustomGroups()[index] then
        ClearCursor()
        ns.SetItemInGroup(index, itemID, true)
        openGroup = index
        refresh()
    end
end

local function createGroupRow()
    local row = CreateFrame("Button", nil, child)
    row:SetHeight(ROW)
    row:SetHighlightAtlas("Options_List_Hover", "ADD")
    row.openBg = row:CreateTexture(nil, "BACKGROUND")
    row.openBg:SetAllPoints()
    row.openBg:SetColorTexture(1, 0.82, 0, 0.08)
    row.line = row:CreateTexture(nil, "ARTWORK")
    row.line:SetColorTexture(1, 1, 1, 0.06)
    row.line:SetHeight(1)
    row.line:SetPoint("BOTTOMLEFT")
    row.line:SetPoint("BOTTOMRIGHT")
    row:SetScript("OnClick", function(self)
        if cursorItemID() then
            addToGroupFromCursor(self.index)
            return
        end
        openGroup = (openGroup ~= self.index) and self.index or nil
        refresh()
    end)
    row:SetScript("OnReceiveDrag", function(self)
        addToGroupFromCursor(self.index)
    end)
    -- Up and down, on top of each other (the same buttons as the game's scroll bars).
    row.up = CreateFrame("Button", nil, row, "UIPanelScrollUpButtonTemplate")
    row.up:SetPoint("TOPLEFT", 4, -1)
    row.up:SetScript("OnClick", function(self)
        local index = self:GetParent().index
        local moved = ns.MoveGroup(index, -1)
        if openGroup == index then
            openGroup = moved
        end
        refresh()
    end)
    row.down = CreateFrame("Button", nil, row, "UIPanelScrollDownButtonTemplate")
    row.down:SetPoint("BOTTOMLEFT", 4, 1)
    row.down:SetScript("OnClick", function(self)
        local index = self:GetParent().index
        local moved = ns.MoveGroup(index, 1)
        if openGroup == index then
            openGroup = moved
        end
        refresh()
    end)
    row.name = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    row.name:SetPoint("LEFT", 30, 0)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    row.meta = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    row.meta:SetPoint("LEFT", row.name, "RIGHT", 8, 0)
    row.meta:SetJustifyH("LEFT")
    row.meta:SetWordWrap(false)
    row.remove = createRemoveButton(row, 20)
    row.remove:SetPoint("RIGHT", -6, 0)
    row.remove:SetScript("OnClick", function(self)
        ns.AskDeleteGroup(self:GetParent().index)
    end)
    row.remove:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip_SetTitle(GameTooltip, L["Delete Group..."])
        GameTooltip:Show()
    end)
    row.remove:SetScript("OnLeave", GameTooltip_Hide)
    row.rename = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.rename:SetSize(70, 20)
    row.rename:SetPoint("RIGHT", row.remove, "LEFT", -6, 0)
    row.rename:SetText(L["Rename"])
    ns.FitButtonText(row.rename, 70)
    row.rename:SetScript("OnClick", function(self)
        ns.AskRenameGroup(self:GetParent().index)
    end)
    row.meta:SetPoint("RIGHT", row.rename, "LEFT", -8, 0)
    return row
end

-- A rule ("All "Potion" items") with a red cross.
local function createChip()
    local chip = CreateFrame("Frame", nil, child)
    chip:SetHeight(20)
    chip.bg = chip:CreateTexture(nil, "BACKGROUND")
    chip.bg:SetAllPoints()
    chip.bg:SetColorTexture(1, 1, 1, 0.06)
    chip.text = chip:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    chip.text:SetPoint("LEFT", 8, 0)
    chip.remove = createRemoveButton(chip, 16)
    chip.remove:SetPoint("LEFT", chip.text, "RIGHT", 4, 0)
    chip.remove:SetScript("OnClick", function(self)
        local parent = self:GetParent()
        ns.SetTypeInGroup(parent.groupIndex, parent.classID, parent.subClassID, false)
        refresh()
    end)
    return chip
end

local function buildGroups(width)
    local list = ns.GetCustomGroups()
    if openGroup and not list[openGroup] then
        openGroup = nil
    end
    local y = 0
    for _, chip in ipairs(chips) do
        chip:Hide()
    end
    for _, cell in ipairs(groupCells) do
        cell:Hide()
    end
    groupPlus:Hide()
    groupInputHolder:Hide()
    for index, group in ipairs(list) do
        local row = groupRows[index]
        if not row then
            row = createGroupRow()
            groupRows[index] = row
        end
        row.index = index
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, -y)
        row:SetWidth(width)
        row.name:SetText(group.name)
        local text, isEmpty = summary(group)
        row.meta:SetText(text)
        row.meta:SetTextColor((isEmpty and GRAY_FONT_COLOR or HIGHLIGHT_FONT_COLOR):GetRGB())
        row.up:SetEnabled(index > 1)
        row.down:SetEnabled(index < #list)
        row.openBg:SetShown(index == openGroup)
        row:Show()
        y = y + ROW

        -- The opened group: the rules, the items as small slots, "+" and an input box.
        if index == openGroup then
            local x, top = 30, y + 6
            local keys = {}
            for key in pairs(group.types) do
                keys[#keys + 1] = key
            end
            table.sort(keys)
            for chipIndex, key in ipairs(keys) do
                local chip = chips[chipIndex]
                if not chip then
                    chip = createChip()
                    chips[chipIndex] = chip
                end
                local classID, subClassID = ns.ParseTypeKey(key)
                chip.groupIndex, chip.classID, chip.subClassID = index, classID, subClassID
                chip.text:SetText(L["All \"%s\" items"]:format(ns.GetTypeName(classID, subClassID)))
                local chipWidth = chip.text:GetStringWidth() + 36
                if x > 30 and x + chipWidth > width then
                    x, top = 30, top + 24
                end
                chip:SetWidth(chipWidth)
                chip:ClearAllPoints()
                chip:SetPoint("TOPLEFT", x, -top)
                chip:Show()
                x = x + chipWidth + 6
            end
            if #keys > 0 then
                top = top + 26
            end
            local ids = {}
            for itemID in pairs(group.items) do
                ids[#ids + 1] = itemID
            end
            sortByName(ids)
            local cols = math.max(1, math.floor((width - 30) / SMALL_CELL))
            for cellIndex, itemID in ipairs(ids) do
                local cell = groupCells[cellIndex]
                if not cell then
                    cell = createItemCell(SMALL, function(id)
                        if openGroup then
                            ns.SetItemInGroup(openGroup, id, false)
                            refresh()
                        end
                    end, function()
                        if openGroup then
                            addToGroupFromCursor(openGroup)
                        end
                    end)
                    groupCells[cellIndex] = cell
                end
                setItemCell(cell, itemID)
                -- The slot is scaled, so its place is counted in its own units.
                local scale = SMALL / 37
                cell:ClearAllPoints()
                cell:SetPoint("TOPLEFT", (30 + ((cellIndex - 1) % cols) * SMALL_CELL) / scale,
                    -(top + math.floor((cellIndex - 1) / cols) * SMALL_CELL) / scale)
                cell:Show()
            end
            local plusIndex = #ids
            groupPlus:ClearAllPoints()
            groupPlus:SetPoint("TOPLEFT", 30 + (plusIndex % cols) * SMALL_CELL, -(top + math.floor(plusIndex / cols) * SMALL_CELL))
            groupPlus:Show()
            top = top + (math.floor(plusIndex / cols) + 1) * SMALL_CELL + 4
            groupInputHolder:ClearAllPoints()
            groupInputHolder:SetPoint("TOPLEFT", 34, -top)
            groupInputHolder:SetWidth(width - 40)
            groupInputHolder:Show()
            y = top + 44
        end
    end
    for index = #list + 1, #groupRows do
        groupRows[index]:Hide()
    end
    -- "+ New Group": click, or drop an item (it goes into the new group).
    newRow:ClearAllPoints()
    newRow:SetPoint("TOPLEFT", 0, -y)
    newRow:SetWidth(width)
    local full = #list >= (ns.MAX_GROUPS or 8)
    newRow:SetEnabled(not full)
    newRow.text:SetText(full and L["You can have at most %d groups."]:format(ns.MAX_GROUPS or 8)
        or L["+ New Group – click, or drop an item"])
    newRow:Show()
    y = y + ROW
    child:SetHeight(y)

    head.icon:SetAtlas("bags-icon-multiple")
    head.title:SetText(L["Your groups"])
    head.count:SetText(L["%d of %d"]:format(#list, ns.MAX_GROUPS or 8))
end

---------------------------------------------------------------------------
-- The panel
---------------------------------------------------------------------------

refresh = function()
    if not (panel and which and panel:IsShown()) then
        return
    end
    local width = panel:GetWidth() - SCROLLBAR
    child:SetWidth(width)
    junkFoot:SetShown(which == "junk")
    scroll:ClearAllPoints()
    scroll:SetPoint("TOPLEFT", 0, -HEAD)
    scroll:SetPoint("BOTTOMRIGHT", -SCROLLBAR, which == "junk" and JUNK_FOOT or 0)
    for _, cell in ipairs(junkCells) do
        cell:SetShown(false)
    end
    junkPlus:Hide()
    junkEmpty:Hide()
    for _, row in ipairs(groupRows) do
        row:Hide()
    end
    newRow:Hide()
    if which == "junk" then
        for _, chip in ipairs(chips) do
            chip:Hide()
        end
        for _, cell in ipairs(groupCells) do
            cell:Hide()
        end
        groupPlus:Hide()
        groupInputHolder:Hide()
        buildJunk(width)
    else
        buildGroups(width)
    end
end

-- Marks.lua and Groups.lua call these when the junk list or the groups change.
ns.RefreshJunkListPage = refresh
ns.RefreshGroupsPage = refresh

-- Layout.lua: show the panel for the view ("junk" or "groups") with width and height. place(panel)
-- puts it in place in the window.
function ns.LayoutPanel(view, place, width, height)
    if not panel then
        return
    end
    if which ~= view then
        scroll:SetVerticalScroll(0)
    end
    which = view
    panel:SetSize(width, height)
    place(panel)
    panel:Show()
    refresh()
end

function ns.HidePanel()
    which = nil
    if panel then
        panel:Hide()
        junkInput:ClearFocus()
        groupInput:ClearFocus()
    end
end

-- The gear menu: open the junk list or the groups in the bags.
function ns.OpenPanel(view)
    -- Only when the bags are open: they are never opened from addon code (see LogoButton.lua).
    if not ns.bagFrame or not ns.bagFrame:IsShown() then
        return
    end
    if ns.SetView then
        ns.SetView(view)
    end
end

ns.OnLoad(function()
    local bagFrame = ns.bagFrame
    if not bagFrame then
        return
    end
    panel = CreateFrame("Frame", nil, bagFrame)
    panel:SetFrameLevel(bagFrame:GetFrameLevel() + 15) -- above the background and the item buttons
    panel:EnableMouse(true)
    panel:Hide()
    -- An item dropped on the panel goes on the junk list, or into the opened group.
    local function dropOnPanel()
        if which == "junk" then
            addJunkFromCursor()
        elseif which == "groups" and openGroup then
            addToGroupFromCursor(openGroup)
        end
    end
    panel:SetScript("OnReceiveDrag", dropOnPanel)
    panel:SetScript("OnMouseUp", dropOnPanel)

    -- The top line: icon, title, count and Done.
    head = CreateFrame("Frame", nil, panel)
    head:SetPoint("TOPLEFT")
    head:SetPoint("TOPRIGHT")
    head:SetHeight(HEAD)
    head.icon = head:CreateTexture(nil, "ARTWORK")
    head.icon:SetSize(28, 28)
    head.icon:SetPoint("LEFT", 2, 0)
    head.title = head:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    head.title:SetPoint("LEFT", head.icon, "RIGHT", 8, 0)
    head.count = head:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    head.count:SetPoint("LEFT", head.title, "RIGHT", 8, 0)
    head.count:SetTextColor(GRAY_FONT_COLOR:GetRGB())
    head.done = CreateFrame("Button", nil, head, "UIPanelButtonTemplate")
    head.done:SetSize(80, 22)
    head.done:SetPoint("RIGHT", -2, 0)
    head.done:SetText(L["Done"])
    ns.FitButtonText(head.done, 80)
    head.done:SetScript("OnClick", function()
        ns.SetView("bags")
    end)
    local line = head:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(1, 0.82, 0, 0.18)
    line:SetHeight(1)
    line:SetPoint("BOTTOMLEFT", 0, 2)
    line:SetPoint("BOTTOMRIGHT", 0, 2)

    -- The list, which scrolls with the mouse wheel. The scroll bar shows only when needed.
    scroll = CreateFrame("ScrollFrame", nil, panel, "ScrollFrameTemplate")
    if scroll.ScrollBar and scroll.ScrollBar.SetHideIfUnscrollable then
        scroll.ScrollBar:SetHideIfUnscrollable(true)
    end
    child = CreateFrame("Frame", nil, scroll)
    child:SetSize(1, 1)
    scroll:SetScrollChild(child)

    -- The junk list: "+" and the text when the list is empty.
    junkPlus = createPlusCell(37, L["Drop an item here to add it to your junk list."], addJunkFromCursor)
    junkEmpty = child:CreateFontString(nil, "ARTWORK", "GameFontDisable")
    junkEmpty:SetText(ns.KeyText(L["Your junk list is empty. Drop an item here, or Alt-click one in your bags."]))

    -- Under the junk list: the input box and the two junk questions (the same options as before).
    junkFoot = CreateFrame("Frame", nil, panel)
    junkFoot:SetPoint("BOTTOMLEFT")
    junkFoot:SetPoint("BOTTOMRIGHT")
    junkFoot:SetHeight(JUNK_FOOT)
    junkInput, junkHint = createInput(junkFoot, 220, function(itemID)
        ns.SetJunk(itemID, true)
    end)
    junkInput:SetPoint("TOPLEFT", 6, -6)
    local label = junkFoot:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    label:SetPoint("TOPLEFT", junkHint, "BOTTOMLEFT", 0, -10)
    label:SetText(L["When you loot something on the list"])
    local previous = label
    for _, option in ipairs({
        { "suggestOnLoot", L["Ask to delete it"],
            L["When you loot an item on your junk list, Tidy Pack asks right away whether to delete it. Nothing is deleted until you press Delete."] },
        { "suggestWhenFull", L["Suggest a deletion when your bags are full"],
            L["When your bags are full and something can't be looted, a panel under the loot window suggests an item to delete: your junk list first, then your cheapest grey item if the new loot is worth more. Nothing is deleted until you press Delete."] },
    }) do
        local check = CreateFrame("CheckButton", nil, junkFoot, "UICheckButtonTemplate")
        check:SetSize(22, 22)
        -- The first under the heading, the next under the one before.
        check:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", previous == label and -4 or 0, previous == label and -2 or 2)
        check.key = option[1]
        check.Text:SetText(option[2])
        check.Text:SetFontObject(GameFontHighlightSmall)
        check:SetScript("OnClick", function(self)
            ns.db[self.key] = self:GetChecked() and true or false
        end)
        check:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip_SetTitle(GameTooltip, option[2])
            GameTooltip_AddNormalLine(GameTooltip, option[3])
            GameTooltip:Show()
        end)
        check:SetScript("OnLeave", GameTooltip_Hide)
        junkChecks[#junkChecks + 1] = check
        previous = check
    end

    -- The groups: "+" in the opened group, the input box under it and the line "+ New Group".
    groupPlus = createPlusCell(SMALL, L["Drop an item here to add it to the group."], function()
        if openGroup then
            addToGroupFromCursor(openGroup)
        end
    end)
    groupInputHolder = CreateFrame("Frame", nil, child)
    groupInputHolder:SetHeight(40)
    groupInput, groupHint = createInput(groupInputHolder, 200, function(itemID)
        if openGroup then
            ns.SetItemInGroup(openGroup, itemID, true)
            refresh()
        end
    end)
    groupInput:SetPoint("TOPLEFT", 4, 0)
    newRow = CreateFrame("Button", nil, child)
    newRow:SetHeight(ROW)
    newRow:SetHighlightAtlas("Options_List_Hover", "ADD")
    newRow.text = newRow:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    newRow.text:SetPoint("LEFT", 30, 0)
    newRow:SetScript("OnClick", function()
        local itemID = cursorItemID()
        if itemID then
            ClearCursor()
        end
        ns.AskNewGroup(function(index)
            if itemID then
                ns.SetItemInGroup(index, itemID, true)
            end
            openGroup = index
            refresh()
        end)
    end)
    newRow:SetScript("OnReceiveDrag", newRow:GetScript("OnClick"))

    -- Shift-click on a link while an input box is active. The game itself only puts links in the
    -- chat and a few own fields (ChatFrameUtil.InsertLink), so Tidy Pack listens afterwards.
    if ChatFrameUtil and ChatFrameUtil.InsertLink then
        hooksecurefunc(ChatFrameUtil, "InsertLink", function(text)
            if type(text) ~= "string" or not text:find("item:", 1, true) then
                return
            end
            for _, input in ipairs({ junkInput, groupInput }) do
                if input:HasFocus() then
                    input:SetText(text)
                    input.add()
                end
            end
        end)
    end
end)
