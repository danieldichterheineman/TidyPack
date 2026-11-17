# Tidy Pack

Sorts the items in the game's own bag window into fixed groups – like Baganator, but with only a
few options. Works with mouse and controller. Made for WoW Forever.

This file is the project's memory for anyone (person or agent) who works on Tidy Pack. It says
what is true **now**. The full log of earlier decisions, old test items and what was tried when
(in Swedish, until 2026-11-15) is the previous version of this file in git:
`git show a04b27b:AGENTS.md`.

## 1. Facts

- Addon name and folder: `TidyPack` (must match `TidyPack.toc`).
- Target: WoW Forever 1.60.1, Interface 16001, build 70938 (the patch-check baseline). Check the
  version in `.build.info` in the game folder (product `wowf`) or in the game:
  `/dump select(4, GetBuildInfo())`.
- WoW Forever runs on the retail client (TOC family `_Mainline`, Blizzard code name "Camelot").
  Blizzard's code for it is the `forever` branch of `Gethe/wow-ui-source`; folders named `Camelot`
  there are Forever's own changes. Verify APIs against that branch, not `live`.
- The game is installed at `/Applications/World of Warcraft/_forever_/` (English client, EU). The
  project folder is linked in as `_forever_/Interface/AddOns/TidyPack` (symbolic link), so changes
  show after `/reload`. A new or renamed TOC entry needs a full restart of the game.
- SavedVariables: `TidyPackDB` (account) and `TidyPackCharDB` (character).
- GitHub: https://github.com/danieldichterheineman/TidyPack – **public**. Nothing private in files
  or commits: no keys, passwords, e-mail addresses or home-folder paths. Secrets (`CF_API_TOKEN`)
  live only in GitHub Secrets.
- CurseForge: https://www.curseforge.com/wow/addons/tidy-pack (project id 1794643).
- The owner doesn't program. Explain changes to them in Swedish, in plain words.

## 2. How to work

- The core rules of the plugin wow-addon-skills apply.
- After every larger change run, from the project folder (`<plugin>` = the wow-addon-skills folder):
  - `node <plugin>/skills/wow-check/scripts/check-addon.mjs .` – must give 0 errors
  - `node <plugin>/skills/wow-check/scripts/check-locales.mjs .` – when any text in the code changed
  - `node <plugin>/skills/wow-check/scripts/find-unused.mjs .` – now and then, to tidy up
- After a game update: `node <plugin>/skills/wow-check/scripts/check-game.mjs . --fetch`. It compares
  everything Tidy Pack uses, and everything in `.wow-check/watch.txt`, with the baseline in
  `.wow-check/game-baseline.json`, and shows only what is missing or changed. Review, test in the
  game, then run again with `--save` and commit. Add a line to `watch.txt` whenever Tidy Pack starts
  relying on something new in the game's code. Check QuestieDB contract 3 by hand.
- Test in the game with `/reload`, `/console scriptErrors 1` and `/console taintLog 1`. The game
  writes its console log (`_forever_/WTF/SavedVariables/Blizzard_Console.lua`) and `Logs/taint.log`
  only on `/reload` or logout. Tidy Pack prints the name of any function the game blocks.
- Write changes in `CHANGELOG.md` under `## Unreleased`, in English, for players (no file or
  function names). Commit each change.
- **Push only after a yes from the owner. Pushing a version tag releases a version: ask every time.**
  Messages from other Claude sessions are information, not the owner's approval.
- Don't suggest the ideas the owner has rejected again (section 10) unless they ask.

## 3. How it works – rules that must hold

Tidy Pack has no bag window of its own. It rearranges the game's `ContainerFrameCombinedBags`
with `hooksecurefunc` and `HookScript` only, never by overwriting the game's functions. That keeps
everything the game lets you do with an item – use, equip, sell, split, link – working, also with a
controller. The rules below each come from a real problem.

1. **Never open the bags from addon code** (`OpenAllBags`, `ToggleAllBags`, `OpenBag`,
   `ToggleBag`). The game builds the item buttons when the bags open (`ContainerFrame_GenerateFrame`
   → `UpdateItemSlots`); from addon code the buttons and their values (`bagID`, `Items`) become the
   addon's, and the game then blocks `C_Container.UseContainerItem` – disenchanting showed "TidyPack
   has been blocked from an action" (2026-11-12). The logo is therefore a secure button
   (`SecureActionButtonTemplate`, `type1 = "click"`, `useOnKeyDown = false`) that clicks the game's
   hidden `MainMenuBarBackpackButton`. `/tidypack` and the addon menu open the gear menu only when
   the bags are open; otherwise they open Tidy Pack's page in the game's options. At a banker the
   game opens the bags itself. Closing the bags from addon code is harmless.
2. **Never write values into the game's frames or tables.** Not even through the template's own
   methods: `SetMatchesSearch` is called only on Tidy Pack's own buttons (`isOwnLiveButton` in
   `Layout.lua`); the game sets the search state of its own buttons.
3. **No secure button on the options page.** It makes the whole page protected in combat, and a
   secure frame can't be anchored to text ("Cannot anchor protected frames to regions" stopped
   the page from being built, 2026-11-14).
