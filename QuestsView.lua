-- TidyPack – QuestsView.lua
-- Fliken Quests i väskfönstret: en översikt över quests som kräver saker, kompakt med en rad per
-- quest. Raden har de riktiga rutorna du har (de går att använda, dra och sälja som i väskan,
-- och har samma lås hos en handlare), questens namn och en rad med vad som behövs, och hur långt du
-- kommit till höger. Det du inte har plockat än syns som en tom ruta. Saker som spelet själv
-- markerat som quest-saker men som inte hör till en quest nedan står sist under "Other quest items".
-- Avsnitten "Ready to turn in", "In progress" och "Other quest items" går att fälla ihop med ett klick
-- på rubriken (valet sparas i TidyPackDB.questOpen). Från början är allt hopfällt, utom "Ready to
-- turn in" när någon quest är klar. Samma rutor flyttas mellan flikarna (Layout.lua), så en sak syns
-- aldrig på två ställen.
-- Layout.lua ger den här filen rutorna och en funktion för att placera dem, och filen lägger ut
-- rubriker och texter (de delarna återanvänds mellan genomgångarna).
-- ⚠️ Sakerna känns igen på namnet i questloggens text, alltså på spelets språk.
-- ⚠️ Får inte alla quests plats får de sista vänta ("...and N more"), eftersom fönstret inte
--    får bli högre än skärmen. Fäll då ihop ett avsnitt.

local _, ns = ...
local L = ns.L

local ITEM_CELL = 42          -- en ruta och luften efter den
local ROW_HEIGHT = 44         -- en quest (en ruta hög och lite luft)
local HEADER_HEIGHT = 26      -- ett avsnitts rubrik
local SECTION_GAP = 6
local MAX_SLOTS = 6           -- så många rutor visas på en rad
local GHOST_SIZE = 30
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
local function acquireHeader(key, label, count, open, color, width)
    usedHeaders = usedHeaders + 1
    local header = headers[usedHeaders]
    if not header then
        header = CreateFrame("Button", nil, ensureHost())
        header:SetHeight(HEADER_HEIGHT - 2)
        header:SetHighlightAtlas("Options_List_Hover", "ADD")
        header.text = header:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        header.text:SetPoint("LEFT", 4, 0)
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
    header.text:SetText(("%s%s (%d)"):format(icon, label, count))
    header.text:SetTextColor(color:GetRGB())
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
        local header = acquireHeader(key, label, count, open, color, width)
        placeRegion(header, 0, y)
        y = y + HEADER_HEIGHT
    end

    local function placeQuest(quest)
        -- Rutorna: de du har, och en tom ruta för varje sak du inte har något av.
        local slots = {}
        for _, objective in ipairs(quest.objectives) do
            local stacks = byName[objective.name]
            if stacks then
                for _, entry in ipairs(stacks) do
                    if not placedEntries[entry] then
                        slots[#slots + 1] = entry
                    end
                end
            else
                slots[#slots + 1] = false
            end
        end
        local first
        local shown = 0
        for _, slot in ipairs(slots) do
            if shown >= MAX_SLOTS then
                break
            end
            if slot then
                placedEntries[slot] = true
                placeEntry(slot, shown * ITEM_CELL, y)
                buttons[#buttons + 1] = slot.button
                first = first or slot.button
            else
                placeRegion(acquireGhost(), shown * ITEM_CELL + 3, y + 3)
            end
            shown = shown + 1
        end
        local textX = shown * ITEM_CELL + 6

        local head = acquireText("GameFontNormal")
        local prefix = quest.level > 0 and ("[%d] "):format(quest.level) or ""
        local mark = quest.ready and (CreateAtlasMarkup(CHECK, 12, 12) .. " ") or ""
        head:SetWidth(math.max(40, width - textX - 60))
        head:SetText(mark .. prefix .. quest.title)
        placeRegion(head, textX, y + 4)

        -- Vad som behövs, på en rad: "Goretusk Liver 4/8".
        local parts = {}
        for _, objective in ipairs(quest.objectives) do
            parts[#parts + 1] = ("%s %s"):format(objective.name, progressText(objective.have, objective.need))
        end
        local detail = acquireText("GameFontHighlightSmall")
        detail:SetWidth(math.max(40, width - textX - 60))
        detail:SetText(table.concat(parts, "   "))
        placeRegion(detail, textX, y + 22)

        -- Framsteget till höger: antalet om en sak, annars hur många mål som är klara.
        local total = acquireText("GameFontHighlightSmall")
        total:SetWidth(54)
        total:SetJustifyH("RIGHT")
        if #quest.objectives == 1 then
            total:SetText(progressText(quest.objectives[1].have, quest.objectives[1].need))
        else
            local done = 0
            for _, objective in ipairs(quest.objectives) do
                if objective.finished then
                    done = done + 1
                end
            end
            total:SetText(progressText(done, #quest.objectives))
        end
        placeRegion(total, width - 58, y + 14)

        firsts[#firsts + 1] = first
        y = y + ROW_HEIGHT
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
                if fits(ROW_HEIGHT) then
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
