enum 77500 "KMS Reservation Mode"
{
    Extensible = false;
    Caption = 'Reservation Mode';

    value(0; "Reserve Available")
    {
        Caption = 'Reserve what is available';
    }
    value(1; "Fully Reservable Only")
    {
        Caption = 'Only fully reservable orders';
    }
}
