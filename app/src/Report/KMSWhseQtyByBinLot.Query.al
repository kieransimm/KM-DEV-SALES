query 77500 "KMS Whse. Qty by Bin Lot"
{
    Caption = 'Warehouse Qty. by Bin and Lot';
    QueryType = Normal;

    elements
    {
        dataitem(WarehouseEntry; "Warehouse Entry")
        {
            filter(Item_No; "Item No.")
            {
            }
            filter(Location_Code; "Location Code")
            {
            }
            filter(Variant_Code; "Variant Code")
            {
            }
            column(Bin_Code; "Bin Code")
            {
            }
            column(Lot_No; "Lot No.")
            {
            }
            column(Expiration_Date; "Expiration Date")
            {
            }
            column(Qty_Base; "Qty. (Base)")
            {
                Method = Sum;
            }
        }
    }
}
