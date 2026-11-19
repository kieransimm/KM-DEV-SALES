table 77502 "KMS Outstanding Order Line"
{
    Caption = 'Outstanding Order Line';
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
        field(3; "Line No."; Integer)
        {
            Caption = 'Line No.';
        }
        field(4; Flag; Text[10])
        {
            Caption = 'Flag';
        }
        field(5; "Flag Colour"; Enum "KMS Flag Colour")
        {
            Caption = 'Flag Colour';
        }
        field(6; "Line Type"; Text[30])
        {
            Caption = 'Line Type';
        }
        field(7; "No."; Code[20])
        {
            Caption = 'Item No.';
        }
        field(8; Description; Text[100])
        {
            Caption = 'Description';
        }
        field(9; "Description 2"; Text[50])
        {
            Caption = 'Description 2';
        }
        field(10; "Warehouse Class Code"; Code[10])
        {
            Caption = 'Warehouse Classification';
        }
        field(11; "Replenishment System"; Text[30])
        {
            Caption = 'Replen';
        }
        field(12; Status; Enum "KMS Line Status")
        {
            Caption = 'Status';
        }
        field(13; Quantity; Decimal)
        {
            Caption = 'Quantity';
            DecimalPlaces = 0 : 5;
        }
        field(14; "Quantity Shipped"; Decimal)
        {
            Caption = 'Shipped Quantity';
            DecimalPlaces = 0 : 5;
        }
        field(15; "Quantity Invoiced"; Decimal)
        {
            Caption = 'Invoiced Quantity';
            DecimalPlaces = 0 : 5;
        }
        field(16; "Outstanding Quantity"; Decimal)
        {
            Caption = 'Outstanding Quantity';
            DecimalPlaces = 0 : 5;
        }
        field(17; "Outstanding Qty. (Base)"; Decimal)
        {
            Caption = 'Outstanding Qty. (Base)';
            DecimalPlaces = 0 : 5;
        }
        field(18; "Unit Price"; Decimal)
        {
            Caption = 'Unit Price';
            AutoFormatType = 2;
        }
        field(19; "Unit Cost (LCY)"; Decimal)
        {
            Caption = 'Unit Cost (LCY)';
            AutoFormatType = 2;
        }
        field(20; "Unshipped Value (LCY)"; Decimal)
        {
            Caption = 'Unshipped Value (LCY)';
            AutoFormatType = 1;
        }
        field(21; "Unshipped Cost (LCY)"; Decimal)
        {
            Caption = 'Unshipped Cost (LCY)';
            AutoFormatType = 1;
        }
        field(22; "Margin (LCY)"; Decimal)
        {
            Caption = 'Margin (LCY)';
            AutoFormatType = 1;
        }
        field(23; "Margin %"; Decimal)
        {
            Caption = 'Margin %';
            DecimalPlaces = 1 : 1;
        }
        field(24; "Ready Value (LCY)"; Decimal)
        {
            Caption = 'Ready Value (LCY)';
            AutoFormatType = 1;
        }
        field(25; "Reserved Value (LCY)"; Decimal)
        {
            Caption = 'Reserved Value (LCY)';
            AutoFormatType = 1;
        }
        field(30; "On Shipment Qty."; Decimal)
        {
            Caption = 'On Shipment Qty.';
            DecimalPlaces = 0 : 5;
        }
        field(31; "Reserved Qty."; Decimal)
        {
            Caption = 'Reserved Qty.';
            DecimalPlaces = 0 : 5;
        }
        field(32; "Unreserved Qty."; Decimal)
        {
            Caption = 'Unreserved Qty.';
            DecimalPlaces = 0 : 5;
        }
        field(33; "Ready Qty. (Base)"; Decimal)
        {
            Caption = 'Ready Qty. (Base)';
            DecimalPlaces = 0 : 5;
        }
        field(34; "Suggested Qty. to Reserve"; Decimal)
        {
            Caption = 'Suggested Qty. to Reserve';
            DecimalPlaces = 0 : 5;
        }
        field(35; "Qty. to Reserve"; Decimal)
        {
            Caption = 'Qty. to Reserve';
            DecimalPlaces = 0 : 5;
        }
        field(40; "Free Stock Meeting Expiry"; Decimal)
        {
            Caption = 'Free Stock Meeting Expiry';
            DecimalPlaces = 0 : 5;
        }
        field(41; "Free Pickable Stock"; Decimal)
        {
            Caption = 'Free Pickable Stock';
            DecimalPlaces = 0 : 5;
        }
        field(42; "Free Stock Below Expiry"; Decimal)
        {
            Caption = 'Free Stock Below Expiry';
            DecimalPlaces = 0 : 5;
        }
        field(43; "Reserved on Unshipped Orders"; Decimal)
        {
            Caption = 'Reserved on Unshipped Orders';
            DecimalPlaces = 0 : 5;
        }
        field(44; "Qty. in Receive Bins"; Decimal)
        {
            Caption = 'Qty. in Receive Bins';
            DecimalPlaces = 0 : 5;
        }
        field(45; "Reserved Awaiting Put-away"; Decimal)
        {
            Caption = 'Reserved - Awaiting Put-away';
            DecimalPlaces = 0 : 5;
        }
        field(46; "Reserved Below Min. Expiry"; Decimal)
        {
            Caption = 'Reserved Below Min. Expiry';
            DecimalPlaces = 0 : 5;
        }
        field(50; "PO Expected"; Date)
        {
            Caption = 'PO Expected';
        }
        field(51; "PO No."; Code[20])
        {
            Caption = 'PO No.';
        }
        field(52; "PO No. (Outstanding Qty.)"; Text[60])
        {
            Caption = 'PO No. (Outstanding Qty.)';
        }
        field(53; "PO Vendor Name"; Text[100])
        {
            Caption = 'PO Vendor Name';
        }
        field(54; "Purchaser Code"; Code[20])
        {
            Caption = 'Purchaser Code';
        }
        field(60; "Reserved Lot Nos."; Text[250])
        {
            Caption = 'Reserved Lot No(s).';
        }
        field(61; "Reserved Lot Expiry"; Text[250])
        {
            Caption = 'Reserved Lot Expiry';
        }
        field(62; "Suggested Lot Nos."; Text[250])
        {
            Caption = 'Suggested Lot No(s).';
        }
        field(63; "Suggested Expiry Dates"; Text[250])
        {
            Caption = 'Suggested Expiry Dates';
        }
        field(64; "Whse. Shipment Nos."; Text[250])
        {
            Caption = 'Whse. Shipment No(s).';
        }
        field(65; "Assembly Order Nos."; Text[250])
        {
            Caption = 'Assembly Order No(s).';
        }
        field(70; "Location Code"; Code[10])
        {
            Caption = 'Location';
        }
        field(71; "Unit of Measure Code"; Code[10])
        {
            Caption = 'Unit of Measure';
        }
        field(72; "Variant Code"; Code[10])
        {
            Caption = 'Variant';
        }
        field(73; "Shipment Date"; Date)
        {
            Caption = 'Shipment Date';
        }
        field(74; "Qty. per Unit of Measure"; Decimal)
        {
            Caption = 'Qty. per Unit of Measure';
            DecimalPlaces = 0 : 5;
        }
        field(75; "Order Date"; Date)
        {
            Caption = 'Order Date';
        }
        field(76; "Customer Min. Expiry Date"; Date)
        {
            Caption = 'Customer Min. Expiry Date';
        }
        field(77; "Is Stock Item"; Boolean)
        {
            Caption = 'Is Stock Item';
        }
        field(78; "Drop Shipment"; Boolean)
        {
            Caption = 'Drop Shipment';
        }
    }

    keys
    {
        key(PK; "Source Type", "Order No.", "Line No.")
        {
            Clustered = true;
        }
    }
}
