# Assign Item Category Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add an action to the Item List that lets users select multiple items and assign them to a chosen Item Category via a lookup dialog.

**Architecture:** A helper codeunit (`ItemCategoryHelper`, 50103) encapsulates the logic for validating category codes and updating items. A page extension (`ItemListExt`, 50103) extends "Item List" with the action. Tests in codeunit 50204 validate all helper logic.

**Tech Stack:** AL (Business Central runtime 16.0), namespace `DefaultPublisher.src` / `DefaultPublisher.Test`

---

### Task 1: Create the Item Category Helper codeunit with tests (TDD)

**Files:**
- Create: `src/ItemCategoryHelper.al`
- Create: `test/ItemCategoryTest.al`

**Step 1: Write the test codeunit with all tests**

Create `test/ItemCategoryTest.al`:

```al
namespace DefaultPublisher.Test;

using DefaultPublisher.src;
using Microsoft.Inventory.Item;

codeunit 50204 "Item Category Test"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        ItemCategoryHelper: Codeunit "Item Category Helper";

    [Test]
    procedure TestValidateCategoryCodeAcceptsValidCode()
    var
        ItemCategory: Record "Item Category";
    begin
        // Given: An existing item category
        ItemCategory.FindFirst();

        // When/Then: Validation should not error
        ItemCategoryHelper.ValidateCategoryCode(ItemCategory.Code);
    end;

    [Test]
    procedure TestValidateCategoryCodeRejectsInvalidCode()
    begin
        // When/Then: Validation should error for non-existent category
        asserterror ItemCategoryHelper.ValidateCategoryCode('ZZZNOTEXIST');

        if GetLastErrorText() = '' then
            Error('Expected an error for invalid category code');
    end;

    [Test]
    procedure TestAssignCategoryToSingleItem()
    var
        Item: Record Item;
        ItemCategory: Record "Item Category";
        ItemsUpdated: Integer;
    begin
        // Given: An item and an existing category
        Item.FindFirst();
        ItemCategory.FindFirst();

        // When: Assign category to the item
        Item.SetRange("No.", Item."No.");
        ItemsUpdated := ItemCategoryHelper.AssignCategoryToItems(Item, ItemCategory.Code);

        // Then: One item updated
        if ItemsUpdated <> 1 then
            Error('Expected 1 item updated, got %1', ItemsUpdated);

        Item.Find();
        if Item."Item Category Code" <> ItemCategory.Code then
            Error('Expected category %1, got %2', ItemCategory.Code, Item."Item Category Code");
    end;

    [Test]
    procedure TestAssignCategoryToMultipleItems()
    var
        Item: Record Item;
        ItemCategory: Record "Item Category";
        ItemsUpdated: Integer;
    begin
        // Given: Multiple items and an existing category
        ItemCategory.FindFirst();
        Item.FindSet();

        // When: Assign category to first 2 items
        Item.SetFilter("No.", '%1|%2', Item."No.", GetSecondItemNo());
        ItemsUpdated := ItemCategoryHelper.AssignCategoryToItems(Item, ItemCategory.Code);

        // Then: Two items updated
        if ItemsUpdated <> 2 then
            Error('Expected 2 items updated, got %1', ItemsUpdated);
    end;

    [Test]
    procedure TestAssignCategoryReturnsZeroWhenNoItems()
    var
        Item: Record Item;
        ItemCategory: Record "Item Category";
        ItemsUpdated: Integer;
    begin
        // Given: A filter that matches no items
        ItemCategory.FindFirst();
        Item.SetRange("No.", 'ZZZNOTEXIST');

        // When: Assign category
        ItemsUpdated := ItemCategoryHelper.AssignCategoryToItems(Item, ItemCategory.Code);

        // Then: No items updated
        if ItemsUpdated <> 0 then
            Error('Expected 0 items updated, got %1', ItemsUpdated);
    end;

    local procedure GetSecondItemNo(): Code[20]
    var
        Item: Record Item;
    begin
        Item.FindFirst();
        Item.Next();
        exit(Item."No.");
    end;
}
```

**Step 2: Write the helper codeunit**

Create `src/ItemCategoryHelper.al`:

