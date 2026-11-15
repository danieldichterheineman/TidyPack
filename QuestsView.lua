-- TidyPack – QuestsView.lua
-- The Quests tab in the bag window: a list of quests that need items. You open the parts "Ready to
-- turn in", "In progress" and "Other quest items" with a click on the heading, and then there is a
-- line per quest with its name and how far you've come. A click on a quest opens just that one: the
-- real item buttons you have (they can be used, dragged and sold as in the bags, and have the same
-- locks at a merchant) and what is needed. What you haven't picked up yet shows as an empty slot.
-- Items the game itself marks as quest items but that don't belong to a quest come last under
-- "Other quest items". The choices are saved in TidyPackDB.questOpen. At first everything is closed,
-- except "Ready to turn in" when a quest is ready. The same buttons move between the tabs
-- (Layout.lua), so an item never shows in two places.
-- Layout.lua gives this file the buttons and a function to place them, and this file lays out
-- headings and texts (those parts are reused between passes).
-- ⚠️ Items are recognised by their name in the quest log's text, so in the game's language.
-- ⚠️ The list never makes the window taller than the other tabs; it scrolls with the mouse wheel
--    instead (ns.ScrollQuests).

local _, ns = ...
local L = ns.L

local ITEM_CELL = 42          -- one slot and the space after it
local OBJECTIVE_HEIGHT = 30   -- one line for an item in an opened quest
local SMALL_ICON = 26         -- a small slot in an opened quest
local SMALL_CELL = 28
local QUEST_HEIGHT = 24       -- a quest's line when it is closed
local INDENT = 16             -- quests are indented under their heading
local SCROLL_WIDTH = 4        -- the scroll bar's width
local SCROLL_ROOM = 12        -- room to the right for the scroll bar
local scrollOffset = 0        -- how many parts the list is scrolled
local maxOffset = 0
local track, thumb            -- the scroll bar
local HEADER_HEIGHT = 26      -- a part's heading
local SECTION_GAP = 6
local MAX_SLOTS = 4           -- this many slots (stacks of the same item) show in one line
local GHOST_SIZE = 22
local EMPTY_SLOT = "Interface\\Buttons\\UI-EmptySlot"
local CHECK = "common-icon-checkmark"

local host                    -- an own frame in the bag window for the texts and headings
local texts, ghosts, headers = {}, {}, {}
local usedTexts, usedGhosts, usedHeaders = 0, 0, 0

local function ensureHost()
    if not host and ns.bagFrame then
        host = CreateFrame("Frame", nil, ns.bagFrame)
        host:SetAllPoints()
        track = host:CreateTexture(nil, "ARTWORK")
        track:SetColorTexture(1, 1, 1, 0.08)
        track:Hide()
        thumb = host:CreateTexture(nil, "OVERLAY")
        thumb:SetColorTexture(1, 0.82, 0, 0.6)
        thumb:Hide()
    end
    return host
end

local function acquireText(fontObject)
    usedTexts = usedTexts + 1
    local text = texts[usedTexts]
    if not text then
        text = ensureHost():CreateFontString(nil, "ARTWORK", fontObject)
        texts[usedTexts] = text
    end
    text:SetFontObject(fontObject)
    text:SetJustifyH("LEFT")
    text:SetWordWrap(false)
    text:ClearAllPoints()
    text:Show()
    return text
end

local function acquireGhost()
    usedGhosts = usedGhosts + 1
    local ghost = ghosts[usedGhosts]
    if not ghost then
        ghost = ensureHost():CreateTexture(nil, "ARTWORK")
        ghost:SetTexture(EMPTY_SLOT)
        ghost:SetTexCoord(0.140625, 0.84375, 0.140625, 0.84375)
        ghost:SetSize(GHOST_SIZE, GHOST_SIZE)
        ghost:SetAlpha(0.6)
        ghosts[usedGhosts] = ghost
    end
    ghost:Show()
    return ghost
end

-- Is the part open? A saved choice first, otherwise: only "Ready to turn in" when a quest is ready.
local function isOpen(key, defaultOpen)
    local saved = ns.db and ns.db.questOpen and ns.db.questOpen[key]
    if saved == nil then
        return defaultOpen
    end
    return saved
end

