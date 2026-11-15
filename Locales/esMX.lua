-- TidyPack – Locales/esMX.lua
-- Español (Latinoamérica). Maskinöversatt 2026-11-15; rättelser från spelare är välkomna. Bygger på
-- Locales/esES.lua (som laddas före) och byter bara de texter där orden skiljer sig: "basura" i
-- stället för "chatarra", "eliminar" i stället för "borrar", "saquear", "agregar" och "tomar".

local _, ns = ...

local overrides = {
    ["Junk"] = "Basura",
    ["Delete"] = "Eliminar",
    ["Add"] = "Agregar",
    ["Delete the group %s? The items stay in your bags."] = "¿Eliminar el grupo %s? Los objetos se quedan en tus bolsas.",
    ["It stays in %s for now."] = "Por ahora se queda en %s.",
    ["Add to Group"] = "Agregar al grupo",
    ["Add All \"%s\" Items to Group"] = "Agregar todos los objetos «%s» al grupo",
    ["Drop anywhere to put it in your bags"] = "Suéltalo en cualquier lugar para guardarlo en tus bolsas",
    ["Drop anywhere to put it in your bank"] = "Suéltalo en cualquier lugar para guardarlo en tu banco",
    ["Your bags are full. Delete %s (on your junk list) to make room for %s?"] = "Tus bolsas están llenas. ¿Eliminar %s (en tu lista de basura) para hacer espacio para %s?",
    ["Your bags are full. Delete %s (%s) to make room for %s (%s)?"] = "Tus bolsas están llenas. ¿Eliminar %s (%s) para hacer espacio para %s (%s)?",
    ["You looted %s, which is on your junk list. Delete it?"] = "Saqueaste %s, que está en tu lista de basura. ¿Eliminarlo?",
    ["Junk List"] = "Lista de basura",
    ["Remove from Junk List"] = "Quitar de la lista de basura",
    ["Add to Favorites"] = "Agregar a favoritos",
    ["Add to Junk List"] = "Agregar a la lista de basura",
    ["Junk List..."] = "Lista de basura...",
    ["Options, your junk list and your own groups."] = "Opciones, tu lista de basura y tus propios grupos.",
    ["Pick up an item and drop it here for its options."] = "Toma un objeto y suéltalo aquí para ver sus opciones.",
    ["Junk value in the header"] = "Valor de la basura en el título",
    ["What your junk sells for, next to the Junk header."] = "Lo que vale tu basura, junto al título Basura.",
    ["At merchants, items your quests need and items in your equipment sets get a lock and can't be clicked, so you can't sell them by mistake. The merchant's own Sell All Junk button doesn't know about these locks."] = "En los mercaderes, los objetos que necesitan tus misiones y los de tus conjuntos de equipo se bloquean y no se pueden presionar, para que no los vendas por error. El botón del mercader para vender toda la basura no conoce estos bloqueos.",
    ["When you loot an item on your junk list, Tidy Pack asks right away whether to delete it. Nothing is deleted until you press Delete."] = "Cuando saqueas un objeto de tu lista de basura, Tidy Pack pregunta enseguida si quieres eliminarlo. No se elimina nada hasta que presiones Eliminar.",
    ["Suggest a deletion when full"] = "Sugerir eliminar algo con las bolsas llenas",
    ["When your bags are full and something can't be looted, a panel under the loot window suggests an item to delete: your junk list first, then your cheapest grey item if the new loot is worth more. Nothing is deleted until you press Delete."] = "Cuando tus bolsas están llenas y no se puede saquear algo, un panel bajo la ventana de botín sugiere un objeto para eliminar: primero de tu lista de basura y después tu objeto gris más barato si el nuevo botín vale más. No se elimina nada hasta que presiones Eliminar.",
    ["• Alt-click an item: favorite, junk list or group."] = "• Alt-clic en un objeto: favorito, lista de basura o grupo.",
    ["• The gear button at the top of the bag window has every option, the junk list and your groups."] = "• El engranaje arriba en la ventana de bolsas tiene todas las opciones, la lista de basura y tus grupos.",
    ["Tidy Pack no longer has sets. Use the game's Equipment Manager in the character window (C), and delete the old \"TP\" macro (Esc → Macros)."] = "Tidy Pack ya no tiene conjuntos. Usa el gestor de equipo de la ventana del personaje (C) y elimina la antigua macro «TP» (Esc → Macros).",
    ["Delete Group..."] = "Eliminar grupo...",
    ["Drop an item here to add it to your junk list."] = "Suelta un objeto aquí para agregarlo a tu lista de basura.",
    ["Your junk list is empty. Drop an item here, or Alt-click one in your bags."] = "Tu lista de basura está vacía. Suelta un objeto aquí o haz Alt-clic en uno de tus bolsas.",
    ["When you loot something on the list"] = "Cuando saqueas algo de la lista",
    ["Ask to delete it"] = "Preguntar si se elimina",
    ["Suggest a deletion when your bags are full"] = "Sugerir eliminar algo cuando tus bolsas estén llenas",
    ["Drop an item here to add it to the group."] = "Suelta un objeto aquí para agregarlo al grupo.",
    ["Alt-click an item for its options: favorite, junk list and groups."] = "Haz Alt-clic en un objeto para ver sus opciones: favorito, lista de basura y grupos.",
    ["The gear button has your junk list, your own groups and the settings."] = "El engranaje tiene tu lista de basura, tus propios grupos y los ajustes.",
}

-- Den spanska översättningen för Spanien, med ändringarna ovanpå (CopyTable är spelets funktion).
local texts = CopyTable(ns.translationEsES or {})
for key, text in pairs(overrides) do
    texts[key] = text
end
ns.AddTranslation("esMX", texts)
