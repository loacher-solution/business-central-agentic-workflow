# Set Unit Price on Sales Lines — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Allow users to set the Unit Price of all item lines in a Sales Order to a fixed value via an input dialog.

**Architecture:** Extend the existing Sales Line Discount infrastructure (Codeunit 50102, Page 50102, PageExtension 50102) with Unit Price support. The Input Page uses a mode variable to show either the Discount or UnitPrice field. The Helper Codeunit gets a new `ApplyUnitPrice` procedure.

**Tech Stack:** AL Language, Business Central Runtime 16.0, Application 27.0

**Design doc:** `docs/plans/2026-03-05-set-unit-price-design.md`

**Skills:** Use `al-language` for AL syntax, `bc-build-and-publish` to compile, `bc-test-runner` to run tests.

---

### Task 1: Add Unit Price logic to SalesLineDiscountHelper

**Files:**
- Modify: `src/SalesLineDiscountHelper.al`

**Step 1: Add `ValidateUnitPrice` procedure**

Add after the existing `ValidateDiscountPct` procedure:

```al
    procedure ValidateUnitPrice(UnitPrice: Decimal)
    var
        InvalidUnitPriceErr: Label 'Unit Price must be 0 or greater. You entered %1.', Comment = '%1 = entered value';
    begin
        if UnitPrice < 0 then
            Error(InvalidUnitPriceErr, UnitPrice);
    end;
```

**Step 2: Add `ApplyUnitPrice` procedure**

Add after `ApplyLineDiscount`:

```al
    procedure ApplyUnitPrice(SalesHeader: Record "Sales Header"; UnitPrice: Decimal): Integer
    var
        SalesLine: Record "Sales Line";
        LinesUpdated: Integer;
    begin
        ValidateUnitPrice(UnitPrice);

        SalesLine.SetRange("Document Type", SalesHeader."Document Type");
        SalesLine.SetRange("Document No.", SalesHeader."No.");
        SalesLine.SetRange(Type, SalesLine.Type::Item);

        if not SalesLine.FindSet(true) then
            exit(0);

        repeat
            SalesLine.Validate("Unit Price", UnitPrice);
            SalesLine.Modify(true);
            LinesUpdated += 1;
        until SalesLine.Next() = 0;

        exit(LinesUpdated);
    end;
```

**Step 3: Build to verify compilation**

Run: `powershell -ExecutionPolicy Bypass -File .claude/skills/bc-build-and-publish/scripts/build.ps1 -ProjectDir src`
Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add src/SalesLineDiscountHelper.al
git commit -m "feat: add ApplyUnitPrice and ValidateUnitPrice to Sales Line Discount Helper"
```

---

### Task 2: Add mode support to SalesLineDiscountInput page

**Files:**
- Modify: `src/SalesLineDiscountInput.al`

**Step 1: Replace entire file content**

The page needs a mode variable, conditional field visibility, dynamic caption, and new getter/setters:

```al
namespace DefaultPublisher.src;