-- A heading you can click to open or close the part.
local function acquireHeader(key, text, rightText, open, color, width, indent)
    usedHeaders = usedHeaders + 1
    local header = headers[usedHeaders]
    if not header then
        header = CreateFrame("Button", nil, ensureHost())
        header:SetHeight(HEADER_HEIGHT - 2)
        header:SetHighlightAtlas("Options_List_Hover", "ADD")
        header.text = header:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        header.text:SetJustifyH("LEFT")
        header.text:SetWordWrap(false)
        header.right = header:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        header.right:SetPoint("RIGHT", -4, 0)
        header.right:SetJustifyH("RIGHT")
        header:SetScript("OnClick", function(self)
            if ns.db then
                ns.db.questOpen = ns.db.questOpen or {}
                ns.db.questOpen[self.key] = not self.open
            end
            if ns.Refresh then
                ns.Refresh()
            end
        end)
        headers[usedHeaders] = header
    end
    header.key, header.open = key, open
    header:SetWidth(width)
    local icon = ("|TInterface\\Buttons\\UI-%sButton-Up:14:14|t "):format(open and "Minus" or "Plus")
    header.text:ClearAllPoints()
    header.text:SetPoint("LEFT", 4 + indent, 0)
    header.text:SetWidth(math.max(40, width - indent - 70))
    header.text:SetText(icon .. text)
    header.text:SetTextColor(color:GetRGB())
    header.right:SetText(rightText or "")
    header:Show()
    return header
end

-- Hides everything this file has laid out (when you switch to another tab, and first in every
-- pass of the Quests tab).
function ns.HideQuestsView()
    for _, text in ipairs(texts) do
        text:Hide()
    end
    for _, ghost in ipairs(ghosts) do
        ghost:Hide()
    end
    for _, header in ipairs(headers) do
        header:Hide()
    end
    if track then
        track:Hide()
        thumb:Hide()
    end
    usedTexts, usedGhosts, usedHeaders = 0, 0, 0
end

local function progressText(have, need)
    local text = ("%d/%d"):format(have, need)
    if need > 0 and have >= need then
        return GREEN_FONT_COLOR:WrapTextInColorCode(text)
    end
    return text
end

-- Scrolls the list one part (the mouse wheel over the bags, Layout.lua). delta 1 = up.
function ns.ScrollQuests(delta)
    local new = math.max(0, math.min(scrollOffset - delta, maxOffset))
    if new ~= scrollOffset then
        scrollOffset = new
        if ns.Refresh then
            ns.Refresh()
        end
    end
end

