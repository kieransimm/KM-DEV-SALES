table 77501 "KMS Outstanding Order"
{
    Caption = 'Outstanding Order';
    TableType = Temporary;
    DataClassification = SystemMetadata;

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
        field(3; Flag; Text[10])
        {
            Caption = 'Flag';
        }
        field(4; "Flag Colour"; Enum "KMS Flag Colour")
        {
            Caption = 'Flag Colour';
        }
        field(5; Status; Enum "KMS Order Status")
        {
            Caption = 'Status';
        }
        field(6; "Order Date"; Date)
        {
            Caption = 'Order Date';
        }
        field(7; "Promised Delivery Date"; Date)
        {
            Caption = 'Promised Delivery Date';
        }
        field(8; "Warehouse Note"; Text[250])
        {
            Caption = 'Warehouse Note';
        }
        field(9; "Customer No."; Code[20])
        {
            Caption = 'Customer No.';
        }
        field(10; "Customer Name"; Text[100])
        {
            Caption = 'Customer Name';
        }
        field(11; "Shipping Advice"; Text[20])
        {
            Caption = 'Partial / Complete';
        }
        field(12; "Ship Complete"; Boolean)
        {
            Caption = 'Ship Complete';
        }
        field(13; "Item Lines"; Integer)
        {
            Caption = 'Item Lines';
        }
        field(14; "Lines Unreserved"; Integer)
        {
            Caption = 'Lines Unreserved';
        }
        field(15; "Lines Awaiting Put-away"; Integer)
        {
            Caption = 'Lines Awaiting Put-away';
        }
        field(16; "Unshipped Value (LCY)"; Decimal)
        {
            Caption = 'Unshipped Value (LCY)';
            AutoFormatType = 1;
        }
        field(17; "Ready Value (LCY)"; Decimal)
        {
            Caption = 'Ready Value (LCY)';
            AutoFormatType = 1;
        }
        field(18; "Reserved Value (LCY)"; Decimal)
        {
            Caption = 'Reserved Value (LCY)';
            AutoFormatType = 1;
        }
        field(19; "Unshipped Cost (LCY)"; Decimal)
        {
            Caption = 'Unshipped Cost (LCY)';
            AutoFormatType = 1;
        }
        field(20; "Margin (LCY)"; Decimal)
        {
            Caption = 'Margin (LCY)';
            AutoFormatType = 1;
        }
        field(21; "Margin %"; Decimal)
        {
            Caption = 'Margin %';
            DecimalPlaces = 1 : 1;
        }
        field(22; "Created By"; Text[100])
        {
            Caption = 'Created By';
        }
        field(23; "Shipment Method Code"; Code[10])
        {
            Caption = 'Shipment Method';
        }
        field(24; "Shipping Agent Code"; Code[10])
        {
            Caption = 'Shipment Method Agent';
        }
        field(25; "Shipping Agent Service"; Text[100])
        {
            Caption = 'Shipment Method Agent Service';
        }
        field(26; "Territory Code"; Text[50])
        {
            Caption = 'Region Territory';
        }
        field(27; "Salesperson Code"; Code[20])
        {
            Caption = 'Salesperson Code';
        }
        field(28; Blocked; Text[20])
        {
            Caption = 'Blocked';
        }
        field(29; "Customer Blocked"; Boolean)
        {
            Caption = 'Customer Blocked';
        }
        field(30; "Customer Min. Expiry Date"; Date)
        {
            Caption = 'Customer Min. Expiry Date';
        }
        field(31; "Min. Remaining Shelf Life"; Text[30])
        {
            Caption = 'Min. Remaining Shelf Life';
        }
        field(32; "Document Status"; Text[30])
        {
            Caption = 'Status (Order)';
        }
        field(33; "Whse. Shipment No."; Code[20])
        {
            Caption = 'Whse. Shipment No.';
        }
        field(34; "Whse. Shipment Status"; Text[30])
        {
            Caption = 'Whse. Shipment Status';
        }
        field(35; "Related Order"; Text[250])
        {
            Caption = 'Related Order';
        }
        field(36; "Shipment Date"; Date)
        {
            Caption = 'Shipment Date';
        }
        field(37; "Location Code"; Code[10])
        {
            Caption = 'Location';
        }
        field(38; "Fully on Shipment"; Boolean)
        {
            Caption = 'Fully on Shipment';
        }
    }

    keys
    {
        key(PK; "Source Type", "Order No.")
        {
            Clustered = true;
        }
        key(OrderDate; "Order Date", "Order No.")
        {
        }
    }
}
