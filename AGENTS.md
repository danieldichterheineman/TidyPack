# Tidy Pack

Ordnar sakerna i spelets väskfönster i fasta grupper, som Baganator men med bara några få
inställningar.
Bara väskorna som karaktären bär med sig. Fungerar med mus och handkontroll.

## Fakta
- Addonnamn och mapp: `TidyPack` (måste matcha `TidyPack.toc`)
- Målklient: WoW Forever 1.60.1, Interface 16001. Källor: installationens `.build.info`
  (version `1.60.1.70862`, produkt `wowf`, 2026-11-09), sidan "TOC format" på
  warcraft.wiki.gg och commit-meddelandet `1.60.1 (70862)` i GitHub-repot
  `Gethe/wow-ui-source`, gren `forever`. I spelet: `/dump select(4, GetBuildInfo())`.
- Spelet: `/Applications/World of Warcraft/_forever_/` (engelsk klient, EU). Projektmappen är
  länkad in som `_forever_/Interface/AddOns/TidyPack` (symbolisk länk, 2026-11-09), så
  ändringar syns efter `/reload`. En ny eller omdöpt TOC-fil kräver omstart av spelet.
- WoW Forever bygger på samma klient som retail (TOC-familjen `_Mainline`, Blizzards kodnamn
  "Camelot"). Blizzards kod för Forever finns i grenen `forever` i `Gethe/wow-ui-source`.
  Mappar som heter `Camelot` där är Forevers egna ändringar. Verifiera API:er mot den grenen,
  inte mot `live`.
- SavedVariables: `TidyPackDB` (per konto)
- Inställningssida i spelets Options → AddOns → Tidy Pack, med en egen sida för
  skräplistan (`Options.lua`). Öppnas också med `/tidypack`, från addonmenyn vid minikartan
  (`## AddonCompartmentFunc: TidyPack_OnAddonCompartmentClick`) och från kugghjulet (se Beslut).
- Projektmapp: `/Users/danhei1104/TidyPack`, med git (gren `main`).
- GitHub: https://github.com/danieldichterheineman/TidyPack (privat, skapat 2026-11-09).
  Pusha bara efter ett ja från användaren.

## Funktioner
- ✅ Elva grupper i fast ordning: Favorites, Empty ("Add to bag"), New, Consumables, Equipment,
  Trade Goods, Quest Items, Keys, Bags, Miscellaneous, Junk. Tomma grupper visas inte.
  Indelningen står i `Categories.lua`. Mer luft mot ramen än spelets rutnät (se Layout.lua; ursprungligen 6 enheter på
  var sida, 4 under sökrutan, 9 ovanför pengarna).
- ✅ Specialväskor (`Layout.lua`): koger, ammunitionspåsar, själsväskor, yrkesväskor
  (`bagFamily` ≠ 0) och reagensväskan får varsin grupp längst ned, under spelets linje
  `bank-divider` (från Forevers bankfönster), med väskans ikon och namn som rubrik. Allt i
  väskan stannar i dess grupp, och dess tomma platser räknas där, inte i Empty. Visas bara
  när en sådan väska sitter på plats. Med mus visar spelet reagensväskan i ett eget fönster.
- ✅ Egna set (`Sets.lua`, `SetsView.lua`), per karaktär, sköts i fliken Sets ovanför
  fönstret (spelets `PanelTopTabButtonTemplate`, flikarna Bags och Sets). En rad per set:
  ikon, namn, sakerna som små rutor (grå = saknas) och till höger "Equipped", "⚠ N
  missing", antal eller "Drop items here". Klick tar på allt som går att ha på sig
  (`C_Item.EquipItemByName`, ringar, smycken och enhandsvapen på båda platserna). Släpp en
  sak på en rad = lägg till. Ett kugghjul på varje rad (och högerklick) öppnar setets
  meny: "Add What I'm Wearing" (allt du har på dig utom skjorta och tabard), "Edit Name and
  Icon…", "Remove Item ▸" och "Delete Set…". "New Set" står på sökrutans plats, och mitt i
  fönstret med en förklaring när det inte finns några set (en sak på markören hamnar i det
  nya setet). Håller man en sak över fliken Sets byter fönstret dit. Kugghjulets "Add to Set"
  finns kvar. Saker i set är låsta hos handlaren och tooltipen visar "Tidy Pack set: …".
  Fönstret öppnas alltid på Bags.
- ⚠️ Set tas bara på utanför strid (spelet låter ingen byta rustning i strid). Flikarna
  och raderna med handkontroll är inte provade; kugghjulets meny har "Show Sets"/"Show
  Bags" som reserv, bara med handkontroll.
- ✅ Hel bakgrund bakom sakerna (`inset` i `Layout.lua`, spelets `InsetFrameTemplate` med
  marmorn tonad till 0,7), så att världen och questlistan inte lyser igenom när de tomma
  rutorna döljs. Provat i spelet 2026-11-10 (1.0.1-testet): fungerar, men var nästan svart
  (0,4) och sakerna låg bara 4 enheter från bakgrundens kant. Nu: 12 enheters luft innanför
  bakgrunden (`INSET_PAD`, `PADDING_SIDE` 14, `PADDING_TOP` 16, `MONEY_GAP` 16) och färgen
  0,7. Inte provat i spelet.
- ✅ Antal kolumner (`chooseColumns`, `flow` i `Layout.lua`): 14 som standard och upp till 20
  när sakerna annars skulle göra fönstret högre än skärmen. Skälet: spelet krymper
  väskfönstret till högst 75 % (`GetContainerScale`, `CONTAINER_SCALE` i
  `Blizzard_UIPanels_Game/Mainline/ContainerFrame.lua`, nedre marginal `CONTAINER_OFFSET_Y`
  85) men räknar bara om skalan när fönstret öppnas. Tidy Pack siktar på skala 0,85
  (`TARGET_SCALE`). Egen uträkning (inte provad i spelet, 36 platser antagen som största
  väska, skärmhöjd 768): med 12 kolumner blev 160 fyllda platser ca 1050 enheter höga och
  fick inte plats ens vid 75 %; med 20 kolumner ca 770. Bredden begränsas till 75 % av
  skärmen. 14 kolumner gör också att grupper med 13 saker får plats på en rad.
- ✅ Fönstret är lika högt i fliken Sets som i Bags (`bagsContentHeight`), och växer bara om
  setlistan är längre. Med 1–3 set förklarar en hjälptext hur man lägger till saker
  (`hintText` i `SetsView.lua`).
- ✅ Lediga platser i väskikonen uppe till vänster, som spelet visar med handkontroll
  (`CountContainer.Count`; spelet visar den bara då): `updatePortraitCount` visar den också
  med mus. Rutan för lediga platser (gruppen Empty) är kvar som släppplats för saker, med
  handkontroll den enda, eftersom spelets väskknappar döljs. Den heter "Add to bag" (före
  2026-11-10 "Free", längst ned), står näst först och delar översta raden med Favorites,
  har ett + mitt i rutan (som den tomma rutan i fliken Sets), antalet lediga platser nere
  till höger och en tooltip ("Free slots: N / Drop an item here to put it in your bags").
  Handkontrollens markör börjar på första riktiga sak (`startGroupIndex`), inte på rutan.
  Inte provat i spelet.
- ✅ Quest-saker (`QuestLock.lua`, `Layout.lua`, `QuestsView.lua`, `SetsView.lua`, byggt 2026-11-10 efter
  skissen `.design/sketch-quests-tab.html`): (1) varje quest-sak på en vanlig ruta visar antal man har /
  antal som behövs ("3/7", grönt när det räcker) uppe till vänster (questloggens `numFulfilled` och
  `numRequired`; `entry.questRecord`, `extra.quest` i `Layout.lua`), och tooltipen säger "Needed for: <quest>
  (3/7)" och "And N more quests". (2) `ns.UpdateQuestStacks`: har du flera högar av samma sak räknas de
  största tills antalet räcker som quest-saker, resten (över) är vanliga saker och går att sälja; en ensam
  hög är alltid kvar hel och spelets egna quest-saker rörs aldrig. (3) Tredje fliken Quests
  (`ns.BuildQuestsView`, avsnitt och quests fälls ut för sig): klara quests överst ("Ready to turn in", `C_QuestLog.ReadyForTurnIn`), sedan de som
  pågår, med de riktiga rutorna, namn, antal och en stapel, och tom ruta med grå text för det som saknas;
  "Other quest items" sist; högst så många quests som ryms (`maxContentHeight`), resten som "...and N more
  quests". Samma rutor flyttas mellan flikarna. En grön/blå prick på fliken (`ns.UpdateQuestsNotice`) när en
  quest är klar. (4) Inställningen `showQuestItemsInBags` ("Show quest items in Bags", påslagen): avstängd
  ersätts gruppen Quest Items i Bags av en rad "N slots hold quest items – see Quests" (`questNote`) som
  öppnar fliken. Inte provat i spelet.
