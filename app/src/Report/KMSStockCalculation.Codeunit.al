codeunit 77501 "KMS Stock Calculation"
{
    // Works out free stock in pickable bins, per lot, for each item / variant / location the report needs.
    // Free = qty in pickable bins - qty on open picks (take lines) - qty reserved but not yet on a pick.
    // Each item / variant / location is loaded once per build and cached.

    var
        TempLot: Record "KMS Lot Stock" temporary;
        TempLocation: Record Location temporary;
        Setup: Record "KMS Sales Report Setup";
        LoadedKeys: Dictionary of [Text, Boolean];
        ReservedTotals: Dictionary of [Text, Decimal];
        ReceiveTotals: Dictionary of [Text, Decimal];
        WhseShipmentTotals: Dictionary of [Text, Decimal];
        BinKinds: Dictionary of [Text, Integer];

    procedure Initialise(NewSetup: Record "KMS Sales Report Setup")
    begin
        Setup := NewSetup;
        TempLot.Reset();
        TempLot.DeleteAll();
        TempLocation.Reset();
        TempLocation.DeleteAll();
        Clear(LoadedKeys);
        Clear(ReservedTotals);
        Clear(ReceiveTotals);
        Clear(WhseShipmentTotals);
        Clear(BinKinds);
    end;

    procedure ShareLots(var Target: Record "KMS Lot Stock" temporary)
    begin
        Target.Copy(TempLot, true);
    end;

    procedure MakeKey(ItemNo: Code[20]; VariantCode: Code[10]; LocationCode: Code[10]): Text
    begin
        exit(ItemNo + '|' + VariantCode + '|' + LocationCode);
    end;

    /// <summary>Sales: bins plus Require Shipment and Require Pick, or directed put-away and pick. Assembly: bins plus Require Pick, or directed.</summary>
    procedure IsLocationSetUp(LocationCode: Code[10]; ForAssembly: Boolean): Boolean
    begin
        if not GetLocation(LocationCode) then
            exit(false);
        if not TempLocation."Bin Mandatory" then
            exit(false);
        if TempLocation."Directed Put-away and Pick" then
            exit(true);
        if ForAssembly then
            exit(TempLocation."Require Pick");
        exit(TempLocation."Require Shipment" and TempLocation."Require Pick");
    end;

    procedure EnsureLoaded(ItemNo: Code[20]; VariantCode: Code[10]; LocationCode: Code[10])
    var
        KeyTxt: Text;
        ReceiveTotal: Decimal;
        UnassignedPick: Decimal;
    begin
        KeyTxt := MakeKey(ItemNo, VariantCode, LocationCode);
        if LoadedKeys.ContainsKey(KeyTxt) then
            exit;
        LoadedKeys.Add(KeyTxt, true);

        if GetLocation(LocationCode) and TempLocation."Bin Mandatory" then begin
            LoadBinQuantities(ItemNo, VariantCode, LocationCode, ReceiveTotal);
            LoadOpenPicks(ItemNo, VariantCode, LocationCode, UnassignedPick);
        end;
        ReservedTotals.Set(KeyTxt, LoadReservations(ItemNo, VariantCode, LocationCode));
        ReceiveTotals.Set(KeyTxt, ReceiveTotal);
        WhseShipmentTotals.Set(KeyTxt, LoadWhseShipmentQty(ItemNo, VariantCode, LocationCode));
        CalculateFree(ItemNo, VariantCode, LocationCode);
        if UnassignedPick > 0 then
            DeductUnassignedPicks(ItemNo, VariantCode, LocationCode, UnassignedPick);
        TempLot.Reset();
    end;

    procedure Invalidate(ItemNo: Code[20]; VariantCode: Code[10]; LocationCode: Code[10])
    var
        KeyTxt: Text;
    begin
        KeyTxt := MakeKey(ItemNo, VariantCode, LocationCode);
        TempLot.Reset();
        TempLot.SetRange("Item No.", ItemNo);
        TempLot.SetRange("Variant Code", VariantCode);
        TempLot.SetRange("Location Code", LocationCode);
        TempLot.DeleteAll();
        TempLot.Reset();
        if LoadedKeys.ContainsKey(KeyTxt) then
            LoadedKeys.Remove(KeyTxt);
        if ReservedTotals.ContainsKey(KeyTxt) then
            ReservedTotals.Remove(KeyTxt);
        if ReceiveTotals.ContainsKey(KeyTxt) then
            ReceiveTotals.Remove(KeyTxt);
        if WhseShipmentTotals.ContainsKey(KeyTxt) then
            WhseShipmentTotals.Remove(KeyTxt);
    end;

    /// <summary>Free pickable stock, split into lots meeting the minimum expiry date and lots below it. Expired lots are never counted.</summary>
    procedure GetFree(ItemNo: Code[20]; VariantCode: Code[10]; LocationCode: Code[10]; MinExpiryDate: Date; var FreeMeeting: Decimal; var FreeBelow: Decimal)
    begin
        FreeMeeting := 0;
        FreeBelow := 0;
        EnsureLoaded(ItemNo, VariantCode, LocationCode);
        TempLot.Reset();
        TempLot.SetRange("Item No.", ItemNo);
        TempLot.SetRange("Variant Code", VariantCode);
        TempLot.SetRange("Location Code", LocationCode);
        if TempLot.FindSet() then
            repeat
                if not IsExpired(TempLot."Expiration Date") then
                    if MeetsMinExpiry(TempLot."Expiration Date", MinExpiryDate) then
                        FreeMeeting += TempLot."Free Qty."
                    else
                        FreeBelow += TempLot."Free Qty.";
            until TempLot.Next() = 0;
        TempLot.Reset();
    end;

    procedure GetReservedTotal(ItemNo: Code[20]; VariantCode: Code[10]; LocationCode: Code[10]): Decimal
    begin
        EnsureLoaded(ItemNo, VariantCode, LocationCode);
        exit(GetTotal(ReservedTotals, MakeKey(ItemNo, VariantCode, LocationCode)));
    end;

    procedure GetReceiveTotal(ItemNo: Code[20]; VariantCode: Code[10]; LocationCode: Code[10]): Decimal
    begin
        EnsureLoaded(ItemNo, VariantCode, LocationCode);
        exit(GetTotal(ReceiveTotals, MakeKey(ItemNo, VariantCode, LocationCode)));
    end;

    procedure GetWhseShipmentTotal(ItemNo: Code[20]; VariantCode: Code[10]; LocationCode: Code[10]): Decimal
    begin
        EnsureLoaded(ItemNo, VariantCode, LocationCode);
        exit(GetTotal(WhseShipmentTotals, MakeKey(ItemNo, VariantCode, LocationCode)));
    end;

    procedure IsExpired(ExpirationDate: Date): Boolean
    begin
        exit((ExpirationDate <> 0D) and (ExpirationDate < Today()));
    end;

    procedure MeetsMinExpiry(ExpirationDate: Date; MinExpiryDate: Date): Boolean
    begin
        exit((ExpirationDate = 0D) or (MinExpiryDate = 0D) or (ExpirationDate >= MinExpiryDate));
    end;

    local procedure GetTotal(var Totals: Dictionary of [Text, Decimal]; KeyTxt: Text): Decimal
    var
        Value: Decimal;
    begin
        if Totals.Get(KeyTxt, Value) then
            exit(Value);
        exit(0);
    end;

    local procedure LoadBinQuantities(ItemNo: Code[20]; VariantCode: Code[10]; LocationCode: Code[10]; var ReceiveTotal: Decimal)
    var
        WhseQty: Query "KMS Whse. Qty by Bin Lot";
        Kind: Integer;
    begin
        WhseQty.SetRange(Item_No, ItemNo);
        WhseQty.SetRange(Location_Code, LocationCode);
        WhseQty.SetRange(Variant_Code, VariantCode);
        WhseQty.Open();
        while WhseQty.Read() do
            if WhseQty.Qty_Base <> 0 then begin
                GetOrCreateLot(ItemNo, VariantCode, LocationCode, WhseQty.Lot_No, WhseQty.Expiration_Date);
                Kind := GetBinKind(LocationCode, WhseQty.Bin_Code);
                if Kind = BinKindPickable() then
                    TempLot."Pickable Qty." += WhseQty.Qty_Base
                else
                    if Kind = BinKindReceive() then begin
                        TempLot."Receive Qty." += WhseQty.Qty_Base;
                        ReceiveTotal += WhseQty.Qty_Base;
                    end else
                        TempLot."Other Qty." += WhseQty.Qty_Base;
                TempLot.Modify();
            end;
        WhseQty.Close();
    end;

    local procedure LoadOpenPicks(ItemNo: Code[20]; VariantCode: Code[10]; LocationCode: Code[10]; var UnassignedPick: Decimal)
    var
        WhseActivityLine: Record "Warehouse Activity Line";
    begin
        WhseActivityLine.SetLoadFields("Bin Code", "Lot No.", "Expiration Date", "Qty. Outstanding (Base)");
        WhseActivityLine.SetRange("Activity Type", WhseActivityLine."Activity Type"::Pick);
        WhseActivityLine.SetRange("Action Type", WhseActivityLine."Action Type"::Take);
        WhseActivityLine.SetRange("Item No.", ItemNo);
        WhseActivityLine.SetRange("Location Code", LocationCode);
        WhseActivityLine.SetRange("Variant Code", VariantCode);
        if WhseActivityLine.FindSet() then
            repeat
                if GetBinKind(LocationCode, WhseActivityLine."Bin Code") = BinKindPickable() then
                    if WhseActivityLine."Lot No." <> '' then begin
                        GetOrCreateLot(ItemNo, VariantCode, LocationCode, WhseActivityLine."Lot No.", WhseActivityLine."Expiration Date");
                        TempLot."Pick Qty." += WhseActivityLine."Qty. Outstanding (Base)";
                        TempLot.Modify();
                    end else
                        UnassignedPick += WhseActivityLine."Qty. Outstanding (Base)";
            until WhseActivityLine.Next() = 0;
    end;

    local procedure LoadReservations(ItemNo: Code[20]; VariantCode: Code[10]; LocationCode: Code[10]) Total: Decimal
    var
        ReservEntry: Record "Reservation Entry";
    begin
        ReservEntry.SetLoadFields("Lot No.", "Expiration Date", "Quantity (Base)");
        ReservEntry.SetRange("Source Type", Database::"Item Ledger Entry");
        ReservEntry.SetRange("Item No.", ItemNo);
        ReservEntry.SetRange("Variant Code", VariantCode);
        ReservEntry.SetRange("Location Code", LocationCode);
        ReservEntry.SetRange("Reservation Status", ReservEntry."Reservation Status"::Reservation);
        ReservEntry.SetRange(Positive, true);
        if ReservEntry.FindSet() then
            repeat
                GetOrCreateLot(ItemNo, VariantCode, LocationCode, ReservEntry."Lot No.", ReservEntry."Expiration Date");
                TempLot."Reserved Qty." += ReservEntry."Quantity (Base)";
                TempLot.Modify();
                Total += ReservEntry."Quantity (Base)";
            until ReservEntry.Next() = 0;
    end;

    local procedure LoadWhseShipmentQty(ItemNo: Code[20]; VariantCode: Code[10]; LocationCode: Code[10]): Decimal
    var
        WhseShipmentLine: Record "Warehouse Shipment Line";
    begin
        WhseShipmentLine.SetRange("Item No.", ItemNo);
        WhseShipmentLine.SetRange("Variant Code", VariantCode);
        WhseShipmentLine.SetRange("Location Code", LocationCode);
        WhseShipmentLine.CalcSums("Qty. Outstanding (Base)");
        exit(WhseShipmentLine."Qty. Outstanding (Base)");
    end;

    local procedure CalculateFree(ItemNo: Code[20]; VariantCode: Code[10]; LocationCode: Code[10])
    var
        ReservedNotOnPick: Decimal;
    begin
        TempLot.Reset();
        TempLot.SetRange("Item No.", ItemNo);
        TempLot.SetRange("Variant Code", VariantCode);
        TempLot.SetRange("Location Code", LocationCode);
        if TempLot.FindSet() then
            repeat
                if IsExpired(TempLot."Expiration Date") then
                    TempLot."Free Qty." := 0
                else begin
                    // Units on an open pick are deducted once; reservations already on a pick are not deducted again.
                    ReservedNotOnPick := TempLot."Reserved Qty." - TempLot."Pick Qty.";
                    if ReservedNotOnPick < 0 then
                        ReservedNotOnPick := 0;
                    TempLot."Free Qty." := TempLot."Pickable Qty." - TempLot."Pick Qty." - ReservedNotOnPick;
                    if TempLot."Free Qty." < 0 then
                        TempLot."Free Qty." := 0;
                end;
                TempLot.Modify();
            until TempLot.Next() = 0;
    end;

    local procedure DeductUnassignedPicks(ItemNo: Code[20]; VariantCode: Code[10]; LocationCode: Code[10]; Qty: Decimal)
    var
        Take: Decimal;
    begin
        // Pick lines without a lot yet: take them off the earliest-expiring lots first, as FEFO picking would.
        TempLot.Reset();
        TempLot.SetCurrentKey("Item No.", "Variant Code", "Location Code", "FEFO Date");
        TempLot.SetRange("Item No.", ItemNo);
        TempLot.SetRange("Variant Code", VariantCode);
        TempLot.SetRange("Location Code", LocationCode);
        if TempLot.FindSet() then
            repeat
                Take := TempLot."Free Qty.";
                if Take > Qty then
                    Take := Qty;
                if Take > 0 then begin
                    TempLot."Free Qty." -= Take;
                    TempLot.Modify();
                    Qty -= Take;
                end;
            until (TempLot.Next() = 0) or (Qty <= 0);
        TempLot.Reset();
    end;

    local procedure GetOrCreateLot(ItemNo: Code[20]; VariantCode: Code[10]; LocationCode: Code[10]; LotNo: Code[50]; ExpirationDate: Date)
    begin
        if TempLot.Get(ItemNo, VariantCode, LocationCode, LotNo) then begin
            if (TempLot."Expiration Date" = 0D) and (ExpirationDate <> 0D) then begin
                TempLot."Expiration Date" := ExpirationDate;
                TempLot."FEFO Date" := ExpirationDate;
                TempLot.Modify();
            end;
            exit;
        end;
        TempLot.Init();
        TempLot."Item No." := ItemNo;
        TempLot."Variant Code" := VariantCode;
        TempLot."Location Code" := LocationCode;
        TempLot."Lot No." := LotNo;
        TempLot."Expiration Date" := ExpirationDate;
        if ExpirationDate = 0D then
            TempLot."FEFO Date" := DMY2Date(31, 12, 9999)
        else
            TempLot."FEFO Date" := ExpirationDate;
        TempLot.Insert();
    end;

    local procedure GetLocation(LocationCode: Code[10]): Boolean
    var
        Location: Record Location;
    begin
        if LocationCode = '' then
            exit(false);
        if TempLocation.Get(LocationCode) then
            exit(true);
        if not Location.Get(LocationCode) then
            exit(false);
        TempLocation := Location;
        TempLocation.Insert();
        exit(true);
    end;

    local procedure GetBinKind(LocationCode: Code[10]; BinCode: Code[20]): Integer
    var
        KeyTxt: Text;
        Kind: Integer;
    begin
        KeyTxt := LocationCode + '|' + BinCode;
        if BinKinds.Get(KeyTxt, Kind) then
            exit(Kind);
        Kind := ComputeBinKind(LocationCode, BinCode);
        BinKinds.Add(KeyTxt, Kind);
        exit(Kind);
    end;

    local procedure ComputeBinKind(LocationCode: Code[10]; BinCode: Code[20]): Integer
    var
        Bin: Record Bin;
        BinType: Record "Bin Type";
        FilterBin: Record Bin;
    begin
        if (BinCode = '') or not GetLocation(LocationCode) then
            exit(BinKindOther());
        if BinCode = TempLocation."Receipt Bin Code" then
            exit(BinKindReceive());
        if IsSpecialBin(BinCode) then
            exit(BinKindOther());
        if not Bin.Get(LocationCode, BinCode) then
            exit(BinKindOther());
        if Bin.Dedicated then
            exit(BinKindOther());
        if Bin."Block Movement" in [Bin."Block Movement"::Outbound, Bin."Block Movement"::All] then
            exit(BinKindOther());
        if Bin."Bin Type Code" <> '' then
            if BinType.Get(Bin."Bin Type Code") then begin
                if BinType.Receive then
                    exit(BinKindReceive());
                if BinType.Ship or not BinType.Pick then
                    exit(BinKindOther());
            end;
        if (Bin."Bin Type Code" = '') and TempLocation."Directed Put-away and Pick" then
            exit(BinKindOther());
        if Setup."Non-Pickable Bin Filter" <> '' then begin
            FilterBin.SetRange("Location Code", LocationCode);
            FilterBin.FilterGroup(2);
            FilterBin.SetFilter(Code, Setup."Non-Pickable Bin Filter");
            FilterBin.FilterGroup(0);
            FilterBin.SetRange(Code, BinCode);
            if not FilterBin.IsEmpty() then
                exit(BinKindOther());
        end;
        exit(BinKindPickable());
    end;

    local procedure IsSpecialBin(BinCode: Code[20]): Boolean
    begin
        exit(
          (BinCode = TempLocation."Shipment Bin Code") or
          (BinCode = TempLocation."Adjustment Bin Code") or
          (BinCode = TempLocation."To-Assembly Bin Code") or
          (BinCode = TempLocation."From-Assembly Bin Code") or
          (BinCode = TempLocation."Asm.-to-Order Shpt. Bin Code") or
          (BinCode = TempLocation."To-Production Bin Code") or
          (BinCode = TempLocation."From-Production Bin Code") or
          (BinCode = TempLocation."Open Shop Floor Bin Code"));
    end;

    local procedure BinKindOther(): Integer
    begin
        exit(0);
    end;

    local procedure BinKindPickable(): Integer
    begin
        exit(1);
    end;

    local procedure BinKindReceive(): Integer
    begin
        exit(2);
    end;
}
