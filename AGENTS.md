# Tidy Pack

Ordnar sakerna i spelets väskfönster i fasta grupper, som Baganator men utan inställningar.
Bara väskorna som karaktären bär med sig. Fungerar med mus och handkontroll.

## Fakta
- Addonnamn och mapp: `TidyPack` (måste matcha `TidyPack.toc`)
- Målklient: WoW Forever 1.60.1, Interface 16001 (källa: sidan "TOC format" på
  warcraft.wiki.gg och commit-meddelandet `1.60.1 (70862)` i GitHub-repot
  `Gethe/wow-ui-source`, gren `forever`, 2026-11-08). Kontrollera i spelet med
  `/dump select(4, GetBuildInfo())` när spelet är installerat.
- WoW Forever bygger på samma klient som retail (TOC-familjen `_Mainline`, Blizzards kodnamn
  "Camelot"). Blizzards kod för Forever finns i grenen `forever` i `Gethe/wow-ui-source`.
  Mappar som heter `Camelot` där är Forevers egna ändringar. Verifiera API:er mot den grenen,
  inte mot `live`.
- SavedVariables: `TidyPackDB` (per konto)
- Inga slash-kommandon, ingen inställningssida och ingen rad i addonfacket (se Beslut).
- Projektmapp: `/Users/danhei1104/TidyPack`

## Funktioner
- ✅ Fasta grupper, uppifrån och ned: Potions, Food & Drink, Consumables · **Equipment**
  (Weapons, Armor, Ammo) · **Crafting** (Trade Goods, Recipes) · Quest Items, Keys, Bags,
  Miscellaneous, Junk, Empty. Tomma grupper visas inte. Indelningen står i `Categories.lua`.
- ✅ Inom en grupp: bäst kvalitet först, sedan namn, sedan störst hög. Små grupper delar rad.
  Fönstret är 12 rutor brett.
- ✅ Tomma platser visas som en ruta per väsktyp, med antalet. Rutan är den första lediga
  platsen, så en sak som släpps där hamnar där spelet ändå skulle ha lagt den.
- ✅ Nivå (uppe till vänster) och "BoE" (nere till vänster) på vapen och rustning.
- ✅ Handkontroll: fönstret och rutorna är spelets egna, så spelets markör och knappar
  (använd, utrusta, sälj, dela, förstör, länka) fungerar som vanligt. Måste provas i spelet.
- ✅ Sökruta, pengar och markering av nya saker är spelets egna.
- ✅ Väskorna man har på sig syns inte bland sakerna. Med handkontroll lägger spelet annars
  in dem i rutnätet (`GamepadBagBar`), så Tidy Pack döljer den raden.
- ✅ Spelets knapp för att städa väskorna (`BagItemAutoSortButton`) döljs, eftersom
  sakerna ändå alltid visas grupperade.
- ⚠️ Byta väska (`BagSwap.lua`): högerklick på en vanlig väska i gruppen Bags (eller
  Equip på handkontrollen) byter ut den minsta vanliga väskan när alla fyra platser är fulla.
  Begränsningar: bara utanför strid; specialväskor (koger, väskor för örter m.m.) byts inte;
  storleken läses från väskans tooltip (raden "14 Slot Bag", mönstret byggs av
  `CONTAINER_SLOTS` om den finns, annars `(%d+) Slot`, alltså engelska). En grön pil visar
  väskor som är större än någon av ens väskor.
- ⚠️ Nyckelringen: med handkontroll (och `showKeyring` på) visar spelet nycklarna i
  väskfönstret, och då hamnar de i Keys. Med mus är nyckelringen en egen knapp vid
  väskknapparna, som Tidy Pack inte ändrar.
- ⚠️ Spelets inställning "Combined Bags" (CVar `combinedBags`) måste vara på med mus.
  Tidy Pack slår på den en gång vid första inloggningen. Stängs den av får man spelets
  vanliga, separata väskor.

## Så fungerar det (viktigt vid nya patchar)
Tidy Pack har inget eget fönster. Det ordnar om rutorna i spelets fönster
`ContainerFrameCombinedBags` och använder bara `hooksecurefunc`, aldrig överskrivna
funktioner:
- `UpdateFrameSize`: spelet har gett fönstret storlek efter sitt rutnät. Tidy Pack räknar
  bort spelets rutnät (`GetColumns`, `GetRows`, ruta 37 och avstånd 5) och får fram
  kanterna, titelraden och raden med pengar.
- `UpdateItemLayout` och `UpdateItems`: Tidy Pack går igenom rutorna
  (`EnumerateValidItems`), sorterar in dem i grupper, flyttar dem (fästa i
  `MoneyFrame`, som spelets eget rutnät) och sätter fönstrets storlek.
- `EventRegistry`-eventet `ContainerFrameItemButton.OnItemClicked` (sist i spelets klick på
  en ruta) används för väskbytet.
- Spelets delar som används: `ContainerFrameCombinedBags`, `MoneyFrame`, rutornas
  `UpgradeIcon` (som spelet inte använder i väskorna), `GamepadBagBar` och
  `BagItemAutoSortButton`.