-- Lays out the Quests tab.
--   byName      item name → the buttons (entries in Layout.lua) that belong to a quest
--   others      buttons with items the game marks as quest items but that belong to no quest above
--   width       the grid's width
--   maxHeight   how tall the content may get (nil = no limit)
--   placeEntry(entry, x, y) and placeRegion(part, x, y) place a button or a text, heading or image
-- Returns the height, the list of buttons in order and the first button of each quest (for the controller).
function ns.BuildQuestsView(byName, others, width, maxHeight, placeEntry, placeRegion)
    ensureHost()
    ns.HideQuestsView()
    local buttons, firsts = {}, {}
    local list = ns.GetQuestList()
    local ready, progress = {}, {}
    for _, quest in ipairs(list) do
        local target = quest.ready and ready or progress
        target[#target + 1] = quest
    end

    local y = 0
    local placedEntries = {}  -- a button shows only once, even if several quests need the item

    -- Room for the scroll bar on the right, so the numbers don't end up under it.
    local rowWidth = width - SCROLL_ROOM

    local function section(key, label, count, open, color)
        local header = acquireHeader(key, ("%s (%d)"):format(label, count), nil, open, color, rowWidth, 0)
        placeRegion(header, 0, y)
        y = y + HEADER_HEIGHT
    end

    -- How far a quest has come: the count for one item, otherwise how many objectives are done.
    local function questTotal(quest)
        if #quest.objectives == 1 then
            return progressText(quest.objectives[1].have, quest.objectives[1].need)
        end
        local done = 0
        for _, objective in ipairs(quest.objectives) do
            if objective.finished then
                done = done + 1
            end
        end
        return progressText(done, #quest.objectives)
    end

    -- The content of an opened quest: a line per item, with a small slot for each stack you have
    -- (or an empty slot), then the item's name and how many are needed. Returns the height.
    local function placeBody(quest)
        local rowY = y
        local first
        for _, objective in ipairs(quest.objectives) do
            local stacks = byName[objective.name]
            local shown = 0
            if stacks then
                for _, entry in ipairs(stacks) do
                    if not placedEntries[entry] and shown < MAX_SLOTS then
                        placedEntries[entry] = true
                        entry.scale = SMALL_ICON / ns.ITEM_BUTTON_SIZE
                        placeEntry(entry, INDENT + shown * SMALL_CELL, rowY + 2)
                        buttons[#buttons + 1] = entry.button
                        first = first or entry.button
                        shown = shown + 1
                    end
                end
            else
                placeRegion(acquireGhost(), INDENT + 2, rowY + 4)
                shown = 1 -- the empty slot takes one place
            end
            local line = acquireText("GameFontHighlightSmall")
            local textX = INDENT + math.max(shown, 1) * SMALL_CELL + 4
            line:SetWidth(math.max(40, rowWidth - textX - 10))
            line:SetText(("%s  %s"):format(objective.name, progressText(objective.have, objective.need)))
            placeRegion(line, textX, rowY + 8)
            rowY = rowY + OBJECTIVE_HEIGHT
        end
        firsts[#firsts + 1] = first
        return rowY - y + 2
    end

    -- A quest: a line you can click, and when it is open, its content.
    local function placeQuest(quest)
        local key = "q" .. quest.questID
        local open = isOpen(key, false)
        local prefix = quest.level > 0 and ("[%d] "):format(quest.level) or ""
        local mark = quest.ready and (CreateAtlasMarkup(CHECK, 12, 12) .. " ") or ""
        local header = acquireHeader(key, mark .. prefix .. quest.title, questTotal(quest), open,
            NORMAL_FONT_COLOR, rowWidth, INDENT)
        placeRegion(header, 0, y)
        y = y + QUEST_HEIGHT
        if open then
            y = y + placeBody(quest) + 2
        end
    end

    -- Everything that can show, as a list of parts (heading, quest, line of slots) and their height.
    -- The tab is never taller than the other tabs; if not everything fits you scroll with the mouse
    -- wheel (ns.ScrollQuests), and a thin scroll bar on the right shows where you are (2026-11-11).
    local units = {}
    local function addUnit(height, draw)
        units[#units + 1] = { height = height, draw = draw }
    end

    local function addSection(key, label, quests, color, defaultOpen)
        if #quests == 0 then
            return
        end
        local open = isOpen(key, defaultOpen)
        addUnit(HEADER_HEIGHT, function()
            section(key, label, #quests, open, color)
        end)
        if open then
            for _, quest in ipairs(quests) do
                local height = QUEST_HEIGHT
                if isOpen("q" .. quest.questID, false) then
                    height = height + math.max(#quest.objectives, 1) * OBJECTIVE_HEIGHT + 4
                end
                addUnit(height, function()
                    placeQuest(quest)
                end)
            end
        end
        addUnit(SECTION_GAP, nil)
    end

    addSection("ready", L["Ready to turn in"], ready, GREEN_FONT_COLOR, true)
    addSection("progress", L["In progress"], progress, NORMAL_FONT_COLOR, false)

    -- Quest items without a quest above, in a grid (one part per row).
    if #others > 0 then
        local open = isOpen("other", false)
        addUnit(HEADER_HEIGHT, function()
            section("other", L["Other quest items"], #others, open, GRAY_FONT_COLOR)
        end)
        if open then
            local columns = math.max(1, math.floor((width - SCROLL_ROOM + 5) / ITEM_CELL))
            for rowStart = 1, #others, columns do
                addUnit(ITEM_CELL, function()
                    for index = rowStart, math.min(rowStart + columns - 1, #others) do
                        local entry = others[index]
                        placeEntry(entry, (index - rowStart) * ITEM_CELL, y)
                        buttons[#buttons + 1] = entry.button
                        if index == 1 then
                            firsts[#firsts + 1] = entry.button
                        end
                    end
                end)
            end
        end
        addUnit(SECTION_GAP, nil)
    end

    -- How much fits, and where the list starts.
    local total = 0
    for _, unit in ipairs(units) do
        total = total + unit.height
    end
    local scrolling = maxHeight and total > maxHeight
    local firstUnit = 1
    if scrolling then
        -- The last place you can scroll to: so that the end of the list is at the bottom.
        local lastStart, room = #units, maxHeight
        for index = #units, 1, -1 do
            if room - units[index].height < 0 then
                break
            end
            room = room - units[index].height
            lastStart = index
        end
        scrollOffset = math.max(0, math.min(scrollOffset, lastStart - 1))
        firstUnit = scrollOffset + 1
        maxOffset = lastStart - 1
    else
        scrollOffset, maxOffset = 0, 0
    end

    y = 0
    for index = firstUnit, #units do
        local unit = units[index]
        if maxHeight and y + unit.height > maxHeight then
            break
        end
        local unitY = y
        if unit.draw then
            unit.draw()
        end
        y = unitY + unit.height
    end

    -- The scroll bar: a thin track and a marker for the part that shows.
    if scrolling then
        local before = 0
        for index = 1, firstUnit - 1 do
            before = before + units[index].height
        end
        track:SetSize(SCROLL_WIDTH, maxHeight)
        placeRegion(track, width - SCROLL_WIDTH, 0)
        track:Show()
        local thumbHeight = math.max(16, maxHeight * maxHeight / total)
        local thumbY = (maxHeight - thumbHeight) * (maxOffset > 0 and scrollOffset / maxOffset or 0)
        thumb:SetSize(SCROLL_WIDTH, thumbHeight)
        placeRegion(thumb, width - SCROLL_WIDTH, thumbY)
        thumb:Show()
        y = maxHeight
    end

    if #list == 0 and #others == 0 then
        local empty = acquireText("GameFontHighlight")
        empty:SetWidth(width)
        empty:SetJustifyH("CENTER")
        empty:SetText(L["No quests need items right now."])
        placeRegion(empty, 0, 30)
        y = 80
    end
    return y, buttons, firsts
end
