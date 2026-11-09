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
- Projektmapp: `/Users/danhei1104/TidyPack`, med git (gren `main`, inget fjärrförråd).

## Funktioner
- ✅ Elva grupper i fast ordning: Favorites, New, Consumables, Equipment, Trade Goods,
  Quest Items, Keys, Bags, Miscellaneous, Junk, Empty. Inga sektioner eller linjer. Tomma
  grupper visas inte. Indelningen står i `Categories.lua`.
- ✅ Inom en grupp ligger lika saker bredvid varandra (drycker, mat, förband, skriftrullar;
  vapen, rustning, ammunition; handelsvaror, ädelstenar, förbättringar, recept), sedan
  bäst kvalitet, namn och störst hög. Små grupper delar rad. Fönstret är 12 rutor brett.
- ✅ Favorites (`Favorites.lua`): Alt-klick (mus) eller släpp saken på ★-knappen uppe
  till höger (mus och handkontroll). ★ är svag tills man håller en sak. Sparas per itemID
  och konto.
- ✅ New: saker som spelet markerar som nya hamnar överst tills fönstret stängs. Tidy Pack
  kommer ihåg dem själv, eftersom spelet tar bort markeringen när musen hålls över saken.
- ✅ Lås (`QuestLock.lua`): quest-saker, vanliga saker som en pågående quest kräver
  (namnet i målet, t.ex. "Linen Cloth: 3/10") och saker i utrustningsset. Låsikonen syns
  bara hos en handlare, och då är rutan avstängd (`Disable`), så att den inte kan säljas
  med mus eller handkontroll. Tooltipen får raden "Needed for: <quest>".
- ⚠️ Låsen: namnmatchningen följer spelets språk (engelska). Spelets egen knapp
  "Sell All Junk" i handlarfönstret känner inte till låsen.
- ⚠️ Sell Junk (`Junk.lua`): säker knapp ovanför väskfönstret när man handlar och det
  finns skräp. Säljer gråa saker utom låsta och stjärnmärkta, högst 12 per klick (Buyback
  rymmer 12), med spelets `/use väska plats`. Kan inte ändras i strid. Ligger utanför
  väskfönstret, så handkontrollens markör når den inte – med handkontroll används spelets
  "Sell All Junk".
- ✅ Junk-rubriken visar skräpets värde.
- ✅ Tomma platser: en ruta per väsktyp med antalet. Siffran blir röd vid 5 eller färre.
  När väskorna blir helt fulla visas "Your bags are full." en gång (`UIErrorsFrame`).
- ✅ Nivå och "BoE" bara på gröna och bättre vapen och rustningar.
- ✅ Handkontroll: fönstret och rutorna är spelets egna, så spelets markör och knappar
  (använd, utrusta, sälj, dela, förstör, länka) fungerar som vanligt. Måste provas i spelet.
- ✅ Sökruta, pengar och markering av nya saker är spelets egna.
- ✅ Väskorna man har på sig syns inte bland sakerna (`GamepadBagBar` döljs med
  handkontroll).
- ✅ Spelets städknapp (`BagItemAutoSortButton`) och spelets väskmeny (`PortraitButton`,
  klick på väskikonen) döljs. Utan menyn kan ingen råka stänga av "Combined Bags".
