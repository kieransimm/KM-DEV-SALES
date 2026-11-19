table 77504 "KMS Lot Allocation"
{
    Caption = 'Lot Allocation';
    TableType = Temporary;
    DataClassification = SystemMetadata;

    // Stock set aside for a line by Suggest or a typed Qty. to Reserve. Nothing is reserved until Reserve is run.
    fields
    {
        field(1; "Source Type"; Enum "KMS Order Source")
        {
            Caption = 'Document Type';
        }
        field(2; "Order No."; Code[20])
        {
            Caption = 'Order No.';
        }
        field(3; "Line No."; Integer)
        {
            Caption = 'Line No.';
        }
        field(4; "Lot No."; Code[50])
        {
            Caption = 'Lot No.';
        }
        field(5; "Item No."; Code[20])
        {
            Caption = 'Item No.';
        }
        field(6; "Variant Code"; Code[10])
        {
            Caption = 'Variant Code';
        }
        field(7; "Location Code"; Code[10])
        {
            Caption = 'Location Code';
        }
        field(8; "Expiration Date"; Date)
        {
            Caption = 'Expiration Date';
        }
        field(9; "Quantity (Base)"; Decimal)
        {
            Caption = 'Quantity (Base)';
            DecimalPlaces = 0 : 5;
        }
    }

    keys
    {
        key(PK; "Source Type", "Order No.", "Line No.", "Lot No.")
        {
            Clustered = true;
        }
        key(Item; "Item No.", "Variant Code", "Location Code")
        {
        }
    }
}
