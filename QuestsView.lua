-- TidyPack – QuestsView.lua
-- Fliken Quests i väskfönstret: en lista över quests som kräver saker. Avsnitten "Ready to turn in",
-- "In progress" och "Other quest items" fäller du ut med ett klick på rubriken, och då syns en rad
-- per quest med namn och hur långt du kommit. Ett klick på en quest fäller ut just den: de riktiga
-- rutorna du har (de går att använda, dra och sälja som i väskan, och har samma lås hos en
-- handlare) och vad som behövs. Det du inte har plockat än syns som en tom ruta. Saker som spelet
-- själv markerat som quest-saker men som inte hör till en quest står sist under "Other quest
-- items". Valen sparas i TidyPackDB.questOpen. Från början är allt hopfällt, utom "Ready to turn in"
-- när någon quest är klar. Samma rutor flyttas mellan flikarna (Layout.lua), så en sak syns
-- aldrig på två ställen.
-- Layout.lua ger den här filen rutorna och en funktion för att placera dem, och filen lägger ut
-- rubriker och texter (de delarna återanvänds mellan genomgångarna).
-- ⚠️ Sakerna känns igen på namnet i questloggens text, alltså på spelets språk.
-- ⚠️ Får inte alla quests plats får de sista vänta ("...and N more"), eftersom fönstret inte
--    får bli högre än skärmen. Fäll då ihop ett avsnitt.

local _, ns = ...
local L = ns.L

local ITEM_CELL = 42          -- en ruta och luften efter den
local OBJECTIVE_HEIGHT = 30   -- en rad för en sak i en uppfälld quest
local SMALL_ICON = 26         -- en liten ruta i en uppfälld quest
local SMALL_CELL = 28
local QUEST_HEIGHT = 24       -- en quests rad när den är hopfälld
local INDENT = 16             -- quests står indragna under sin rubrik
local SCROLL_WIDTH = 4        -- rullistens bredd
local SCROLL_ROOM = 12        -- plats till höger för rullisten
local scrollOffset = 0        -- hur många delar listan är rullad
local maxOffset = 0
local track, thumb            -- rullisten
local HEADER_HEIGHT = 26      -- ett avsnitts rubrik
local SECTION_GAP = 6
local MAX_SLOTS = 4           -- så många rutor (högar av samma sak) visas på en rad
local GHOST_SIZE = 22
local EMPTY_SLOT = "Interface\\Buttons\\UI-EmptySlot"
local CHECK = "common-icon-checkmark"

local host                    -- en egen ram i väskfönstret för texterna och rubrikerna
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

-- Är avsnittet öppet? Sparat val först, annars: bara "Ready to turn in" när någon quest är klar.
local function isOpen(key, defaultOpen)
    local saved = ns.db and ns.db.questOpen and ns.db.questOpen[key]
    if saved == nil then
        return defaultOpen
    end
    return saved
end

-- En rubrik du kan klicka på för att öppna eller fälla ihop avsnittet.
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

-- Döljer allt som den här filen har lagt ut (när du byter till en annan flik, och först i varje
-- genomgång av fliken Quests).
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

-- Rullar listan en del (mushjulet över väskan, Layout.lua). delta 1 = uppåt.
function ns.ScrollQuests(delta)
    local new = math.max(0, math.min(scrollOffset - delta, maxOffset))
    if new ~= scrollOffset then
        scrollOffset = new
        if ns.Refresh then
            ns.Refresh()
        end
    end
end

-- Lägger ut fliken Quests.
--   byName      sakens namn → rutorna (entries i Layout.lua) som hör till en quest
--   others      rutor med saker som spelet markerat som quest-saker men som inte hör till en quest ovan
--   width       rutnätets bredd
--   maxHeight   så högt får innehållet bli (nil = obegränsat)
--   placeEntry(entry, x, y) och placeRegion(del, x, y) placerar en ruta eller en text, rubrik eller bild
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
    local placedEntries = {}  -- en ruta visas bara en gång, även om flera quests behöver saken

    -- Plats för rullisten till höger, så att siffrorna inte hamnar under den.
    local rowWidth = width - SCROLL_ROOM

    local function section(key, label, count, open, color)
        local header = acquireHeader(key, ("%s (%d)"):format(label, count), nil, open, color, rowWidth, 0)
        placeRegion(header, 0, y)
        y = y + HEADER_HEIGHT
    end

    -- Hur långt en quest har kommit: antalet om en sak, annars hur många mål som är klara.
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

    -- Innehållet i en uppfälld quest: en rad för varje sak, med en liten ruta för varje hög du har
    -- (eller en tom ruta) och därefter sakens namn och hur många som behövs. Returnerar höjden.
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
                shown = 1 -- den tomma rutan tar en plats
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

    -- En quest: en rad du kan klicka på, och när den är uppfälld dess innehåll.
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

    -- Allt som kan visas, som en lista med delar (rubrik, quest, rad med rutor) och deras höjd. Fliken
    -- är aldrig högre än de andra flikarna; ryms inte allt rullar man med mushjulet (ns.ScrollQuests),
    -- och en smal rullist till höger visar var man är (användarens önskan 2026-11-11).
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

    -- Quest-saker utan quest ovan, i ett rutnät (en del per rad).
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

    -- Hur mycket som ryms, och var listan börjar.
    local total = 0
    for _, unit in ipairs(units) do
        total = total + unit.height
    end
    local scrolling = maxHeight and total > maxHeight
    local firstUnit = 1
    if scrolling then
        -- Den sista platsen man kan rulla till: så att listans slut står längst ner.
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

    -- Rullisten: ett smalt spår och en markering för den del som syns.
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
