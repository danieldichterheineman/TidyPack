-- TidyPack – Junk.lua
-- Vad som räknas som skräp. Tidy Pack hade tidigare en egen knapp Sell Junk hos handlaren.
-- Den togs bort 2026-11-09 (användarens beslut): spelet har en egen knapp "Sell All Junk" i
-- handlarens fönster, och Tidy Packs knapp gick inte att nå med handkontroll.
-- ⚠️ Spelets knapp säljer alla grå saker och känner inte till Tidy Packs lås eller
-- skräplista. Saker på skräplistan som inte är grå säljs för hand.

local _, ns = ...

-- Vad för sorts skräp en sak är: "marked" (du har markerat den som skräp i Marks.lua),
-- "grey" (grå) eller nil (inte skräp). Favoriter, låsta saker, quest-saker och saker
-- som spelet håller på med är aldrig skräp, och inte heller grå saker som en quest behöver
-- senare (QuestHints.lua). Det du själv markerat räknas även om en quest behöver det senare:
-- där har du bestämt dig. Används av förslagen vid fulla väskor och frågan vid loot (MakeRoom.lua).
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
