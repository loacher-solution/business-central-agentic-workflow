# Design: Assign Item Category from Item List

## Summary

Add an action to the Item List page that allows users to select multiple items and assign them to a chosen Item Category in bulk.

## Architecture

### New AL Objects

| File | Type | ID | Name |
|------|------|----|------|
| `src/ItemCategoryHelper.al` | Codeunit | 50103 | Item Category Helper |
| `src/ItemListExt.al` | PageExtension | 50103 | ItemListExt (extends "Item List") |
| `test/ItemCategoryTest.al` | Codeunit (Test) | 50203 | Item Category Test |

### Codeunit: Item Category Helper (50103)

**Procedures:**

- `AssignCategoryToItems(var Item: Record Item; CategoryCode: Code[20]): Integer`
  - Validates the category code exists
  - Loops through filtered Item records
  - Sets `"Item Category Code"` on each item
  - Calls `Item.Modify(true)` to trigger standard BC validation
  - Returns count of updated items

- `ValidateCategoryCode(CategoryCode: Code[20])`
  - Looks up the category in the "Item Category" table (5722)
  - Errors if not found

### Page Extension: ItemListExt (50103) extends "Item List"

- Action "Assign Item Category" added to `addlast(Processing)`, promoted
- Opens standard "Item Categories" page (5730) via `Page.RunModal` in lookup mode
- On `Action::LookupOK`: uses `CurrPage.SetSelectionFilter(Item)` to get selected items
- Calls `ItemCategoryHelper.AssignCategoryToItems(Item, SelectedCategoryCode)`
- Shows confirmation message: "Updated X items to category Y."

### Data Flow

```
User selects items on Item List
  → Clicks "Assign Item Category" action
  → "Item Categories" lookup page opens
  → User picks a category → clicks OK
  → Helper validates category code
  → Helper updates all selected items
  → Confirmation message shown
```

### Error Handling

- No items selected: show message "No items selected."
- Invalid category: error from `ValidateCategoryCode`
- `Modify(true)` ensures standard BC field validation triggers run

## Testing

- AssignCategoryToItems: single item, multiple items, empty filter
- ValidateCategoryCode: valid code, invalid code (asserterror)
- Follow existing test patterns from SalesLineDiscountTest.al
