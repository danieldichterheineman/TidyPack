# Changelog

## Unreleased

- Fixed: with a special bag (a quiver, ammo pouch, soul bag or profession bag such as a
  mining bag), sorting could stop working after logging in or reloading, leaving the
  game's own grid.
- Cleaner look: a solid, dark background behind your items, so the world no longer shows
  through, and more room between the groups.
- The Sets tab explains itself when you have no sets yet.
- Sets: a gear button on every set opens its menu, also with a controller. The new "Add
  What I'm Wearing" puts everything you wear into the set in one click.
- New setting: "Lock quest and set items" turns the locks at merchants on or off.
- Removed the Sell Junk button. Use the merchant's own "Sell All Junk" button instead. Note
  that it sells every grey item and doesn't know about Tidy Pack's locks or junk list.
- More room between your items and the border of the background, and a lighter background.
- The window is now 14 items wide, and gets wider (up to 20) when your bags are so full
  that it would otherwise be taller than the screen.
- The Sets tab is as tall as the Bags tab, so the window no longer changes size when you
  switch. With a few sets it also shows a short tip.
- The number of free slots is shown on the backpack icon, also when you play with a mouse.
- The slot that shows your free slots is now called "Add to bag" and stands next to Favorites
  instead of at the bottom. It has a + and a tooltip, and an item you drop on it goes into
  your bags. Controller: the cursor still starts on an item.
- Your own groups: make up to 8 groups with names you choose, like "Potions" or "Food &
  Drink". Drop an item on the gear button and choose "Add to Group" for that item, or "Add all
  ... items to Group" for the whole type (all potions, all bandages …). They come after
  Favorites and "Add to bag". Manage them under Esc → Options → AddOns → Tidy Pack → Groups.
- Quest items: each quest item shows how many you have and how many the quest needs (3/7), and its
  tooltip names the quest. A new Quests tab lists every quest that needs items, ready ones first, with
  your items, a progress bar and what you are still missing. Stacks of an item beyond what the quest
  needs are no longer locked at merchants. A dot on the tab shows when a quest is ready to turn in.
  The setting "Show quest items in Bags" can move them out of the Bags tab (a line there says how many
  slots they use).
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
