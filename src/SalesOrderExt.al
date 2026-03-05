namespace DefaultPublisher.src;

using Microsoft.Sales.Document;

pageextension 50102 SalesOrderExt extends "Sales Order"
{
    actions
    {
        addlast(Processing)
        {
            action(SetLineDiscount)
            {
                ApplicationArea = All;
                Caption = 'Set Line Discount';
                ToolTip = 'Sets a line discount percentage on all item lines in this sales order.';
                Image = LineDiscount;
                Promoted = true;
                PromotedCategory = Process;

                trigger OnAction()
                var
                    SalesLineDiscountHelper: Codeunit "Sales Line Discount Helper";
                    SalesLineDiscountInput: Page "Sales Line Discount Input";
                    DiscountPct: Decimal;
                    LinesUpdated: Integer;
                    NoItemLinesMsg: Label 'There are no item lines to update.';
                    LinesUpdatedMsg: Label '%1 item line(s) updated with %2% line discount.', Comment = '%1 = count, %2 = discount pct';
                begin
                    if SalesLineDiscountInput.RunModal() <> Action::OK then
                        exit;

                    DiscountPct := SalesLineDiscountInput.GetDiscountPct();
                    LinesUpdated := SalesLineDiscountHelper.ApplyLineDiscount(Rec, DiscountPct);

                    if LinesUpdated = 0 then
                        Message(NoItemLinesMsg)
                    else
                        Message(LinesUpdatedMsg, LinesUpdated, DiscountPct);

                    CurrPage.Update(false);
                end;
            }
        }
    }
}