- ✅ Egna grupper (`Groups.lua`, `GroupsPage.lua`, byggda 2026-11-10 efter skissen
  `.design/sketch-groups.html`): upp till 8 per konto, efter Favorites och "Add to bag". En sak
  läggs dit med kugghjulets meny ("Add to Group ▸", med en bockruta per grupp och "New
  Group...") eller en hel typ ("Add all "<typ>" items to Group ▸": klass och undertyp ur
  `C_Item.GetItemInfoInstant`, typens namn ur `C_Item.GetItemSubClassInfo`). En sak eller
  typ ligger i högst en grupp (en bockruta flyttar den). Företräde i `ns.GetGroup`: Favorites,
  New, Quest Items och Junk först, sedan de egna grupperna (enskild sak före typregel, sedan
  den grupp som står högst), sedan spelets typer. Sidan "Groups" i inställningarna: välj en
  grupp, ändra ordning (▲▼), byt namn, ta bort, och se och ändra vad den innehåller (länk,
  namn, nummer eller släpp en sak). Tooltipen visar "Tidy Pack group: …". Rubrikerna kommer ur
  `ns.groupNames`, ordningen ur `ns.groupOrder`, som `ns.RebuildGroupOrder` bygger om. Inte
  provat i spelet.
- ✅ Inom en grupp ligger lika saker bredvid varandra (drycker, mat, förband, skriftrullar;
  vapen, rustning, ammunition; handelsvaror, ädelstenar, förbättringar, recept), sedan
  bäst kvalitet, namn och störst hög. Små grupper delar rad. Fönstret är 14 rutor brett, och bredare (upp till 20) när sakerna annars skulle bli för höga.
- ✅ Kugghjulet (`Marks.lua`) är den enda knapp Tidy Pack lägger i väskfönstret, på
  sorteringsknappens plats. Det är spelets egen menyknapp (`DropdownButton`): med en sak på
  markören (släppt eller klickad) öppnas "Add to Favorites" / "Add to Junk List" /
  "Add to Set ▸", annars "Junk List…" / "Settings…" (med handkontroll också "Show Sets"
  eller "Show Bags"). Svagt tills man håller en sak, pekar på det eller har menyn öppen.
- ✅ Favorites (`Marks.lua`): Alt-klick (mus, öppnar menyn för saken) eller via kugghjulet. Sparas per itemID och konto.
- ✅ Skräplistan (`Marks.lua`, `Options.lua`): Alt-klick-menyn, via kugghjulet eller på skräplistans
  sida i inställningarna (lägg till med länk, namn, nummer eller genom att släppa en sak;
  ta bort med det röda krysset). Saker på listan hamnar sist i Junk, får spelets eget
  skräpmynt (`JunkIcon` på rutan) och föreslås först när väskorna är fulla. En sak kan inte vara både favorit och på listan. Sparas per itemID och konto.
- ⚠️ Frågor om radering (`MakeRoom.lua`), i en panel med samma mall som lootfönstret
  (`DefaultPanelFlatTemplate`): (1) när en sak från skräplistan lootas (antalet ökar,
  `C_Item.GetItemCount` vid `BAG_UPDATE_DELAYED`) frågar Tidy Pack direkt, (2) när loot
  misslyckas med `ERR_INV_FULL` föreslås skräplistan först, annars den billigaste grå saken
  om det nya är värt mer. Panelen hänger under lootfönstret (220 bred) eller syns uppe i
  mitten (260 bred, `TOP -135`). Raderas bara när spelaren trycker Delete
  (`DeleteCursorItem` kräver en hårdvaruhändelse och tar en sak per tryck). I strid väntar
  frågorna om skräplistan. Med handkontroll: under lootfönstret kopplas knapparna in i
  lootfönstrets markör, uppe i mitten blir panelen en fråga
  (`GamepadMode.FrameControlsManager:HandlePopupShown`), bara utanför strid. Måste provas i
  spelet, särskilt med handkontroll.
- ✅ Inställningar (`Options.lua`), allt påslaget från början: fråga när skräp lootas,
  förslag vid fulla väskor, lås för quest- och set-saker hos handlaren, quests i förväg (går inte att ändra utan
  Questie, och rubriken säger om Questie finns), nivå och BoE.
- ⚠️ Quests i förväg (`QuestHints.lua`): kräver Questie (QuestieDB, `## OptionalDeps`).
  Saker som behövs för quests man inte har gjort, för ens ras och klass, som man kan ta nu
  eller inom 5 nivåer (och som inte är mer än 5 nivåer under en), får kartans gula
  utropstecken (atlas `QuestNormal`) uppe till höger och raden "Needed later for: <quest>
  (<zon>, level N)" i tooltipen (högst 3, sedan "...and N more quests"). Grå sådana saker
  säljs och föreslås aldrig. Utan Questie skrivs en rad i chatten, en gång per konto.
  QuestieDB:s data för Forevers nya quests är inte komplett.
- ✅ New: saker som spelet markerar som nya hamnar överst tills fönstret stängs. Tidy Pack
  kommer ihåg dem själv, eftersom spelet tar bort markeringen när musen hålls över saken.
- ✅ Lås (`QuestLock.lua`): quest-saker, vanliga saker som en pågående quest kräver
  (namnet i målet, t.ex. "Linen Cloth: 3/10") och saker i utrustningsset. Låsikonen syns
  bara hos en handlare. Med mus är rutan då avstängd (`Disable`). Med handkontroll får
  markören inte klicka på den (`SmartNavigation_MarkFrameBlockingSmartNavClick`), så att
  varken A eller X gör något (se Beslut 2026-11-09 om handkontrollen). Tooltipen visas ändå
  (`SetMotionScriptsWhileDisabled`) och får raden "Needed for: <quest>" och hos handlaren
  en röd rad "Locked by Tidy Pack: can't be sold."
- ⚠️ Låsen: namnmatchningen följer spelets språk (engelska). Spelets egen knapp
  "Sell All Junk" i handlarfönstret känner inte till låsen. Med handkontroll kan låset inte
  sättas eller släppas i strid; det görs när striden är över.
- ⚠️ Ingen egen Sell Junk-knapp (togs bort 2026-11-09, användarens beslut): spelets egen
  "Sell All Junk" (`MerchantSellAllJunkButton`) i handlarfönstret säljer alla grå saker, och
  går att nå med handkontroll. Den känner inte till Tidy Packs lås eller skräplista, så saker
  på skräplistan som inte är grå säljs för hand. `Junk.lua` har bara `ns.GetJunkKind` kvar.
- ✅ Junk-rubriken visar skräpets värde.
- ✅ Tomma platser: en ruta per väsktyp med antalet. Siffran blir röd vid 5 eller färre.
  När väskorna blir helt fulla visas "Your bags are full." en gång (`UIErrorsFrame`).
- ✅ Nivå och "BoE" bara på gröna och bättre vapen och rustningar.
- ✅ Handkontroll: fönstret och rutorna är spelets egna, så spelets markör och knappar
  (använd, utrusta, sälj, dela, förstör, länka) fungerar som vanligt. Måste provas i spelet.
- ⚠️ Handkontrollens markör (`Gamepad.lua`): börjar på första saken i New (annars första
  rutan), LB/RB hoppar till förra/nästa grupp, styrkorset går till närmaste ruta åt det
  hållet (spelets fria navigering i stället för rutnätet), och står markören på en ruta som
  döljs flyttas den till närmaste synliga. Begränsningar: inget av det kan göras i strid
  (görs när striden är över), och LB/RB bygger på spelets väskräkning – med nyckelringen
  påslagen gör LB inget på saker i ryggsäcken och RB inget på nycklar, som i spelets fönster.
- ✅ kugghjulets tooltip visar handkontrollens knapp A med handkontroll, och Alt-klick med mus.
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
- `SetSearchBoxPoint`: med handkontroll kortas sökrutan av så att kugghjulet får plats.
- `OnHide` (HookScript): gruppen New glöms.
- Rutornas `OnClick` (HookScript, en gång per ruta): Alt-klick (vänster) öppnar menyn för saken vid rutan
  (`MenuUtil.CreateContextMenu`, samma meny som kugghjulet har med en sak på markören). Alt-högerklick gör
  inget (spelet använder saken). Medan Alt hålls ner (`MODIFIER_STATE_CHANGED`) visas märket "..." på
  varje sak; tooltipen har raden "Alt-click: Tidy Pack options"; kugghjulet visar "Drop here for options" när
  du håller en sak; en tipsrad längst ner i Bags visas de 5 första gångerna fönstret öppnas
  (`itemTip = { opens, dismissed }`) tills den stängs eller du Alt-klickar.
- `EventRegistry`-eventet `ContainerFrameItemButton.OnItemClicked` (sist i spelets klick på
  en ruta): väskbytet.
- `TooltipDataProcessor.AddTooltipPostCall` (typ Item): raden "Needed for" och den röda
  raden på låsta saker hos en handlare (tooltipens ägare är en låst ruta).
