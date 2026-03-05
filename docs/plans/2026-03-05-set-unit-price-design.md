# Design: Set Unit Price on Sales Order Lines

## Goal

Add a function to set the Unit Price of all item lines in a Sales Order to a user-specified value X, entered via an input dialog.

## Approach: Extend Existing Objects

Reuse the existing Discount infrastructure by adding Unit Price support to the same objects.

## Changes

### 1. SalesLineDiscountHelper.al (Codeunit 50102)

- Add `ApplyUnitPrice(SalesHeader: Record "Sales Header"; UnitPrice: Decimal): Integer`
  - Filters item lines (same pattern as `ApplyLineDiscount`)
  - `Validate("Unit Price", UnitPrice)` on each line
  - Returns count of updated lines
- Add `ValidateUnitPrice(UnitPrice: Decimal)`
  - Error if UnitPrice < 0

### 2. SalesLineDiscountInput.al (Page 50102)

- Add `InputMode` variable (enum or Option: "Discount", "UnitPrice")
- Add `UnitPriceField` (Decimal, MinValue = 0) — visible only when mode = UnitPrice
- Hide `DiscountPctField` when mode = UnitPrice
- Add `SetInputMode()` procedure to switch mode
- Add `GetUnitPrice()` / `SetUnitPrice()` getter/setter
- Caption changes based on mode

### 3. SalesOrderExt.al (PageExtension 50102)

- Add `SetUnitPrice` action next to `SetLineDiscount`
  - Opens SalesLineDiscountInput in UnitPrice mode
  - Calls `ApplyUnitPrice()` on helper
  - Shows result message

### 4. Tests (SalesLineDiscountTest.al, Codeunit 50202)

- `TestApplyUnitPriceToItemLines` — sets price on 2 item lines
- `TestApplyUnitPriceSkipsNonItemLines` — comment lines unaffected
- `TestApplyUnitPriceReturnsZeroWhenNoItemLines`
- `TestValidateUnitPriceRejectsNegative`
- `TestValidateUnitPriceAcceptsZero`

## Object IDs

No new objects needed — all changes extend existing objects.
