permissionset 77500 "KMS SALES REPORT"
{
    Assignable = true;
    Caption = 'Outstanding Orders Report';

    // For salespeople. Gives the Outstanding Orders Report and its reservation actions only:
    // it does not include the Order Release Worksheet or any shipment/pick creation.
    // Assign alongside the user's normal sales permission sets.
    Permissions =
        tabledata "KMS Sales Report Setup" = R,
        table "KMS Sales Report Setup" = X,
        page "KMS Outstanding Orders" = X,
        page "KMS Outstanding Order Lines" = X,
        codeunit "KMS Outstanding Orders Mgt." = X,
        codeunit "KMS Stock Calculation" = X,
        codeunit "KMS Reservation Mgt." = X,
        codeunit "KMS Optional Fields" = X,
        query "KMS Whse. Qty by Bin Lot" = X,
        tabledata "Sales Header" = R,
        tabledata "Sales Line" = R,
        tabledata Customer = R,
        tabledata Item = R,
        tabledata "Item Ledger Entry" = R,
        tabledata "Reservation Entry" = RIMD,
        tabledata "Action Message Entry" = RIMD,
        tabledata "Tracking Specification" = R,
        tabledata "Item Tracking Code" = R,
        tabledata "Warehouse Entry" = R,
        tabledata "Warehouse Activity Line" = R,
        tabledata "Warehouse Shipment Header" = R,
        tabledata "Warehouse Shipment Line" = R,
        tabledata Bin = R,
        tabledata "Bin Type" = R,
        tabledata Location = R,
        tabledata "Purchase Header" = R,
        tabledata "Purchase Line" = R,
        tabledata "Assembly Header" = R,
        tabledata "Assembly Line" = R,
        tabledata "Assemble-to-Order Link" = R,
        tabledata "Shipping Agent Services" = R,
        tabledata User = R;
}

permissionset 77501 "KMS SALES RPT ADMIN"
{
    Assignable = true;
    Caption = 'Outstanding Orders Report Admin';
    IncludedPermissionSets = "KMS SALES REPORT";

    Permissions =
        tabledata "KMS Sales Report Setup" = RIMD,
        page "KMS Sales Report Setup" = X;
}
