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
