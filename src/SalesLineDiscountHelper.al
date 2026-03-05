namespace DefaultPublisher.src;

using Microsoft.Sales.Document;

codeunit 50102 "Sales Line Discount Helper"
{
    procedure ApplyLineDiscount(SalesHeader: Record "Sales Header"; DiscountPct: Decimal): Integer
    var
        SalesLine: Record "Sales Line";
        LinesUpdated: Integer;
    begin
        ValidateDiscountPct(DiscountPct);

        SalesLine.SetRange("Document Type", SalesHeader."Document Type");
        SalesLine.SetRange("Document No.", SalesHeader."No.");
        SalesLine.SetRange(Type, SalesLine.Type::Item);

        if not SalesLine.FindSet(true) then
            exit(0);

        repeat
            SalesLine.Validate("Line Discount %", DiscountPct);
            SalesLine.Modify(true);
            LinesUpdated += 1;
        until SalesLine.Next() = 0;

        exit(LinesUpdated);
    end;

    procedure ValidateDiscountPct(DiscountPct: Decimal)
    var
        InvalidDiscountErr: Label 'Line Discount %% must be between 0 and 100. You entered %1.', Comment = '%1 = entered value';
    begin
        if (DiscountPct < 0) or (DiscountPct > 100) then
            Error(InvalidDiscountErr, DiscountPct);
    end;

    procedure ValidateUnitPrice(UnitPrice: Decimal)
    var
        InvalidUnitPriceErr: Label 'Unit Price must be 0 or greater. You entered %1.', Comment = '%1 = entered value';
    begin
        if UnitPrice < 0 then
            Error(InvalidUnitPriceErr, UnitPrice);
    end;

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
}
