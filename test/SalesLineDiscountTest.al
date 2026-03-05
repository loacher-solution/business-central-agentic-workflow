namespace DefaultPublisher.Test;

using DefaultPublisher.src;
using Microsoft.Sales.Document;

codeunit 50202 "Sales Line Discount Test"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        SalesLineDiscountHelper: Codeunit "Sales Line Discount Helper";
        SalesLibrary: Codeunit "Sales Library";

    [Test]
    procedure TestApplyDiscountToItemLines()
    var
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";
        LinesUpdated: Integer;
    begin
        // Given: A sales order with two item lines
        SalesLibrary.CreateSalesOrderWithItemLines(SalesHeader, 2);

        // When: Apply 10% discount
        LinesUpdated := SalesLineDiscountHelper.ApplyLineDiscount(SalesHeader, 10);

        // Then: Both lines should be updated
        if LinesUpdated <> 2 then
            Error('Expected 2 lines updated, got %1', LinesUpdated);

        SalesLine.SetRange("Document Type", SalesHeader."Document Type");
        SalesLine.SetRange("Document No.", SalesHeader."No.");
        SalesLine.SetRange(Type, SalesLine.Type::Item);
        SalesLine.FindSet();
        repeat
            if SalesLine."Line Discount %" <> 10 then
                Error('Expected 10%% discount on line %1, got %2', SalesLine."Line No.", SalesLine."Line Discount %");
        until SalesLine.Next() = 0;
    end;

    [Test]
    procedure TestApplyDiscountSkipsNonItemLines()
    var
        SalesHeader: Record "Sales Header";
        LinesUpdated: Integer;
    begin
        // Given: A sales order with one item line and one comment line
        SalesLibrary.CreateSalesOrderWithItemLines(SalesHeader, 1);
        SalesLibrary.CreateCommentLine(SalesHeader);

        // When: Apply 15% discount
        LinesUpdated := SalesLineDiscountHelper.ApplyLineDiscount(SalesHeader, 15);

        // Then: Only the item line should be updated
        if LinesUpdated <> 1 then
            Error('Expected 1 line updated, got %1', LinesUpdated);
    end;

    [Test]
    procedure TestApplyDiscountReturnsZeroWhenNoItemLines()
    var
        SalesHeader: Record "Sales Header";
        LinesUpdated: Integer;
    begin
        // Given: A sales order with no item lines (only a comment)
        SalesLibrary.CreateSalesOrder(SalesHeader);
        SalesLibrary.CreateCommentLine(SalesHeader);

        // When: Apply discount
        LinesUpdated := SalesLineDiscountHelper.ApplyLineDiscount(SalesHeader, 10);

        // Then: No lines updated
        if LinesUpdated <> 0 then
            Error('Expected 0 lines updated, got %1', LinesUpdated);
    end;

    [Test]
    procedure TestApplyZeroDiscount()
    var
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";
        LinesUpdated: Integer;
    begin
        // Given: A sales order with an item line that has a discount
        SalesLibrary.CreateSalesOrderWithItemLines(SalesHeader, 1);
        SalesLine.SetRange("Document Type", SalesHeader."Document Type");
        SalesLine.SetRange("Document No.", SalesHeader."No.");
        SalesLine.SetRange(Type, SalesLine.Type::Item);
        SalesLine.FindFirst();
        SalesLine.Validate("Line Discount %", 20);
        SalesLine.Modify(true);

        // When: Apply 0% discount
        LinesUpdated := SalesLineDiscountHelper.ApplyLineDiscount(SalesHeader, 0);

        // Then: Line discount should be reset to 0
        if LinesUpdated <> 1 then
            Error('Expected 1 line updated, got %1', LinesUpdated);

        SalesLine.Find();
        if SalesLine."Line Discount %" <> 0 then
            Error('Expected 0%% discount, got %1', SalesLine."Line Discount %");
    end;

    [Test]
    procedure TestValidateDiscountPctRejectsNegative()
    begin
        asserterror SalesLineDiscountHelper.ValidateDiscountPct(-1);

        if GetLastErrorText() = '' then
            Error('Expected an error for negative discount');
    end;

    [Test]
    procedure TestValidateDiscountPctRejectsOver100()
    begin
        asserterror SalesLineDiscountHelper.ValidateDiscountPct(101);

        if GetLastErrorText() = '' then
            Error('Expected an error for discount over 100');
    end;

    [Test]
    procedure TestValidateDiscountPctAcceptsBoundaryValues()
    begin
        SalesLineDiscountHelper.ValidateDiscountPct(0);
        SalesLineDiscountHelper.ValidateDiscountPct(100);
    end;
}
