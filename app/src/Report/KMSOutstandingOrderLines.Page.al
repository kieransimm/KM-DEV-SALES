page 77502 "KMS Outstanding Order Lines"
{
    Caption = 'Order Lines';
    PageType = ListPart;
    SourceTable = "KMS Outstanding Order Line";
    SourceTableTemporary = true;
    InsertAllowed = false;
    DeleteAllowed = false;

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field(Flag; Rec.Flag)
                {
                    ApplicationArea = All;
                    Editable = false;
                    StyleExpr = FlagStyle;
                    Width = 2;
                    ToolTip = 'Specifies the state of the line: green on pick, blue reserved, amber part-reservable, red nothing reservable, grey awaiting put-away.';
                }
                field("Line Type"; Rec."Line Type")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Specifies the type of line: Item, Drop Shipment, Non-Inventory, Charge (Item), G/L Account and so on.';
                }
                field("No."; Rec."No.")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Specifies the item, or the number of the G/L account, charge or resource. Click an item to open the item card.';

                    trigger OnDrillDown()
                    begin
                        Mgt.OpenItem(Rec."No.");
                    end;
                }
                field(Description; Rec.Description)
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Specifies the line description.';
                }
                field("Description 2"; Rec."Description 2")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Specifies Description 2 from the item card.';
                }
                field(Status; Rec.Status)
                {
                    ApplicationArea = All;
                    Editable = false;
                    StyleExpr = FlagStyle;
                    ToolTip = 'Specifies where the line is: for example Ready, Reserve Lines, Awaiting Put-away or No Stock.';
                }
                field(Quantity; Rec.Quantity)
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Specifies the quantity on the line, in the line''s unit of measure.';
                }
                field("Quantity Shipped"; Rec."Quantity Shipped")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Specifies how much has been shipped (consumed, for assembly components).';
                }
                field("Quantity Invoiced"; Rec."Quantity Invoiced")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Specifies how much has been invoiced.';
                }
                field("Outstanding Quantity"; Rec."Outstanding Quantity")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Specifies how much is still to ship, in the line''s unit of measure.';
                }
                field("Unit Price"; Rec."Unit Price")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Specifies the unit price on the line, in the order''s currency.';
                }
                field("Unit Cost (LCY)"; Rec."Unit Cost (LCY)")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Specifies the unit cost on the line.';
                }
                field("Unshipped Value (LCY)"; Rec."Unshipped Value (LCY)")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Specifies the value still to ship, excluding VAT.';
                }
                field("Margin (LCY)"; Rec."Margin (LCY)")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Specifies the unshipped value minus the unshipped cost.';
                }
                field("Margin %"; Rec."Margin %")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Specifies the margin as a percentage of the unshipped value.';
                }
                field("On Shipment Qty."; Rec."On Shipment Qty.")
                {
                    ApplicationArea = All;
                    Editable = false;
                    BlankZero = true;
                    ToolTip = 'Specifies how much of the line is already on a warehouse shipment (on a pick, for assembly components), in base units.';
                }
                field("Reserved Qty."; Rec."Reserved Qty.")
                {
                    ApplicationArea = All;
                    Editable = false;
                    BlankZero = true;
                    ToolTip = 'Specifies how much of the line is reserved, in base units.';
                }
                field("Unreserved Qty."; Rec."Unreserved Qty.")
                {
                    ApplicationArea = All;
                    Editable = false;
                    BlankZero = true;
                    ToolTip = 'Specifies how much of the line still needs to be reserved, in base units.';
                }
                field("Suggested Qty. to Reserve"; Rec."Suggested Qty. to Reserve")
                {
                    ApplicationArea = All;
                    Editable = false;
                    BlankZero = true;
                    ToolTip = 'Specifies what Suggest found could be reserved from free pickable stock.';
                }
                field("Qty. to Reserve"; Rec."Qty. to Reserve")
                {
                    ApplicationArea = All;
                    Editable = CanEditQty;
                    BlankZero = true;
                    ToolTip = 'Specifies what Reserve will reserve, in base units. Filled by Suggest; you can type over it (checked against what the line needs and the free stock across the report), or enter 0 to leave the line out.';

                    trigger OnValidate()
                    begin
                        Mgt.SetQtyToReserve(Rec);
                    end;
                }
                field("Suggested Lot Nos."; Rec."Suggested Lot Nos.")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Specifies which lots Reserve would use, with the quantity from each.';
                }
                field("Suggested Expiry Dates"; Rec."Suggested Expiry Dates")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Specifies the expiry date and quantity of each lot Reserve would use.';
                }
                field("Free Stock Meeting Expiry"; Rec."Free Stock Meeting Expiry")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Specifies free pickable stock that meets the customer''s minimum expiry date (all free pickable stock if the customer has none).';
                }
                field("Free Pickable Stock"; Rec."Free Pickable Stock")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Specifies free stock in pickable bins: in pickable bins, minus on open picks, minus reserved but not yet on a pick.';
                }
                field("Free Stock Below Expiry"; Rec."Free Stock Below Expiry")
                {
                    ApplicationArea = All;
                    Editable = false;
                    BlankZero = true;
                    ToolTip = 'Specifies free pickable stock that expires before the customer''s minimum expiry date.';
                }
                field("PO Expected"; Rec."PO Expected")
                {
                    ApplicationArea = All;
                    Editable = false;
                    StyleExpr = POStyle;
                    ToolTip = 'Specifies the earliest expected receipt date on an open purchase order for the item at this location. Red if the date has passed. Click to open the purchase order.';

                    trigger OnDrillDown()
                    begin
                        Mgt.OpenPurchaseOrder(Rec."PO No.");
                    end;
                }
                field("PO No. (Outstanding Qty.)"; Rec."PO No. (Outstanding Qty.)")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Specifies that purchase order and the quantity still to receive on it. Click to open it.';

                    trigger OnDrillDown()
                    begin
                        Mgt.OpenPurchaseOrder(Rec."PO No.");
                    end;
                }
                field("PO Vendor Name"; Rec."PO Vendor Name")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Specifies the vendor on that purchase order.';
                }
                field("Purchaser Code"; Rec."Purchaser Code")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Specifies the purchaser on that purchase order.';
                }
                field("Reserved on Unshipped Orders"; Rec."Reserved on Unshipped Orders")
                {
                    ApplicationArea = All;
                    Editable = false;
                    BlankZero = true;
                    ToolTip = 'Specifies stock of this item reserved to other orders that are not yet on a shipment or pick.';
                }
                field("Qty. in Receive Bins"; Rec."Qty. in Receive Bins")
                {
                    ApplicationArea = All;
                    Editable = false;
                    BlankZero = true;
                    ToolTip = 'Specifies stock of this item in receive bins, waiting to be put away.';
                }
                field("Reserved Awaiting Put-away"; Rec."Reserved Awaiting Put-away")
                {
                    ApplicationArea = All;
                    Editable = false;
                    BlankZero = true;
                    ToolTip = 'Specifies reserved stock for this line that is not yet on the pick face.';
                }
                field("Reserved Below Min. Expiry"; Rec."Reserved Below Min. Expiry")
                {
                    ApplicationArea = All;
                    Editable = false;
                    BlankZero = true;
                    Style = Unfavorable;
                    ToolTip = 'Specifies reserved stock from lots that expire before the customer''s minimum expiry date.';
                }
                field("Reserved Lot Nos."; Rec."Reserved Lot Nos.")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Specifies the lots reserved for the line, with the quantity from each.';
                }
                field("Reserved Lot Expiry"; Rec."Reserved Lot Expiry")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Specifies the expiry date and quantity of each reserved lot.';
                }
                field("Whse. Shipment Nos."; Rec."Whse. Shipment Nos.")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Specifies the warehouse shipments the line is on. Click to open them.';

                    trigger OnDrillDown()
                    begin
                        Mgt.OpenWhseShipments(Rec."Whse. Shipment Nos.");
                    end;
                }
                field("Assembly Order Nos."; Rec."Assembly Order Nos.")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Specifies open assembly orders for this item that are for this sales order. Click to open them.';

                    trigger OnDrillDown()
                    begin
                        Mgt.OpenAssemblyOrders(Rec."Assembly Order Nos.");
                    end;
                }
                field("Warehouse Class Code"; Rec."Warehouse Class Code")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Specifies the item''s warehouse class.';
                }
                field("Replenishment System"; Rec."Replenishment System")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Specifies the item''s replenishment system.';
                }
                field("Location Code"; Rec."Location Code")
                {
                    ApplicationArea = All;
                    Editable = false;
                    Visible = false;
                    ToolTip = 'Specifies the location on the line.';
                }
                field("Unit of Measure Code"; Rec."Unit of Measure Code")
                {
                    ApplicationArea = All;
                    Editable = false;
                    Visible = false;
                    ToolTip = 'Specifies the line''s unit of measure.';
                }
                field("Variant Code"; Rec."Variant Code")
                {
                    ApplicationArea = All;
                    Editable = false;
                    Visible = false;
                    ToolTip = 'Specifies the item variant.';
                }
                field("Shipment Date"; Rec."Shipment Date")
                {
                    ApplicationArea = All;
                    Editable = false;
                    Visible = false;
                    ToolTip = 'Specifies the shipment date on the line (due date, for assembly components).';
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            group(OrderActions)
            {
                Caption = 'Order';

                action(SuggestOrder)
                {
                    ApplicationArea = All;
                    Caption = 'Suggest Qty. to Reserve (Order)';
                    Image = Calculate;
                    ToolTip = 'Fill Qty. to Reserve on this order''s lines from free pickable stock. Nothing is reserved yet.';

                    trigger OnAction()
                    begin
                        Mgt.SuggestOrder(Rec."Source Type", Rec."Order No.");
                        CurrPage.Update(false);
                    end;
                }
                action(ReserveOrder)
                {
                    ApplicationArea = All;
                    Caption = 'Reserve Qty. (Order)';
                    Image = Reserve;
                    ToolTip = 'Reserve the Qty. to Reserve on this order''s lines.';

                    trigger OnAction()
                    begin
                        Mgt.ReserveOrder(Rec."Source Type", Rec."Order No.");
                        CurrPage.Update(false);
                    end;
                }
                action(CancelSuggestOrder)
                {
                    ApplicationArea = All;
                    Caption = 'Cancel Suggested Qty. (Order)';
                    Image = Cancel;
                    ToolTip = 'Clear Qty. to Reserve on this order''s lines.';

                    trigger OnAction()
                    begin
                        Mgt.CancelSuggestionOrder(Rec."Source Type", Rec."Order No.");
                        CurrPage.Update(false);
                    end;
                }
                action(CancelReservationsOrder)
                {
                    ApplicationArea = All;
                    Caption = 'Cancel Reservations (Order)';
                    Image = CancelLine;
                    ToolTip = 'Free all stock reserved to this order.';

                    trigger OnAction()
                    begin
                        if not Confirm(CancelOrderQst, false, Rec."Order No.") then
                            exit;
                        Mgt.CancelReservationsOrder(Rec."Source Type", Rec."Order No.");
                        CurrPage.Update(false);
                    end;
                }
                action(ReduceOrder)
                {
                    ApplicationArea = All;
                    Caption = 'Reduce Reservations to Pickable Qty. (Order)';
                    Image = Undo;
                    ToolTip = 'On every line of this sales order, reduce reservations to what is in pickable bins, freeing stock still awaiting put-away.';

                    trigger OnAction()
                    begin
                        Mgt.ReduceToPickableOrder(Rec."Source Type", Rec."Order No.");
                        CurrPage.Update(false);
                    end;
                }
            }
            group(LineActions)
            {
                Caption = 'Line';

                action(SuggestLine)
                {
                    ApplicationArea = All;
                    Caption = 'Suggest Qty. to Reserve (Line)';
                    Image = Calculate;
                    ToolTip = 'Fill Qty. to Reserve on the selected line from free pickable stock.';

                    trigger OnAction()
                    begin
                        Mgt.SuggestLine(Rec."Source Type", Rec."Order No.", Rec."Line No.");
                        CurrPage.Update(false);
                    end;
                }
                action(CancelSuggestLine)
                {
                    ApplicationArea = All;
                    Caption = 'Cancel Suggested Qty. (Line)';
                    Image = Cancel;
                    ToolTip = 'Clear Qty. to Reserve on the selected line.';

                    trigger OnAction()
                    begin
                        Mgt.CancelSuggestionLine(Rec."Source Type", Rec."Order No.", Rec."Line No.");
                        CurrPage.Update(false);
                    end;
                }
                action(ReserveLine)
                {
                    ApplicationArea = All;
                    Caption = 'Reserve Qty. to Reserve (Line)';
                    Image = Reserve;
                    ToolTip = 'Reserve the Qty. to Reserve on the selected line.';

                    trigger OnAction()
                    begin
                        CurrPage.SaveRecord();
                        Mgt.ReserveLine(Rec."Source Type", Rec."Order No.", Rec."Line No.");
                        CurrPage.Update(false);
                    end;
                }
                action(CancelReservationLine)
                {
                    ApplicationArea = All;
                    Caption = 'Cancel Reservation (Line)';
                    Image = CancelLine;
                    ToolTip = 'Free the stock reserved to the selected line.';

                    trigger OnAction()
                    begin
                        Mgt.CancelReservationsLine(Rec."Source Type", Rec."Order No.", Rec."Line No.");
                        CurrPage.Update(false);
                    end;
                }
                action(ReduceLine)
                {
                    ApplicationArea = All;
                    Caption = 'Reduce Reservation to Pickable Qty.';
                    Image = Undo;
                    ToolTip = 'Reduce the selected sales line''s reservation to what is in pickable bins, freeing stock still awaiting put-away.';

                    trigger OnAction()
                    begin
                        Mgt.ReduceToPickableLine(Rec."Source Type", Rec."Order No.", Rec."Line No.");
                        CurrPage.Update(false);
                    end;
                }
            }
        }
    }

    var
        Mgt: Codeunit "KMS Outstanding Orders Mgt.";
        FlagStyle: Text;
        POStyle: Text;
        CanEditQty: Boolean;
        CancelOrderQst: Label 'Cancel all reservations on order %1?', Comment = '%1 = order no.';

    /// <summary>Called by the report page once its data is built, so both sections share the same lines.</summary>
    procedure InitLines()
    begin
        Mgt.ShareLines(Rec);
        CurrPage.Update(false);
    end;

    trigger OnAfterGetRecord()
    begin
        FlagStyle := Mgt.GetStyle(Rec."Flag Colour");
        POStyle := 'Standard';
        if (Rec."PO Expected" <> 0D) and (Rec."PO Expected" < Today()) then
            POStyle := 'Unfavorable';
        CanEditQty := Rec."Is Stock Item" and (Rec."Unreserved Qty." > 0);
    end;
}