page 50102 "Sales Line Discount Input"
{
    PageType = StandardDialog;
    Caption = 'Set Line Discount';

    layout
    {
        area(Content)
        {
            group(General)
            {
                field(DiscountPctField; DiscountPct)
                {
                    ApplicationArea = All;
                    Caption = 'Line Discount %';
                    ToolTip = 'Enter the line discount percentage to apply to all item lines.';
                    MinValue = 0;
                    MaxValue = 100;
                    Visible = IsDiscountMode;
                }
                field(UnitPriceField; UnitPrice)
                {
                    ApplicationArea = All;
                    Caption = 'Unit Price';
                    ToolTip = 'Enter the unit price to set on all item lines.';
                    MinValue = 0;
                    Visible = IsUnitPriceMode;
                }
            }
        }
    }

    trigger OnOpenPage()
    begin
        IsDiscountMode := InputMode = InputMode::Discount;
        IsUnitPriceMode := InputMode = InputMode::UnitPrice;

        if IsUnitPriceMode then
            CurrPage.Caption := 'Set Unit Price';
    end;

    procedure GetDiscountPct(): Decimal
    begin
        exit(DiscountPct);
    end;

    procedure SetDiscountPct(NewDiscountPct: Decimal)
    begin
        DiscountPct := NewDiscountPct;
    end;

    procedure GetUnitPrice(): Decimal
    begin
        exit(UnitPrice);
    end;

    procedure SetUnitPrice(NewUnitPrice: Decimal)
    begin
        UnitPrice := NewUnitPrice;
    end;

    procedure SetInputMode(NewMode: Option Discount,UnitPrice)
    begin
        InputMode := NewMode;
    end;

    var
        DiscountPct: Decimal;
        UnitPrice: Decimal;
        InputMode: Option Discount,UnitPrice;
        IsDiscountMode: Boolean;
        IsUnitPriceMode: Boolean;
}
```

**Step 2: Build to verify compilation**

Run: `powershell -ExecutionPolicy Bypass -File .claude/skills/bc-build-and-publish/scripts/build.ps1 -ProjectDir src`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add src/SalesLineDiscountInput.al
git commit -m "feat: add UnitPrice mode to Sales Line Discount Input page"
```

---

### Task 3: Add SetUnitPrice action to SalesOrderExt

**Files:**
- Modify: `src/SalesOrderExt.al`

**Step 1: Add the new action**

Add a new `SetUnitPrice` action after the existing `SetLineDiscount` action inside `addlast(Processing)`:

```al
            action(SetUnitPrice)
            {
                ApplicationArea = All;
                Caption = 'Set Unit Price';
                ToolTip = 'Sets a unit price on all item lines in this sales order.';
                Image = Price;
                Promoted = true;
                PromotedCategory = Process;

                trigger OnAction()
                var
                    SalesLineDiscountHelper: Codeunit "Sales Line Discount Helper";
                    SalesLineDiscountInput: Page "Sales Line Discount Input";
                    NewUnitPrice: Decimal;
                    LinesUpdated: Integer;
                    NoItemLinesMsg: Label 'There are no item lines to update.';
                    LinesUpdatedMsg: Label '%1 item line(s) updated with unit price %2.', Comment = '%1 = count, %2 = unit price';
                begin
                    SalesLineDiscountInput.SetInputMode(1); // UnitPrice
                    if SalesLineDiscountInput.RunModal() <> Action::OK then
                        exit;

                    NewUnitPrice := SalesLineDiscountInput.GetUnitPrice();
                    LinesUpdated := SalesLineDiscountHelper.ApplyUnitPrice(Rec, NewUnitPrice);

                    if LinesUpdated = 0 then
                        Message(NoItemLinesMsg)
                    else
                        Message(LinesUpdatedMsg, LinesUpdated, NewUnitPrice);

                    CurrPage.Update(false);
                end;
            }
```

**Step 2: Build to verify compilation**