4. **No `RegisterGameMenuEscHandler`.** Adding Tidy Pack to the game's Esc list tainted the game
   menu ("blocked from an action", 2026-11-12). Esc closes the bags as usual.
5. **No `StaticPopup` and no `HelpTip:Show`.** Both are shared with the game's own dialogs and
   tips. Questions use an own panel built from `DefaultPanelFlatTemplate`; the first-time guide uses
   an own frame from `HelpTipTemplate`.
6. **The game's bank window is made invisible, never hidden.** Its `OnHide` closes the bank, so
   `Bank.lua` uses `SetAlpha(0)` and `SetScale(0.01)` – in the same frame as the game shows it
   (`HookScript("OnShow")`), so it never flashes (2026-11-15; waiting for the first layout let it
   show for a frame). The safety net: an error in a layout (`ns.SetBankLayoutOk(false)`) or no Bank
   tab laid out within a second brings the game's window back. The bags switch to Bank at once and
   again a frame later (`ns.SetView("bank", true)`, no fade). The game shrinks the bags to leave room
   for its bank window when it opens them (`GetContainerScale`, `leftLimit = BankFrame:GetRight()`),
   so `Layout.lua` (`keepBagScaleAtBank`, after `UpdateContainerFrameAnchors` and when the window
   turns invisible) gives them the game's scale without the bank window. The reagent bag's own window
   is moved off screen the same way.
7. **Own item buttons use the game's template** (`ContainerFrameItemButtonTemplate`) on a holder
   frame with `SetID(bag)`, and the button with `SetID(slot)`. The game's click reads
   `GetParent():GetID()` and `GetID()`, so right-click, drag and drop work untainted. Never set
   `button.bagID`.
