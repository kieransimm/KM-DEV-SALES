table 77503 "KMS Lot Stock"
{
    Caption = 'Lot Stock';
    TableType = Temporary;
    DataClassification = SystemMetadata;

    // One row per item / variant / location / lot (blank lot for items that are not lot tracked).
    fields
    {
        field(1; "Item No."; Code[20])
        {
            Caption = 'Item No.';
        }
        field(2; "Variant Code"; Code[10])
        {
            Caption = 'Variant Code';
        }
        field(3; "Location Code"; Code[10])
        {
            Caption = 'Location Code';
        }
        field(4; "Lot No."; Code[50])
        {
            Caption = 'Lot No.';
        }
        field(5; "Expiration Date"; Date)
        {
            Caption = 'Expiration Date';
        }
        field(6; "FEFO Date"; Date)
        {
            Caption = 'FEFO Date';
        }
        field(10; "Pickable Qty."; Decimal)
        {
            Caption = 'Qty. in Pickable Bins';
            DecimalPlaces = 0 : 5;
        }
        field(11; "Pick Qty."; Decimal)
        {
            Caption = 'Qty. on Open Picks';
            DecimalPlaces = 0 : 5;
        }
        field(12; "Reserved Qty."; Decimal)
        {
            Caption = 'Reserved Qty.';
            DecimalPlaces = 0 : 5;
        }
        field(13; "Receive Qty."; Decimal)
        {
            Caption = 'Qty. in Receive Bins';
            DecimalPlaces = 0 : 5;
        }
        field(14; "Other Qty."; Decimal)
        {
            Caption = 'Qty. in Other Bins';
            DecimalPlaces = 0 : 5;
        }
        field(15; "Free Qty."; Decimal)
        {
            Caption = 'Free Pickable Qty.';
            DecimalPlaces = 0 : 5;
        }
        field(16; "Allocated Qty."; Decimal)
        {
            Caption = 'Allocated Qty.';
            DecimalPlaces = 0 : 5;
        }
    }

    keys
    {
        key(PK; "Item No.", "Variant Code", "Location Code", "Lot No.")
        {
            Clustered = true;
        }
        key(FEFO; "Item No.", "Variant Code", "Location Code", "FEFO Date")
        {
        }
    }
}
