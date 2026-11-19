codeunit 77502 "KMS Reservation Mgt."
{
    // Creates and cancels reservations for report lines.
    // OnRun reserves the allocations of one order (or one line) so Reserve on All Orders can run each order
    // in its own transaction and carry on if one fails.
    // Lots are set on the stock side of the reservation only; the sales line's Item Tracking Lines stay empty.

    trigger OnRun()
    begin
        ReserveAllocations();
    end;

    var
        TempLine: Record "KMS Outstanding Order Line" temporary;
        TempAlloc: Record "KMS Lot Allocation" temporary;
        ContextSourceType: Enum "KMS Order Source";
        ContextOrderNo: Code[20];
        ContextLineNo: Integer;
        ReserveNeverErr: Label 'Item %1 on order %2, line %3 has Reserve = Never, so it cannot be reserved.', Comment = '%1 = item no., %2 = order no., %3 = line no.';
        TooMuchErr: Label 'Order %1, line %2 cannot have more reserved than its outstanding quantity. Refresh the report and try again.', Comment = '%1 = order no., %2 = line no.';
        NotEnoughStockErr: Label 'Only %1 of the %2 requested could be reserved for item %3, lot %4 at %5. Refresh the report and try again.', Comment = '%1 = qty reserved, %2 = qty requested, %3 = item no., %4 = lot no., %5 = location';

    procedure SetContext(var NewLine: Record "KMS Outstanding Order Line" temporary; var NewAlloc: Record "KMS Lot Allocation" temporary; SourceType: Enum "KMS Order Source"; OrderNo: Code[20]; LineNo: Integer)
    begin
        TempLine.Copy(NewLine, true);
        TempAlloc.Copy(NewAlloc, true);
        ContextSourceType := SourceType;
        ContextOrderNo := OrderNo;
        ContextLineNo := LineNo;
    end;

    local procedure ReserveAllocations()
    begin
        TempLine.Reset();
        TempLine.SetRange("Source Type", ContextSourceType);
        TempLine.SetRange("Order No.", ContextOrderNo);
        if ContextLineNo <> 0 then
            TempLine.SetRange("Line No.", ContextLineNo);
        TempLine.SetFilter("Qty. to Reserve", '>0');
        if TempLine.FindSet() then
            repeat
                TempAlloc.Reset();
                TempAlloc.SetRange("Source Type", TempLine."Source Type");
                TempAlloc.SetRange("Order No.", TempLine."Order No.");
                TempAlloc.SetRange("Line No.", TempLine."Line No.");
                if TempAlloc.FindSet() then
                    repeat
                        ReserveLotForLine(TempLine, TempAlloc."Lot No.", TempAlloc."Quantity (Base)");
                    until TempAlloc.Next() = 0;
            until TempLine.Next() = 0;
        TempLine.Reset();
        TempAlloc.Reset();
    end;

    /// <summary>Reserves QtyBase of one lot (blank for items that are not lot tracked) against open item ledger entries.</summary>
    procedure ReserveLotForLine(var L: Record "KMS Outstanding Order Line"; LotNo: Code[50]; QtyBase: Decimal)
    var
        ItemLedgerEntry: Record "Item Ledger Entry";
        Remaining: Decimal;
        Take: Decimal;
    begin
        if QtyBase <= 0 then
            exit;
        CheckDemandLine(L, QtyBase);
        ItemLedgerEntry.SetRange("Item No.", L."No.");
        ItemLedgerEntry.SetRange(Open, true);
        ItemLedgerEntry.SetRange(Positive, true);
        ItemLedgerEntry.SetRange("Variant Code", L."Variant Code");
        ItemLedgerEntry.SetRange("Location Code", L."Location Code");
        ItemLedgerEntry.SetRange("Lot No.", LotNo);
        Remaining := QtyBase;
        if ItemLedgerEntry.FindSet() then
            repeat
                ItemLedgerEntry.CalcFields("Reserved Quantity");
                Take := ItemLedgerEntry."Remaining Quantity" - ItemLedgerEntry."Reserved Quantity";
                if Take > Remaining then
                    Take := Remaining;
                if Take > 0 then begin
                    CreateReservation(L, ItemLedgerEntry, Take);
                    Remaining -= Take;
                end;
            until (ItemLedgerEntry.Next() = 0) or (Remaining <= 0);
        if Remaining > 0 then
            Error(NotEnoughStockErr, QtyBase - Remaining, QtyBase, L."No.", LotNo, L."Location Code");
    end;

    /// <summary>Cancels the line's reservations; with FilterByLot, only those against item ledger entries of that lot.</summary>
    procedure CancelLineReservations(var L: Record "KMS Outstanding Order Line"; FilterByLot: Boolean; LotNo: Code[50])
    var
        ReservEntry: Record "Reservation Entry";
        SupplyEntry: Record "Reservation Entry";
        CancelEntry: Record "Reservation Entry";
        ReservEngineMgt: Codeunit "Reservation Engine Mgt.";
        EntryNos: List of [Integer];
        EntryNo: Integer;
        Include: Boolean;
    begin
        FilterDemandReservations(L, ReservEntry);
        if ReservEntry.FindSet() then
            repeat
                Include := true;
                if FilterByLot then begin
                    Include := false;
                    if SupplyEntry.Get(ReservEntry."Entry No.", true) then
                        Include := (SupplyEntry."Source Type" = Database::"Item Ledger Entry") and (SupplyEntry."Lot No." = LotNo);
                end;
                if Include then
                    EntryNos.Add(ReservEntry."Entry No.");
            until ReservEntry.Next() = 0;

        foreach EntryNo in EntryNos do
            if CancelEntry.Get(EntryNo, false) then
                ReservEngineMgt.CancelReservation(CancelEntry);
    end;

    procedure FilterDemandReservations(var L: Record "KMS Outstanding Order Line"; var ReservEntry: Record "Reservation Entry")
    begin
        ReservEntry.Reset();
        ReservEntry.SetRange("Source Type", GetDemandTableNo(L));
        ReservEntry.SetRange("Source Subtype", 1); // Order, for both sales and assembly
        ReservEntry.SetRange("Source ID", L."Order No.");
        ReservEntry.SetRange("Source Batch Name", '');
        ReservEntry.SetRange("Source Ref. No.", L."Line No.");
        ReservEntry.SetRange("Reservation Status", ReservEntry."Reservation Status"::Reservation);
        ReservEntry.SetRange(Positive, false);
    end;

    /// <summary>Lots already assigned on the line's Item Tracking Lines (not yet reserved), so Suggest can use them first.</summary>
    procedure GetAssignedLots(var L: Record "KMS Outstanding Order Line"; var AssignedLots: Dictionary of [Code[50], Decimal])
    var
        ReservEntry: Record "Reservation Entry";
        Qty: Decimal;
    begin
        Clear(AssignedLots);
        ReservEntry.SetRange("Source Type", GetDemandTableNo(L));
        ReservEntry.SetRange("Source Subtype", 1);
        ReservEntry.SetRange("Source ID", L."Order No.");
        ReservEntry.SetRange("Source Batch Name", '');
        ReservEntry.SetRange("Source Ref. No.", L."Line No.");
        ReservEntry.SetFilter("Reservation Status", '<>%1', ReservEntry."Reservation Status"::Reservation);
        ReservEntry.SetFilter("Lot No.", '<>%1', '');
        if ReservEntry.FindSet() then
            repeat
                if AssignedLots.Get(ReservEntry."Lot No.", Qty) then
                    AssignedLots.Set(ReservEntry."Lot No.", Qty + Abs(ReservEntry."Quantity (Base)"))
                else
                    AssignedLots.Add(ReservEntry."Lot No.", Abs(ReservEntry."Quantity (Base)"));
            until ReservEntry.Next() = 0;
    end;

    local procedure CheckDemandLine(var L: Record "KMS Outstanding Order Line"; QtyBase: Decimal)
    var
        SalesLine: Record "Sales Line";
        AssemblyLine: Record "Assembly Line";
    begin
        case L."Source Type" of
            L."Source Type"::"Sales Order":
                begin
                    SalesLine.Get(SalesLine."Document Type"::Order, L."Order No.", L."Line No.");
                    if SalesLine.Reserve = SalesLine.Reserve::Never then
                        Error(ReserveNeverErr, L."No.", L."Order No.", L."Line No.");
                    SalesLine.CalcFields("Reserved Qty. (Base)");
                    if SalesLine."Reserved Qty. (Base)" + QtyBase > SalesLine."Outstanding Qty. (Base)" then
                        Error(TooMuchErr, L."Order No.", L."Line No.");
                end;
            L."Source Type"::"Assembly Order":
                begin
                    AssemblyLine.Get(AssemblyLine."Document Type"::Order, L."Order No.", L."Line No.");
                    if AssemblyLine.Reserve = AssemblyLine.Reserve::Never then
                        Error(ReserveNeverErr, L."No.", L."Order No.", L."Line No.");
                    AssemblyLine.CalcFields("Reserved Qty. (Base)");
                    if AssemblyLine."Reserved Qty. (Base)" + QtyBase > AssemblyLine."Remaining Quantity (Base)" then
                        Error(TooMuchErr, L."Order No.", L."Line No.");
                end;
        end;
    end;

    local procedure CreateReservation(var L: Record "KMS Outstanding Order Line"; var ItemLedgerEntry: Record "Item Ledger Entry"; QtyBase: Decimal)
    var
        TrackingSpecification: Record "Tracking Specification";
        ForReservEntry: Record "Reservation Entry";
        CreateReservEntry: Codeunit "Create Reserv. Entry";
        QtyPerUOM: Decimal;
    begin
        QtyPerUOM := L."Qty. per Unit of Measure";
        if QtyPerUOM = 0 then
            QtyPerUOM := 1;

        // Supply side: the item ledger entry, carrying the lot.
        TrackingSpecification.Init();
        TrackingSpecification.SetSource(Database::"Item Ledger Entry", 0, '', ItemLedgerEntry."Entry No.", '', 0);
        TrackingSpecification."Item No." := ItemLedgerEntry."Item No.";
        TrackingSpecification."Variant Code" := ItemLedgerEntry."Variant Code";
        TrackingSpecification."Location Code" := ItemLedgerEntry."Location Code";
        TrackingSpecification."Qty. per Unit of Measure" := ItemLedgerEntry."Qty. per Unit of Measure";
        TrackingSpecification.CopyTrackingFromItemLedgEntry(ItemLedgerEntry);

        // Demand side: the sales or assembly line, outbound so negative, with no lot (ForReservEntry left blank).
        CreateReservEntry.CreateReservEntryFor(
          GetDemandTableNo(L), 1, L."Order No.", '', 0, L."Line No.", QtyPerUOM,
          -Round(QtyBase / QtyPerUOM, 0.00001), -QtyBase, ForReservEntry);
        CreateReservEntry.CreateReservEntryFrom(TrackingSpecification);
        CreateReservEntry.CreateReservEntry(
          L."No.", L."Variant Code", L."Location Code", L.Description, 0D, L."Shipment Date", 0,
          "Reservation Status"::Reservation);
    end;

    local procedure GetDemandTableNo(var L: Record "KMS Outstanding Order Line"): Integer
    begin
        if L."Source Type" = L."Source Type"::"Assembly Order" then
            exit(Database::"Assembly Line");
        exit(Database::"Sales Line");
    end;
}
