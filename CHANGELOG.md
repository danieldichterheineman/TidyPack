# Changelog

## Unreleased

- New Bank tab, between Bags and Sets. At a banker, your bank is sorted in the same groups and
  parts as your bags, and the game's bank window is hidden. Right-click an item to move it between
  your bank and your bags, or drag it onto the other tab. Drop an item on an empty spot in the Bank
  tab to put it in your bank.
- Away from the bank, the Bank tab shows what your bank held the last time you were there (for
  each character). You can see the items and their tooltips, but not move them.
- The gear button's menu at a banker can show the game's bank window again, for example to buy a
  bank slot. Turn the Bank tab off with "Use the Bank tab at bankers" in the settings.

## 1.1.0 (2026-11-11)

- More room for your items: the search box and the bag icon in the top left corner are gone, and
  the items start right under the title. Your free slots are shown in "Add to bag".
- Bags, Sets and Quests are always the same size, so the window no longer changes when you
  switch tabs. It only grows or shrinks when your bags do.
- The Sets tab has five numbered places, the same as the key bindings "Equip set 1–5". Click an
  empty place, or drop an item on it, type a name and press Enter to make a new set. Its icon is
  its first item's; change it with "..." → Edit Name and Icon. The New Set button is gone. You
  can have at most five sets.
- A green arrow on weapons and armor you can use that have a higher item level than what you wear
  in that slot. Turn it off with "Show upgrade arrows" in the settings.
- Quest items no longer have the game's yellow border – they're already in Quest Items. Items
  that start a quest keep their yellow exclamation mark.
- The reagent bag's own window is attached to the left of the Tidy Pack window. With a mouse the
  game always shows the reagent bag in its own window, so its items aren't sorted into groups.
- The Tidy Pack logo replaces the game's backpack and bag buttons at the bottom right. Click it
  to open your bags, right-click for the settings, or drop an item on it. It sits right next to
  the micro menu and looks like the game's own backpack button. Turn it off with "Replace the game's bag buttons" in the settings.
- Your bags are shown as small icons at the bottom of the bag window, next to your free slots,
  on a taller money row with your money on the right.
  Point at one to see what's in it; drop a bigger bag on one to swap it.
- Holding an item over the Bags, Sets or Quests tab switches to that tab.
- Bags, Sets and Quests are always exactly the same height, set by your bags (never less than
  the five places in Sets). When the Quests tab has more than fits, scroll it with the mouse
  wheel; a thin bar on the right shows where you are.
- The Bags tab is in five parts, each starting on a new row with a thin line above: your own
  (Favorites, your groups, New), everyday (Consumables, Equipment), crafting materials, quest
  items, and the rest (Keys, Miscellaneous, Spare Bags, Junk). Special bags stay at the bottom.
- With a mouse, the "Add to bag" slot is gone – drop items anywhere instead. Your free slots are
  shown at the bottom left ("10 free", red when few are left). With a controller the slot stays.
- The leftover Trade Goods group (recipes, gems, enhancements) is now called "Recipes & Gems".
- A short guide the first time you open your bags, in the game's own yellow tip boxes: Alt-click
  on items, the gear button, Sets and Quests. Show it again under Esc → Options → AddOns → Tidy
  Pack → Tips. It replaces the blue tip line at the bottom of the bags. Like the game's own tips,
  it doesn't show with a controller or when the game's tips are turned off.
- Hold an item over your bags and the background lights up: drop it anywhere on an empty spot
  to put it in your bags.
- Trade Goods are split by type – Cloth, Leather, Herb, Metal & Stone, Cooking and so on – with
  the ones your professions use first, marked with the profession's icon and name.
- Drag a set's icon to an action bar: Tidy Pack makes a macro ("TP <set name>") with the set's
  icon that puts the set on. It uses one of your account's macro slots, and can't be made in
  combat. Renaming the set or changing its icon updates the macro.
