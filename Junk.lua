-- TidyPack – Junk.lua
-- What counts as junk. Tidy Pack used to have its own Sell Junk button at merchants. It was
-- removed 2026-11-09 (the owner's decision): the game has its own "Sell All Junk" button in the
-- merchant window, and Tidy Pack's button couldn't be reached with a controller.
-- ⚠️ The game's button sells every grey item and doesn't know about Tidy Pack's locks or junk
-- list. Items on the junk list that aren't grey are sold by hand.

local _, ns = ...

-- What kind of junk an item is: "marked" (you marked it as junk in Marks.lua), "grey", or nil
-- (not junk). Favorites, locked items, quest items and items the game is busy with are never
-- junk, and neither are grey items a quest will need later (QuestHints.lua). What you marked
-- yourself counts even if a quest needs it later: there you have decided. Used by the
-- suggestions when the bags are full and the question on loot (MakeRoom.lua).
function ns.GetJunkKind(bagID, slot, info)
    if not info or info.isLocked or ns.IsFavorite(info.itemID) or ns.IsLocked(bagID, slot, info) then
        return nil
    end
    if ns.IsJunkMarked(info.itemID) then
        return "marked"
    end
    if info.quality == Enum.ItemQuality.Poor and not (ns.IsNeededLater and ns.IsNeededLater(info.itemID, true)) then
        return "grey"
    end
    return nil
end