```al
namespace DefaultPublisher.src;

using Microsoft.Inventory.Item;

codeunit 50103 "Item Category Helper"
{
    procedure ValidateCategoryCode(CategoryCode: Code[20])
    var
        ItemCategory: Record "Item Category";
        CategoryNotFoundErr: Label 'Item Category %1 does not exist.', Comment = '%1 = category code';
    begin
        if not ItemCategory.Get(CategoryCode) then
            Error(CategoryNotFoundErr, CategoryCode);
    end;

    procedure AssignCategoryToItems(var Item: Record Item; CategoryCode: Code[20]): Integer
    var
        ItemsUpdated: Integer;
    begin
        ValidateCategoryCode(CategoryCode);

        if not Item.FindSet(true) then
            exit(0);

        repeat
            Item.Validate("Item Category Code", CategoryCode);
            Item.Modify(true);
            ItemsUpdated += 1;
        until Item.Next() = 0;

        exit(ItemsUpdated);
    end;
}
```

**Step 3: Build both projects to verify compilation**

Run: `powershell -ExecutionPolicy Bypass -File .claude/skills/bc-build-and-publish/scripts/build.ps1`
Expected: Both `src` and `test` compile successfully.

**Step 4: Publish and run tests**

Run: `powershell -ExecutionPolicy Bypass -File .claude/skills/bc-build-and-publish/scripts/publish.ps1 -BuildFirst -IncludeTest`
Then: `powershell -ExecutionPolicy Bypass -File .claude/skills/bc-test-runner/scripts/run-tests.ps1 -TestAppPath "test/app.json" -SkipPublish`
Expected: All tests pass (existing + new Item Category tests).

---

### Task 2: Create the Item List page extension

**Files:**
- Create: `src/ItemListExt.al`

**Step 1: Write the page extension**

Create `src/ItemListExt.al`:

```al
namespace DefaultPublisher.src;

using Microsoft.Inventory.Item;

pageextension 50103 ItemListExt extends "Item List"
{
    actions
    {
        addlast(Processing)
        {
            action(AssignItemCategory)
            {
                ApplicationArea = All;
                Caption = 'Assign Item Category';
                ToolTip = 'Assigns the selected items to a chosen item category.';
                Image = Category;
                Promoted = true;
                PromotedCategory = Process;

                trigger OnAction()
                var
                    Item: Record Item;
                    ItemCategory: Record "Item Category";
                    ItemCategoryHelper: Codeunit "Item Category Helper";
                    ItemCategories: Page "Item Categories";
                    ItemsUpdated: Integer;
                    NoItemsSelectedMsg: Label 'No items selected.';
                    ItemsUpdatedMsg: Label '%1 item(s) assigned to category %2.', Comment = '%1 = count, %2 = category code';
                begin
                    ItemCategories.LookupMode(true);
                    if ItemCategories.RunModal() <> Action::LookupOK then
                        exit;

                    ItemCategories.GetRecord(ItemCategory);

                    CurrPage.SetSelectionFilter(Item);
                    if not Item.HasFilter() then begin
                        Message(NoItemsSelectedMsg);
                        exit;
                    end;

                    ItemsUpdated := ItemCategoryHelper.AssignCategoryToItems(Item, ItemCategory.Code);

                    if ItemsUpdated = 0 then
                        Message(NoItemsSelectedMsg)
                    else
                        Message(ItemsUpdatedMsg, ItemsUpdated, ItemCategory.Code);

                    CurrPage.Update(false);
                end;
            }
        }
    }
}
```

**Step 2: Build to verify compilation**

Run: `powershell -ExecutionPolicy Bypass -File .claude/skills/bc-build-and-publish/scripts/build.ps1`
Expected: All projects compile successfully.

**Step 3: Publish and run all tests**

Run: `powershell -ExecutionPolicy Bypass -File .claude/skills/bc-build-and-publish/scripts/publish.ps1 -BuildFirst -IncludeTest`
Then: `powershell -ExecutionPolicy Bypass -File .claude/skills/bc-test-runner/scripts/run-tests.ps1 -TestAppPath "test/app.json" -SkipPublish`
Expected: All tests pass.

---

### Task 3: Commit

**Step 1: Commit implementation + tests together**

```bash
git add src/ItemCategoryHelper.al src/ItemListExt.al test/ItemCategoryTest.al
git commit -m "feat: add Assign Item Category action to Item List

Adds a bulk action to the Item List page that lets users select
multiple items and assign them to a chosen Item Category via lookup.

- ItemCategoryHelper codeunit (50103): validates category codes and
  updates items
- ItemListExt page extension (50103): extends Item List with the action
- ItemCategoryTest (50204): unit tests for helper logic"
```
