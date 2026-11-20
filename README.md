# Tamriel Tools: Writ Checker

A master writ readiness check inside sealed master writ tooltips, using a
borderless Crafting Ledger layout.
Your writ description and existing Master Merchant/TTC information stay intact.

## What it checks

- **Blacksmithing, clothing, woodworking, jewelry:** the material-tier passive,
  the exact requested trait, the set's trait count on that specific item, and
  the specific crafting motif chapter. Jewelry does not require a motif.
- **Materials:** refined base materials, trait and style materials, and every
  upgrade step at **100% success**, using ESO's current guaranteed-upgrade API.
  A Crown Mimic Stone can substitute for an unavailable style material, but
  never substitutes for knowing the motif.
- **Provisioning:** recipe learned, Recipe Improvement and Recipe Quality,
  plus ingredients for eight servings using the character's current yield.
- **Enchanting:** Potency and Aspect Improvement, plus all three runes.
- **Alchemy:** Solvent Proficiency, Laboratory Use, and a valid three-reagent
  formula. Prefers combinations with the fewest missing reagents, then the
  largest available stocks. Calculates sixteen items using current yields.
  Undiscovered effects and untranslated runes do not block manual crafting.

### Verdicts

| Verdict | Meaning |
| --- | --- |
| Ready to craft | Checked requirements and materials are satisfied. |
| Just need materials | Knowledge and skills pass; some supplies are missing. |
| Requirements missing | At least one skill, research, motif or recipe is missing. |
| Needs verification | Required data is unavailable or the contract is unsupported. |

Materials show **owned / needed**, with shortages in red. Missing materials
sort first. Counts include the current character's backpack, personal bank
(including ESO Plus bank space as reported by ESO), and Craft Bag. They do
**not** include other characters, guild banks, or housing storage.

## Tooltip appearance

Crafting Ledger is the only layout: a native ESO divider and restrained
single-column rows, with requirement names on the left and details or
quantities aligned on the right. It shows all requirements and materials,
with the required crafting station beneath the other crafting requirements.
The verdict, check count, section headings and station text are centered.
A native ESO horizontal divider separates the check from the writ description.
Explanatory notes and the inventory-scope footer are omitted to stay compact.
There is no addon settings panel or saved preference.

## Inventory indicators

Sealed master writs in the keyboard backpack list have a small marker on
their item icon:

- **Green +:** ready to craft.
- **Red !:** missing requirements or materials.
- **Grey ?:** readiness could not be verified.

The markers use the same checks as the tooltip. Hover the writ for details.
They refresh when the inventory opens and after inventory, skill, research,
recipe or motif knowledge changes. Non-writ items are left unchanged.
Each writ is checked independently; materials are not reserved across writs.

## Install

Requires **LibLazyCrafting**, **LibSets**, **LibCharacterKnowledge**, and
**LibAlchemy**, including their dependencies. Install/update these with your
usual addon manager. No library source is bundled.

Place this folder in your ESO `live\AddOns` directory as
`TamrielToolsWritChecker`, or create a directory junction with that name.
The folder must contain `TamrielToolsWritChecker.txt` directly.
All addon code is in `TamrielToolsWritChecker.lua`; the manifest loads this
single Lua file.
Enable **Tamriel Tools: Writ Checker** in the addon list. For an addon ESO
already recognizes, use `/reloadui` after updating. If a newly installed
addon or changed manifest/new file is not discovered, restart ESO.

Hover a sealed master writ in inventory, bank, guild-store search results,
listings, trade, mail attachments, loot, or supported merchant tooltips.
Clicking a writ link in chat also works. Re-hover to refresh counts after
inventory, research, skill, or recipe changes. `/writchecker` prints help.

## Scope and limitations

- **PC keyboard item tooltips** (`ItemTooltip` and `PopupTooltip`).
  Gamepad tooltip layouts are not supported.
- Checks the **currently logged-in character**, not your other crafters.
- Standard sealed master writs: CP150 equipment, CP150/160 glyphs, eight
  provisioning servings, sixteen potions/poisons. Seasonal/event contracts
  and accepted quest-journal writs are not covered.
- "Ready" means ready to make the item **at the appropriate crafting station**.
  It does not claim you are currently at that station or can reach it.
  Crafting skill/passive rank matters; the character's combat level does not
  independently prevent crafting. The addon does not require CP150 to craft
  CP150 equipment.
- Calculates crafting from scratch. Already-crafted items, partial upgrades,
  and existing food/potion stocks do not reduce the material estimate.
- Requires library data to be loaded. Missing/unknown data is never reported
  as a successful check. UI labels are English; item/style/trait names use ESO's
  localization.
- Does not accept, consume, queue, craft, purchase, or spend anything.

## Tests

From this directory, with Lua 5.1:

```powershell
lua .\tests\runtime.lua
```

For integration checks against the installed LibAlchemy implementation:

```powershell
lua .\tests\runtime.lua '..\..\live\AddOns\LibAlchemy'
```

The tests load the actual addon, with mocked ESO APIs and tooltip controls.
Regressions include weapon motif chapters, malformed and unsupported equipment
or glyph requirements, unavailable recipe skills and alchemy formulas, and slash
help. For dependencies and measured coverage, see the
[shared setup and coverage guide](../Tamriel-Tools/tools/testing/README.md);
select `--project Tamriel-Tools-Writ-Checker`.

## In-Game Verification

Automated tests cannot replace an in-game visual/API smoke test. Verify the four
equipment professions, a provisioning writ, a glyph writ, and alchemy;
hover a normal item afterward to check cleanup. Check alongside Master
Merchant with its graph enabled and at your normal UI scale. Confirm the
Crafting Ledger layout remains intact after `/reloadui`.
Check inventory markers for ready, blocked, material-short and unsupported
writs, including after scrolling, filtering, and changing material stocks.

## License

Original addon code is [MIT-licensed](LICENSE). Required libraries retain their
own licenses and are not bundled.
