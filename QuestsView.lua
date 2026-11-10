-- TidyPack – QuestsView.lua
-- Fliken Quests i väskfönstret: en översikt över quests som kräver saker. Klara quests står
-- överst ("Ready to turn in"), sedan de som pågår. Under varje quest: en rad per sak med de
-- riktiga rutorna du har (de går att använda, dra och sälja som i väskan, och har samma lås hos
-- en handlare), vad saken heter, hur många du har av hur många som behövs, och en stapel. Det du
-- inte har plockat än syns som text med en tom ruta. Saker som spelet själv markerat som
-- quest-saker men som inte hör till en quest nedan står sist under "Other quest items".
-- Samma rutor flyttas mellan flikarna (Layout.lua), så en sak syns aldrig på två ställen.
-- Layout.lua ger den här filen rutorna och en funktion för att placera dem, och filen lägger ut
-- rubriker, texter och staplar (de delarna återanvänds mellan genomgångarna).
-- ⚠️ Sakerna känns igen på namnet i questloggens text, alltså på spelets språk.
-- ⚠️ Får inte alla quests plats får de sista vänta ("...and N more"), eftersom fönstret inte
--    får bli högre än skärmen.

local _, ns = ...
local L = ns.L

local ITEM_CELL = 42          -- en ruta och luften efter den
local ROW_HEIGHT = 40         -- en sak (en ruta hög)
local HEAD_HEIGHT = 22        -- questens rubrik
local SECTION_HEIGHT = 22     -- "Ready to turn in" och "In progress"
local QUEST_GAP = 8
local MAX_STACKS = 6          -- så många högar av samma sak visas bredvid varandra
local BAR_WIDTH = 160
local BAR_HEIGHT = 6
local GHOST_SIZE = 30
local EMPTY_SLOT = "Interface\\Buttons\\UI-EmptySlot"
local CHECK = "common-icon-checkmark"

local host                    -- en egen ram i väskfönstret för texterna och staplarna
local texts, bars, ghosts = {}, {}, {}
local usedTexts, usedBars, usedGhosts = 0, 0, 0

local function ensureHost()
    if not host and ns.bagFrame then
        host = CreateFrame("Frame", nil, ns.bagFrame)
        host:SetAllPoints()
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

local function acquireBar()
    usedBars = usedBars + 1
    local bar = bars[usedBars]
    if not bar then
        bar = {}
        bar.background = ensureHost():CreateTexture(nil, "ARTWORK")
        bar.background:SetColorTexture(0, 0, 0, 0.6)
        bar.fill = ensureHost():CreateTexture(nil, "ARTWORK", nil, 1)
        bars[usedBars] = bar
    end
    bar.background:SetSize(BAR_WIDTH, BAR_HEIGHT)
    bar.background:Show()
    bar.fill:Show()
    return bar
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

-- Döljer allt som den här filen har lagt ut (när du byter till en annan flik, och först i varje
-- genomgång av fliken Quests).
function ns.HideQuestsView()
    for _, text in ipairs(texts) do
        text:Hide()
    end
    for _, bar in ipairs(bars) do
        bar.background:Hide()
        bar.fill:Hide()
    end
    for _, ghost in ipairs(ghosts) do
        ghost:Hide()
    end
    usedTexts, usedBars, usedGhosts = 0, 0, 0
end

local function progressText(have, need)
    local text = ("%d/%d"):format(have, need)
    if need > 0 and have >= need then
        return GREEN_FONT_COLOR:WrapTextInColorCode(text)
    end
    return text
end

-- Hur högt en quest blir: rubriken och en rad per sak.
local function questHeight(quest)
    return HEAD_HEIGHT + #quest.objectives * ROW_HEIGHT + QUEST_GAP
end

