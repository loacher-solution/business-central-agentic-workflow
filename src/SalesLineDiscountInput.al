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
                }
            }
        }
    }

    procedure GetDiscountPct(): Decimal
    begin
        exit(DiscountPct);
    end;

    procedure SetDiscountPct(NewDiscountPct: Decimal)
    begin
        DiscountPct := NewDiscountPct;
    end;

    var
        DiscountPct: Decimal;
}
