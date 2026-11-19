table 77500 "KMS Sales Report Setup"
{
    Caption = 'Outstanding Orders Report Setup';
    DataClassification = CustomerContent;
    DrillDownPageId = "KMS Sales Report Setup";
    LookupPageId = "KMS Sales Report Setup";

    fields
    {
        field(1; "Primary Key"; Code[10])
        {
            Caption = 'Primary Key';
        }
        field(10; "Location Filter"; Text[250])
        {
            Caption = 'Location Filter';
        }
        field(11; "Min. Value for Part Shipment"; Decimal)
        {
            Caption = 'Min. Value for Part Shipment (LCY)';
            MinValue = 0;
            AutoFormatType = 1;
        }
        field(12; "Value Incl. Non-Item Lines"; Boolean)
        {
            Caption = 'Value Incl. Non-Item Lines';
        }
        field(13; "Reservation Mode"; Enum "KMS Reservation Mode")
        {
            Caption = 'Reservation Mode';
        }
        field(14; "Non-Pickable Bin Filter"; Text[250])
        {
            Caption = 'Non-Pickable Bin Filter';
        }
        // The report reads these existing custom fields by name or number at run time,
        // so KM-DEV-SALES does not need a dependency on the extensions that add them.
        field(20; "Warehouse Note Field Name"; Text[80])
        {
            Caption = 'Sales Header Warehouse Note Field';
        }
        field(21; "Created By Field No."; Integer)
        {
            Caption = 'Sales Header Created By Field No.';
            MinValue = 0;
        }
        field(22; "Shelf Life Field Name"; Text[80])
        {
            Caption = 'Customer Min. Shelf Life Field';
        }
        field(23; "Related Orders Field Name"; Text[80])
        {
            Caption = 'Assembly Header Related Orders Field';
        }
        field(24; "Territory Field Name"; Text[80])
        {
            Caption = 'Customer Region Territory Field';
        }
    }

    keys
    {
        key(PK; "Primary Key")
        {
            Clustered = true;
        }
    }

    /// <summary>Loads the setup, or the defaults if nobody has opened the setup page yet (no insert, so read-only users can run the report).</summary>
    procedure GetSetup()
    begin
        if not Get() then begin
            Init();
            InitDefaults();
        end;
    end;

    procedure InitDefaults()
    begin
        "Location Filter" := 'SPEKE1';
        "Min. Value for Part Shipment" := 100;
        "Value Incl. Non-Item Lines" := false;
        "Reservation Mode" := "Reservation Mode"::"Reserve Available";
        "Warehouse Note Field Name" := 'Warehouse Note';
        "Created By Field No." := 50006;
        "Shelf Life Field Name" := 'Min. Remaining Shelf Life';
        "Related Orders Field Name" := 'Related_Orders';
        "Territory Field Name" := 'Region Territory';
    end;
}