-- Lägger ut fliken Quests.
--   byName      sakens namn → rutorna (entries i Layout.lua) som hör till en quest
--   others      rutor med saker som spelet markerat som quest-saker men som inte hör till en quest ovan
--   width       rutnätets bredd
--   maxHeight   så högt får innehållet bli (nil = obegränsat)
--   placeEntry(entry, x, y) och placeRegion(del, x, y) placerar en ruta eller en text, stapel eller bild
-- Returnerar höjden, listan med rutor i ordning och första rutan i varje quest (för handkontrollen).
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
    local hidden = 0
    local placedEntries = {}  -- en ruta visas bara en gång, även om flera quests behöver saken
    local function fits(height)
        return not maxHeight or y + height <= maxHeight or (#buttons == 0 and y == 0)
    end

    local function section(label, color)
        local text = acquireText("GameFontHighlightSmall")
        text:SetText(label)
        text:SetTextColor(color:GetRGB())
        placeRegion(text, 0, y)
        y = y + SECTION_HEIGHT
    end

    local function placeQuest(quest)
        local head = acquireText("GameFontNormal")
        local prefix = quest.level > 0 and ("[%d] "):format(quest.level) or ""
        local mark = quest.ready and (CreateAtlasMarkup(CHECK, 12, 12) .. " ") or ""
        head:SetWidth(width - 70)
        head:SetText(mark .. prefix .. quest.title)
        placeRegion(head, 0, y)
        -- Framsteget till höger: hur många av målen som är klara om flera, annars antalet.
        local progressLabel = acquireText("GameFontHighlightSmall")
        progressLabel:SetWidth(width)
        progressLabel:SetJustifyH("RIGHT")
        if #quest.objectives == 1 then
            progressLabel:SetText(progressText(quest.objectives[1].have, quest.objectives[1].need))
        else
            local done = 0
            for _, objective in ipairs(quest.objectives) do
                if objective.finished then
                    done = done + 1
                end
            end
            progressLabel:SetText(progressText(done, #quest.objectives))
        end
        placeRegion(progressLabel, 0, y + 2)
        y = y + HEAD_HEIGHT

        local first
        for _, objective in ipairs(quest.objectives) do
            local stacks = byName[objective.name]
            local free = {}
            for _, entry in ipairs(stacks or {}) do
                if not placedEntries[entry] and #free < MAX_STACKS then
                    free[#free + 1] = entry
                end
            end
            local shown = #free
            if shown > 0 then
                for index, entry in ipairs(free) do
                    placedEntries[entry] = true
                    placeEntry(entry, (index - 1) * ITEM_CELL, y)
                    buttons[#buttons + 1] = entry.button
                    first = first or entry.button
                end
            elseif not stacks then
                -- Inget i väskorna: en tom ruta och grå text.
                placeRegion(acquireGhost(), 3, y + 3)
            end
            local hasStacks = shown > 0 or stacks ~= nil
            local textX = (shown > 0 and shown * ITEM_CELL or ITEM_CELL) + 6
            local name = acquireText("GameFontHighlight")
            name:SetWidth(width - textX - 10)
            name:SetText(hasStacks and objective.name or GRAY_FONT_COLOR:WrapTextInColorCode(objective.name))
            placeRegion(name, textX, y + 4)
            local counts = acquireText("GameFontHighlightSmall")
            counts:SetText(progressText(objective.have, objective.need))
            counts:SetWidth(60)
            placeRegion(counts, textX + 0, y + 22)
            if objective.need > 1 then
                local bar = acquireBar()
                local fraction = math.min(1, objective.have / objective.need)
                bar.fill:ClearAllPoints()
                bar.fill:SetPoint("TOPLEFT", bar.background, "TOPLEFT")
                bar.fill:SetPoint("BOTTOMLEFT", bar.background, "BOTTOMLEFT")
                bar.fill:SetWidth(math.max(1, BAR_WIDTH * fraction))
                if objective.have >= objective.need then
                    bar.fill:SetColorTexture(0.23, 0.82, 0.23, 1)
                else
                    bar.fill:SetColorTexture(0.79, 0.64, 0.15, 1)
                end
                placeRegion(bar.background, textX + 50, y + 27)
            end
            y = y + ROW_HEIGHT
        end
        firsts[#firsts + 1] = first
        y = y + QUEST_GAP
    end

    local function placeList(quests)
        for _, quest in ipairs(quests) do
            if fits(questHeight(quest) + SECTION_HEIGHT) then
                placeQuest(quest)
            else
                hidden = hidden + 1
            end
        end
    end

    if #ready > 0 then
        section(L["Ready to turn in"], GREEN_FONT_COLOR)
        placeList(ready)
    end
    if #progress > 0 then
        if #ready > 0 then
            section(L["In progress"], GRAY_FONT_COLOR)
        end
        placeList(progress)
    end

    -- Quest-saker utan quest ovan, i ett rutnät.
    if #others > 0 and fits(SECTION_HEIGHT + ROW_HEIGHT) then
        section(L["Other quest items"], GRAY_FONT_COLOR)
        local columns = math.max(1, math.floor((width + 5) / ITEM_CELL))
        for index, entry in ipairs(others) do
            local column = (index - 1) % columns
            local row = math.floor((index - 1) / columns)
            placeEntry(entry, column * ITEM_CELL, y + row * ITEM_CELL)
            buttons[#buttons + 1] = entry.button
            if index == 1 then
                firsts[#firsts + 1] = entry.button
            end
        end
        y = y + math.ceil(#others / columns) * ITEM_CELL + QUEST_GAP
    end

    if hidden > 0 then
        local more = acquireText("GameFontDisableSmall")
        more:SetWidth(width)
        more:SetText(L["...and %d more quests – see your quest log."]:format(hidden))
        placeRegion(more, 0, y)
        y = y + SECTION_HEIGHT
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