Efter en patch: kontrollera att de här namnen finns kvar i grenen `forever`
(`Blizzard_UIPanels_Game/Mainline/ContainerFrame.lua` och `.xml`,
`Blizzard_MainMenuBarBagButtons/Camelot/`), och att rutans storlek (37) och avstånd (5)
är oförändrade.

## Sparad data
- `TidyPackDB` (per konto): `combinedBagsTurnedOn` (sant när Tidy Pack har slagit på
  "Combined Bags" en gång) och `dataVersion`
- Version 1: första versionen (2026-11-09).

## Idéer och önskemål
- Valt bort för att hålla addonet avskalat: banken, andra karaktärers väskor, egna grupper,
  flera utseenden, val av ordning, flytt till post och handel.

## Filer
- `TidyPack.toc`: namn och laddordning
- `Locales.lua`: all text som visas i spelet (engelska)
- `Core.lua`: sparad data, events och att "Combined Bags" slås på första gången
- `Categories.lua`: grupperna, vilken grupp en sak hör till och ordningen inom en grupp
- `BagSwap.lua`: byter ut den minsta väskan, och avgör vilka väskor som får en grön pil
- `Layout.lua`: ordnar om spelets väskfönster med grupper, rubriker, tomma platser, nivå och BoE
- `.design/sketch.html`: skissen av hur addonet ser ut (följer inte med till spelarna)

## Testlista
<!-- Det användaren ska prova i spelet efter varje större ändring. -->
1. Addonet syns och är aktiverat i addonlistan (knappen AddOns på karaktärsskärmen).
2. Första inloggningen: om "Combined Bags" var av kommer ett meddelande i chatten.
3. B öppnar spelets väskfönster med grupperna. Inga väskor syns bland sakerna, och
   kvastknappen syns inte.
4. Sakerna hamnar i rätt grupp (dryck, mat, utrustning, handelsvaror, uppdrag, skräp) och i
   rätt ordning inom gruppen.
5. Tomma platser: en ruta med antalet. Släpp en sak där.
6. Mus: högerklick använder och utrustar, dra och släpp flyttar, shift-klick länkar i chatten,
   shift-dra delar en hög.
7. Sökrutan tonar ner det som inte matchar.
8. Hos en handlare: högerklick säljer, och skräp får spelets mynt.
9. Väskbyte: med alla fyra väskplatser fulla och en större väska bland sakerna (grön pil):
   högerklick byter ut den minsta väskan och sakerna flyttas med. I strid kommer ett
   meddelande i stället.
10. Nivå och BoE syns på vapen och rustning.
11. Handkontroll: markören hoppar logiskt mellan grupperna, och Use, Equip, Sell och Split
    fungerar. Nycklarna syns i Keys.
12. I strid (t.ex. mot en träningsdocka): använd en dryck ur väskan, och se att fönstret
    uppdateras när du lootar.
13. Efter `/reload` ser allt likadant ut.

## Arbetssätt
- Kärnreglerna i pluginet wow-addon-skills gäller.
- Kör skillen `wow-check` efter varje större ändring.
- Testa i spelet med `/reload` efter varje ändring och `/console scriptErrors 1` påslaget.

## Publicering
- Status: inte publicerat

## Beslut
- 2026-11-08: Addon för WoW Forever som hanterar väskorna man bär med sig, med fokus på
  sortering. Baganator (licens All Rights Reserved) är inspiration: ingen kod kopieras,
  bara idéer om funktioner.
- 2026-11-08: Namn Tidy Pack (`TidyPack`), engelska i spelet. Spelet ska installeras på den
  här Macen och addonet länkas in i `AddOns`. Projektmapp i hemmappen.
- 2026-11-09: Bara den grupperade visningen, med fast ordning och inga val. Ingen
  inställningssida och inget slash-kommando. Pengar ska synas.
- 2026-11-09: Måste fungera med handkontroll. Därför ordnar Tidy Pack om spelets eget
  väskfönster i stället för att ha ett eget. Ett eget fönster kan inte få spelets knappar för
  handkontroll, eftersom att använda saker är skyddat och addons bara får koppla in egna
  fönster i handkontrollens styrning utanför strid. Fönstret ligger där spelet lägger det
  och går inte att flytta.
- 2026-11-09: Väskor ska vara lätta att byta men inte synas bland sakerna. Högerklick
  eller Equip på en större väska byter ut den minsta, och spelets väskrad för handkontroll
  döljs.
- 2026-11-09: Nivå och BoE på utrustning, som i Baganator. Reagenser
  (`Enum.ItemClass.Reagent`) räknas som Consumables.

## Källor
- WoW Forever: https://warcraft.wiki.gg/wiki/Patch_1.60.1
- Interface-nummer och TOC-suffix: https://warcraft.wiki.gg/wiki/TOC_format
- Blizzards kod för Forever: https://github.com/Gethe/wow-ui-source/tree/forever
- Byta väska som inte är tom: https://warcraft.wiki.gg/wiki/Bag
