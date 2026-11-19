page 77500 "KMS Sales Report Setup"
{
    Caption = 'Outstanding Orders Report Setup';
    PageType = Card;
    SourceTable = "KMS Sales Report Setup";
    ApplicationArea = All;
    UsageCategory = Administration;
    InsertAllowed = false;
    DeleteAllowed = false;

    layout
    {
        area(Content)
        {
            group(General)
            {
                Caption = 'General';

                field("Location Filter"; Rec."Location Filter")
                {
                    ToolTip = 'Specifies which locations the report loads lines for, for example SPEKE1.';
                }
                field("Min. Value for Part Shipment"; Rec."Min. Value for Part Shipment")
                {
                    ToolTip = 'Specifies the minimum value of ready lines for an order to count as Ready (Part Shipment). Fully reservable orders are Ready whatever their value.';
                }
                field("Value Incl. Non-Item Lines"; Rec."Value Incl. Non-Item Lines")
                {
                    ToolTip = 'Specifies whether non-item lines (charges, G/L lines) count towards the part shipment minimum value.';
                }
                field("Reservation Mode"; Rec."Reservation Mode")
                {
                    ToolTip = 'Specifies whether Suggest and Reserve work on whatever stock is available, or only on orders that can be fully reserved.';
                }
                field("Non-Pickable Bin Filter"; Rec."Non-Pickable Bin Filter")
                {
                    ToolTip = 'Specifies a filter of extra bin codes whose stock is never treated as pickable, for example QC*|DAMAGED.';
                }
            }
            group(CustomFields)
            {
                Caption = 'Existing custom fields';

                field("Warehouse Note Field Name"; Rec."Warehouse Note Field Name")
                {
                    ToolTip = 'Specifies the name of the existing Warehouse Note field on the sales header. Leave blank to hide it.';
                }
                field("Created By Field No."; Rec."Created By Field No.")
                {
                    ToolTip = 'Specifies the field number of the existing Created By field on the sales header. If it is blank on an order, the user who created the order is shown.';
                }
                field("Shelf Life Field Name"; Rec."Shelf Life Field Name")
                {
                    ToolTip = 'Specifies the name of the existing minimum remaining shelf life field on the customer card. A date formula or a number of days.';
                }
                field("Related Orders Field Name"; Rec."Related Orders Field Name")
                {
                    ToolTip = 'Specifies the name of the existing related orders field on the assembly header, used to link assembly orders to sales orders.';
                }
                field("Territory Field Name"; Rec."Territory Field Name")
                {
                    ToolTip = 'Specifies the name of an existing Region Territory field on the customer card. If it does not exist, the standard Territory Code is shown.';
                }
            }
        }
    }

    trigger OnOpenPage()
    begin
        Rec.Reset();
        if not Rec.Get() then begin
            Rec.Init();
            Rec.InitDefaults();
            Rec.Insert();
        end;
    end;
}