- Handkontrollens markör (`Gamepad.lua`), som är spelets `SmartNavigation`:
  - `hooksecurefunc(SmartNavigation, "SetUseGridNavigation")`: spelet slår på sitt rutnät
    för väskfönstret (i `SmartNavPanelInfoAdded`). Tidy Pack slår av det en bildruta senare
    med `SmartNavigation:SetUseGridNavigation(bagFrame, false)`.
  - `hooksecurefunc(SmartNavigation, "SelectButton")`: hamnar markören på en dold ruta i
    väskfönstret flyttar Tidy Pack den en bildruta senare med
    `SmartNavigation:SetTargetButtonForFrame(bagFrame, ruta)`. En dold väskknapp efter en
    synlig sak betyder LB/RB (`Gamepad_SetCursorToBag` väljer väskan före eller efter).
  - Efter varje utläggning kontrolleras om markören står på en ruta som just dolts.
  - Spelet tillåter addons att anropa `SetUseGridNavigation`, `SetTargetButtonForFrame` och
    `SmartNavigation_*` utanför strid (de går via `SecureHelper`). I strid väntar Tidy Pack
    på `ADDON_RESTRICTION_STATE_CHANGED` eller `PLAYER_REGEN_ENABLED`.
- Panelen för frågorna (`MakeRoom.lua`, namn `TidyPackMakeRoomPanel`) använder samma mall
  som lootfönstret (`DefaultPanelFlatTemplate`, rubrik med `SetTitle`, knappar med
  `UIPanelButtonTemplate`). Den flyttas mellan `LootFrame` (TOP mot lootfönstrets BOTTOM,
  -2) och `UIParent` (TOP, -135, strata DIALOG). Den reagerar på `UI_ERROR_MESSAGE` med
  `ERR_INV_FULL`, `BAG_UPDATE_DELAYED` (antalet av sakerna på skräplistan med
  `C_Item.GetItemCount`), `LOOT_CLOSED`, `PLAYER_ENTERING_WORLD` och `PLAYER_REGEN_ENABLED`,
  läser lootet med `GetNumLootItems`, `GetLootSlotType`, `GetLootSlotLink` och
  `GetLootSlotInfo`, och raderar i knappens klick med `C_Container.PickupContainerItem` och
  `DeleteCursorItem`. Med handkontroll: `SmartNavigation:RefreshButtonGroups(LootFrame)`
  under lootfönstret, `GamepadMode.FrameControlsManager:HandlePopupShown/HandlePopupHide`
  uppe i mitten.
- Kugghjulet (`Marks.lua`) är `CreateFrame("DropdownButton")` med `SetupMenu`, `SetMenuAnchor`
  (`CreateAnchor`) och `OpenMenu` vid `OnReceiveDrag`. Menyn byggs med
  `rootDescription:CreateTitle` och `CreateButton`.
- Inställningarna (`Options.lua`): `Settings.RegisterVerticalLayoutCategory`,
  `Settings.RegisterAddOnSetting`, `Settings.CreateCheckbox` (med `SetValueChangedCallback`
  och `AddModifyPredicate`), `CreateSettingsListSectionHeaderInitializer`,
  `CreateSettingsButtonInitializer`, `Settings.RegisterCanvasLayoutSubcategory`,
  `Settings.RegisterAddOnCategory` och `Settings.OpenToCategory`. Skräplistans sida:
  `WowScrollBoxList`, `MinimalScrollBar`, `CreateScrollBoxListLinearView`,
  `ScrollUtil.InitScrollBoxListWithScrollBar`, `CreateDataProvider`, `InputBoxTemplate`,
  atlas `RedButton-Exit` och `hooksecurefunc(ChatFrameUtil, "InsertLink")` för
  shift-klickade länkar.
- Questie (`QuestHints.lua`): `LibQuestieDB.RequireContract(3)`,
  `LibQuestieDB.Item.Get(id, "relatedQuests")`, `LibQuestieDB.Quest.GetAll` (målen i grupp 3,
  `requiredSourceItems`, `requiredLevel`, `questLevel`, `requiredRaces`, `requiredClasses`,
  `name`, `zoneOrSort`) och `LibQuestieDB.Enum.raceMaskById`. Klassens bit är 2^(klass − 1).
  Zonens namn kommer från `C_Map.GetAreaInfo`. Anropen ligger i `pcall`, så att ett fel i
  QuestieDB inte stoppar Tidy Pack.
- Rutornas `JunkIcon` (spelets skräpmynt) visas även på markerat skräp. Villkoret innehåller
  spelets eget (`UpdateJunkItem`: grått, säljbart och hos en handlare).
- Spelets delar som används: `ContainerFrameCombinedBags`, `MoneyFrame`, `PortraitButton`,
  rutornas `UpgradeIcon` och `JunkIcon`, `GamepadBagBar`, `BagItemAutoSortButton`,
  `MerchantFrame`, `LootFrame`, `SmartNavigation`, `STARTING_BAG_INDEX`, `ENDING_BAG_INDEX`,
  `InputIconTextureSetUtility`, `ERR_INV_FULL`, mallarna `DefaultPanelFlatTemplate` och
  `UIPanelButtonTemplate`, och atlasbilderna `auctionhouse-icon-favorite`, `bags-junkcoin`,
  `QuestNormal` och `LFG-lock`.

Efter en patch: kontrollera att de här namnen finns kvar i grenen `forever`
(`Blizzard_UIPanels_Game/Mainline/ContainerFrame.lua` och `.xml`,
`Blizzard_MainMenuBarBagButtons/Camelot/`, `Blizzard_FrameXML/SecureTemplates.lua`,
`Blizzard_GamepadSmartNavigation/SmartNavigation.lua`, `Utility.lua` och `SecureHelper.lua`,
`Blizzard_UIPanels_Game/Mainline/LootFrame.lua` och `.xml`,
`Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.xml`), att väskfönstrets
`SmartNavPanelInfoAdded` och `Gamepad_SetCursorToBag` fungerar som förut, att rutans storlek
(37) och avstånd (5) är oförändrade, och att QuestieDB fortfarande klarar kontrakt 3.

## Sparad data
- `TidyPackDB` (per konto): `combinedBagsTurnedOn` (sant när Tidy Pack har slagit på
  "Combined Bags" en gång), `favorites` (itemID → true), `junk` (skräplistan, itemID →
  true), `questieNoticeShown` (sant när raden om Questie har visats), inställningarna
  `suggestOnLoot`, `suggestWhenFull`, `lockAtMerchant`, `showQuestItemsInBags`, `questHints` och `itemLevelAndBoE`
  (alla sanna från början), `groups` (egna grupper, ny 2026-11-10: lista med
  `{ id, name, items = { [itemID] = true }, types = { ["klass:undertyp"] = true } }` i visningsordning)
  och `nextGroupID`, och `dataVersion`. De nya nycklarna har standardvärden, så ingen migrering behövdes.
- `TidyPackCharDB` (per karaktär, ny 2026-11-09): `sets` = lista med
  `{ name = "...", items = { itemID, ... } }` i den ordning seten skapades. Kräver omstart
  av spelet första gången, eftersom TOC-filen fick en ny rad.
- Version 2 (2026-11-10): `sellJunkButton` tas bort ur sparad data (knappen finns inte längre).
- Version 1: första versionen (2026-11-09). Allt utom `combinedBagsTurnedOn` lades till som
  nya nycklar med standardvärden, så ingen migrering behövdes.

## Idéer och önskemål
- Quest-saker är byggda (2026-11-10, se Funktioner; planen A + fliken Quests). Kompisens förslag (2026-11-10): visa vilken
  quest en sak hör till och antal (3/7), och bara låsa det som behövs. Skiss med tre sätt i
  `.design/sketch-quests.html` (och `.png`): A antal på ikonen och i tooltipen (rekommenderas
  först), B en grupp med rubrik per quest, C en flik "Quests". Planen: A, sedan C som en översikt, med Quest Items kvar i väskan (B behövs troligen inte); skiss i `.design/sketch-quests-tab.html` (och `.png`): klara quests överst, grön prick på fliken, och ett valfritt val "Show quest items in the Bags tab" (påslaget från början; avstängt ersätts gruppen av en rad "N slots hold quest items – see Quests"). Samma rutor flyttas mellan flikarna, aldrig i båda samtidigt. Spelet ger `numFulfilled` och
  `numRequired` per mål (`C_QuestLog.GetQuestObjectives`, kontrollerat i forever). En hög är en
  ruta och kan inte delas i visningen, men överblivna högar kan bli säljbara. Väntar på ett ja till planen.
- Nästa efter första testet: introduktion med sex korta tips i spelets tipsruta (välkommen,
  stjärnan, LB/RB, låsta saker, större väska), ett i taget och en gång per konto.
  Med handkontroll utan knapp och med kontrollens knappsymboler. Se skissen.
- Möjliga senare: slå ihop högar av samma sak till en ruta, fälla ihop grupper, visa
  antalet pilar och kulor i rubriken.
- Valt bort för att hålla addonet avskalat: banken, andra karaktärers väskor, egna grupper
  (egna set finns i stället, i en egen flik),
  flera utseenden, val av ordning, flytt till post och handel, uppgraderingspilar på
  utrustning (nivån säger för lite i Forevers föremål).
- Går inte: sälja eller öppna saker automatiskt (spelet kräver ett klick på en säker knapp).

