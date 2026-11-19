page 77501 "KMS Outstanding Orders"
{
    Caption = 'Outstanding Orders Report';
    PageType = List;
    ApplicationArea = All;
    UsageCategory = ReportsAndAnalysis;
    SourceTable = "KMS Outstanding Order";
    SourceTableTemporary = true;
    SourceTableView = sorting("Order Date", "Order No.") order(descending);
    InsertAllowed = false;
    DeleteAllowed = false;
    ModifyAllowed = false;
    AboutTitle = 'Outstanding Orders Report';
    AboutText = 'Open and released sales orders, and assembly orders, with stock, purchase order and margin information for each line. Select an order to see its lines underneath.';

    layout
    {
        area(Content)
        {
            repeater(Orders)
            {
                field(Flag; Rec.Flag)
                {
                    StyleExpr = FlagStyle;
                    Width = 2;
                    ToolTip = 'Specifies the state of the whole order: green on pick, blue ready, amber partly reservable, red nothing reservable, grey awaiting put-away.';
                }
                field("Order No."; Rec."Order No.")
                {
                    ToolTip = 'Specifies the sales or assembly order. Click to open it.';

                    trigger OnDrillDown()
                    begin
                        Mgt.OpenOrder(Rec."Source Type", Rec."Order No.");
                    end;
                }
                field(Status; Rec.Status)
                {
                    StyleExpr = FlagStyle;
                    ToolTip = 'Specifies where the order is: for example Ready, Reserve Lines, Awaiting Put-away or No Stock.';
                }
                field("Order Date"; Rec."Order Date")
                {
                    ToolTip = 'Specifies the order date. For assembly orders, the date the order was created.';
                }
                field("Promised Delivery Date"; Rec."Promised Delivery Date")
                {
                    StyleExpr = PDDStyle;
                    ToolTip = 'Specifies the promised delivery date. Red when today or earlier, green when later.';
                }
                field("Customer No."; Rec."Customer No.")
                {
                    ToolTip = 'Specifies the sell-to customer.';
                }
                field("Customer Name"; Rec."Customer Name")
                {
                    ToolTip = 'Specifies the sell-to customer name. For assembly orders, the item being assembled.';
                }
                field("Salesperson Code"; Rec."Salesperson Code")
                {
                    ToolTip = 'Specifies the salesperson on the customer card.';
                }
                field("Territory Code"; Rec."Territory Code")
                {
                    ToolTip = 'Specifies the customer''s region territory.';
                }
                field("Document Status"; Rec."Document Status")
                {
                    ToolTip = 'Specifies whether the order is Open or Released.';
                }
                field("Whse. Shipment Status"; Rec."Whse. Shipment Status")
                {
                    ToolTip = 'Specifies the status of the order''s open warehouse shipment, for example Partially Picked or Completely Picked.';
                }
                field("Unshipped Value (LCY)"; Rec."Unshipped Value (LCY)")
                {
                    ToolTip = 'Specifies the value of what is still to ship, excluding VAT, in local currency.';
                }
                field("Margin (LCY)"; Rec."Margin (LCY)")
                {
                    ToolTip = 'Specifies the unshipped value minus the unshipped cost.';
                }
                field("Margin %"; Rec."Margin %")
                {
                    ToolTip = 'Specifies the margin as a percentage of the unshipped value.';
                }
                field("Reserved Value (LCY)"; Rec."Reserved Value (LCY)")
                {
                    BlankZero = true;
                    ToolTip = 'Specifies the value of reserved stock not yet on a shipment.';
                }
                field("Ready Value (LCY)"; Rec."Ready Value (LCY)")
                {
                    Visible = false;
                    ToolTip = 'Specifies the value of reserved, pickable stock not yet on a shipment.';
                }
                field("Unshipped Cost (LCY)"; Rec."Unshipped Cost (LCY)")
                {
                    Visible = false;
                    ToolTip = 'Specifies the cost of what is still to ship.';
                }
                field("Item Lines"; Rec."Item Lines")
                {
                    ToolTip = 'Specifies how many stocked item lines are still outstanding.';
                }
                field("Lines Unreserved"; Rec."Lines Unreserved")
                {
                    ToolTip = 'Specifies how many item lines are not fully reserved.';
                }
                field("Lines Awaiting Put-away"; Rec."Lines Awaiting Put-away")
                {
                    ToolTip = 'Specifies how many item lines have stock waiting to be put away.';
                }
                field("Shipping Advice"; Rec."Shipping Advice")
                {
                    ToolTip = 'Specifies whether the order can ship in part (Partial) or only complete (Complete).';
                }
                field("Warehouse Note"; Rec."Warehouse Note")
                {
                    ToolTip = 'Specifies the warehouse note on the sales order.';
                }
                field("Created By"; Rec."Created By")
                {
                    ToolTip = 'Specifies who created the order.';
                }
                field("Shipment Method Code"; Rec."Shipment Method Code")
                {
                    ToolTip = 'Specifies the shipment method.';
                }
                field("Shipping Agent Code"; Rec."Shipping Agent Code")
                {
                    ToolTip = 'Specifies the shipping agent.';
                }
                field("Shipping Agent Service"; Rec."Shipping Agent Service")
                {
                    ToolTip = 'Specifies the shipping agent service.';
                }
                field(Blocked; Rec.Blocked)
                {
                    ToolTip = 'Specifies whether the customer is blocked.';
                }
                field("Customer Min. Expiry Date"; Rec."Customer Min. Expiry Date")
                {
                    ToolTip = 'Specifies the earliest expiry date the customer accepts: today plus their minimum remaining shelf life.';
                }
                field("Source Type"; Rec."Source Type")
                {
                    ToolTip = 'Specifies whether this is a sales order or an assembly order.';
                }
                field("Whse. Shipment No."; Rec."Whse. Shipment No.")
                {
                    ToolTip = 'Specifies the open warehouse shipment for the order. Click to open it.';

                    trigger OnDrillDown()
                    begin
                        Mgt.OpenWhseShipments(Rec."Whse. Shipment No.");
                    end;
                }
                field("Related Order"; Rec."Related Order")
                {
                    ToolTip = 'Specifies the sales orders an assembly order is for, so searching for a sales order number also finds its assembly orders.';
                }
                field("Shipment Date"; Rec."Shipment Date")
                {
                    Visible = false;
                    ToolTip = 'Specifies the shipment date.';
                }
                field("Min. Remaining Shelf Life"; Rec."Min. Remaining Shelf Life")
                {
                    Visible = false;
                    ToolTip = 'Specifies the customer''s minimum remaining shelf life.';
                }
                field("Location Code"; Rec."Location Code")
                {
                    Visible = false;
                    ToolTip = 'Specifies the location on the order header.';
                }
                field("Flag Colour"; Rec."Flag Colour")
                {
                    Visible = false;
                    ToolTip = 'Specifies the flag colour, for filtering.';
                }
            }
            part(Lines; "KMS Outstanding Order Lines")
            {
                Caption = 'Order Lines';
                ApplicationArea = All;
                SubPageLink = "Source Type" = field("Source Type"), "Order No." = field("Order No.");
                UpdatePropagation = Both;
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(Refresh)
            {
                Caption = 'Refresh';
                Image = Refresh;
                ToolTip = 'Rebuild the report from live data.';

                trigger OnAction()
                begin
                    Mgt.Build();
                    ApplyView();
                    CurrPage.Update(false);
                end;
            }
            action(ShowHideFullyOnShipment)
            {
                Caption = 'Show / Hide Fully Picking Orders';
                Image = ShowList;
                ToolTip = 'Show or hide orders that are fully on a warehouse shipment and pick.';

                trigger OnAction()
                begin
                    ShowFullyOnShipment := not ShowFullyOnShipment;
                    ApplyView();
                    CurrPage.Update(false);
                end;
            }
            group(BulkActions)
            {
                Caption = 'Bulk Actions';
                Image = Calculate;

                action(SuggestAll)
                {
                    Caption = 'Suggest for All Orders';
                    Image = Calculate;
                    ToolTip = 'Fill Qty. to Reserve on every order from free pickable stock, oldest order first. Nothing is reserved yet.';

                    trigger OnAction()
                    begin
                        Mgt.SuggestAll();
                        CurrPage.Update(false);
                    end;
                }
                action(ReserveAll)
                {
                    Caption = 'Reserve Suggested Qty. on All Orders';
                    Image = Reserve;
                    ToolTip = 'Reserve the Qty. to Reserve on every order, oldest first. Each order is reserved on its own, so one failure does not stop the others.';

                    trigger OnAction()
                    begin
                        if not Confirm(ReserveAllQst, false) then
                            exit;
                        Mgt.ReserveAll();
                        ApplyView();
                        CurrPage.Update(false);
                    end;
                }
                action(CancelSuggestAll)
                {
                    Caption = 'Cancel Suggested Qty. on All Orders';
                    Image = Cancel;
                    ToolTip = 'Clear Qty. to Reserve on every order.';

                    trigger OnAction()
                    begin
                        Mgt.CancelSuggestionAll();
                        CurrPage.Update(false);
                    end;
                }
            }
        }
        area(Navigation)
        {
            action(OpenOrder)
            {
                Caption = 'Open Order';
                Image = Document;
                ToolTip = 'Open the selected sales or assembly order.';

                trigger OnAction()
                begin
                    Mgt.OpenOrder(Rec."Source Type", Rec."Order No.");
                end;
            }
            action(Setup)
            {
                Caption = 'Setup';
                Image = Setup;
                ToolTip = 'Open the Outstanding Orders Report Setup.';
                RunObject = page "KMS Sales Report Setup";
            }
        }
        area(Promoted)
        {
            group(Category_Process)
            {
                Caption = 'Process';

                actionref(Refresh_Promoted; Refresh)
                {
                }
                actionref(ShowHide_Promoted; ShowHideFullyOnShipment)
                {
                }
                group(Category_Bulk)
                {
                    Caption = 'Bulk Actions';
                    ShowAs = SplitButton;

                    actionref(SuggestAll_Promoted; SuggestAll)
                    {
                    }
                    actionref(ReserveAll_Promoted; ReserveAll)
                    {
                    }
                    actionref(CancelSuggestAll_Promoted; CancelSuggestAll)
                    {
                    }
                }
            }
        }
    }

    var
        Mgt: Codeunit "KMS Outstanding Orders Mgt.";
        ShowFullyOnShipment: Boolean;
        FlagStyle: Text;
        PDDStyle: Text;
        ReserveAllQst: Label 'Reserve the Qty. to Reserve on all orders?';

    trigger OnOpenPage()
    begin
        Mgt.BuildIfStale();
        Mgt.ShareOrders(Rec);
        CurrPage.Lines.Page.InitLines();
        ApplyView();
    end;

    trigger OnAfterGetRecord()
    begin
        FlagStyle := Mgt.GetStyle(Rec."Flag Colour");
        PDDStyle := 'Standard';
        if Rec."Promised Delivery Date" <> 0D then
            if Rec."Promised Delivery Date" <= Today() then
                PDDStyle := 'Unfavorable'
            else
                PDDStyle := 'Favorable';
    end;

    local procedure ApplyView()
    begin
        Rec.SetCurrentKey("Order Date", "Order No.");
        Rec.Ascending(false);
        Rec.FilterGroup(2);
        if ShowFullyOnShipment then
            Rec.SetRange("Fully on Shipment")
        else
            Rec.SetRange("Fully on Shipment", false);
        Rec.FilterGroup(0);
        if Rec.FindFirst() then;
    end;
}
