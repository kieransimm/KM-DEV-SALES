enum 77501 "KMS Order Status"
{
    Extensible = false;
    Caption = 'Order Status';

    // Values are in ranking order: the first one that applies to an order wins.
    value(0; " ")
    {
        Caption = ' ';
    }
    value(1; "Fully on Shipment")
    {
        Caption = 'Fully on Shipment';
    }
    value(2; "Customer Blocked")
    {
        Caption = 'Customer Blocked';
    }
    value(3; "Location Not Set Up")
    {
        Caption = 'Location Not Set Up';
    }
    value(4; Ready)
    {
        Caption = 'Ready';
    }
    value(5; "Ready (Before PDD)")
    {
        Caption = 'Ready but before PDD';
    }
    value(6; "Reserve Lines")
    {
        Caption = 'Reserve Lines';
    }
    value(7; "Short-Dated Stock Only")
    {
        Caption = 'Short-Dated Stock Only';
    }
    value(8; "Awaiting Put-away")
    {
        Caption = 'Awaiting Put-away';
    }
    value(9; "Ready (Part Shipment)")
    {
        Caption = 'Ready (Part Shipment)';
    }
    value(10; "Below Min. Value")
    {
        Caption = 'Below Min. Value';
    }
    value(11; "Partial Stock (Ship Complete)")
    {
        Caption = 'Partial Stock (Ship Complete)';
    }
    value(12; "No Stock (Partly on Shipment)")
    {
        Caption = 'No Stock (Partly on Shipment)';
    }
    value(13; "No Stock")
    {
        Caption = 'No Stock';
    }
}

enum 77502 "KMS Line Status"
{
    Extensible = false;
    Caption = 'Line Status';

    value(0; " ")
    {
        Caption = ' ';
    }
    value(1; "Not Stock Item")
    {
        Caption = 'Not a Stock Item';
    }
    value(2; "Location Not Set Up")
    {
        Caption = 'Location Not Set Up';
    }
    value(3; "Fully on Shipment")
    {
        Caption = 'Fully on Shipment';
    }
    value(4; Ready)
    {
        Caption = 'Ready';
    }
    value(5; "Reserve Lines")
    {
        Caption = 'Reserve Lines';
    }
    value(6; "Awaiting Put-away")
    {
        Caption = 'Awaiting Put-away';
    }
    value(7; "Short-Dated Stock Only")
    {
        Caption = 'Short-Dated Stock Only';
    }
    value(8; "Partial Reservation (No Stock)")
    {
        Caption = 'Partial Reservation (No Stock)';
    }
    value(9; "No Stock (Partly on Shipment)")
    {
        Caption = 'No Stock (Partly on Shipment)';
    }
    value(10; "No Stock")
    {
        Caption = 'No Stock';
    }
}

enum 77503 "KMS Flag Colour"
{
    Extensible = false;
    Caption = 'Flag Colour';

    value(0; None)
    {
        Caption = ' ';
    }
    value(1; Green)
    {
        Caption = 'Green';
    }
    value(2; Blue)
    {
        Caption = 'Blue';
    }
    value(3; Amber)
    {
        Caption = 'Amber';
    }
    value(4; Red)
    {
        Caption = 'Red';
    }
    value(5; Grey)
    {
        Caption = 'Grey';
    }
}

enum 77504 "KMS Order Source"
{
    Extensible = false;
    Caption = 'Document Type';

    value(0; "Sales Order")
    {
        Caption = 'Sales Order';
    }
    value(1; "Assembly Order")
    {
        Caption = 'Assembly Order';
    }
}