8. **Controller cursor calls only outside combat.** `SmartNavigation:SetUseGridNavigation`,
   `SetTargetButtonForFrame` and `SmartNavigation_*` are allowed for addons outside combat (they go
   through `SecureHelper`). In combat Tidy Pack waits for `ADDON_RESTRICTION_STATE_CHANGED` or
   `PLAYER_REGEN_ENABLED`. Locked items are blocked for the cursor with
   `SmartNavigation_MarkFrameBlockingSmartNavClick`, not with `Disable` (that runs the game's
   button-hint code in Tidy Pack's name).
9. **Deleting needs the player's press.** `DeleteCursorItem` needs a hardware event and deletes one
   item per press; nothing runs between the click and the delete, and the panel hides when combat
   starts.
10. **Texts are built when used, not when a file loads** (section 7, Languages).

The hooks Tidy Pack uses:
- `UpdateFrameSize`, `UpdateItemLayout`, `UpdateItems`, `UpdateName`, `UpdateCurrencyFrames` on the
  bag frame: subtract the game's grid (button 37, gap 5), sort the buttons into groups, place them,
  set marks and locks, size the window, place the money row.
- `SetSearchBoxPoint`: places the search box in the title bar.
- `OnHide`: the group New is forgotten.
- `EventRegistry` callback `ContainerFrameItemButton.OnItemClicked` (the end of the game's click on
  an item): bag swaps (`BagSwap.lua`).
- Each tab's `OnEnter` (`HookScript`): holding an item over a tab switches to it.
- Each item button's `OnClick` (`HookScript`, once per button): Alt-click opens the item menu.
- `UpdateQuestItem` per button: hides the game's yellow quest border.
- `UpdateContainerFrameAnchors`: moves the reagent bag window away.
- `MicroMenuContainer:SetPoint` / `Layout`: keeps the logo next to the micro menu.
- `BagsBar:Show`, `BagItemSearchBox:Show`, `CountContainer:Show`, `PortraitButton:Show`,
  `BagItemAutoSortButton:Show`, the money frame's border `Show`: hide the game's parts Tidy Pack
  replaces.
- `TooltipDataProcessor.AddTooltipPostCall` (items): quest, lock, group and count lines.
- `SmartNavigation:SetUseGridNavigation` and `SelectButton`: the controller cursor (`Gamepad.lua`).

## 4. Features

Status: ✅ tried in the game · ⚠️ built, not tried in the game yet.

**Bags tab**
- ✅ Groups in a fixed order: Favorites, your own groups, New, Consumables, Equipment, crafting
  materials per type (your professions first), Recipes & Gems, Quest Items, Keys, Miscellaneous,
  Spare Bags, Junk. Five parts with a thin line between them. Empty groups are hidden. Similar items
  sit side by side (`Categories.lua`, `Groups.lua`). A group with items that isn't in the order is
  shown last under "Other", so no item can ever be hidden.
- ✅ 14 columns, up to 20 when the window would otherwise be taller than the screen.
- ✅ New loot stays in New until the window closes.
- ✅ Item level and "BoE" on uncommon or better weapons and armor.
- ⚠️ Upgrade arrows (`bags-greenarrow`) on gear you can use with a higher item level than the worse
  of the slots it fits (`upgradeArrows`). "Can use" = no red line in `C_TooltipInfo.GetBagItem`
  (`leftColor`, confirmed in Forever's `TooltipDataHandler.lua`), cached per link.
- ⚠️ Group headings: point at one for items, slots and merchant value; drop an item on it.
- ⚠️ Drop anywhere: hold an item over the bags – gold glow and "Drop anywhere to put it in your
  bags". With a controller, the "Add to bag" slot is the drop target.
- ⚠️ Special bags (quivers, soul bags, profession bags, the reagent bag) get their own part at the
  bottom with the bag's icon and name. With the mouse, the reagent bag is drawn with own buttons
  and the game's separate reagent window is moved off screen (✅ tried 2026-11-14).
- ⚠️ "Show by bag" (`groupByBag`): each bag and bank tab in slot order with its empty slots;
  Favorites and own groups stay on top.
- ⚠️ Search box (`showSearchBox`, off by default): in the title bar of Bags and Bank; matches glow
  blue, the rest dims; works on the saved bank by item name.
- ⚠️ Bag row at the bottom, on a taller money row: "N free" (red at 5 or fewer) and small icons of
  your bags; point at one to light up its items; drop a bag on one to swap it (`PutItemInBag`).
  Point at "N free" for each bag's free slots. In the Bank tab the row shows the bank's slots (below).
- ⚠️ Bag swap: right-click a bigger spare bag (or Equip with a controller) to replace your smallest
  bag (`BagSwap.lua`, outside combat).
- ⚠️ Keyring: with a controller (and `showKeyring` on) the game shows keys in the bag window and
  they go to Keys; with the mouse the keyring keeps its own button, which Tidy Pack doesn't touch.
- ✅ The game's sort button, portrait menu and bag count are hidden (nobody can turn off "Combined
  Bags" by mistake). Tidy Pack turns on "Combined Bags" once, at the first login.

**Logo**
- ✅ The Tidy Pack logo replaces the game's bag buttons (`replaceBagBar`). Click opens and closes the
  bags, right-click opens the gear menu, a dropped item goes into the bags. No count on the logo.

**Marks and the gear button**
- ✅ Gear button (`Marks.lua`, the game's `DropdownButton`) at the top right of the window. With an
  item on the cursor: Add to Favorites / Junk List / Group ▸ / Add All "type" Items to Group ▸.
  Without: Junk List…, Groups…, Show ▸ (headings On items, In tooltips, In the window), Merchants and
  loot ▸, Bag and bank ▸, Language ▸, Show Tips Again. Checkboxes keep the menu open.
- ✅ Alt-click (Option-click on a Mac) an item for the same menu; "..." on every item while Alt is
  held; a tooltip line says so.
- ✅ Favorites and the junk list (per account, by item id). Junk list items get the game's junk coin,
  sort last in Junk and are suggested first when the bags are full.
- ⚠️ Own groups (`Groups.lua`, up to 8 per account): single items or a whole type; managed in the
  bag window (gear → Groups…).
- ⚠️ Junk list panel in the bag window (gear → Junk List…): drop, type a name, link or number,
  remove with the red cross, and the two loot questions.

**Merchants and loot**
- ✅ Locks at merchants (`lockAtMerchant`): quest items, items a quest needs, items in the game's
  equipment sets. Lock icon, can't be clicked; the tooltip says why. The merchant's own "Sell All
  Junk" button doesn't know about the locks. Quest locks match item names in the game's language;
  with a controller, locks can't change in combat and catch up afterwards.
- ⚠️ Junk list loot (`suggestOnLoot`): looting an item on the list asks right away whether to delete
  it. Bags full (`suggestWhenFull`): a panel under the loot window suggests the junk list first, then
  the cheapest grey item if the new loot is worth more. Nothing is deleted without pressing Delete.

**Bank tab** (issue #4: test in the game)
- ⚠️ At a banker: the bank sorted in the same groups, with own buttons; right-click and drag between
  bank and bags; drop on empty space to put an item in the bank. The game's bank window is invisible;
  gear → Bag and bank → "Show the game's bank window" brings it back (buying a bank slot). Closing
  the bags closes the bank. Setting `bankTab`.
- ⚠️ Away from the bank: what the bank held last time (per character), with tooltips.
- ⚠️ Bottom row in Bank (`ns.UpdateBottomRow` in `Layout.lua`, `ns.GetBankSlots` in `Bank.lua`; owner's
  wish 2026-11-15, sketch `.design/sketch-bank-slots.html`): the bank itself (chest, its size), bank
  bags (icon and size), bought empty slots, "+" for the next slot (price from
  `C_Bank.FetchNextPurchasableBankTabData`; a click opens the game's bank window, because
  `C_Bank.PurchaseBankTab` has restrictions) and locks for the rest. Point at the bank or a bag: its
  items light up. Drop a bag on a bag slot: it goes in or swaps
  (`PickupContainerItem(Enum.BagIndex.Characterbanktab, index)`, like the game's own bank bag buttons);
  drop another item: the first free slot there. "N free" tooltip: free per container, bag slots
  bought and filled, the next price, and how old the saved bank is. The bank's first part is called
  Bank (it was "Tab 1" with a "?"), bank bags have their item's name, and "Show by bag" headings add
  "· N free".
- ⚠️ Tooltip counts (`showCounts`, `Characters.lua`): "Bags 12 · Bank 40 · Total 52" for this
  character, only when the item is in the bank.
- ⚠️ Counts on other characters (`showOtherCharacters`, `Characters.lua`; owner's wish 2026-11-15,
  sketch `.design/sketch-characters.html`): each character saves itemID counts for its bags
  (backpack, bags, reagent bag) and its saved bank in `TidyPackDB.characters` – 2 seconds after
  `BAG_UPDATE_DELAYED`, at `BANKFRAME_CLOSED` and at `PLAYER_LOGOUT` (skipped when the backpack has 0
  slots, so a logout without bags never wipes the counts). When another character on this realm or a
  connected one (`GetAutoCompleteRealms`) has the item, the tooltip lists: you first, then the
  others with the most first, names in class color (`C_ClassColor.GetClassColor`), at most 8 lines,
  "+N more characters", Total. Gear → Bag and bank → Forget a Character (newest first, other realms
  with " - Realm") asks with `ns.ShowDialog`. Not counted: mail, worn items, the account bank.
- ⚠️ Money's tooltip (`Characters.lua`, sketch `.design/sketch-money.html`): each character also saves
  `GetMoney()` (and at `PLAYER_MONEY`). Pointing at the coins in the bag window (`HookScript` on
  `MoneyFrame.GoldButton`/`SilverButton`/`CopperButton`; the game's click still picks up money) shows
  Money, "Total: …" in gold, you first, the others with the most first, "+N more characters" and
  "Account bank" (`C_Bank.FetchDepositedMoney(Enum.BankType.Account)`, only when above 0). No tooltip
  with no other character and an empty account bank. Needs `showCounts` and `showOtherCharacters`.
- Not built: the account (warband) bank, buying a slot right from the "+", controller.

**Quests tab**
- ⚠️ Quest items show "3/7" (green when done); the tooltip says which quest. Extra stacks beyond
  what a quest needs are normal items and can be sold.
- ⚠️ Quests tab: ready quests first, then in progress, then other quest items; a heading or quest
  opens with a click; scrolls with the mouse wheel; a dot on the tab when a quest is ready.
- ⚠️ "Quest items in Bags" off: the Bags tab shows one line with how many slots they use.
- ⚠️ With Questie (QuestieDB, optional): a yellow exclamation mark on items that quests you can take
  now or within 5 levels will need, and "Needed later for: …". Without Questie: one chat line, once.
  QuestieDB's data for Forever's new quests isn't complete.

**Other**
- ⚠️ Languages (section 7).
- ✅ First-time guide (`Tour.lua`): four tips – Alt-click, the gear, the Bank tab, the Quests tab.
  Not shown with a controller or with the game's tips turned off. Gear → Show Tips Again.
- ✅ Tidy Pack's page in Esc → Options → AddOns: logo, version, author, short help, a link to copy,
  Show Tips Again.
- ⚠️ Controller cursor (`Gamepad.lua`): starts on the newest loot, LB/RB jump between groups, the
  D-pad goes to the nearest item, never stays on a hidden button. The panels (junk list, groups) and
  the Bank tab aren't reachable with the cursor yet (issue #6).
- Removed: the Sets tab (2026-11-14, the game's Equipment Manager does the job; old "TP" macros print
  a line), Tidy Pack's own Sell Junk button (2026-11-09).

## 5. Saved data

`Core.lua` has the defaults and the migrations (`DATA_VERSION = 2`, `CHAR_DATA_VERSION = 2`). New keys
with a default need no migration; a key that is removed or changes meaning needs one.

- `TidyPackDB` (account): `favorites` and `junk` (item id → true); `groups` (list of
  `{ id, name, items = { [itemID] = true }, types = { ["class:subclass"] = true } }`) and
  `nextGroupID`; `questOpen` (open headings in the Quests tab); `tourDone`; `questieNoticeShown`;
  `combinedBagsTurnedOn`; `language` (`"auto"` or a language code); the options `itemLevelAndBoE`,
  `upgradeArrows`, `questHints`, `showCounts`, `showOtherCharacters`, `tooltipLines`,
  `showQuestItemsInBags`, `junkValue`,
  `showSearchBox` (false), `groupByBag` (false), `lockAtMerchant`, `suggestOnLoot`, `suggestWhenFull`,
  `replaceBagBar`, `bankTab`; `characters` (`["Name-Realm"] = { name, realm, class, time, bags =
  { [itemID] = count }, bank = { [itemID] = count }, money } }`, `bank` nil before a visit to a banker);
  `dataVersion`.
- `TidyPackCharDB` (character): `bank` = `{ time, free, maxTabs, nextCost, tabs = { { id, index, name,
  icon, link, slots, free } }, items = { { link, count, quality, icon, bag, slot, quest, bound,
  noValue } } }`, saved at every change at a banker; `dataVersion`. Banks saved before 1.2.0 lack
  `index`, `free`, `maxTabs` and `nextCost` until the next visit to a banker (read with defaults).
- Migrations: account 2 (2026-11-10) removes `sellJunkButton`; character 2 (2026-11-14) removes
  `sets` (the Sets tab).

## 6. Files

- `TidyPack.toc` – name and load order. `Locales.lua` and `Locales/*.lua` first, then `Core.lua`.
- `Locales.lua` – `ns.L`, `ns.LANGUAGES`, `ns.SetLanguage`, `ns.AddTranslation`.
- `Locales/<code>.lua` – one translation per language; `esMX.lua` is changes on top of `esES.lua`.
- `Core.lua` – saved data, migrations, events, `ns.OnLoad`, `ns.KeyText`, `ns.FitButtonText`,
  blocked-action reporting, "Combined Bags".
- `Categories.lua` – which group an item belongs to, order within a group, crafting groups.
- `Groups.lua` – own groups: data, rules, order, dialogs, menus, tooltip line.
- `QuestLock.lua` – locks (quests, equipment sets), merchant state, quest tooltip lines.
- `QuestHints.lua` – items that later quests need (QuestieDB).
- `BagSwap.lua` – bag swaps and which bags get a green arrow.
- `Layout.lua` – rearranges the bag window: groups, parts, headings, marks, locks, special and
  reagent bags, money, bag row and the bank's row, search, views, drop glow, fade. (2,545 lines – being
  split, section 10.)
- `Tabs.lua` – the tabs Bags, Bank and Quests and the switch between views (`ns.SetView`,
  `ns.GetView`); loads right after `Layout.lua`.
- `Bank.lua` – the Bank tab, saved bank, the bank's slots and bags, the game's bank window.
- `Characters.lua` – counts in item tooltips, for this character and your other characters; the
  money's tooltip; Forget a Character.
- `QuestsView.lua` – the Quests tab.
- `Marks.lua` – favorites, junk list marks, Alt-click, the gear button and its menu, Language ▸.
- `Panels.lua` – the junk list and own groups in the bag window.
- `Tour.lua` – the first-time guide.
- `LogoButton.lua` – the logo instead of the game's bag bar.
- `Junk.lua` – what counts as junk (`ns.GetJunkKind`).
- `MakeRoom.lua` – the delete questions (junk list loot, full bags).
- `Options.lua` – the gear menu's options (`ns.optionMenus`), the options page, `/tidypack`, the
  addon menu.
- `Gamepad.lua` – the controller cursor, cursor locks, button icons in text.
- `Media/Logo.tga` – the logo in the game (made from `.design/logo.png`).
- `.wow-check/` – patch-check baseline and watch list.
- `.design/` – sketches (HTML and PNG), logo sources, CurseForge texts; never in the zip.
- `.github/` – the GitHub front page (`README.md`) and the release workflows.

## 7. Languages

- Tidy Pack follows the game's language (`GetLocale`) or the one picked under gear → Language ▸, any
  of the game's eleven: enUS, deDE, esES, esMX, frFR, itIT, ptBR, ruRU, koKR, zhCN, zhTW (`enGB` shows
  as enUS, `ptPT` as ptBR). No Swedish – the game has no Swedish client. A change needs a reload of
  the interface, so choosing a language asks first (Tidy Pack's own dialog, `ns.ShowDialog`): "Reload
  Now" saves the choice and reloads (`C_UI.Reload`), "Cancel" changes nothing (the owner's wish
  2026-11-15). A choice that shows the same language is saved without asking. The dialog's buttons
  and height follow the text, so long translations fit.
- The English text is the key: `L["English text"]`. `L` looks up the translation every time a text
  is used. Never build texts when a file loads; `ns.groupNames` and `ns.optionMenus` are (re)built in
  `ns.OnLoad`, and `Core.lua` calls `ns.SetLanguage` before every `ns.OnLoad`.
- In translations `%s`/`%d` keep the English order, and "Alt-" stands before the word for click
  (`ns.KeyText` turns it into "Option-" on a Mac). Buttons with text grow with it
  (`ns.FitButtonText`).
- The translations are machine-made (2026-11-15) using the game's own words where known; the README
  asks for corrections. CurseForge's translation tool could take player corrections later.
- When an English text changes, its translations stop showing until they are redone:
  `check-locales.mjs` lists them. The full guide is in the plugin:
  `skills/wow-maintain/references/translations.md`.

## 8. Test checklist

What the owner tries in the game after larger changes. Start the game fully after a TOC change;
otherwise `/reload`. Have `/console scriptErrors 1` and `/console taintLog 1` on.

**Basics**
1. Tidy Pack is listed and enabled in the AddOns list. First login with "Combined Bags" off: one
   chat line, and the setting is on.
2. B opens the bag window with groups; no bags among the items; no sort button; clicking the
   portrait opens no menu. After `/reload` everything looks the same.
3. Items land in the right group and order (potions before food, weapons before armor); crafting
   materials per type, your professions first; an unusual crafting material still shows.
4. New: loot something – it stays in New while hovered and moves to its group after reopening.
5. Mouse: right-click uses and equips, drag moves, shift-click links, shift-drag splits.

**Marks and menus**
6. Hold Alt: "..." on items; Alt-click the Hearthstone → Add to Favorites (top) → again → Remove.
   On a Mac the tooltip says "Option-click".
7. Junk list: Alt-click a white item → Add to Junk List (last in Junk, junk coin); gear → Junk List…:
   add by dropping, name or shift-clicked link; remove with the cross; scroll a long list.
8. Own groups: drop a potion on the gear → Add to Group ▸ New Group… "Potions"; drop another →
   Add All "Potion" Items to Group ▸ Potions; tooltip "Tidy Pack group: Potions"; gear → Groups…:
   ▲▼, Rename, ✕, rules; 8 groups disables "New Group"; still there after `/reload`.
9. Gear menu: Show ▸ has the headings On items, In tooltips, In the window; each line explains
   itself; a checkbox keeps the menu open and the window changes behind it.
10. Group headings: point at one – items, slots, value; drop an item on one – it goes into the bags.

**Bags window**
11. Drop anywhere: gold glow and text; dropping fills the first free normal slot.
12. Bag row: "N free" red at 5 or fewer, at the same height as the money; point at "N free" – the
    total in gold and each bag (special bags grey); point at a bag icon – its items light up; drop a bigger bag
    on one – it swaps; right-click a bigger spare bag – replaces the smallest (in combat: a message).
13. Special bags (quiver, profession bag) at the bottom under a line, also right after `/reload`;
    the reagent bag's items in their own part; its separate window never shows.
14. Show by bag: each bag on its own rows with empty slots; Favorites and own groups stay on top.
15. Search box (gear → Show → In the window): matches glow, the rest dims, also in Bank away from the
    banker; disenchant an item after a search – no "blocked from an action".
16. Large bags: the window gets wider (up to 20 columns) instead of taller than the screen; tabs,
    gear and money stay reachable; the window doesn't change size when switching tabs.
17. Upgrade arrow on wearable gear better than what you wear; none on items you can't use.

**Logo**
18. Click the logo: bags open and close. Right-click: the gear menu (bags open first if closed). Drop
    an item on it: it goes into the bags. Disenchant and "use an item on another" after opening with
    the logo: no "blocked from an action". In combat: the logo still opens and closes the bags.

**Merchants and loot**
19. At a merchant: quest items, items a quest needs and equipment-set items show a lock, can't be
    clicked, the tooltip has the red line. "Lock items at merchants" off: they can be clicked.
20. Loot an item on the junk list: the question comes (under the loot window, or at the top when it
    closes); Delete deletes that item, Not now closes; in combat the question waits.
21. Full bags: loot fails with "Inventory is full" – the panel suggests the junk list or the cheapest
    grey item; Delete deletes it. No blocked-action message.

**Bank**
22. At a banker: the bags open on the Bank tab, sorted, with no blue frame on the slots (also the
    first time after `/reload`); the game's bank window never shows, not even for a moment, and the
    Bags tab doesn't flash first. The bag window has the same size whether the bags were open or
    closed when you spoke to the banker.
    Right-click an item in Bank → bags, and in Bags → bank; drag between the tabs; drop on empty
    space in Bank → bank; "N free" shows the bank's free slots. Gear → "Show the game's bank window"
    and back. Closing the bags closes the bank. Open the character window (C) at the banker.
    Bottom row: the chest with its size, your bank bags with their size, an empty bought slot, "+"
    (tooltip with the price; a click shows the game's bank window) and locks. Point at the chest or a
    bag – its items light up. Drop a bag on an empty bag slot – it goes in; on a bag – they swap;
    drop another item on a bag – it goes in that bag. Point at "N free" – free slots per container.
    Show by bag: headings "Bank · N free" and the bags' names. Buy a slot – the row shows it.
23. Away from the banker: "You're not at a banker – this is what your bank held today …"; a character
    that never visited: "Visit a banker once …". "Use the Bank tab at bankers" off: the game's window.
    The bottom row and the "N free" tooltip as last time, with "Last seen today".
24. Tooltip counts: "Bags N · Bank N · Total N" for an item in both; none for an item only in the
    bags; counts follow changes at the banker. Other characters: log in with a second character on
    the same realm (visit a banker with it), then back – the tooltip of an item both have lists the
    two, names in class colors, the most first, and Total; an item only the other one has shows only
    that line. Gear → Show → Other characters off: only this character's line; "Bag and bank counts"
    off greys it out. Gear → Bag and bank → Forget a Character → the other one with "today" → the
    question; Cancel keeps it, Forget removes its line.
    Money: point at the coins with two characters – Money, "Total" in gold, both with their money; with
    the other one forgotten (and an empty account bank) – no tooltip; click a coin – the game's box
    for picking up money opens as before.

**Quests**
25. Take a quest that needs items (e.g. 3 of 7): "3/7" on the item, green when done; tooltip "Needed
    for: …"; two stacks beyond the need – the extra one can be sold.
26. Quests tab: ready quests first; headings and quests open with a click and stay open after
    `/reload`; mouse wheel scrolls; a dot on the tab when a quest is ready. "Quest items in Bags" off:
    one line in Bags, and clicking it opens Quests.
27. With Questie: yellow exclamation marks and "Needed later for: …". Without: one chat line, once.

**Languages**
28. Gear → Language ▸ → Deutsch: the menu closes and a question asks to reload. Cancel: nothing
    reloads, and Language ▸ still has the old language ticked. Again → Reload Now: tabs, menus,
    headings, tooltips and panels in German, and the question's text and buttons fit. Try Русский,
    한국어 and 简体中文: characters show (no boxes); long buttons (Rename, Add, Delete, Not now, Show Tips
    Again) don't clip. Back to Automatic → Reload Now: the game's language again.

**Guide and options page**
29. Gear → Show Tips Again, reopen the bags: four tips – an item, the gear, the Bank tab, the Quests
    tab; Next goes on, Got it ends.
30. Esc → Options → AddOns → Tidy Pack: logo, version, help, link (click, Cmd+C); opens in combat
    without "Interface action failed". `/tidypack` with bags closed opens this page; with bags open,
    the gear menu. An old "TP" set macro prints the Equipment Manager line.

**Controller**
31. Loot and open the bags: the cursor is on the new item (else the first item), never on an empty or
    hidden spot. LB/RB jump between groups; the D-pad goes to the nearest item. Use, Equip, Sell,
    Split work; after selling, the cursor is on the item that took its place. Pick up an item with A
    and drop it on the gear (its tooltip shows A). At a merchant A and X do nothing on locked items.
    No "Interface action failed". Keys show in Keys.

**Combat and performance**
32. In combat (training dummy): use a potion from the bags; the window updates while looting; with a
    controller the cursor works as without Tidy Pack and is fixed after combat.
33. `/dump C_AddOnProfiler.GetAddOnMetric("TidyPack", Enum.AddOnProfilerMetric.PeakTime)` after
    opening, looting and selling: the longest frame Tidy Pack used, in ms (a frame is ~16 ms at 60 fps).

### Tried in the game
- 2026-11-09 (`v0.2.0-alpha1`–`alpha2`): groups, favorites, item level, junk value, options page,
  tabs. Fixed: too long option labels, unequal tabs.
- 2026-11-09 (`1.0.0` with a controller): a crash with special bags (`contentHeight` nil) – fixed;
  1.0.0 must never be published.
- 2026-11-10–11: many layout fixes from the owner's screenshots (money row, bag row, spacing,
  scrolling Quests). 1.0.1 was released before the owner had tried its last zip; 1.1.0 was tried
  first.
- 2026-11-12: "blocked from an action" with Esc (removed handler) and with disenchant (logo opened the
  bags from addon code – fixed with the secure logo; confirmed working).
- 2026-11-14: guide loads without errors; reagent bag with the mouse works (empty and with items);
  options page error with the secure button found in the console log – button removed.
- 2026-11-15: languages and the reload question work; the Bank tab with its bottom row (screenshots:
  chest 48, an empty bought slot, "+", locks; the free tooltips). Fixed from screenshots: a blue
  shop highlight on every bank slot, the money a little lower than "N free", the game's bank window
  flashing when the bank opened, and smaller bags when the bank opened them. The owner then said it
  all works and 1.2.0 is ready.

## 9. Publishing

- Released: **1.0.1** (2026-11-10), **1.1.0** (2026-11-11) and **1.2.0** (2026-11-15), all through the
  release workflow.
  **1.0.0** was uploaded by hand as "publish manually once approved" and has the special-bag crash:
  never publish it.
- **1.2.0** was released 2026-11-15 with the tag `v1.2.0` (run 43742598575: "Success!" for
  CurseForge and the GitHub release). Left for the owner on CurseForge: paste the new Summary
  (`.design/curseforge-page.md`) and Description (`README.md`), and add new images. CurseForge
  approved the file the same day.
- Steps for every release: set `## Version:`, rename `## Unreleased` to `## <version> (date)`, run
  `check-addon.mjs --release`, commit, ask, push, ask, then push the tag `v<version>`, and read the
  run's log for `Success!`.
- CurseForge has no field for an addon's languages in the upload API; the project's Localization
  tool is only for translating phrases. The languages are listed in `README.md` (the description).
- `.github/workflows/release.yml` runs only for clean version tags (`vN.N.N`): it checks the tag
  against `## Version:` in the TOC, builds the zip with BigWigs packager v2 from `.pkgmeta` (`-u` for
  Unix line endings, `-n "TidyPack-<version>:TidyPack-<version>"`), uploads it to CurseForge as a
  Release (`CF_API_TOKEN`, `## X-Curse-Project-ID`) and makes a GitHub release. Tags like
  `v1.2.0-alpha1` start nothing.
- `.github/workflows/package-check.yml`: a dry run started by hand (Actions → Package check → Run
  workflow); the zip is kept for 7 days. The packager needs bash 4.3+ (the Mac's is 3.2), so build
  checks run on GitHub.
- Test versions for other computers: a GitHub pre-release (`gh release create --prerelease`) with the
  zip from `package-addon.mjs` (it lands in `.release/`, which git ignores).
- `README.md` is the CurseForge description and is in the zip; `.github/README.md` is the GitHub
  front page. Keep their feature lists in step. The logo is `.design/logo.png` (source `logo.svg`);
  the social preview (`.design/social-preview.png`) is set by hand under Settings → General.

## 10. Ideas and decisions

**Binding decisions** (dates; details in `git show a04b27b:AGENTS.md`)
- 2026-11-08: Baganator (All Rights Reserved) is inspiration only – no code copied.
- 2026-11-09: Rearrange the game's own bag window instead of an own window – it is the only way to
  keep the game's item actions and controller support. The window stays where the game puts it.
- 2026-11-09: Questie is an optional dependency; no data copied (license). One chat notice, approved.
- 2026-11-09: Blizzard's policy allows the game's templates, fonts and atlases but not copying its
  files or looking like Blizzard; panels are titled "Tidy Pack".
- 2026-11-09: No own LB/RB bindings (the controller binding stack is shared and would taint).
- 2026-11-09: Deleting only on the player's Delete press; the controller cursor never moves to Delete.
- 2026-11-09: No own Sell Junk button; the game's "Sell All Junk" exists.
- 2026-11-09: Tabs like the spellbook (`TabSystemTemplate` + `TabSystemTopButtonTemplate`), above the
  window's top edge, all the same size; all tabs share one height (`sharedHeight`), set by Bags.
- 2026-11-11: The logo replaces the game's bag bar; bags are swapped in the bag row.
- 2026-11-12: All options in the gear menu; the game's options page only informs.
- 2026-11-14: Solid window background; the Sets tab removed; the window opens on Bags.
- 2026-11-15: Languages (section 7); Show ▸ with headings; the guide shows the Bank tab; the Bank
  tab's bottom row shows the bank's slots, and "+" sends you to the game's bank window to buy; counts
  on your other characters in item tooltips, with an option and Forget a Character (still no
  browsing of other characters' bags); the money's tooltip for all characters; the game's bank window
  is made invisible as soon as it shows (it flashed for a frame).

**Open ideas** (proposed, not decided)
- Counts on other characters: mail, worn items and the account bank too.
- The account (warband) bank in the Bank tab – Forever has it (`Enum.BankType.Account` in
  `Camelot/BankFrame.lua`).
- Controller access to the Bank tab and the panels (issue #6).
- Split `Layout.lua` into smaller files (owner's yes 2026-11-17), one step at a time, each tried
  in the game: 1 `Tabs.lua` (done, not tried yet), 2 `GameWindow.lua`, 3 `BottomRow.lua`,
  4 `ItemMarks.lua`, 5 `Search.lua`. Code moves unchanged; shared parts go through `ns.layout`.
  Players notice nothing, so no release of its own. Lua 5.1 allows 200 locals in a file's main
  chunk; `Layout.lua` had 143.
- Bank: buy the next bag slot right from the "+" (`C_Bank.PurchaseBankTab` must be called in the
  click itself; issue #4).

**Rejected by the owner – don't suggest again unless asked**
- 2026-11-09: several looks, choosing the order, mail and trade, browsing other characters' bags.
- 2026-11-12: collapsible groups, a "what's new" window, moving or scaling the window, sort options,
  a sell-junk button, changes to the CurseForge page, selecting and moving several items at once.

**Can't be done**: selling or opening items automatically (the game needs a click on a secure button).

## 11. Sources

- WoW Forever: https://warcraft.wiki.gg/wiki/Patch_1.60.1
- Interface numbers and TOC suffixes: https://warcraft.wiki.gg/wiki/TOC_format
- Blizzard's code for Forever: https://github.com/Gethe/wow-ui-source/tree/forever
- Using items is protected: https://warcraft.wiki.gg/wiki/API_C_Container.UseContainerItem
- Deleting items: https://warcraft.wiki.gg/wiki/API_DeleteCursorItem (hardware event since 9.0.2,
  one item per event since 9.1.5)
- Swapping a non-empty bag: https://warcraft.wiki.gg/wiki/Bag
- Blizzard's add-on policy: https://us.forums.blizzard.com/en/wow/t/ui-add-on-development-policy/24534
- QuestieDB for other add-ons: https://github.com/Questie/QuestieDB (`docs/api.md`, `docs/forever.md`,
  `LICENSE.md`); Questie with Forever support: https://github.com/Questie/Questie
- Controller cursor in Forever: `Blizzard_GamepadSmartNavigation` (`SmartNavigation.lua`,
  `Utility.lua`, `SecureHelper.lua`) and `SetupGamepad`, `SmartNavPanelInfoAdded`,
  `Gamepad_SetCursorToBag` in `Blizzard_UIPanels_Game/Mainline/ContainerFrame.lua`
- Tips and the controller: `HelpTip:AreHelpTipsEnabled` in `Blizzard_SharedXML/HelpTip.lua`,
  `Blizzard_HelpPlate/Camelot/HelpPlateOverrides.lua`, `TutorialLogic:IsNPEAllowed` in
  `Blizzard_NewPlayerExperience/Camelot/`
- Languages: `WowLocale` in `LFGListInfoDocumentation.lua`; font families in
  `Blizzard_Fonts_Shared/Shared/Fonts.xml`