- ⚠️ Byta väska (`BagSwap.lua`): högerklick på en vanlig väska i gruppen Bags (eller
  Equip på handkontrollen) byter ut den minsta vanliga väskan när alla fyra platser är fulla.
  Bara utanför strid; specialväskor byts inte; storleken läses från tooltipen ("14 Slot
  Bag", mönster från `CONTAINER_SLOTS` eller `(%d+) Slot`). Grön pil på större väskor.
- ⚠️ Nyckelringen: med handkontroll (och `showKeyring` på) visar spelet nycklarna i
  väskfönstret, och då hamnar de i Keys. Med mus är nyckelringen en egen knapp vid
  väskknapparna, som Tidy Pack inte ändrar.
- ⚠️ "Combined Bags" (CVar `combinedBags`) slås på en gång vid första inloggningen.

## Så fungerar det (viktigt vid nya patchar)
Tidy Pack har inget eget väskfönster. Det ordnar om rutorna i spelets fönster
`ContainerFrameCombinedBags` och använder bara `hooksecurefunc` och `HookScript`, aldrig
överskrivna funktioner:
- `UpdateFrameSize`: spelet har gett fönstret storlek efter sitt rutnät. Tidy Pack räknar
  bort spelets rutnät (`GetColumns`, `GetRows`, ruta 37 och avstånd 5) och får fram
  kanterna, titelraden och raden med pengar.
- `UpdateItemLayout` och `UpdateItems`: Tidy Pack går igenom rutorna
  (`EnumerateValidItems`), sorterar in dem i grupper, flyttar dem (fästa i `MoneyFrame`,
  som spelets eget rutnät), sätter märken och lås och sätter fönstrets storlek.
- `SetSearchBoxPoint`: med handkontroll kortas sökrutan av så att ★-knappen får plats.
- `OnHide` (HookScript): gruppen New glöms och Sell Junk döljs.
- Rutornas `OnClick` (HookScript, en gång per ruta): Alt-klick stjärnmärker.
- `EventRegistry`-eventet `ContainerFrameItemButton.OnItemClicked` (sist i spelets klick på
  en ruta): väskbytet.
- `TooltipDataProcessor.AddTooltipPostCall` (typ Item): raden "Needed for".
- Sell Junk är en `SecureActionButtonTemplate` med typ `macro`, hängd i `UIParent` (en säker
  knapp i spelets väskfönster skulle skydda hela fönstret i strid). Den placeras utifrån
  väskfönstrets läge, bara utanför strid.
- Spelets delar som används: `ContainerFrameCombinedBags`, `MoneyFrame`, `PortraitButton`,
  rutornas `UpgradeIcon` (som spelet inte använder i väskorna), `GamepadBagBar`,
  `BagItemAutoSortButton`, `MerchantFrame` och atlasbilderna `auctionhouse-icon-favorite`
  och `LFG-lock`.

Efter en patch: kontrollera att de här namnen finns kvar i grenen `forever`
(`Blizzard_UIPanels_Game/Mainline/ContainerFrame.lua` och `.xml`,
`Blizzard_MainMenuBarBagButtons/Camelot/`, `Blizzard_FrameXML/SecureTemplates.lua`), och att
rutans storlek (37) och avstånd (5) är oförändrade.

## Sparad data
- `TidyPackDB` (per konto): `combinedBagsTurnedOn` (sant när Tidy Pack har slagit på
  "Combined Bags" en gång), `favorites` (itemID → true) och `dataVersion`
- Version 1: första versionen (2026-11-09). `favorites` lades till i 0.2.0 som en ny nyckel
  med standardvärde, så ingen migrering behövdes.

## Idéer och önskemål
- Möjliga senare: slå ihop högar av samma sak till en ruta, fälla ihop grupper, visa
  antalet pilar och kulor i rubriken.
- Valt bort för att hålla addonet avskalat: banken, andra karaktärers väskor, egna grupper,
  flera utseenden, val av ordning, flytt till post och handel, uppgraderingspilar på
  utrustning (nivån säger för lite i Forevers föremål).
- Går inte: sälja eller öppna saker automatiskt (spelet kräver ett klick på en säker knapp).

## Filer
- `TidyPack.toc`: namn och laddordning
- `Locales.lua`: all text som visas i spelet (engelska)
- `Core.lua`: sparad data, events och att "Combined Bags" slås på första gången
- `Categories.lua`: grupperna, vilken grupp en sak hör till och ordningen inom en grupp
- `QuestLock.lua`: vilka saker som är låsta (quest och utrustningsset), handlarläget och
  raden i tooltipen
- `BagSwap.lua`: byter ut den minsta väskan, och avgör vilka väskor som får en grön pil
- `Layout.lua`: ordnar om spelets väskfönster: grupper, rubriker, New, märken, lås, tomma
  platser, varningen för fulla väskor och att städknappen och väskmenyn döljs
- `Favorites.lua`: stjärnmärkning med Alt-klick och ★-knappen
- `Junk.lua`: knappen Sell Junk
- `CHANGELOG.md`: ändringarna, på engelska, för spelare
- `.design/sketch.html`: skissen av hur addonet ser ut (följer inte med till spelarna)

## Testlista
<!-- Det användaren ska prova i spelet efter varje större ändring. -->
1. Addonet syns och är aktiverat i addonlistan (knappen AddOns på karaktärsskärmen).
2. Första inloggningen: om "Combined Bags" var av kommer ett meddelande i chatten.
3. B öppnar spelets väskfönster med grupperna. Inga väskor syns bland sakerna. Kvastknappen
   syns inte, och klick på väskikonen uppe till vänster öppnar ingen meny.
4. Sakerna hamnar i rätt grupp och ligger i rätt ordning (drycker före mat, vapen före
   rustning).
5. New: loota något, öppna väskan – saken ligger i New även när musen hålls över den, och
   flyttar till sin grupp när fönstret stängs och öppnas igen.
6. Favorites: Alt-klicka på Hearthstone (hamnar överst), Alt-klicka igen (tillbaka). Plocka
   upp en sak, se att ★ lyser upp, och släpp den på ★. Kvar efter `/reload`.
7. Tomma platser: en ruta med antalet, röd vid 5 eller färre. Släpp en sak där. Fyll
   väskorna: "Your bags are full." visas en gång.
8. Mus: högerklick använder och utrustar, dra och släpp flyttar, shift-klick länkar i chatten,
   shift-dra delar en hög.
9. Sökrutan tonar ner det som inte matchar.
10. Hos en handlare: låsta saker har ett lås och går inte att klicka på (quest-sak, en vanlig
    sak som en quest kräver, en sak i ett utrustningsset). Tooltipen visar "Needed for".
    Sell Junk syns ovanför fönstret med skräpets värde, säljer högst 12 per klick och aldrig
    låsta eller stjärnmärkta saker. Allt går att köpa tillbaka.
11. Väskbyte: med alla fyra väskplatser fulla och en större väska bland sakerna (grön pil):
    högerklick byter ut den minsta väskan och sakerna flyttas med. I strid kommer ett
    meddelande i stället.
12. Nivå och BoE syns bara på gröna och bättre vapen och rustningar.
13. Handkontroll: markören hoppar logiskt mellan grupperna och till ★, och Use, Equip,
    Sell och Split fungerar. Plocka upp en sak och lägg den på ★. Hos en handlare går låsta
    saker inte att sälja. Nycklarna syns i Keys.
14. I strid (t.ex. mot en träningsdocka): använd en dryck ur väskan, och se att fönstret
    uppdateras när du lootar.
15. Efter `/reload` ser allt likadant ut.

## Arbetssätt
- Kärnreglerna i pluginet wow-addon-skills gäller.
- Kör skillen `wow-check` efter varje större ändring.
- Testa i spelet med `/reload` efter varje ändring och `/console scriptErrors 1` påslaget.
- Skriv ändringar i `CHANGELOG.md` under `## Unreleased` och committa med git.

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
- 2026-11-09: Git i projektmappen, en commit per ändring.
- 2026-11-09 (0.2.0): Stjärnmärkning (Alt-klick och ★-knapp), questlås som spärrar hos
  handlaren, egen Sell Junk-knapp (12 per klick), gruppen New, skräpets värde, varning för
  fulla väskor och skydd för utrustningsset.
- 2026-11-09 (0.2.0): Så rent som möjligt: elva grupper utan sektioner och linjer, lås bara
  hos handlaren, nivå och BoE bara på gröna och bättre, Sell Junk bara när det finns skräp,
  svag ★-knapp, och spelets väskmeny borttagen.

## Källor
- WoW Forever: https://warcraft.wiki.gg/wiki/Patch_1.60.1
- Interface-nummer och TOC-suffix: https://warcraft.wiki.gg/wiki/TOC_format
- Blizzards kod för Forever: https://github.com/Gethe/wow-ui-source/tree/forever
- Byta väska som inte är tom: https://warcraft.wiki.gg/wiki/Bag
- Att använda saker är skyddat: https://warcraft.wiki.gg/wiki/API_C_Container.UseContainerItem
- Alt-klick räknas som modifierat klick: https://warcraft.wiki.gg/wiki/API_IsModifiedClick
