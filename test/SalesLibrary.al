namespace DefaultPublisher.Test;

using Microsoft.Sales.Document;
using Microsoft.Sales.Customer;
using Microsoft.Inventory.Item;

codeunit 50203 "Sales Library"
{
    procedure CreateSalesOrder(var SalesHeader: Record "Sales Header")
    var
        Customer: Record Customer;
    begin
        Customer.FindFirst();
        SalesHeader.Init();
        SalesHeader."Document Type" := SalesHeader."Document Type"::Order;
        SalesHeader.Insert(true);
        SalesHeader.Validate("Sell-to Customer No.", Customer."No.");
        SalesHeader.Modify(true);
    end;

    procedure CreateSalesOrderWithItemLines(var SalesHeader: Record "Sales Header"; LineCount: Integer)
    var
        Item: Record Item;
        SalesLine: Record "Sales Line";
        i: Integer;
        LineNo: Integer;
    begin
        CreateSalesOrder(SalesHeader);
        Item.FindFirst();
        LineNo := 10000;

        for i := 1 to LineCount do begin
            SalesLine.Init();
            SalesLine."Document Type" := SalesHeader."Document Type";
            SalesLine."Document No." := SalesHeader."No.";
            SalesLine."Line No." := LineNo;
            SalesLine.Insert(true);
            SalesLine.Validate(Type, SalesLine.Type::Item);
            SalesLine.Validate("No.", Item."No.");
            SalesLine.Validate(Quantity, 1);
            SalesLine.Modify(true);
            LineNo += 10000;
        end;
    end;

    procedure CreateCommentLine(SalesHeader: Record "Sales Header")
    var
        SalesLine: Record "Sales Line";
    begin
        SalesLine.Init();
        SalesLine."Document Type" := SalesHeader."Document Type";
        SalesLine."Document No." := SalesHeader."No.";
        SalesLine."Line No." := GetNextLineNo(SalesHeader);
        SalesLine.Type := SalesLine.Type::" ";
        SalesLine.Description := 'Test Comment';
        SalesLine.Insert(true);
    end;

    procedure GetNextLineNo(SalesHeader: Record "Sales Header"): Integer
    var
        SalesLine: Record "Sales Line";
    begin
        SalesLine.SetRange("Document Type", SalesHeader."Document Type");
        SalesLine.SetRange("Document No.", SalesHeader."No.");
        if SalesLine.FindLast() then
            exit(SalesLine."Line No." + 10000);
        exit(10000);
    end;
}