Run: `powershell -ExecutionPolicy Bypass -File .claude/skills/bc-build-and-publish/scripts/build.ps1 -ProjectDir src`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add src/SalesOrderExt.al
git commit -m "feat: add Set Unit Price action to Sales Order page extension"
```

---

### Task 4: Write tests for Unit Price functionality

**Files:**
- Modify: `test/SalesLineDiscountTest.al`

**Step 1: Add Unit Price tests**

Add these test procedures at the end of the codeunit (before the closing `}`):

```al
    [Test]
    procedure TestApplyUnitPriceToItemLines()
    var
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";
        LinesUpdated: Integer;
    begin
        // Given: A sales order with two item lines
        SalesLibrary.CreateSalesOrderWithItemLines(SalesHeader, 2);

        // When: Apply unit price of 50
        LinesUpdated := SalesLineDiscountHelper.ApplyUnitPrice(SalesHeader, 50);

        // Then: Both lines should be updated with unit price 50
        if LinesUpdated <> 2 then
            Error('Expected 2 lines updated, got %1', LinesUpdated);

        SalesLine.SetRange("Document Type", SalesHeader."Document Type");
        SalesLine.SetRange("Document No.", SalesHeader."No.");
        SalesLine.SetRange(Type, SalesLine.Type::Item);
        SalesLine.FindSet();
        repeat
            if SalesLine."Unit Price" <> 50 then
                Error('Expected unit price 50 on line %1, got %2', SalesLine."Line No.", SalesLine."Unit Price");
        until SalesLine.Next() = 0;
    end;

    [Test]
    procedure TestApplyUnitPriceSkipsNonItemLines()
    var
        SalesHeader: Record "Sales Header";
        LinesUpdated: Integer;
    begin
        // Given: A sales order with one item line and one comment line
        SalesLibrary.CreateSalesOrderWithItemLines(SalesHeader, 1);
        SalesLibrary.CreateCommentLine(SalesHeader);

        // When: Apply unit price of 75
        LinesUpdated := SalesLineDiscountHelper.ApplyUnitPrice(SalesHeader, 75);

        // Then: Only the item line should be updated
        if LinesUpdated <> 1 then
            Error('Expected 1 line updated, got %1', LinesUpdated);
    end;

    [Test]
    procedure TestApplyUnitPriceReturnsZeroWhenNoItemLines()
    var
        SalesHeader: Record "Sales Header";
        LinesUpdated: Integer;
    begin
        // Given: A sales order with no item lines (only a comment)
        SalesLibrary.CreateSalesOrder(SalesHeader);
        SalesLibrary.CreateCommentLine(SalesHeader);

        // When: Apply unit price
        LinesUpdated := SalesLineDiscountHelper.ApplyUnitPrice(SalesHeader, 100);

        // Then: No lines updated
        if LinesUpdated <> 0 then
            Error('Expected 0 lines updated, got %1', LinesUpdated);
    end;

    [Test]
    procedure TestValidateUnitPriceRejectsNegative()
    begin
        asserterror SalesLineDiscountHelper.ValidateUnitPrice(-1);

        if GetLastErrorText() = '' then
            Error('Expected an error for negative unit price');
    end;

    [Test]
    procedure TestValidateUnitPriceAcceptsZero()
    begin
        SalesLineDiscountHelper.ValidateUnitPrice(0);
    end;
```

**Step 2: Build test app**

Run: `powershell -ExecutionPolicy Bypass -File .claude/skills/bc-build-and-publish/scripts/build.ps1`
Expected: BUILD SUCCEEDED (both src and test)

**Step 3: Commit**

```bash
git add test/SalesLineDiscountTest.al
git commit -m "test: add unit tests for ApplyUnitPrice functionality"
```

---

### Task 5: Publish and run tests

**Step 1: Publish both apps (src + test)**

Run: `powershell -ExecutionPolicy Bypass -File .claude/skills/bc-build-and-publish/scripts/publish.ps1 -BuildFirst -IncludeTest`
Expected: Both apps published successfully

**Step 2: Run all tests**

Run: `powershell -ExecutionPolicy Bypass -File .claude/skills/bc-test-runner/scripts/run-tests.ps1 -TestAppPath "test/app.json" -SkipPublish`
Expected: All tests pass (existing 7 discount tests + 5 new unit price tests = 12 total)

**Step 3: Fix any failing tests if needed**

If tests fail, read the error output, fix the issue, rebuild, republish, and re-run.

---

### Summary of Changes

| File | Change |
|------|--------|
| `src/SalesLineDiscountHelper.al` | Add `ApplyUnitPrice()` and `ValidateUnitPrice()` |
| `src/SalesLineDiscountInput.al` | Add mode support, UnitPrice field, getter/setter |
| `src/SalesOrderExt.al` | Add `SetUnitPrice` action |
| `test/SalesLineDiscountTest.al` | Add 5 unit price tests |
