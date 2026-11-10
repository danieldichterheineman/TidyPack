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
    usedTexts, usedGhosts, usedHeaders = 0, 0, 0
end

local function progressText(have, need)
    local text = ("%d/%d"):format(have, need)
    if need > 0 and have >= need then
        return GREEN_FONT_COLOR:WrapTextInColorCode(text)
    end
    return text
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
    local hidden = 0
    local placedEntries = {}  -- en ruta visas bara en gång, även om flera quests behöver saken

    local function fits(height)
        return not maxHeight or y + height <= maxHeight
    end

    local function section(key, label, count, open, color)
        local header = acquireHeader(key, ("%s (%d)"):format(label, count), nil, open, color, width, 0)
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
            line:SetWidth(math.max(40, width - textX - 10))
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
            NORMAL_FONT_COLOR, width, INDENT)
        placeRegion(header, 0, y)
        y = y + QUEST_HEIGHT
        if open then
            y = y + placeBody(quest) + 2
        end
    end

    local function placeSection(key, label, quests, color, defaultOpen)
        if #quests == 0 then
            return
        end
        if not fits(HEADER_HEIGHT) then
            hidden = hidden + #quests
            return
        end
        local open = isOpen(key, defaultOpen)
        section(key, label, #quests, open, color)
        if open then
            for _, quest in ipairs(quests) do
                -- En uppfälld quest måste få plats med hela sitt innehåll.
                local needed = QUEST_HEIGHT
                if isOpen("q" .. quest.questID, false) then
                    needed = needed + #quest.objectives * OBJECTIVE_HEIGHT + 4
                end
                if fits(needed) then
                    placeQuest(quest)
                else
                    hidden = hidden + 1
                end
            end
        end
        y = y + SECTION_GAP
    end

    placeSection("ready", L["Ready to turn in"], ready, GREEN_FONT_COLOR, true)
    placeSection("progress", L["In progress"], progress, NORMAL_FONT_COLOR, false)

    -- Quest-saker utan quest ovan, i ett rutnät.
    if #others > 0 and fits(HEADER_HEIGHT) then
        local open = isOpen("other", false)
        section("other", L["Other quest items"], #others, open, GRAY_FONT_COLOR)
        if open then
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
            y = y + math.ceil(#others / columns) * ITEM_CELL
        end
        y = y + SECTION_GAP
    end

    if hidden > 0 then
        local more = acquireText("GameFontDisableSmall")
        more:SetWidth(width)
        more:SetText(L["...and %d more quests – fold a section above or see your quest log."]:format(hidden))
        placeRegion(more, 0, y)
        y = y + HEADER_HEIGHT
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