- Everything for sets happens in the bag: click a set's icon to choose a new one from a grid
  (the set's own items first), and rename a set right on its row ("..." → Rename).
- Fixed: the icon list in the set name window was empty.
- When quest items are hidden from the Bags tab, they are shown as one slot with their number.
  Click it to open the Quests tab.
- The Quests tab starts right away, without the summary line.
- On a Mac, the texts say Option-click instead of Alt-click.

## 1.0.1 (2026-11-10)

New

- Quests tab: a list of the quests that need items, with ready ones first. Open "In progress",
  then a quest, to see your items and what is still missing. A dot on the tab shows when a quest
  is ready to turn in, and your open sections are remembered.
- Quest items show how many you have and how many the quest needs (3/7), and their tooltip names
  the quest. Stacks beyond what the quest needs are no longer locked at merchants.
- Your own groups: make up to 8 groups with names you choose, like "Potions". Add a single item,
  or a whole type at once ("Add all ... items to Group"). They come after Favorites and "Add to
  bag". Manage them under Esc → Options → AddOns → Tidy Pack → Groups.
- Alt-click an item for a menu: favorite, junk list, sets and groups. Holding Alt shows a small
  "..." on every item, and a tip in the Bags tab explains it the first few times.
- Sets: "Add What I'm Wearing" puts everything you wear into a set in one click. Each set has a
  "..." button for its options, which also works with a controller.
- "Add to bag": the slot that shows your free slots now stands next to Favorites, and an item
  you drop on it goes into your bags. The free-slot count is also shown on the backpack icon.
- New settings: "Lock items at merchants" and "Show quest items in Bags".

Changed

- The gear button sits next to the close button on every tab. Click it for your junk list,
  groups and settings, or drop an item on it for the item's menu.
- Cleaner look: a solid, dark background behind your items and more room between the groups.
- The window is 14 items wide, and gets wider (up to 20) when your bags are so full that it
  would otherwise be taller than the screen. It keeps its size when you switch tabs.
- The settings page is in a clearer order: Bag window, Merchants, Quests, Junk.
- Alt-click now opens the item's menu instead of marking a favorite directly, and
  Alt-right-click no longer marks junk. Both are in the menu.
- Removed the Sell Junk button. Use the merchant's own "Sell All Junk" button instead. Note
  that it sells every grey item and doesn't know about Tidy Pack's locks or junk list.

Fixed

- With a special bag (a quiver, ammo pouch, soul bag or profession bag such as a mining bag),
  sorting could stop working after logging in or reloading, leaving the game's own grid.
- If the game ever blocks something because of Tidy Pack, a line in chat now says what was
  blocked, so you can report it.

## 1.0.0 (2026-11-09)

First public release.

- The game's bag window shows everything you carry, sorted into groups: Favorites, New,
  Consumables, Equipment, Trade Goods, Quest Items, Keys, Spare Bags, Miscellaneous, Junk and
  Free. Similar items sit side by side, and empty groups are hidden.
- Special bags – quivers, ammo pouches, soul bags, profession bags and the reagent bag – get
  their own groups at the bottom, under a line, with the bag's icon, name and free slots.
- Items you have looted since you last opened your bags are shown at the top.
- Favorites: Alt-click an item, or drop it on the gear button, to keep it at the top.
- Sets: collect items under a name and icon you pick in the Sets tab, and click a set to put
  it on (not in combat). Missing items are greyed out, and a dot on the tab tells you a set
  is missing something. Sets are saved per character.
- Locked items: quest items, items your active quests ask for and items in your sets can't
  be sold by mistake at a merchant. Their tooltip tells you why.
- Sell Junk: at a merchant, a button above your bags sells grey items and items on your junk
  list – never locked or favorite ones – 12 at a time, so everything can be bought back.
- Junk list: Alt-right-click an item, drop it on the gear button or add it in the settings.
  Tidy Pack asks whether to delete listed items when you loot them.
- Bags full: when something can't be looted, Tidy Pack suggests an item to delete. Nothing is
  deleted until you press Delete.
- Item level and "BoE" on uncommon or better gear, and a free-slot count that turns red when
  5 or fewer slots are left.
- Quick bag swaps: right-click a bigger bag to replace your smallest one.
- With Questie installed, items that quests you haven't taken yet will need get a yellow
  exclamation mark and are never sold or suggested for deletion.
- Controller: the cursor starts on your newest loot, LB and RB jump between groups and the
  D-pad moves to the nearest item.
- Key bindings to open the Sets tab and equip sets 1–5.
- Settings: /tidypack, the minimap's addon menu, or Esc → Options → AddOns → Tidy Pack.