## Filer
- `TidyPack.toc`: namn och laddordning
- `Bindings.xml`: snabbtangenterna (spelet läser den själv)
- `Locales.lua`: all text som visas i spelet (engelska)
- `Core.lua`: sparad data, events och att "Combined Bags" slås på första gången
- `Categories.lua`: grupperna, vilken grupp en sak hör till och ordningen inom en grupp
- `LogoButton.lua`: loggan i stället för spelets väskrad nere till höger
- `Media/Logo.tga`: loggan som spelbild
- `Tour.lua`: guiden med spelets tipsrutor första gången väskan öppnas
- `QuestsView.lua`: fliken Quests – rubriker, texter, staplar och rader per quest
- `Groups.lua`: egna grupper – data, regler, ordning, frågor, kugghjulets menyer och tooltipen
- `GroupsPage.lua`: sidan "Groups" i inställningarna
- `QuestLock.lua`: vilka saker som är låsta (quest, utrustningsset och egna set),
  handlarläget och raden i tooltipen
- `Sets.lua`: egna set – data, ta på ett set, rutan för namn och frågor, raden i tooltipen
- `BagSwap.lua`: byter ut den minsta väskan, och avgör vilka väskor som får en grön pil
- `Layout.lua`: ordnar om spelets väskfönster: grupper, specialväskor, rubriker, New,
  märken, lås, tomma platser, listläget för fliken Sets, varningen för fulla väskor och att städknappen och väskmenyn döljs
- `SetsView.lua`: flikarna Bags och Sets och listan med set i väskfönstret
- `QuestHints.lua`: saker som quests man inte har tagit än behöver, via Questies databas
- `Marks.lua`: favoriter och skräplistan, med Alt-klick och kugghjulet med spelets meny (hette
  `Favorites.lua` före 2026-11-09)
- `Junk.lua`: vad som räknas som skräp (`ns.GetJunkKind`)
- `MakeRoom.lua`: frågorna om radering, när skräp lootas och när väskorna är fulla
- `Options.lua`: inställningssidan, skräplistans sida, `/tidypack` och addonmenyn
- `Gamepad.lua`: handkontrollens markör (start, LB/RB, fri navigering, dolda rutor), låsen
  för markören och knappsymboler i text
- `CHANGELOG.md`: ändringarna, på engelska, för spelare
- `.design/sketch.html`: skissen av hur addonet ser ut, med förslaget på introduktion
  (följer inte med till spelarna)

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
6. Favorites: håll Alt ("..." syns på sakerna), Alt-klicka på Hearthstone och välj Add to Favorites (hamnar överst), gör om och välj Remove from Favorites (tillbaka). Tipsraden längst ner i Bags syns de första 5 gångerna och försvinner med x. Plocka
   upp en sak, se att kugghjulet lyser upp, och släpp den på kugghjulet. Kvar efter `/reload`.
7. Tomma platser: en ruta med antalet, röd vid 5 eller färre. Släpp en sak där. Fyll
   väskorna: "Your bags are full." visas en gång.
8. Mus: högerklick använder och utrustar, dra och släpp flyttar, shift-klick länkar i chatten,
   shift-dra delar en hög.
9. Sökrutan tonar ner det som inte matchar.
10. Hos en handlare: låsta saker har ett lås och går inte att klicka på (quest-sak, en vanlig
    sak som en quest kräver, en sak i ett utrustningsset). Tooltipen visas ändå, med
    "Needed for" och den röda raden "Locked by Tidy Pack: can't be sold." Spelets egen
    "Sell All Junk" säljer alla grå saker och känner inte till låsen. Inställningen "Lock
    quest and set items" (Esc → Options → AddOns → Tidy Pack) slår av och på låsen.
11. Väskbyte: med alla fyra väskplatser fulla och en större väska bland sakerna (grön pil):
    högerklick byter ut den minsta väskan och sakerna flyttas med. I strid kommer ett
    meddelande i stället.
12. Nivå och BoE syns bara på gröna och bättre vapen och rustningar.
13. Handkontroll, utanför strid:
    - Loota något och öppna väskan: markören står på saken i New. Utan nya saker står den
      på första rutan – aldrig på en tom plats eller utanför rutorna.
    - LB och RB hoppar till förra och nästa grupp. (Med nyckelringen påslagen gör LB inget
      på saker i ryggsäcken, precis som utan Tidy Pack.)
    - Styrkorset går till rutan närmast åt det håll du trycker, även mellan grupper som
      delar rad. Uppåt från översta raden längst till höger når kugghjulet.
    - Use, Equip, Sell och Split fungerar. Sälj en sak med X: markören hamnar på saken som
      tar dess plats.
    - Plocka upp en sak med A och lägg den på kugghjulet. kugghjulets tooltip visar knappen A.
    - Hos en handlare gör A och X ingenting på låsta saker, och tooltipen har den röda
      raden. Efter handeln går quest-saker att använda igen.
    - Inget "Interface action failed because of an AddOn" i chatten eller som fel.
    - Nycklarna syns i Keys.
14. I strid (t.ex. mot en träningsdocka): använd en dryck ur väskan, och se att fönstret
    uppdateras när du lootar. Med handkontroll fungerar markören som utan Tidy Pack tills
    striden är över, och rättas sedan.
15. Efter `/reload` ser allt likadant ut.
16. Skräplistan: Alt-klicka på en vit sak och välj Add to Junk List – den hamnar sist i Junk med spelets
    skräpmynt. Gör om och välj Remove from Junk List – den går tillbaka. Med handkontroll: plocka upp en sak
    med A, gå till kugghjulet, tryck A och välj "Add to Junk List" i menyn. Saker på listan som
    inte är grå säljs för hand (spelets "Sell All Junk" tar bara grå).
17. Loota en sak som står på skräplistan: frågan "You looted ..., which is on your junk
    list. Delete it?" kommer direkt – under lootfönstret, och uppe i mitten om lootfönstret
    stängs. Delete raderar just den saken, "Not now" stänger. Inte i strid: då kommer frågan
    när striden är över. Med handkontroll: frågan uppe i mitten ska få markören direkt.
18. Fulla väskor: fyll väskorna och loota eller flå något. När "Inventory is full." visas
    kommer en panel under lootfönstret, med samma ram och bredd, och föreslår skräplistan
    eller den billigaste grå saken (bara om det nya är värt mer). Med handkontroll: gå ned
    till knapparna med styrkorset och tryck A på Delete. Inget felmeddelande om blockerade
    handlingar.
19. Kugghjulet: klicka utan sak – menyn visar "Junk List…" och "Settings…". Släpp en sak på kugghjulet –
    menyn visar "Add to Favorites" och "Add to Junk List". Menyn ser ut som spelets egna.
    kugghjulet lyser upp när du pekar på den och medan menyn är öppen.
20. Inställningar: Esc → Options → AddOns → Tidy Pack, `/tidypack` och addonmenyn vid
    minikartan öppnar sidan. Ingen etikett slutar med "...", och tooltipen förklarar varje
    rad. Varje kryssruta gör det den säger, även efter `/reload`.
    Rubriken för quests säger om Questie finns, och utan Questie går kryssrutan inte att
    ändra. Skräplistans sida: lägg till genom att shift-klicka på en länk (t.ex. i chatten)
    medan rutan är aktiv, skriv ett namn eller nummer, eller släpp en sak på sidan; ta bort
    med det röda krysset. Rullningslisten syns bara när listan inte får plats.
21. Quests i förväg, med Questie installerat: saker som en quest du inte tagit än behöver
    har ett gult utropstecken uppe till höger, och tooltipen visar "Needed later for: ...".
    Utan Questie: en rad i chatten första gången, och aldrig mer.
22. Utseende: panelen ser ut som lootfönstret, kugghjulet står i höjd med sökrutan, och Tidy Packs
    siffror och märken krockar inte med spelets egna (antal nere till höger, skräpmynt och
    grön pil uppe till vänster).
23. Prestanda: öppna väskan, loota och sälj något, och skriv sedan
    `/dump C_AddOnProfiler.GetAddOnMetric("TidyPack", Enum.AddOnProfilerMetric.PeakTime)`.
    Svaret är den längsta tid Tidy Pack har tagit under en bildruta, i millisekunder (en
    bildruta är ungefär 16 ms vid 60 bilder per sekund). Addonlistan visar också hur mycket
    av datorns tid varje addon använder.
24. Specialväskor: med ett koger eller en själsväska på plats ligger den längst ned under
    en linje, med väskans ikon och namn, sina saker och sina lediga platser. Empty räknar
    bara vanliga platser. Utan specialväska syns ingen linje.
25. Mer luft: rutorna står längre från ramen än förut, och inget krockar (kugghjulet, sökrutan,
    pengarna). Skicka en skärmbild.
26. Set, i fliken Sets: "New Set" → namn och ikon i spelets ruta → Okay. Plocka upp en sak
    och håll den över fliken Sets (fönstret byter flik), släpp den på setets rad – den syns
    som en liten ruta. Klick på raden tar på utrustningen och visar "Equipped". Sälj eller
    banka en sak – rutan blir grå och raden visar "⚠ 1 missing". Högerklick: byt namn och
    ikon, ta bort en sak, ta bort setet. Hos en handlare är setets saker låsta. Tooltipen
    visar "Tidy Pack set". I strid: ett meddelande i stället. Kugghjulets "Add to Set"
    fungerar också. Med handkontroll: nå flikarna och raderna med markören, och prova "Show
    Sets" i kugghjulets meny. Grupperna heter
    "Spare Bags" och "Add to bag".
27. Efter uppdateringen: starta om spelet helt (ny rad i TOC-filen), och kontrollera att
    favoriter, skräplista och inställningar finns kvar.
28. Fliken Sets: New Set överst, Equip på varje rad (grå när setet redan sitter på), "+"
    sist bland sakerna. Pricken på fliken Sets lyser när ett set saknar en sak. Båda
    flikarnas text är lika stor. Esc → Options → Keybindings → AddOns → Tidy Pack: lägg en
    tangent på "Open the Sets tab" och "Equip set 1" och prova (i strid: ett meddelande).
29. Specialväska och `/reload`: med en specialväska på plats (t.ex. Apprentice's Mining Pack
    eller ett koger), gör `/reload` och öppna väskan direkt, med mus och med handkontroll.
    Grupperna och linjen ovanför specialväskan syns, och inget felmeddelande kommer.
30. Set: kugghjulet på en rad öppnar setets meny, också med handkontroll. "Add What I'm
    Wearing" lägger det du har på dig i setet (inte skjorta och tabard). Fliken Sets utan
    set visar en förklaring med New Set under.
33. "Add to bag": rutan står näst först (bredvid Favorites, eller först utan favoriter), har ett
    + och antalet lediga platser, och en tooltip. Släpp en sak på den – saken hamnar i väskorna.
    Prova också med handkontroll: markören börjar på en riktig sak, och en sak du plockat upp
    med A kan läggas ner på rutan.
34. Egna grupper: släpp en dryck på kugghjulet → "Add to Group ▸ New Group..." → namnet "Potions"
    → saken hamnar i gruppen Potions (efter Favorites och "Add to bag"). Släpp en annan dryck →
    "Add all "Potion" items to Group ▸ Potions": alla drycker flyttar dit och lämnar Consumables.
    Kontrollera: tooltipen visar "Tidy Pack group: Potions"; en favorit och en skräpmarkerad sak
    ligger kvar i Favorites och Junk; en ny dryck du lootar ligger i New tills du stänger väskan
    och sedan i Potions. Esc → Options → AddOns → Tidy Pack → Groups: välj gruppen, ▲▼ ändrar
    ordning, Rename, ✕ (med fråga), kryss tar bort en regel eller sak, lägg till en sak med länk,
    namn eller genom att släppa den. Skapa 8 grupper: "New Group" blir avstängd. Med handkontroll:
    menyn och sidan nås med markören. `/reload` och logga in igen: grupperna finns kvar.
44. Reagensväskan (2026-11-11): med mus visar spelet väskplats 5 i ett eget fönster (`ENDING_BAG_INDEX` sätts
    när spelets fil laddas; att ändra den skulle smitta spelets kod och kan blockera att saker används).
    Fönstret fästs till vänster om Tidy Pack med nederkanterna i linje (`dockReagentBag`, efter
    `UpdateContainerFrameAnchors` och efter varje storleksändring). Sakerna sorteras inte. Inte provat i spelet.
43. Väskor (2026-11-11, skissen `.design/sketch-bag-bar.html`): loggan (`Media/Logo.tga`, 64×64, okomprimerad
    TGA gjord ur `.design/logo.png`) ersätter spelets väskrad (`BagsBar` döljs efter varje Show,
    `LogoButton.lua`, inställningen `replaceBagBar`): klick öppnar väskan (`ToggleAllBags`), högerklick
    inställningarna, en släppt sak läggs i väskorna, siffran är lediga platser. I väskfönstret: "N free"
    följt av fem små väskikoner (antal platser); musen över en tonar ner allt som inte ligger i den;
    en väska som släpps på en plats byter ut den (`PutItemInBag`), en vanlig sak läggs i den väskan;
    medan du håller en väska lyser platserna och raden säger "Drop on one of your bags to swap it".
    Alla tre flikar byter när du håller en sak över dem. Inte provat i spelet.
42. Avsnitt (2026-11-11, skissen `.design/sketch-order.html`; innehållet centreras mellan ramens kanter med `contentShift`, eftersom pengaraden sitter längre från höger kant): Bags i fem avsnitt (`ns.GetGroupSection`):
    1 Favorites, egna grupper, New; 2 Consumables, Equipment; 3 råvaror och Recipes & Gems; 4 Quest Items;
    5 Keys, Miscellaneous, Spare Bags, Junk. Nytt avsnitt = ny rad och en tunn gul linje (`sectionYs`,
    `placeSectionLines`). Med mus visas inte "Add to bag"; "N free" står nere till vänster (rött vid 5 eller
    färre) och byts mot "Drop anywhere ..." medan du håller en sak. Med handkontroll: "Add to bag" kvar,
    ingen text. Gruppen med recept, ädelstenar och förbättringar heter "Recipes & Gems". Inte provat i spelet.
41. Guiden (2026-11-11, `Tour.lua`): spelets tipsrutor (`HelpTip:Show`, samma som HUD Edit Modes guide).
    Första gången väskan öppnas i Bags: fyra rutor med Next/Got it – en sak (Alt-klick), kugghjulet,
    fliken Sets, fliken Quests. Saknas något att peka på hoppas steget över. Stängs väskan mitt i börjar
    guiden om nästa gång. Klar → `tourDone = true`. Esc → Options → AddOns → Tidy Pack → Tips → Show again
    (`ns.ResetTour`). Visas inte med handkontroll eller med spelets inställning "hideHelptips"
    (`HelpTip:AreHelpTipsEnabled`). Ersätter den blå tipsraden (`itemTip` används inte längre).
    Inte provat i spelet.
40. Råvaror och släpp (2026-11-11, skissen `.design/sketch-drop-and-crafting.html`): Trade Goods delas i
    grupper per undertyp (`trade<subClassID>`, namn från `C_Item.GetItemSubClassInfo`); grupper för dina
    yrken står först med yrkets ikon och namn i grått (`ns.GetTradeGroupKeys`, `GetProfessions`,
    `SKILL_LINES_CHANGED`). Ädelstenar, förbättringar och recept står kvar i "Trade Goods". ⚠️ Undertypernas
    och yrkenas nummer är retail-värden, inte i Forevers dokumentation – kontrollera att Cloth hamnar
    först för en skräddare. Avvikelse från skissen: inga rader "Your professions"/"Other crafting".
    Håll en sak över väskan: gul kant och "Drop anywhere to put it in your bags"; släpp på tom yta →
    första lediga plats i en vanlig väska (`C_Container.PickupContainerItem`); full väska → spelets
    röda "Inventory is full". Inte provat i spelet.
39. Set i väskan (2026-11-10, skissen `.design/sketch-sets-in-bag.html`): dra setets ikon till en
    actionbar → makrot "TP <namn>" (kontots, `/tidypack equip <namn>`, setets ikon) skapas eller uppdateras
    och läggs på markören (`ns.PickupSetMacro`); släpp på en knapp och klicka – setet tas på. Byt namn eller
    ikon: makrot följer med. I strid: en rad i chatten, inget makro. Klick på ikonen: ett rutnät med ikoner i
    fliken (setets saker först), ett klick byter ikonen, Done tillbaka, rullningen står kvar efter ett klick.
    "..." → Rename: namnet skrivs på raden (Enter/Esc). Med handkontroll: spelets ruta som förut, nu med
    synliga ikoner (listan låg i lagret HIGH under rutans DIALOG). Inte provat i spelet.
38. Mer plats (2026-11-10, efter 1.0.1, skissen `.design/sketch-more-room.html`): ingen sökruta
    (`BagItemSearchBox` döljs efter varje `Show`), ingen väskikon (`PortraitContainer`, `PortraitButton`
    och `CountContainer` döljs, ramen byts till `ButtonFrameTemplateNoPortrait` med
    `NineSliceUtil.ApplyLayoutByName`), och sakerna börjar direkt under titeln (`searchRoom()`: 55 med
    mus, 43 med handkontroll – 30 och 40 lämnade ett band; justerat efter en
    skärmbild). Flikarna börjar 14 från kanten. Alla tre flikar har samma höjd (`sharedHeight` i
    `relayout`: den högsta av Bags, `ns.SETS_VIEW_HEIGHT` och `MIN_QUESTS_HEIGHT`); Quests visar "...and N
    more" i stället för att växa. Sets: fem numrerade platser (`ns.MAX_SETS = 5`, samma som Equip set
    1–5), tomma platser med "+" som skapar ett set (klick eller släppt sak), ingen New Set-knapp, ingen
    tipstext. Ett klick (eller en släppt sak) gör den tomma raden till en skrivruta (`startNaming`):
    Enter skapar setet utan ikon (första sakens ikon visas), Esc eller tom ruta avbryter, fel visas
    i rött under rutan. Med handkontroll öppnas spelets ruta för namn och ikon som förut. Dolda quest-saker i Bags: en ruta med antalet och spelets gula quest-ram
    (`TEXTURE_ITEM_QUEST_BORDER`), tooltip och klick öppnar Quests. Quests saknar sammanfattningsraden.
    Mac: `ns.KeyText` byter "Alt-click" mot "Option-click" (`IsMacClient`). Inte provat i spelet.
37. Sista granskningen (2026-11-10): kugghjulet är gult med en tunn gul ram på mörk botten (grå bild som
    färgas, `SetDesaturated` + `SetVertexColor`), i lagret HIGH så att det syns över titelraden. Quests har
    en rad under titeln ("8 quests need items – 1 ready to turn in"). Inställningssidan: Bag window (nivå och
    BoE, quest-saker i Bags, knappen Your own groups), Merchants (Lock items at merchants), Quests (Questie),
    Junk (två kryssrutor och Junk List). Texterna säger "favorite" i stället för "star".
36. Kugghjul och ⋯ (2026-11-10): ett kugghjul i fönsterhuvudet, till vänster om stängknappen, på alla
    flikar: meny med Junk List, Groups, Settings och två kryssrutor (Show quest items in Bags, Lock quest
    and set items); en sak som släpps på det öppnar menyn för favorit/skräp/set/grupp som förut. Sökrutan
    går ända fram till kanten. På varje set-rad står "..." (tooltip "More options") i stället för ett
    kugghjul. Quests: tre rubriker med antal ("Ready to turn in (1)", "In progress (7)", "Other quest
    items (3)") med plus/minus; allt hopfällt första gången utom "Ready to turn in" när en quest är klar;
    ett klick fäller ut och valet finns kvar efter /reload. Under en öppen rubrik står en rad per quest
    (plus/minus, namn, totalen till höger); ett klick på en quest fäller ut just den: en rad per sak med små rutor
    (skala 26/37, `entry.scale` i Layout.lua) följda av namn och antal (`questOpen["q<questID>"]`). Ingen rullist (inte byggd): ryms inte allt står "...and N more quests".
35. Quest-saker: ta en quest som kräver saker (t.ex. fenor, 3 av 7). Bags: Quest Items visar "3/7" på
    rutan, grönt när det räcker; tooltipen säger "Needed for: <quest> (3/7)". Har du två högar av samma sak
    med mer än questen behöver: den största hålls kvar i Quest Items, den andra ligger bland vanliga saker och
    går att sälja hos handlaren. Fliken Quests: klara quests överst under "Ready to turn in", sedan de som
    pågår, med rutor, namn, antal och en stapel; det du inte har plockat än syns som grå text med en tom
    ruta; en sak som två quests behöver visas bara under den första. En prick på fliken lyser när en quest
    är klar. Esc → Options → AddOns → Tidy Pack → "Show quest items in Bags" av: Bags visar en rad "N slots
    hold quest items – see Quests", och ett klick öppnar fliken Quests. Fönstret är lika högt i alla flikar.
    Med många quests: de som inte får plats ersätts av "...and N more quests". Med handkontroll: nå
    fliken och rutorna i den.
32. Stora väskor: med så många saker att fönstret annars skulle bli högre än skärmen blir
    fönstret bredare (upp till 20 kolumner) och ryms. Fyll gärna alla väskplatser och kontrollera
    att sökrutan, kugghjulet och flikarna syns och går att nå. Byt flik Bags ↔ Sets: fönstret
    ändrar inte storlek. Med mus syns antalet lediga platser i väskikonen uppe till vänster,
    och hjälptexten under setlistan syns med 1–3 set.
31. Bakgrund och lås: bakgrunden bakom sakerna är mörk och hel i båda flikarna. Med "Lock
    quest and set items" avstängd går låsta saker att klicka på hos handlaren.

### Provat i spelet
- 2026-11-09, testversion `v0.2.0-alpha1` på en annan dator (skärmbilder): addonet laddas
  (1), väskfönstret visar grupperna utan väskor och kvastknapp (3), Hearthstone ligger i
  Favorites (6), Empty visar antalet (7), nivå och BoE bara på grönt (12), Junk visar
  värdet, ★-menyn utan sak (19) och inställningssidan och skräplistans sida (20, bara
  utseendet). Fel som hittades: fyra etiketter på inställningssidan var för långa och
  slutade med "..." – kortade. Resten av listan är inte provad.
- 2026-11-09, `v0.2.0-alpha2`: mer luft syns, fliken Bags fungerar. Fel: flikarna hade
  olika storlek (spelets valda flik är högre och de andras text flyttas ned, så "Sets"
  kapades av ramen), och tom flik Sets lade texten långt ovanför fönstret och krympte
  fönstret. Rättat: båda flikarna använder den valda flikens bilder, 80 enheter breda, den
  andra lite mörkare; listan placeras när höjden är känd och är minst 120 hög.
- 2026-11-09, `v0.2.0-alpha2` hos en kollega (hunter, koger med pilar, reagensväska
  "Shipwright's Satchel" i eget fönster): inga grupper alls, spelets eget rutnät med alla
  tomma platser. Flikarna och ★ fanns, så uppstarten gick bra; troligen stoppade ett fel i
  genomgången (`relayout`), sannolikt i delen för specialväskor. Felet är inte hittat
  genom att läsa koden. Därför skriver Tidy Pack nu felet en gång i chatten
  (`safeRelayout`). Väntar på felraden.
- 2026-11-09, `1.0.0` (zip-filen) med handkontroll, Mining Pack som specialväska: grupperna
  försvann efter en stund och spelets ruta "TidyPack has been blocked from an action only
  available to the Blizzard UI" kom. Spelets konsollogg
  (`_forever_/WTF/SavedVariables/Blizzard_Console.lua`) visade felet: `Layout.lua:280`,
  `contentHeight` var nil. Linjen ovanför specialväskorna placerades innan höjden var
  räknad; första genomgången efter inloggning eller `/reload` stannade då, och alla
  följande likaså. Samma fel förklarar troligen kollegans koger ovan. Rättat. Vad spelet
  stoppade är inte känt än – Tidy Pack skriver nu funktionens namn i chatten
  (ADDON_ACTION_FORBIDDEN/BLOCKED), och `taintLog` ska vara på vid nästa prov.

## Arbetssätt
- Kärnreglerna i pluginet wow-addon-skills gäller.
- Kör skillen `wow-check` efter varje större ändring.
- Testa i spelet med `/reload` efter varje ändring och `/console scriptErrors 1` påslaget.
- Skriv ändringar i `CHANGELOG.md` under `## Unreleased` (skapa rubriken överst igen efter en
  släppt version) och committa med git.

## Publicering
- Status: projektet "Tidy Pack" (CurseForge-id 1794643) godkändes av CurseForge 2026-11-10. **1.0.1
  släpptes 2026-11-10** med taggen `v1.0.1`: arbetsflödet `.github/workflows/release.yml` byggde
  `TidyPack-v1.0.1-forever.zip`, laddade upp den till CurseForge ("Success!", spelversion 1.60.1, typ
  release) och skapade en release på GitHub. Det var första uppladdningen via Upload API:t, så nyckeln
  `CF_API_TOKEN` fungerar. Kontrollera på CurseForge att filen blir godkänd och synlig.
- Filen fick visningsnamnet "v1.0.1-forever" på CurseForge (packagerns standard: taggen och speltypen).
  Från nästa version sätter arbetsflödet namnet med `-n "TidyPack-<version>:TidyPack-<version>"` (filnamn:
  visningsnamn), med versionen ur TOC-filen.
- 1.0.0 laddades upp för hand 2026-11-09 med "publish manually once approved" och står som "Pending
  Release". Den har kraschen med specialväskor och knappen Sell Junk och ska **aldrig publiceras** –
  användaren tar bort den eller låter den stå orörd.
- Version 1.0.0 förbereddes så: LICENSE (MIT), README.md (projektbeskrivningen), CHANGELOG.md, zip-filen i
  `.release/` och texterna till projektsidan i `.design/curseforge-page.md`. Kategori Bags & Inventory,
  spelversion WoW Forever 1.60.1, Questie som valfritt beroende. Loggan är `.design/logo.png` (egen
  teckning, källa `logo.svg`).
- 1.0.1 släpptes utan att användaren hade bekräftat den sista zip-filen i spelet (gult kugghjul, omordnad
  inställningssida, raden under titeln i Quests). Nästa version: börja med de punkterna i testlistan.
- GitHub-sidan: `.github/README.md` är förstasidan på GitHub (logga, installation, kort
  funktionslista, länk till feedback). GitHub visar den före `README.md` i roten, som i stället
  är CurseForge-beskrivningen och också följer med i zip-filen. Håll funktionerna lika i
  båda, och uppdatera raden om CurseForge när projektet är godkänt. Loggan ligger i
  `.design/logo.png` (länkas med adress till `main`). Repots "Social preview" (1280 × 640,
  `.design/social-preview.png`) kan bara läggas in för hand: Settings → General → Social
  preview. Beskrivning och ämnesord sätts med `gh repo edit`.
- Testversioner för andra datorer läggs som förhandsversion (pre-release) under Releases på
  GitHub, med zip-filen från `package-addon.mjs` (den hamnar i `.release/`, som git
  ignorerar). Första: `v0.2.0-alpha1`, andra: `v0.2.0-alpha2`, tredje: `v0.2.0-alpha3`, fjärde: `v0.2.0-alpha4`, femte: `v0.2.0-alpha5` (alla 2026-11-09). Efter 1.0.0: `v1.0.1-alpha1` (2026-11-09, rättelsen för specialväskor, ny bakgrund, set-menyn, utan Sell Junk). Taggarna har `alpha` i namnet. När
  arbetsflödet nedan finns får bara rena versionstaggar (vN.N.N) något att göra; testtaggar
  med `alpha` startar ingenting och laddas inte upp till CurseForge.
- CurseForge-projektet: id 1794643 (`## X-Curse-Project-ID` i TOC-filen), adress
  `curseforge.com/wow/addons/tidy-pack`. 1.0.0 laddades upp med "publish manually once
  approved" (bekräftat 2026-11-10), så den släpps inte av sig själv när projektet godkänns;
  den har kraschen och ska inte släppas. Hemligheten `CF_API_TOKEN` ligger i repot
  (2026-11-10). Nyckeln skrevs av misstag i chatten en gång och byttes ut. Arbetsflödet
  markerar inga filer för manuell release (packagern har ingen sådan flagga), så 1.0.1 blir
  tillgänglig så fort CurseForge godkänt filen.
- Automatisk uppladdning (pushad och provbyggd 2026-11-10, men ingen riktig tagg är släppt än):
  `.github/workflows/release.yml` startar bara när en tagg som `v1.0.1` pushas (inte
  `v1.0.1-alpha1`). Först kontrolleras att taggen stämmer med `## Version:` i TOC-filen
  (ett fast nummer, inte `@project-version@`), sedan bygger BigWigs packager v2 zip-filen
  utifrån `.pkgmeta`, laddar upp den till CurseForge som Release och lägger en release med
  zip-filen på GitHub. Kräver hemligheten `CF_API_TOKEN` (användaren lägger in den själv)
  och `## X-Curse-Project-ID: <id>` i TOC-filen (saknas än). Packagern känner igen Forever
  (Interface 16xxx, spelversionstyp 88568). Fråga alltid före en tagg: den släpper en
  version. `.github/workflows/package-check.yml` är ett provbygge som startas för hand
  (Actions → Package check → Run workflow): samma packager med `-d` (ingen uppladdning, ingen
  nyckel), och zip-filen sparas som nedladdningsbar fil i 7 dagar. Provet 2026-11-10 gav
  samma 19 filer som `package-addon.mjs`, byte för byte lika med flaggan `-u` (Unix-radslut;
  utan den skriver packagern Windows-radslut, CRLF). Packagern kände igen Forever
  (spelversion 1.60.1) och döper filen `TidyPack-<tagg>-forever.zip`. Byggtypen följer taggen:
  en ren `vN.N.N` ger Release, annars (som vid provet, efter taggen `v1.0.1-alpha1`) Alpha.
  Två spår på GitHub: förhandsversioner (alpha, för testare, med `gh release create
  --prerelease`) och rena versioner (laddas upp av arbetsflödet). GitHubs "Latest" pekar
  alltid på den senaste rena versionen.
- Packagerns skript (`release.sh`) kräver bash 4.3 eller nyare. Macens egen bash är 3.2, så
  provbygget görs på GitHub med `package-check.yml` (inget behöver installeras).
- Kvar innan första riktiga släppet: hemligheten `CF_API_TOKEN` (användaren lägger in den),
  `## X-Curse-Project-ID` i TOC-filen och att CurseForge godkänt projektet. Att API:t tar emot
  uppladdningar till ett ännu ogodkänt projekt är inte verifierat.

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
- 2026-11-09: Handkontrollen rättad efter genomläsning av Blizzards kod (inte provat i
  spelet än). Spelets markör började på den dolda väskknappen, LB/RB gick till dolda
  väskknappar, och rutnätet passade inte grupperna. Nu: start i New, LB/RB mellan grupper,
  spelets fria navigering och flytt bort från dolda rutor. Ingen egen knappbindning för
  LB/RB: spelets knappstack för handkontroll (`InputBindingManager`) är delad, och en
  bindning från ett addon skulle smitta spelets egna knappar (taint).
- 2026-11-09: Med handkontroll stängs låsta rutor inte av. Spelets markör lyssnar på när
  rutan den står på stängs av eller på (`TrackButtonEnabledState`) och kör då knapptipsens
  kod, som bygger om knappbindningarna. Gör Tidy Pack det, sker det i Tidy Packs namn, och
  sedan kan spelet blockera Use och Sell. I stället används spelets egen spärr för markörens
  klick, som addons får sätta utanför strid.
- 2026-11-09: Spelets tips (HelpTip), hjälpskyltar (HelpPlate) och nybörjarguide är
  avstängda med handkontroll i Forever. En introduktion i Tidy Pack ska därför använda
  spelets mall `HelpTipTemplate` i egna ramar. Föreslagen och skissad
  (`.design/sketch.html`), byggs efter första testet i spelet.
- 2026-11-09: Städning: questloggen gås igenom högst en gång per bildruta och väskan läggs
  bara om när något nytt krävs, Sell Junk uppdateras en gång per bildruta, och varje sak
  frågas bara en gång om den behövs för en quest.
- 2026-11-09: Blizzards addonpolicy har inga regler om utseende. Addons får använda spelets
  mallar, typsnitt och bilder i spelet, men inte kopiera spelets bildfiler eller se ut att
  komma från Blizzard. Därför: frågepanelen har lootfönstrets mall, skräpet spelets
  skräpmynt, quest-märket kartans utropstecken och siffran för tomma platser samma plats
  som spelets egen siffra för antal. Panelens rubrik är "Tidy Pack", så att det syns vem som
  frågar.
- 2026-11-09: Spelets egna frågerutor (StaticPopup) används inte. De är delade, och ett
  addon som visar sin fråga i dem kan smitta spelets egna frågor (taint), t.ex. den när man
  raderar en sak. Panelen är en egen ram byggd av spelets mallar.
- 2026-11-09: Fulla väskor: automatiska förslag, men radering bara när spelaren trycker
  Delete (användarens önskan, och spelets regel för `DeleteCursorItem`). Med handkontroll
  flyttas markören inte till Delete, så att ett tryck på A för att loota aldrig raderar.
- 2026-11-09: Quests i förväg använder QuestieDB som valfritt beroende. Ingen data kopieras,
  eftersom QuestieDB:s licens är en blandning av GPLv3 och "all rights reserved". Användaren
  godkände att Tidy Pack berättar en gång att Questie låser upp funktionen. På CurseForge
  ska Questie anges som valfritt beroende. "Lär av dina karaktärer", som fyller luckorna för
  Forevers nya quests, tas efter att detta är provat.
- 2026-11-09: Skräplistan ska ge förslag automatiskt när en sak från listan lootas, t.ex.
  vid flåning (användarens förtydligande). Saker ska kunna läggas till utan att man har dem,
  därför en egen sida med länk, namn och nummer. Shift-klickade länkar fångas med
  `hooksecurefunc(ChatFrameUtil, "InsertLink")`, eftersom spelet bara lägger länkar i
  chatten och några egna fält.
- 2026-11-09: En enda knapp i väskfönstret (★, spelets `DropdownButton` med spelets meny) i
  stället för ★ och skräpmynt bredvid varandra. Användaren ville ha luft och ett
  inbyggt intryck; spelets eget väskfönster har bara en knapp på den platsen.
- 2026-11-09: Inställningssida (ändrar beslutet från 2026-11-09 om att inte ha någon):
  användaren vill kunna välja vad som är på, t.ex. Questie. Huvudsidan använder spelets
  vanliga rader, skräplistan en egen sida. Öppnas från Options, `/tidypack`, addonmenyn vid
  minikartan och ★.
- 2026-11-09: Etiketterna på inställningssidan är högst ungefär lika långa som "Show item
  level and BoE on gear". Spelet kortar av längre etiketter med "..." (sett i spelet).
  Förklaringen står i tooltipen, som på spelets egna sidor.
- 2026-11-09: Mer luft mellan ramen och rutorna (användarens önskan): 6 enheter på var
  sida, 4 under sökrutan och 9 ovanför pengarna. Pengarna står kvar där spelet lägger dem.
- 2026-11-09: Specialväskor i egna grupper längst ned under en linje, med väskans ikon och
  namn (användarens önskan: tydligt att de inte hör till de vanliga väskorna). Linjen ändrar
  beslutet om "inga linjer" – den syns bara när en specialväska finns.
- 2026-11-09: Knappen i väskfönstret är ett kugghjul (`questlog-icon-setting`, spelets
  bild för inställningar) i stället för ★, eftersom den nu gör mer än favoriter. Gruppen
  Favorites behåller stjärnan.
- 2026-11-09: Namn och ikon för set väljs i spelets egen ruta
  (`IconSelectorPopupFrameTemplate`, som Forevers utrustningsset), med utrustningens ikoner
  först. Ikonen sparas som `icon` i setet; äldre set utan ikon visar första sakens ikon.
  Setens sida har en rubrikrad per set med ikon, namn, antal, Edit och Delete.
- 2026-11-09: Granskning: sökrutan går nu fram till knappen även med mus (spelet gav den en
  fast bredd, 330) och döljs i fliken Sets. Questies databas frågas i bakgrunden, högst
  3 ms per bildruta, så att väskfönstret aldrig väntar på den (Sell Junk frågar direkt för
  grå saker).
- 2026-11-09: Rubriken är "Backpack" (spelets `BACKPACK_TOOLTIP`) i stället för "Combined
  Backpack" (användarens val). Byts efter spelets `UpdateName`.
- 2026-11-09: Flikarna i Forevers egna fönster: flikar som byter hela fönstrets innehåll
  sitter under fönstret (`PanelTabButtonTemplate`, t.ex. handlarens Merchant/Buyback och
  karaktärsfönstret). Flikar ovanpå (`PanelTopTabButtonTemplate`) används bara inuti ett
  fönster (samlingarnas Items/Sets). Forevers bank har ikonflikar på sidan
  (`LargeSideTabButtonTemplate`). Forevers nya trollbok har flikar under titelraden,
  inuti fönstret (`TabSystemTemplate` + `TabSystemTopButtonTemplate`, TOPLEFT 70, -26).
- 2026-11-09: Flikarna Bags och Sets byggs som trollbokens (användaren visade den som
  förebild): `TabSystemTemplate` med `TabSystemTopButtonTemplate`, 90 breda, text i
  `GameFontNormal`/`GameFontHighlight`. Den valda är högre, som i spelet. På användarens
  önskan sitter de utanför ramen, ovanpå fönstrets övre kant (BOTTOMLEFT mot fönstrets
  TOPLEFT 62, -2) – mallen är gjord för flikar som hänger ovanpå en ram. Sökrutan har
  spelets plats. Mallen läser `tabTemplate` när den skapas, så Tidy Pack sätter mallen och
  poolen efteråt.
- 2026-11-09 (efter skärmbilder av `v0.2.0-alpha4`): den valda flikens text var mindre
  (knappen är avstängd och spelet använde dess "disabled"-stil) – rättat med
  `SetDisabledFontObject`. Kugghjulet såg avstängt ut vid 0.35 – nu 0.6. Fliken Sets:
  New Set står på sökrutans plats, läget efter namnet, en Equip-knapp till höger (avstängd
  när allt sitter på), större saker (22) och en tom ruta med "+" sist. Spelets prick på
  fliken Sets (`SetTabNotification`) när ett set saknar något. Snabbtangenter i
  `Bindings.xml` (öppna Sets, Equip set 1–5) via den namngivna ramen `TidyPackKeys`, så
  att inga globala funktioner behövs.
- 2026-11-09: Färre steg (användarens önskan, alla fem förslagen): allt om set sköts i
  fliken Sets (rader med sakerna, släpp på en rad, högerklick för Edit/Remove/Delete, New
  Set i fliken), fliken Sets öppnas när man håller en sak över den, kugghjulets meny utan
  sak har bara Junk List och Settings, setens sida i inställningarna är borttagen, och
  grupperna "Bags" och "Empty" heter "Spare Bags" och "Free".
- 2026-11-09: Flikarna Bags och Sets är alltid lika stora (användarens önskan), till
  skillnad från spelets egna flikar där den valda är högre.
- 2026-11-09: Egna set (användarens önskan): egna samlingar per karaktär, inte spelets
  utrustningsset. Läggs till via ★-menyn (högerklick används av spelet). Flikarna Bags och
  Sets ovanför fönstret; klick på ett set tar på det direkt, med varning när något saknas.
  Setens sida i inställningarna visar var varje sak finns. Saker i set låses hos handlaren,
  som spelets utrustningsset. Rutan för namn är en egen ram (inte StaticPopup). Sell Junk
  flyttades till höger ovanför fönstret för att inte krocka med flikarna.
- 2026-11-09: Väskfönstret behåller spelets egen bakgrund. Den är halvgenomskinlig
  (`PANEL_BACKGROUND_COLOR`, samma som spelets andra fönster), så questlistan syns svagt
  bakom ett stort väskfönster. Tidy Pack ändrar inte bakgrunden, eftersom fönstret då
  skulle se annorlunda ut än resten av spelet.

- 2026-11-09 (utseende, användarens val A–D efter skärmbilder med handkontroll): hel, mörk
  bakgrund bakom sakerna (`InsetFrameTemplate` med mörkare marmor, `inset` i `Layout.lua`).
  Det ändrar beslutet ovan om att behålla spelets genomskinliga bakgrund: när de tomma
  rutorna döljs lyser questlistan igenom. Fliken Sets har ett tomt läge med text och New Set
  i mitten. Mer luft mellan grupperna (`SHELF_GAP` 10, `PADDING_TOP` 8). Rubrikerna behåller
  storleken (`GameFontNormal`): nästa mindre typsnitt är för litet på en tv. Inte provat i
  spelet – färgen på bakgrunden justeras efter en skärmbild.

- 2026-11-09 (genomgång av funktionerna, användarens val): (1) "Add What I'm Wearing" i
  setets meny (`ns.AddWornToSet`, allt utom skjorta och tabard). (2) Ett kugghjul på varje
  set-rad öppnar setets meny (`DropdownButton`), eftersom högerklick inte syns och inte nås
  med handkontroll; högerklick finns kvar. (3) Inställningen `lockAtMerchant` ("Lock quest
  and set items"), påslagen från början. (4) Knappen Sell Junk är borttagen (`Junk.lua` har
  bara `ns.GetJunkKind` kvar, inställningen `sellJunkButton` används inte längre): spelet har
  `MerchantSellAllJunkButton`. Den säljer alla grå saker och känner inte till låsen eller
  skräplistan. Funktioner och testlistan ovan är rättade efter det. Inte provat i spelet.

- 2026-11-10: rutan för lediga platser heter "Add to bag" (användarens val bland "Add to bag",
  "Free slots" och "Drop here") och flyttades från sist till näst först, bredvid Favorites,
  så att den inte tar en egen rad (65 enheters höjd) och ligger nära siffran i väskikonen.
  Rutan behålls, eftersom den är släppplatsen. Se funktionslistan.
- 2026-11-10 (efter test av 1.0.1 med skärmbilder, användarens val A–G): mer luft innanför
  bakgrunden, ljusare bakgrund, samma storlek i båda flikarna, fler kolumner efter behov,
  14 som standard, hjälptext i Sets och siffran i väskikonen. Siffran i gruppen Free är kvar:
  rutan är släppplatsen för saker. Tänkbart senare (kompisens förslag, se nedan): dela upp
  quest-saker efter quest med antal (3/7) och bara låsa det antal som behövs.

- 2026-11-10: egna grupper byggda enligt det godkända förslaget (användaren svarade "Ja, bygg";
  frågorna om konto/karaktär, antal och placering besvarades med mina rekommendationer: per konto,
  högst 8, efter Favorites och "Add to bag"). Två avvikelser från skissen: en sak eller typ ligger i
  högst en grupp (bockrutan flyttar den i stället för att lägga den i flera), och raden om att en
  favorit eller skräpmarkerad sak ligger kvar i sin grupp är en rubrikrad i menyn (guld), inte grå.

- 2026-11-10: städning efter en granskning (analys av alla `ns`-medlemmar, lokala variabler och
  inställningar; ingen oanvänd funktion hittades): borttaget oanvänt `addonName` i 14 filer
  (`local _, ns = ...`) och oanvänd `L` i `Junk.lua`; knappvariablerna i `Marks.lua` heter
  `gearButton` i stället för `starButton`; gamla kommentarer om ★-knappen och Sell Junk rättade;
  migrering 2 tar bort `sellJunkButton` ur sparad data; `.design/sketch.html` märkt som gammal.
  Kvar med avsikt: `locale` i `Locales.lua` (mall för översättningar) och `migrations` (mall).

## Källor
- WoW Forever: https://warcraft.wiki.gg/wiki/Patch_1.60.1
- Interface-nummer och TOC-suffix: https://warcraft.wiki.gg/wiki/TOC_format
- Blizzards kod för Forever: https://github.com/Gethe/wow-ui-source/tree/forever
- Byta väska som inte är tom: https://warcraft.wiki.gg/wiki/Bag
- Att använda saker är skyddat: https://warcraft.wiki.gg/wiki/API_C_Container.UseContainerItem
- Alt-klick räknas som modifierat klick: https://warcraft.wiki.gg/wiki/API_IsModifiedClick
- Handkontrollens markör i Forever (grenen `forever`, 1.60.1): `SmartNavigation.lua`,
  `Utility.lua` och `SecureHelper.lua` i `Blizzard_GamepadSmartNavigation`, och
  `SetupGamepad`, `SmartNavPanelInfoAdded` och `Gamepad_SetCursorToBag` i
  `Blizzard_UIPanels_Game/Mainline/ContainerFrame.lua`
- Radera saker: https://warcraft.wiki.gg/wiki/API_DeleteCursorItem (hårdvaruhändelse sedan
  9.0.2, en sak per händelse sedan 9.1.5)
- Blizzards addonpolicy: https://us.forums.blizzard.com/en/wow/t/ui-add-on-development-policy/24534
- QuestieDB för andra addons: https://github.com/Questie/QuestieDB (`docs/api.md`,
  `docs/forever.md`, `LICENSE.md`), Questie med stöd för Forever:
  https://github.com/Questie/Questie
- Spelets tips och handkontroll: `HelpTip:AreHelpTipsEnabled` i
  `Blizzard_SharedXML/HelpTip.lua`, `Blizzard_HelpPlate/Camelot/HelpPlateOverrides.lua` och
  `TutorialLogic:IsNPEAllowed` i `Blizzard_NewPlayerExperience/Camelot/`
