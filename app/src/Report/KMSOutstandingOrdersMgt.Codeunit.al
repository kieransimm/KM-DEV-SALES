codeunit 77500 "KMS Outstanding Orders Mgt."
{
    // All logic behind the Outstanding Orders Report: build the order and line buffers, work out statuses
    // and colours, and run Suggest / Reserve / Cancel / Reduce.
    // Single instance so the report page and its Order Lines part share the same buffers in a session.
    SingleInstance = true;

    var
        TempOrder: Record "KMS Outstanding Order" temporary;
        TempLine: Record "KMS Outstanding Order Line" temporary;
        TempLot: Record "KMS Lot Stock" temporary;
        TempAlloc: Record "KMS Lot Allocation" temporary;
        TempItemCache: Record Item temporary;
        TempCustomerCache: Record Customer temporary;
        Setup: Record "KMS Sales Report Setup";
        StockCalc: Codeunit "KMS Stock Calculation";
        OptionalFields: Codeunit "KMS Optional Fields";
        LocationMatchCache: Dictionary of [Code[10], Boolean];
        CustomerExpiryCache: Dictionary of [Code[20], Date];
        CustomerShelfLifeCache: Dictionary of [Code[20], Text];
        CustomerTerritoryCache: Dictionary of [Code[20], Text];
        AsmOrdersByItem: Dictionary of [Code[20], List of [Code[20]]];
        AsmRelatedText: Dictionary of [Code[20], Text];
        PurchaseLineCache: Dictionary of [Text, Text];
        LastBuildAt: DateTime;
        IsBuilt: Boolean;
        BuildingMsg: Label 'Building the Outstanding Orders Report...';
        NothingToReserveMsg: Label 'There is nothing to reserve on order %1. Use Suggest Qty. to Reserve, or type a Qty. to Reserve, first.', Comment = '%1 = order no.';
        NotFullyReservableMsg: Label 'Order %1 cannot be fully reserved, and Setup only allows fully reservable orders to be reserved.', Comment = '%1 = order no.';
        ReserveAllResultMsg: Label 'Orders reserved: %1\Orders skipped: %2\Orders that failed: %3%4', Comment = '%1 = count, %2 = count, %3 = count, %4 = error details';
        NothingToReserveLineErr: Label 'There is no Qty. to Reserve on this line.';
        NegativeQtyErr: Label 'Qty. to Reserve cannot be negative.';
        ExceedsNeedErr: Label 'Qty. to Reserve cannot be more than the unreserved quantity on the line (%1).', Comment = '%1 = quantity';
        NotEnoughStockErr: Label 'Only %1 of free pickable stock is available for this line across the report.', Comment = '%1 = quantity';
        ShortDatedQst: Label '%1 of this quantity would come from stock that expires before the customer''s minimum expiry date. Do you want to use short-dated stock?', Comment = '%1 = quantity';
        NotStockLineErr: Label 'Only lines for stocked items can be reserved.';
        LocationNotSetUpErr: Label 'Location %1 is not set up for bins and picks, so stock cannot be reserved from pickable bins.', Comment = '%1 = location code';
        ReduceSalesOnlyErr: Label 'Reduce Reservation to Pickable Qty. is for sales lines only. On assembly components, use Cancel Reservation.';
        FlagTxt: Label '●', Locked = true;
        GreyFlagTxt: Label '◐', Locked = true;
        AssemblyNameTxt: Label 'Assembly: %1 %2', Comment = '%1 = item no., %2 = item description';
        ComponentTxt: Label 'Component';
        DropShipmentTxt: Label 'Drop Shipment';
        SpecialOrderTxt: Label 'Special Order';
        QtyInBracketsTxt: Label '%1 (%2)', Locked = true;
        ErrorLineTxt: Label '\%1: %2', Locked = true;

    // ------------------------------------------------------------------ Build

    /// <summary>Rebuilds unless a build from the last 5 minutes can be reused (for Edit List and reopening the page).</summary>
    procedure BuildIfStale()
    begin
        if IsBuilt and (CurrentDateTime() - LastBuildAt < ReuseWindow()) then
            exit;
        Build();
    end;

    procedure Build()
    var
        Window: Dialog;
    begin
        Setup.GetSetup();
        ResetBuffers();
        StockCalc.Initialise(Setup);
        StockCalc.ShareLots(TempLot);
        if GuiAllowed() then
            Window.Open(BuildingMsg);
        BuildAssemblyIndex();
        BuildSalesOrders();
        BuildAssemblyOrders();
        if GuiAllowed() then
            Window.Close();
        LastBuildAt := CurrentDateTime();
        IsBuilt := true;
    end;

    procedure ShareOrders(var Target: Record "KMS Outstanding Order" temporary)
    begin
        Target.Copy(TempOrder, true);
    end;

    procedure ShareLines(var Target: Record "KMS Outstanding Order Line" temporary)
    begin
        Target.Copy(TempLine, true);
    end;

    local procedure ReuseWindow(): Duration
    begin
        exit(5 * 60 * 1000);
    end;

    local procedure ResetBuffers()
    begin
        TempOrder.Reset();
        TempOrder.DeleteAll();
        TempLine.Reset();
        TempLine.DeleteAll();
        TempAlloc.Reset();
        TempAlloc.DeleteAll();
        TempItemCache.Reset();
        TempItemCache.DeleteAll();
        TempCustomerCache.Reset();
        TempCustomerCache.DeleteAll();
        Clear(LocationMatchCache);
        Clear(CustomerExpiryCache);
        Clear(CustomerShelfLifeCache);
        Clear(CustomerTerritoryCache);
        Clear(AsmOrdersByItem);
        Clear(AsmRelatedText);
        Clear(PurchaseLineCache);
    end;

    local procedure BuildAssemblyIndex()
    var
        AssemblyHeader: Record "Assembly Header";
        RecRef: RecordRef;
    begin
        AssemblyHeader.SetRange("Document Type", AssemblyHeader."Document Type"::Order);
        if AssemblyHeader.FindSet() then
            repeat
                RecRef.GetTable(AssemblyHeader);
                AsmRelatedText.Set(AssemblyHeader."No.", OptionalFields.GetTextByName(RecRef, Setup."Related Orders Field Name"));
                RecRef.Close();
                AddAssemblyToIndex(AssemblyHeader."Item No.", AssemblyHeader."No.");
            until AssemblyHeader.Next() = 0;
    end;

    local procedure AddAssemblyToIndex(ItemNo: Code[20]; OrderNo: Code[20])
    var
        OrderList: List of [Code[20]];
    begin
        if AsmOrdersByItem.Get(ItemNo, OrderList) then
            OrderList.Add(OrderNo)
        else begin
            OrderList.Add(OrderNo);
            AsmOrdersByItem.Add(ItemNo, OrderList);
        end;
    end;

    local procedure BuildSalesOrders()
    var
        SalesHeader: Record "Sales Header";
    begin
        SalesHeader.SetRange("Document Type", SalesHeader."Document Type"::Order);
        SalesHeader.SetFilter(Status, '%1|%2', SalesHeader.Status::Open, SalesHeader.Status::Released);
        if SalesHeader.FindSet() then
            repeat
                BuildSalesOrder(SalesHeader);
            until SalesHeader.Next() = 0;
    end;

    local procedure BuildSalesOrder(var SalesHeader: Record "Sales Header")
    var
        SalesLine: Record "Sales Line";
        MinExpiry: Date;
        AnyItemAtLocation: Boolean;
    begin
        MinExpiry := GetCustomerMinExpiry(SalesHeader."Sell-to Customer No.");
        SalesLine.SetRange("Document Type", SalesHeader."Document Type");
        SalesLine.SetRange("Document No.", SalesHeader."No.");
        SalesLine.SetFilter(Type, '<>%1', SalesLine.Type::" ");
        SalesLine.SetFilter("Outstanding Quantity", '<>0');
        if SalesLine.FindSet() then
            repeat
                if SalesLine.Type = SalesLine.Type::Item then begin
                    if LocationMatches(SalesLine."Location Code") then begin
                        AnyItemAtLocation := true;
                        AddSalesLine(SalesHeader, SalesLine, MinExpiry);
                    end;
                end else
                    AddSalesLine(SalesHeader, SalesLine, MinExpiry);
            until SalesLine.Next() = 0;

        // An order belongs to the report when it is for the report's location(s).
        if not (AnyItemAtLocation or LocationMatches(SalesHeader."Location Code")) then begin
            DeleteOrderLines("KMS Order Source"::"Sales Order", SalesHeader."No.");
            exit;
        end;
        if not OrderHasLines("KMS Order Source"::"Sales Order", SalesHeader."No.") then
            exit;
        InsertSalesOrderRow(SalesHeader, MinExpiry);
    end;

    local procedure AddSalesLine(var SalesHeader: Record "Sales Header"; var SalesLine: Record "Sales Line"; MinExpiry: Date)
    var
        Item: Record Item;
        WhseShipmentNos: Text;
        IsItem: Boolean;
        IsInventory: Boolean;
        LinkedPONo: Code[20];
        LinkedPOLineNo: Integer;
    begin
        TempLine.Init();
        TempLine."Source Type" := TempLine."Source Type"::"Sales Order";
        TempLine."Order No." := SalesLine."Document No.";
        TempLine."Line No." := SalesLine."Line No.";
        TempLine."Order Date" := SalesHeader."Order Date";
        TempLine."No." := SalesLine."No.";
        TempLine.Description := SalesLine.Description;
        TempLine."Description 2" := SalesLine."Description 2";
        TempLine."Location Code" := SalesLine."Location Code";
        TempLine."Variant Code" := SalesLine."Variant Code";
        TempLine."Unit of Measure Code" := SalesLine."Unit of Measure Code";
        TempLine."Shipment Date" := SalesLine."Shipment Date";
        TempLine."Qty. per Unit of Measure" := SalesLine."Qty. per Unit of Measure";
        TempLine.Quantity := SalesLine.Quantity;
        TempLine."Quantity Shipped" := SalesLine."Quantity Shipped";
        TempLine."Quantity Invoiced" := SalesLine."Quantity Invoiced";
        TempLine."Outstanding Quantity" := SalesLine."Outstanding Quantity";
        TempLine."Outstanding Qty. (Base)" := SalesLine."Outstanding Qty. (Base)";
        TempLine."Unit Price" := SalesLine."Unit Price";
        TempLine."Unit Cost (LCY)" := SalesLine."Unit Cost (LCY)";
        TempLine."Unshipped Value (LCY)" := CalcUnshippedValueLCY(SalesHeader, SalesLine);
        TempLine."Unshipped Cost (LCY)" := Round(SalesLine."Unit Cost (LCY)" * SalesLine."Outstanding Quantity");
        TempLine."Margin (LCY)" := TempLine."Unshipped Value (LCY)" - TempLine."Unshipped Cost (LCY)";
        TempLine."Margin %" := CalcMarginPct(TempLine."Margin (LCY)", TempLine."Unshipped Value (LCY)");
        TempLine."Customer Min. Expiry Date" := MinExpiry;
        TempLine."Drop Shipment" := SalesLine."Drop Shipment" or SalesLine."Special Order";

        IsItem := SalesLine.Type = SalesLine.Type::Item;
        if IsItem then
            if GetItem(SalesLine."No.", Item) then begin
                if Item."Description 2" <> '' then
                    TempLine."Description 2" := Item."Description 2";
                TempLine."Warehouse Class Code" := Item."Warehouse Class Code";
                TempLine."Replenishment System" := CopyStr(Format(Item."Replenishment System"), 1, MaxStrLen(TempLine."Replenishment System"));
                IsInventory := Item.Type = Item.Type::Inventory;
            end;
        TempLine."Line Type" := GetSalesLineTypeText(SalesLine, Item, IsItem);
        TempLine."Is Stock Item" := IsInventory and not TempLine."Drop Shipment";

        if IsItem then begin
            if SalesLine."Drop Shipment" then begin
                LinkedPONo := SalesLine."Purchase Order No.";
                LinkedPOLineNo := SalesLine."Purch. Order Line No.";
            end;
            if SalesLine."Special Order" then begin
                LinkedPONo := SalesLine."Special Order Purchase No.";
                LinkedPOLineNo := SalesLine."Special Order Purch. Line No.";
            end;
            SetPurchaseInfo(TempLine, LinkedPONo, LinkedPOLineNo);
            TempLine."Assembly Order Nos." := CopyStr(GetAssemblyOrderNos(SalesLine), 1, MaxStrLen(TempLine."Assembly Order Nos."));
        end;

        if TempLine."Is Stock Item" then begin
            GetWhseShipmentInfo(Database::"Sales Line", SalesLine."Document Type".AsInteger(), SalesLine."Document No.", SalesLine."Line No.", TempLine."On Shipment Qty.", WhseShipmentNos);
            TempLine."Whse. Shipment Nos." := CopyStr(WhseShipmentNos, 1, MaxStrLen(TempLine."Whse. Shipment Nos."));
            CalcStockLine(TempLine, false);
        end else
            TempLine.Status := TempLine.Status::"Not Stock Item";
        SetLineFlag(TempLine);
        ApplyAllocations(TempLine);
        TempLine.Insert();
    end;

    local procedure InsertSalesOrderRow(var SalesHeader: Record "Sales Header"; MinExpiry: Date)
    var
        Customer: Record Customer;
        ShippingAgentServices: Record "Shipping Agent Services";
        RecRef: RecordRef;
        ShelfLifeText: Text;
        TerritoryText: Text;
    begin
        TempOrder.Init();
        TempOrder."Source Type" := TempOrder."Source Type"::"Sales Order";
        TempOrder."Order No." := SalesHeader."No.";
        TempOrder."Order Date" := SalesHeader."Order Date";
        TempOrder."Promised Delivery Date" := SalesHeader."Promised Delivery Date";
        TempOrder."Shipment Date" := SalesHeader."Shipment Date";
        TempOrder."Customer No." := SalesHeader."Sell-to Customer No.";
        TempOrder."Customer Name" := SalesHeader."Sell-to Customer Name";
        TempOrder."Shipping Advice" := CopyStr(Format(SalesHeader."Shipping Advice"), 1, MaxStrLen(TempOrder."Shipping Advice"));
        TempOrder."Ship Complete" := SalesHeader."Shipping Advice" = SalesHeader."Shipping Advice"::Complete;
        TempOrder."Shipment Method Code" := SalesHeader."Shipment Method Code";
        TempOrder."Shipping Agent Code" := SalesHeader."Shipping Agent Code";
        if ShippingAgentServices.Get(SalesHeader."Shipping Agent Code", SalesHeader."Shipping Agent Service Code") then
            TempOrder."Shipping Agent Service" := ShippingAgentServices.Description
        else
            TempOrder."Shipping Agent Service" := SalesHeader."Shipping Agent Service Code";
        TempOrder."Document Status" := CopyStr(Format(SalesHeader.Status), 1, MaxStrLen(TempOrder."Document Status"));
        TempOrder."Location Code" := SalesHeader."Location Code";
        TempOrder."Customer Min. Expiry Date" := MinExpiry;

        if GetCustomer(SalesHeader."Sell-to Customer No.", Customer) then begin
            TempOrder."Salesperson Code" := Customer."Salesperson Code";
            TempOrder.Blocked := CopyStr(Format(Customer.Blocked), 1, MaxStrLen(TempOrder.Blocked));
            TempOrder."Customer Blocked" := Customer.Blocked in [Customer.Blocked::Ship, Customer.Blocked::All];
            if CustomerShelfLifeCache.Get(Customer."No.", ShelfLifeText) then
                TempOrder."Min. Remaining Shelf Life" := CopyStr(ShelfLifeText, 1, MaxStrLen(TempOrder."Min. Remaining Shelf Life"));
            if CustomerTerritoryCache.Get(Customer."No.", TerritoryText) then
                TempOrder."Territory Code" := CopyStr(TerritoryText, 1, MaxStrLen(TempOrder."Territory Code"));
        end;

        RecRef.GetTable(SalesHeader);
        TempOrder."Warehouse Note" := CopyStr(OptionalFields.GetTextByName(RecRef, Setup."Warehouse Note Field Name"), 1, MaxStrLen(TempOrder."Warehouse Note"));
        TempOrder."Created By" := CopyStr(OptionalFields.GetTextByNo(RecRef, Setup."Created By Field No."), 1, MaxStrLen(TempOrder."Created By"));
        RecRef.Close();
        if TempOrder."Created By" = '' then
            TempOrder."Created By" := GetUserName(SalesHeader.SystemCreatedBy);

        SetOrderWhseShipment(TempOrder);
        AggregateOrder(TempOrder);
        TempOrder.Insert();
    end;

    local procedure BuildAssemblyOrders()
    var
        AssemblyHeader: Record "Assembly Header";
    begin
        AssemblyHeader.SetRange("Document Type", AssemblyHeader."Document Type"::Order);
        if AssemblyHeader.FindSet() then
            repeat
                BuildAssemblyOrder(AssemblyHeader);
            until AssemblyHeader.Next() = 0;
    end;

    local procedure BuildAssemblyOrder(var AssemblyHeader: Record "Assembly Header")
    var
        AssemblyLine: Record "Assembly Line";
    begin
        AssemblyLine.SetRange("Document Type", AssemblyHeader."Document Type");
        AssemblyLine.SetRange("Document No.", AssemblyHeader."No.");
        AssemblyLine.SetRange(Type, AssemblyLine.Type::Item);
        AssemblyLine.SetFilter("Remaining Quantity", '<>0');
        if AssemblyLine.FindSet() then
            repeat
                if LocationMatches(AssemblyLine."Location Code") then
                    AddAssemblyLine(AssemblyHeader, AssemblyLine);
            until AssemblyLine.Next() = 0;
        if not OrderHasLines("KMS Order Source"::"Assembly Order", AssemblyHeader."No.") then
            exit;
        InsertAssemblyOrderRow(AssemblyHeader);
    end;

    local procedure AddAssemblyLine(var AssemblyHeader: Record "Assembly Header"; var AssemblyLine: Record "Assembly Line")
    var
        Item: Record Item;
        QtyOnPick: Decimal;
    begin
        TempLine.Init();
        TempLine."Source Type" := TempLine."Source Type"::"Assembly Order";
        TempLine."Order No." := AssemblyLine."Document No.";
        TempLine."Line No." := AssemblyLine."Line No.";
        TempLine."Order Date" := DT2Date(AssemblyHeader.SystemCreatedAt);
        TempLine."Line Type" := ComponentTxt;
        TempLine."No." := AssemblyLine."No.";
        TempLine.Description := AssemblyLine.Description;
        TempLine."Description 2" := AssemblyLine."Description 2";
        TempLine."Location Code" := AssemblyLine."Location Code";
        TempLine."Variant Code" := AssemblyLine."Variant Code";
        TempLine."Unit of Measure Code" := AssemblyLine."Unit of Measure Code";
        TempLine."Shipment Date" := AssemblyLine."Due Date";
        TempLine."Qty. per Unit of Measure" := AssemblyLine."Qty. per Unit of Measure";
        TempLine.Quantity := AssemblyLine.Quantity;
        TempLine."Quantity Shipped" := AssemblyLine."Consumed Quantity";
        TempLine."Outstanding Quantity" := AssemblyLine."Remaining Quantity";
        TempLine."Outstanding Qty. (Base)" := AssemblyLine."Remaining Quantity (Base)";
        TempLine."Unit Cost (LCY)" := AssemblyLine."Unit Cost";
        TempLine."Unshipped Cost (LCY)" := Round(AssemblyLine."Unit Cost" * AssemblyLine."Remaining Quantity");
        if GetItem(AssemblyLine."No.", Item) then begin
            if Item."Description 2" <> '' then
                TempLine."Description 2" := Item."Description 2";
            TempLine."Warehouse Class Code" := Item."Warehouse Class Code";
            TempLine."Replenishment System" := CopyStr(Format(Item."Replenishment System"), 1, MaxStrLen(TempLine."Replenishment System"));
            TempLine."Is Stock Item" := Item.Type = Item.Type::Inventory;
        end;
        SetPurchaseInfo(TempLine, '', 0);

        if TempLine."Is Stock Item" then begin
            // For components "on shipment" means on an open pick or picked but not yet consumed.
            AssemblyLine.CalcFields("Pick Qty. (Base)");
            QtyOnPick := AssemblyLine."Pick Qty. (Base)" + MaxDec(0, AssemblyLine."Qty. Picked (Base)" - AssemblyLine."Consumed Quantity (Base)");
            TempLine."On Shipment Qty." := MinDec(QtyOnPick, TempLine."Outstanding Qty. (Base)");
            CalcStockLine(TempLine, true);
        end else
            TempLine.Status := TempLine.Status::"Not Stock Item";
        SetLineFlag(TempLine);
        ApplyAllocations(TempLine);
        TempLine.Insert();
    end;

    local procedure InsertAssemblyOrderRow(var AssemblyHeader: Record "Assembly Header")
    var
        RelatedTxt: Text;
    begin
        TempOrder.Init();
        TempOrder."Source Type" := TempOrder."Source Type"::"Assembly Order";
        TempOrder."Order No." := AssemblyHeader."No.";
        TempOrder."Order Date" := DT2Date(AssemblyHeader.SystemCreatedAt);
        TempOrder."Shipment Date" := AssemblyHeader."Due Date";
        TempOrder."Customer Name" := CopyStr(StrSubstNo(AssemblyNameTxt, AssemblyHeader."Item No.", AssemblyHeader.Description), 1, MaxStrLen(TempOrder."Customer Name"));
        TempOrder."Document Status" := CopyStr(Format(AssemblyHeader.Status), 1, MaxStrLen(TempOrder."Document Status"));
        TempOrder."Location Code" := AssemblyHeader."Location Code";
        TempOrder."Created By" := GetUserName(AssemblyHeader.SystemCreatedBy);
        if AsmRelatedText.Get(AssemblyHeader."No.", RelatedTxt) then
            TempOrder."Related Order" := CopyStr(RelatedTxt, 1, MaxStrLen(TempOrder."Related Order"));
        AggregateOrder(TempOrder);
        TempOrder.Insert();
    end;

    // ------------------------------------------------------------------ Line figures and statuses

    local procedure CalcStockLine(var L: Record "KMS Outstanding Order Line"; ForAssembly: Boolean)
    var
        ReservEntry: Record "Reservation Entry";
        SupplyEntry: Record "Reservation Entry";
        ItemLedgerEntry: Record "Item Ledger Entry";
        ReservationMgt: Codeunit "KMS Reservation Mgt.";
        LotQty: Dictionary of [Code[50], Decimal];
        LotExpiry: Dictionary of [Code[50], Date];
        LotNo: Code[50];
        Expiry: Date;
        Qty: Decimal;
        ReservedAll: Decimal;
        ReservedStock: Decimal;
        Awaiting: Decimal;
        BelowMin: Decimal;
        Need: Decimal;
        ReservedOpen: Decimal;
        ReservedStockOpen: Decimal;
        Shortfall: Decimal;
        FreeMeeting: Decimal;
        FreeBelow: Decimal;
        LotsText: Text;
        ExpiryText: Text;
    begin
        StockCalc.EnsureLoaded(L."No.", L."Variant Code", L."Location Code");

        // What is reserved for this line now, and from which lots.
        ReservationMgt.FilterDemandReservations(L, ReservEntry);
        if ReservEntry.FindSet() then
            repeat
                Qty := Abs(ReservEntry."Quantity (Base)");
                ReservedAll += Qty;
                if SupplyEntry.Get(ReservEntry."Entry No.", true) then
                    if SupplyEntry."Source Type" = Database::"Item Ledger Entry" then begin
                        ReservedStock += Qty;
                        Expiry := SupplyEntry."Expiration Date";
                        if Expiry = 0D then begin
                            ItemLedgerEntry.SetLoadFields("Expiration Date");
                            if ItemLedgerEntry.Get(SupplyEntry."Source Ref. No.") then
                                Expiry := ItemLedgerEntry."Expiration Date";
                        end;
                        AddToLot(LotQty, LotExpiry, SupplyEntry."Lot No.", Qty, Expiry);
                    end;
            until ReservEntry.Next() = 0;

        foreach LotNo in LotQty.Keys() do begin
            Qty := LotQty.Get(LotNo);
            Expiry := LotExpiry.Get(LotNo);
            if LotNo <> '' then
                AppendText(LotsText, StrSubstNo(QtyInBracketsTxt, LotNo, FormatQty(Qty)));
            if Expiry <> 0D then
                AppendText(ExpiryText, StrSubstNo(QtyInBracketsTxt, FormatDate(Expiry), FormatQty(Qty)));
            if not StockCalc.MeetsMinExpiry(Expiry, L."Customer Min. Expiry Date") then
                BelowMin += Qty;
            // Reserved stock not covered by stock in pickable bins (checked lot by lot) is awaiting put-away.
            if TempLot.Get(L."No.", L."Variant Code", L."Location Code", LotNo) then begin
                Shortfall := TempLot."Reserved Qty." - TempLot."Pickable Qty.";
                if Shortfall > 0 then
                    Awaiting += MinDec(Qty, Shortfall);
            end else
                Awaiting += Qty;
        end;

        L."Reserved Qty." := ReservedAll;
        L."Reserved Lot Nos." := CopyStr(LotsText, 1, MaxStrLen(L."Reserved Lot Nos."));
        L."Reserved Lot Expiry" := CopyStr(ExpiryText, 1, MaxStrLen(L."Reserved Lot Expiry"));
        L."Reserved Below Min. Expiry" := BelowMin;

        Need := MaxDec(0, L."Outstanding Qty. (Base)" - L."On Shipment Qty.");
        ReservedOpen := MaxDec(0, ReservedAll - L."On Shipment Qty.");
        ReservedStockOpen := MaxDec(0, ReservedStock - L."On Shipment Qty.");
        L."Unreserved Qty." := MaxDec(0, Need - ReservedOpen);
        L."Reserved Awaiting Put-away" := MinDec(Awaiting, ReservedStockOpen);
        L."Ready Qty. (Base)" := MaxDec(0, ReservedStockOpen - L."Reserved Awaiting Put-away");

        StockCalc.GetFree(L."No.", L."Variant Code", L."Location Code", L."Customer Min. Expiry Date", FreeMeeting, FreeBelow);
        L."Free Stock Meeting Expiry" := FreeMeeting;
        L."Free Stock Below Expiry" := FreeBelow;
        L."Free Pickable Stock" := FreeMeeting + FreeBelow;
        L."Qty. in Receive Bins" := StockCalc.GetReceiveTotal(L."No.", L."Variant Code", L."Location Code");
        L."Reserved on Unshipped Orders" :=
          MaxDec(0, StockCalc.GetReservedTotal(L."No.", L."Variant Code", L."Location Code") - ReservedStock -
            StockCalc.GetWhseShipmentTotal(L."No.", L."Variant Code", L."Location Code"));

        if L."Outstanding Qty. (Base)" <> 0 then begin
            L."Ready Value (LCY)" := Round(L."Unshipped Value (LCY)" * L."Ready Qty. (Base)" / L."Outstanding Qty. (Base)");
            L."Reserved Value (LCY)" := Round(L."Unshipped Value (LCY)" * MinDec(ReservedStockOpen, Need) / L."Outstanding Qty. (Base)");
        end;

        if not StockCalc.IsLocationSetUp(L."Location Code", ForAssembly) then
            L.Status := L.Status::"Location Not Set Up"
        else
            if Need = 0 then
                L.Status := L.Status::"Fully on Shipment"
            else
                if L."Unreserved Qty." = 0 then begin
                    if ReservedStockOpen < Need then
                        L.Status := L.Status::"Partial Reservation (No Stock)" // reserved against a purchase or other supply
                    else
                        if L."Reserved Awaiting Put-away" > 0 then
                            L.Status := L.Status::"Awaiting Put-away"
                        else
                            L.Status := L.Status::Ready;
                end else
                    if FreeMeeting > 0 then
                        L.Status := L.Status::"Reserve Lines"
                    else
                        if FreeBelow > 0 then
                            L.Status := L.Status::"Short-Dated Stock Only"
                        else
                            if L."Qty. in Receive Bins" > 0 then
                                L.Status := L.Status::"Awaiting Put-away"
                            else
                                if ReservedOpen > 0 then
                                    L.Status := L.Status::"Partial Reservation (No Stock)"
                                else
                                    if L."On Shipment Qty." > 0 then
                                        L.Status := L.Status::"No Stock (Partly on Shipment)"
                                    else
                                        L.Status := L.Status::"No Stock";
    end;

    local procedure SetLineFlag(var L: Record "KMS Outstanding Order Line")
    begin
        case L.Status of
            L.Status::"Fully on Shipment":
                L."Flag Colour" := L."Flag Colour"::Green;
            L.Status::Ready:
                L."Flag Colour" := L."Flag Colour"::Blue;
            L.Status::"Reserve Lines", L.Status::"Short-Dated Stock Only", L.Status::"Partial Reservation (No Stock)":
                L."Flag Colour" := L."Flag Colour"::Amber;
            L.Status::"Awaiting Put-away":
                L."Flag Colour" := L."Flag Colour"::Grey;
            L.Status::"Location Not Set Up", L.Status::"No Stock (Partly on Shipment)", L.Status::"No Stock":
                L."Flag Colour" := L."Flag Colour"::Red;
            else
                L."Flag Colour" := L."Flag Colour"::None;
        end;
        L.Flag := GetFlagText(L."Flag Colour");
    end;

    local procedure AggregateOrder(var O: Record "KMS Outstanding Order")
    var
        L: Record "KMS Outstanding Order Line" temporary;
        NonItemValue: Decimal;
        StockLines: Integer;
        AllOnShipment: Boolean;
        AllReadyOrOnShipment: Boolean;
        AnyNotSetUp: Boolean;
        AnyReserveLines: Boolean;
        AnyShortDated: Boolean;
        AnyAwaiting: Boolean;
        AnyReady: Boolean;
        AnyOnShipment: Boolean;
    begin
        L.Copy(TempLine, true);
        L.Reset();
        L.SetRange("Source Type", O."Source Type");
        L.SetRange("Order No.", O."Order No.");
        AllOnShipment := true;
        AllReadyOrOnShipment := true;
        O."Unshipped Value (LCY)" := 0;
        O."Unshipped Cost (LCY)" := 0;
        O."Ready Value (LCY)" := 0;
        O."Reserved Value (LCY)" := 0;
        O."Lines Unreserved" := 0;
        O."Lines Awaiting Put-away" := 0;
        if L.FindSet() then
            repeat
                O."Unshipped Value (LCY)" += L."Unshipped Value (LCY)";
                O."Unshipped Cost (LCY)" += L."Unshipped Cost (LCY)";
                if L."Is Stock Item" then begin
                    StockLines += 1;
                    if L."Unreserved Qty." > 0 then
                        O."Lines Unreserved" += 1;
                    if (L.Status = L.Status::"Awaiting Put-away") or (L."Reserved Awaiting Put-away" > 0) then
                        O."Lines Awaiting Put-away" += 1;
                    O."Ready Value (LCY)" += L."Ready Value (LCY)";
                    O."Reserved Value (LCY)" += L."Reserved Value (LCY)";
                    if L.Status <> L.Status::"Fully on Shipment" then
                        AllOnShipment := false;
                    if not (L.Status in [L.Status::Ready, L.Status::"Fully on Shipment"]) then
                        AllReadyOrOnShipment := false;
                    case L.Status of
                        L.Status::"Location Not Set Up":
                            AnyNotSetUp := true;
                        L.Status::"Reserve Lines":
                            AnyReserveLines := true;
                        L.Status::"Short-Dated Stock Only":
                            AnyShortDated := true;
                        L.Status::"Awaiting Put-away":
                            AnyAwaiting := true;
                    end;
                    if L."Ready Qty. (Base)" > 0 then
                        AnyReady := true;
                    if L."On Shipment Qty." > 0 then
                        AnyOnShipment := true;
                end else
                    NonItemValue += L."Unshipped Value (LCY)";
            until L.Next() = 0;

        O."Item Lines" := StockLines;
        if Setup."Value Incl. Non-Item Lines" and AnyReady then
            O."Ready Value (LCY)" += NonItemValue;
        if O."Source Type" = O."Source Type"::"Sales Order" then begin
            O."Margin (LCY)" := O."Unshipped Value (LCY)" - O."Unshipped Cost (LCY)";
            O."Margin %" := CalcMarginPct(O."Margin (LCY)", O."Unshipped Value (LCY)");
        end;

        // Status ranking: the first rule that applies wins.
        if StockLines = 0 then
            O.Status := O.Status::" "
        else
            if AllOnShipment then
                O.Status := O.Status::"Fully on Shipment"
            else
                if O."Customer Blocked" then
                    O.Status := O.Status::"Customer Blocked"
                else
                    if AnyNotSetUp then
                        O.Status := O.Status::"Location Not Set Up"
                    else
                        if AllReadyOrOnShipment then begin
                            if (O."Promised Delivery Date" <> 0D) and (O."Promised Delivery Date" > Today()) then
                                O.Status := O.Status::"Ready (Before PDD)"
                            else
                                O.Status := O.Status::Ready;
                        end else
                            if AnyReserveLines then
                                O.Status := O.Status::"Reserve Lines"
                            else
                                if AnyShortDated then
                                    O.Status := O.Status::"Short-Dated Stock Only"
                                else
                                    if AnyAwaiting then
                                        O.Status := O.Status::"Awaiting Put-away"
                                    else
                                        if AnyReady then begin
                                            if O."Ship Complete" then
                                                O.Status := O.Status::"Partial Stock (Ship Complete)"
                                            else
                                                if (O."Source Type" = O."Source Type"::"Assembly Order") or
                                                   (O."Ready Value (LCY)" >= Setup."Min. Value for Part Shipment")
                                                then
                                                    O.Status := O.Status::"Ready (Part Shipment)"
                                                else
                                                    O.Status := O.Status::"Below Min. Value";
                                        end else
                                            if AnyOnShipment then
                                                O.Status := O.Status::"No Stock (Partly on Shipment)"
                                            else
                                                O.Status := O.Status::"No Stock";

        case O.Status of
            O.Status::"Fully on Shipment":
                O."Flag Colour" := O."Flag Colour"::Green;
            O.Status::Ready, O.Status::"Ready (Before PDD)", O.Status::"Ready (Part Shipment)":
                O."Flag Colour" := O."Flag Colour"::Blue;
            O.Status::"Reserve Lines", O.Status::"Short-Dated Stock Only", O.Status::"Below Min. Value", O.Status::"Partial Stock (Ship Complete)":
                O."Flag Colour" := O."Flag Colour"::Amber;
            O.Status::"Awaiting Put-away":
                O."Flag Colour" := O."Flag Colour"::Grey;
            O.Status::"Customer Blocked", O.Status::"Location Not Set Up", O.Status::"No Stock (Partly on Shipment)", O.Status::"No Stock":
                O."Flag Colour" := O."Flag Colour"::Red;
            else
                O."Flag Colour" := O."Flag Colour"::None;
        end;
        O.Flag := GetFlagText(O."Flag Colour");
        O."Fully on Shipment" := O.Status = O.Status::"Fully on Shipment";
    end;

    // ------------------------------------------------------------------ Suggest and Qty. to Reserve

    procedure SuggestAll()
    var
        Ord: Record "KMS Outstanding Order" temporary;
    begin
        CancelSuggestionAll();
        // Oldest order first, across sales and assembly orders.
        Ord.Copy(TempOrder, true);
        Ord.Reset();
        Ord.SetCurrentKey("Order Date", "Order No.");
        if Ord.FindSet() then
            repeat
                if CanSuggestOrder(Ord) then
                    SuggestOrderInternal(Ord."Source Type", Ord."Order No.");
            until Ord.Next() = 0;
    end;

    procedure SuggestOrder(SourceType: Enum "KMS Order Source"; OrderNo: Code[20])
    begin
        if not TempOrder.Get(SourceType, OrderNo) then
            exit;
        if not CanSuggestOrder(TempOrder) then
            exit;
        SuggestOrderInternal(SourceType, OrderNo);
    end;

    procedure SuggestLine(SourceType: Enum "KMS Order Source"; OrderNo: Code[20]; LineNo: Integer)
    begin
        if not TempLine.Get(SourceType, OrderNo, LineNo) then
            exit;
        if TempOrder.Get(SourceType, OrderNo) then
            if not CanSuggestOrder(TempOrder) then
                exit;
        SuggestLineInternal(TempLine);
        TempLine.Modify();
    end;

    procedure CancelSuggestionAll()
    begin
        TempAlloc.Reset();
        TempAlloc.DeleteAll();
        TempLot.Reset();
        TempLot.ModifyAll("Allocated Qty.", 0);
        TempLine.Reset();
        TempLine.ModifyAll("Suggested Qty. to Reserve", 0);
        TempLine.ModifyAll("Qty. to Reserve", 0);
        TempLine.ModifyAll("Suggested Lot Nos.", '');
        TempLine.ModifyAll("Suggested Expiry Dates", '');
    end;

    procedure CancelSuggestionOrder(SourceType: Enum "KMS Order Source"; OrderNo: Code[20])
    var
        Line: Record "KMS Outstanding Order Line" temporary;
    begin
        Line.Copy(TempLine, true);
        Line.Reset();
        Line.SetRange("Source Type", SourceType);
        Line.SetRange("Order No.", OrderNo);
        if Line.FindSet() then
            repeat
                ClearSuggestion(Line);
                Line.Modify();
            until Line.Next() = 0;
    end;

    procedure CancelSuggestionLine(SourceType: Enum "KMS Order Source"; OrderNo: Code[20]; LineNo: Integer)
    begin
        if not TempLine.Get(SourceType, OrderNo, LineNo) then
            exit;
        ClearSuggestion(TempLine);
        TempLine.Modify();
    end;

    /// <summary>Checks a typed Qty. to Reserve against what the line still needs and the free stock across the whole report, then sets aside lots (FEFO).</summary>
    procedure SetQtyToReserve(var L: Record "KMS Outstanding Order Line")
    var
        NewQty: Decimal;
        AvailMeeting: Decimal;
        AvailBelow: Decimal;
        UseShortDated: Boolean;
    begin
        NewQty := L."Qty. to Reserve";
        if NewQty < 0 then
            Error(NegativeQtyErr);
        if NewQty = 0 then begin
            ReleaseAllocations(L);
            L."Suggested Qty. to Reserve" := 0;
            UpdateAllocationText(L);
            exit;
        end;
        if not L."Is Stock Item" then
            Error(NotStockLineErr);
        if L.Status = L.Status::"Location Not Set Up" then
            Error(LocationNotSetUpErr, L."Location Code");
        if NewQty > L."Unreserved Qty." then
            Error(ExceedsNeedErr, L."Unreserved Qty.");

        AvailMeeting := GetAvailable(L, true) + GetOwnAllocation(L, true);
        AvailBelow := GetAvailable(L, false) + GetOwnAllocation(L, false);
        if NewQty > AvailMeeting + AvailBelow then
            Error(NotEnoughStockErr, AvailMeeting + AvailBelow);
        UseShortDated := NewQty > AvailMeeting;
        if UseShortDated then
            if not Confirm(ShortDatedQst, false, NewQty - AvailMeeting) then
                Error('');

        ReleaseAllocations(L);
        Allocate(L, NewQty, UseShortDated);
        L."Suggested Qty. to Reserve" := NewQty;
        UpdateAllocationText(L);
    end;

    local procedure CanSuggestOrder(var O: Record "KMS Outstanding Order"): Boolean
    begin
        exit(not (O.Status in [O.Status::"Fully on Shipment", O.Status::"Customer Blocked", O.Status::"Location Not Set Up"]));
    end;

    local procedure SuggestOrderInternal(SourceType: Enum "KMS Order Source"; OrderNo: Code[20])
    var
        Line: Record "KMS Outstanding Order Line" temporary;
        FullyCovered: Boolean;
    begin
        Line.Copy(TempLine, true);
        Line.Reset();
        Line.SetRange("Source Type", SourceType);
        Line.SetRange("Order No.", OrderNo);
        Line.SetRange("Is Stock Item", true);
        FullyCovered := true;
        if Line.FindSet() then
            repeat
                SuggestLineInternal(Line);
                if Line."Qty. to Reserve" < Line."Unreserved Qty." then
                    FullyCovered := false;
                Line.Modify();
            until Line.Next() = 0;

        if (Setup."Reservation Mode" = Setup."Reservation Mode"::"Fully Reservable Only") and not FullyCovered then
            CancelSuggestionOrder(SourceType, OrderNo);
    end;

    local procedure SuggestLineInternal(var L: Record "KMS Outstanding Order Line")
    begin
        ReleaseAllocations(L);
        L."Suggested Qty. to Reserve" := 0;
        if L."Is Stock Item" and (L."Unreserved Qty." > 0) and (L.Status <> L.Status::"Location Not Set Up") then
            L."Suggested Qty. to Reserve" := Allocate(L, L."Unreserved Qty.", false);
        L."Qty. to Reserve" := L."Suggested Qty. to Reserve";
        UpdateAllocationText(L);
    end;

    local procedure ClearSuggestion(var L: Record "KMS Outstanding Order Line")
    begin
        ReleaseAllocations(L);
        L."Suggested Qty. to Reserve" := 0;
        L."Qty. to Reserve" := 0;
        L."Suggested Lot Nos." := '';
        L."Suggested Expiry Dates" := '';
    end;

    /// <summary>Sets aside free pickable stock for the line: lots assigned on the order first, then earliest expiry (FEFO). Short-dated lots only when allowed.</summary>
    local procedure Allocate(var L: Record "KMS Outstanding Order Line"; Qty: Decimal; AllowShortDated: Boolean): Decimal
    var
        Lot: Record "KMS Lot Stock" temporary;
        ReservationMgt: Codeunit "KMS Reservation Mgt.";
        AssignedLots: Dictionary of [Code[50], Decimal];
        AssignedLotNo: Code[50];
        AssignedQty: Decimal;
        Remaining: Decimal;
        Take: Decimal;
        Pass: Integer;
        MeetsExpiry: Boolean;
    begin
        if Qty <= 0 then
            exit(0);
        Remaining := Qty;
        Lot.Copy(TempLot, true);

        // Lots chosen on the order's Item Tracking Lines are used first, if they meet the expiry rule.
        if L."Source Type" = L."Source Type"::"Sales Order" then begin
            ReservationMgt.GetAssignedLots(L, AssignedLots);
            foreach AssignedLotNo in AssignedLots.Keys() do
                if Remaining > 0 then
                    if Lot.Get(L."No.", L."Variant Code", L."Location Code", AssignedLotNo) then
                        if not StockCalc.IsExpired(Lot."Expiration Date") and
                           (AllowShortDated or StockCalc.MeetsMinExpiry(Lot."Expiration Date", L."Customer Min. Expiry Date"))
                        then begin
                            AssignedQty := AssignedLots.Get(AssignedLotNo);
                            Take := MinDec(MinDec(Lot."Free Qty." - Lot."Allocated Qty.", AssignedQty), Remaining);
                            if Take > 0 then begin
                                Lot."Allocated Qty." += Take;
                                Lot.Modify();
                                AddAllocation(L, Lot, Take);
                                Remaining -= Take;
                            end;
                        end;
        end;

        Lot.Reset();
        Lot.SetCurrentKey("Item No.", "Variant Code", "Location Code", "FEFO Date");
        Lot.SetRange("Item No.", L."No.");
        Lot.SetRange("Variant Code", L."Variant Code");
        Lot.SetRange("Location Code", L."Location Code");
        for Pass := 1 to 2 do
            if ((Pass = 1) or AllowShortDated) and (Remaining > 0) then
                if Lot.FindSet() then
                    repeat
                        MeetsExpiry := StockCalc.MeetsMinExpiry(Lot."Expiration Date", L."Customer Min. Expiry Date");
                        if not StockCalc.IsExpired(Lot."Expiration Date") and (MeetsExpiry = (Pass = 1)) then begin
                            Take := MinDec(Lot."Free Qty." - Lot."Allocated Qty.", Remaining);
                            if Take > 0 then begin
                                Lot."Allocated Qty." += Take;
                                Lot.Modify();
                                AddAllocation(L, Lot, Take);
                                Remaining -= Take;
                            end;
                        end;
                    until (Lot.Next() = 0) or (Remaining <= 0);
        exit(Qty - Remaining);
    end;

    local procedure AddAllocation(var L: Record "KMS Outstanding Order Line"; var Lot: Record "KMS Lot Stock" temporary; Qty: Decimal)
    begin
        if TempAlloc.Get(L."Source Type", L."Order No.", L."Line No.", Lot."Lot No.") then begin
            TempAlloc."Quantity (Base)" += Qty;
            TempAlloc.Modify();
            exit;
        end;
        TempAlloc.Init();
        TempAlloc."Source Type" := L."Source Type";
        TempAlloc."Order No." := L."Order No.";
        TempAlloc."Line No." := L."Line No.";
        TempAlloc."Lot No." := Lot."Lot No.";
        TempAlloc."Item No." := Lot."Item No.";
        TempAlloc."Variant Code" := Lot."Variant Code";
        TempAlloc."Location Code" := Lot."Location Code";
        TempAlloc."Expiration Date" := Lot."Expiration Date";
        TempAlloc."Quantity (Base)" := Qty;
        TempAlloc.Insert();
    end;

    local procedure ReleaseAllocations(var L: Record "KMS Outstanding Order Line")
    var
        Alloc: Record "KMS Lot Allocation" temporary;
    begin
        Alloc.Copy(TempAlloc, true);
        Alloc.Reset();
        Alloc.SetRange("Source Type", L."Source Type");
        Alloc.SetRange("Order No.", L."Order No.");
        Alloc.SetRange("Line No.", L."Line No.");
        if Alloc.FindSet() then
            repeat
                if TempLot.Get(Alloc."Item No.", Alloc."Variant Code", Alloc."Location Code", Alloc."Lot No.") then begin
                    TempLot."Allocated Qty." := MaxDec(0, TempLot."Allocated Qty." - Alloc."Quantity (Base)");
                    TempLot.Modify();
                end;
            until Alloc.Next() = 0;
        Alloc.DeleteAll();
    end;

    local procedure DeleteAllocations(SourceType: Enum "KMS Order Source"; OrderNo: Code[20]; LineNo: Integer)
    var
        Alloc: Record "KMS Lot Allocation" temporary;
    begin
        Alloc.Copy(TempAlloc, true);
        Alloc.Reset();
        Alloc.SetRange("Source Type", SourceType);
        Alloc.SetRange("Order No.", OrderNo);
        if LineNo <> 0 then
            Alloc.SetRange("Line No.", LineNo);
        Alloc.DeleteAll();
    end;

    /// <summary>After a line is rebuilt, puts back what Suggest or a typed quantity had set aside for it.</summary>
    local procedure ApplyAllocations(var L: Record "KMS Outstanding Order Line")
    var
        Alloc: Record "KMS Lot Allocation" temporary;
    begin
        Alloc.Copy(TempAlloc, true);
        Alloc.Reset();
        Alloc.SetRange("Source Type", L."Source Type");
        Alloc.SetRange("Order No.", L."Order No.");
        Alloc.SetRange("Line No.", L."Line No.");
        if Alloc.IsEmpty() then
            exit;
        Alloc.CalcSums("Quantity (Base)");
        L."Qty. to Reserve" := Alloc."Quantity (Base)";
        L."Suggested Qty. to Reserve" := Alloc."Quantity (Base)";
        UpdateAllocationText(L);
    end;

    local procedure UpdateAllocationText(var L: Record "KMS Outstanding Order Line")
    var
        Alloc: Record "KMS Lot Allocation" temporary;
        LotsText: Text;
        ExpiryText: Text;
    begin
        Alloc.Copy(TempAlloc, true);
        Alloc.Reset();
        Alloc.SetRange("Source Type", L."Source Type");
        Alloc.SetRange("Order No.", L."Order No.");
        Alloc.SetRange("Line No.", L."Line No.");
        if Alloc.FindSet() then
            repeat
                if Alloc."Lot No." <> '' then
                    AppendText(LotsText, StrSubstNo(QtyInBracketsTxt, Alloc."Lot No.", FormatQty(Alloc."Quantity (Base)")));
                if Alloc."Expiration Date" <> 0D then
                    AppendText(ExpiryText, StrSubstNo(QtyInBracketsTxt, FormatDate(Alloc."Expiration Date"), FormatQty(Alloc."Quantity (Base)")));
            until Alloc.Next() = 0;
        L."Suggested Lot Nos." := CopyStr(LotsText, 1, MaxStrLen(L."Suggested Lot Nos."));
        L."Suggested Expiry Dates" := CopyStr(ExpiryText, 1, MaxStrLen(L."Suggested Expiry Dates"));
    end;

    local procedure GetAvailable(var L: Record "KMS Outstanding Order Line"; Meeting: Boolean) Total: Decimal
    var
        Lot: Record "KMS Lot Stock" temporary;
    begin
        Lot.Copy(TempLot, true);
        Lot.Reset();
        Lot.SetRange("Item No.", L."No.");
        Lot.SetRange("Variant Code", L."Variant Code");
        Lot.SetRange("Location Code", L."Location Code");
        if Lot.FindSet() then
            repeat
                if not StockCalc.IsExpired(Lot."Expiration Date") then
                    if StockCalc.MeetsMinExpiry(Lot."Expiration Date", L."Customer Min. Expiry Date") = Meeting then
                        Total += MaxDec(0, Lot."Free Qty." - Lot."Allocated Qty.");
            until Lot.Next() = 0;
    end;

    local procedure GetOwnAllocation(var L: Record "KMS Outstanding Order Line"; Meeting: Boolean) Total: Decimal
    var
        Alloc: Record "KMS Lot Allocation" temporary;
    begin
        Alloc.Copy(TempAlloc, true);
        Alloc.Reset();
        Alloc.SetRange("Source Type", L."Source Type");
        Alloc.SetRange("Order No.", L."Order No.");
        Alloc.SetRange("Line No.", L."Line No.");
        if Alloc.FindSet() then
            repeat
                if StockCalc.MeetsMinExpiry(Alloc."Expiration Date", L."Customer Min. Expiry Date") = Meeting then
                    Total += Alloc."Quantity (Base)";
            until Alloc.Next() = 0;
    end;

    // ------------------------------------------------------------------ Reserve, cancel, reduce

    procedure ReserveLine(SourceType: Enum "KMS Order Source"; OrderNo: Code[20]; LineNo: Integer)
    var
        ErrorText: Text;
    begin
        if not TempLine.Get(SourceType, OrderNo, LineNo) then
            exit;
        if TempLine."Qty. to Reserve" <= 0 then
            Error(NothingToReserveLineErr);
        RunReservation(SourceType, OrderNo, LineNo, false, ErrorText);
        RefreshOrder(SourceType, OrderNo);
    end;

    procedure ReserveOrder(SourceType: Enum "KMS Order Source"; OrderNo: Code[20])
    var
        ErrorText: Text;
    begin
        if not CheckOrderReservable(SourceType, OrderNo, true) then
            exit;
        RunReservation(SourceType, OrderNo, 0, false, ErrorText);
        RefreshOrder(SourceType, OrderNo);
    end;

    /// <summary>Reserves the suggested / typed quantities on every order, oldest first, each order in its own transaction.</summary>
    procedure ReserveAll()
    var
        Ord: Record "KMS Outstanding Order" temporary;
        OrderKeys: List of [Text];
        OrderKey: Text;
        SourceType: Enum "KMS Order Source";
        OrderNo: Code[20];
        SourceTypeNo: Integer;
        ErrorText: Text;
        ErrorDetails: Text;
        Reserved: Integer;
        Skipped: Integer;
        Failed: Integer;
    begin
        Ord.Copy(TempOrder, true);
        Ord.Reset();
        Ord.SetCurrentKey("Order Date", "Order No.");
        if Ord.FindSet() then
            repeat
                OrderKeys.Add(Format(Ord."Source Type".AsInteger()) + '|' + Ord."Order No.");
            until Ord.Next() = 0;

        foreach OrderKey in OrderKeys do begin
            Evaluate(SourceTypeNo, SelectStr(1, ConvertStr(OrderKey, '|', ',')));
            SourceType := "KMS Order Source".FromInteger(SourceTypeNo);
            OrderNo := CopyStr(CopyStr(OrderKey, StrPos(OrderKey, '|') + 1), 1, MaxStrLen(OrderNo));
            if OrderHasQtyToReserve(SourceType, OrderNo) then begin
                if not CheckOrderReservable(SourceType, OrderNo, false) then
                    Skipped += 1
                else
                    if RunReservation(SourceType, OrderNo, 0, true, ErrorText) then
                        Reserved += 1
                    else begin
                        Failed += 1;
                        if Failed <= 5 then
                            ErrorDetails += StrSubstNo(ErrorLineTxt, OrderNo, ErrorText);
                    end;
            end;
        end;
        Build();
        Message(ReserveAllResultMsg, Reserved, Skipped, Failed, ErrorDetails);
    end;

    procedure CancelReservationsOrder(SourceType: Enum "KMS Order Source"; OrderNo: Code[20])
    var
        Line: Record "KMS Outstanding Order Line" temporary;
        ReservationMgt: Codeunit "KMS Reservation Mgt.";
    begin
        Line.Copy(TempLine, true);
        Line.Reset();
        Line.SetRange("Source Type", SourceType);
        Line.SetRange("Order No.", OrderNo);
        Line.SetRange("Is Stock Item", true);
        if Line.FindSet() then
            repeat
                ReservationMgt.CancelLineReservations(Line, false, '');
            until Line.Next() = 0;
        RefreshOrder(SourceType, OrderNo);
    end;

    procedure CancelReservationsLine(SourceType: Enum "KMS Order Source"; OrderNo: Code[20]; LineNo: Integer)
    var
        ReservationMgt: Codeunit "KMS Reservation Mgt.";
    begin
        if not TempLine.Get(SourceType, OrderNo, LineNo) then
            exit;
        ReservationMgt.CancelLineReservations(TempLine, false, '');
        RefreshOrder(SourceType, OrderNo);
    end;

    procedure ReduceToPickableOrder(SourceType: Enum "KMS Order Source"; OrderNo: Code[20])
    var
        Line: Record "KMS Outstanding Order Line" temporary;
    begin
        if SourceType <> "KMS Order Source"::"Sales Order" then
            Error(ReduceSalesOnlyErr);
        Line.Copy(TempLine, true);
        Line.Reset();
        Line.SetRange("Source Type", SourceType);
        Line.SetRange("Order No.", OrderNo);
        Line.SetRange("Is Stock Item", true);
        if Line.FindSet() then
            repeat
                ReduceLineToPickable(Line);
            until Line.Next() = 0;
        RefreshOrder(SourceType, OrderNo);
    end;

    procedure ReduceToPickableLine(SourceType: Enum "KMS Order Source"; OrderNo: Code[20]; LineNo: Integer)
    begin
        if SourceType <> "KMS Order Source"::"Sales Order" then
            Error(ReduceSalesOnlyErr);
        if not TempLine.Get(SourceType, OrderNo, LineNo) then
            exit;
        ReduceLineToPickable(TempLine);
        RefreshOrder(SourceType, OrderNo);
    end;

    local procedure ReduceLineToPickable(var L: Record "KMS Outstanding Order Line")
    var
        ReservEntry: Record "Reservation Entry";
        SupplyEntry: Record "Reservation Entry";
        ReservationMgt: Codeunit "KMS Reservation Mgt.";
        LotQty: Dictionary of [Code[50], Decimal];
        LotExpiry: Dictionary of [Code[50], Date];
        LotNo: Code[50];
        LineLotQty: Decimal;
        OthersReserved: Decimal;
        AvailForLine: Decimal;
        Keep: Decimal;
    begin
        if not L."Is Stock Item" then
            exit;
        StockCalc.EnsureLoaded(L."No.", L."Variant Code", L."Location Code");
        ReservationMgt.FilterDemandReservations(L, ReservEntry);
        if ReservEntry.FindSet() then
            repeat
                if SupplyEntry.Get(ReservEntry."Entry No.", true) then
                    if SupplyEntry."Source Type" = Database::"Item Ledger Entry" then
                        AddToLot(LotQty, LotExpiry, SupplyEntry."Lot No.", Abs(ReservEntry."Quantity (Base)"), SupplyEntry."Expiration Date");
            until ReservEntry.Next() = 0;

        foreach LotNo in LotQty.Keys() do begin
            LineLotQty := LotQty.Get(LotNo);
            Keep := 0;
            if TempLot.Get(L."No.", L."Variant Code", L."Location Code", LotNo) then
                if not StockCalc.IsExpired(TempLot."Expiration Date") then begin
                    OthersReserved := TempLot."Reserved Qty." - LineLotQty;
                    AvailForLine := TempLot."Pickable Qty." - TempLot."Pick Qty." - MaxDec(0, OthersReserved - TempLot."Pick Qty.");
                    Keep := MinDec(LineLotQty, MaxDec(0, AvailForLine));
                end;
            if Keep < LineLotQty then begin
                ReservationMgt.CancelLineReservations(L, true, LotNo);
                if Keep > 0 then
                    ReservationMgt.ReserveLotForLine(L, LotNo, Keep);
            end;
        end;
    end;

    local procedure RunReservation(SourceType: Enum "KMS Order Source"; OrderNo: Code[20]; LineNo: Integer; CatchErrors: Boolean; var ErrorText: Text): Boolean
    var
        ReservationMgt: Codeunit "KMS Reservation Mgt.";
    begin
        ErrorText := '';
        ReservationMgt.SetContext(TempLine, TempAlloc, SourceType, OrderNo, LineNo);
        if CatchErrors then begin
            Commit();
            if not ReservationMgt.Run() then begin
                ErrorText := GetLastErrorText();
                exit(false);
            end;
        end else
            ReservationMgt.Run();
        DeleteAllocations(SourceType, OrderNo, LineNo);
        exit(true);
    end;

    local procedure CheckOrderReservable(SourceType: Enum "KMS Order Source"; OrderNo: Code[20]; ShowMessages: Boolean): Boolean
    var
        Line: Record "KMS Outstanding Order Line" temporary;
    begin
        if not OrderHasQtyToReserve(SourceType, OrderNo) then begin
            if ShowMessages then
                Message(NothingToReserveMsg, OrderNo);
            exit(false);
        end;
        if Setup."Reservation Mode" <> Setup."Reservation Mode"::"Fully Reservable Only" then
            exit(true);
        Line.Copy(TempLine, true);
        Line.Reset();
        Line.SetRange("Source Type", SourceType);
        Line.SetRange("Order No.", OrderNo);
        Line.SetRange("Is Stock Item", true);
        if Line.FindSet() then
            repeat
                if Line."Qty. to Reserve" < Line."Unreserved Qty." then begin
                    if ShowMessages then
                        Message(NotFullyReservableMsg, OrderNo);
                    exit(false);
                end;
            until Line.Next() = 0;
        exit(true);
    end;

    local procedure OrderHasQtyToReserve(SourceType: Enum "KMS Order Source"; OrderNo: Code[20]): Boolean
    var
        Line: Record "KMS Outstanding Order Line" temporary;
    begin
        Line.Copy(TempLine, true);
        Line.Reset();
        Line.SetRange("Source Type", SourceType);
        Line.SetRange("Order No.", OrderNo);
        Line.SetFilter("Qty. to Reserve", '>0');
        exit(not Line.IsEmpty());
    end;

    /// <summary>Rebuilds one order after Reserve / Cancel / Reduce, reloading stock for its items. Other orders catch up on the next Refresh.</summary>
    procedure RefreshOrder(SourceType: Enum "KMS Order Source"; OrderNo: Code[20])
    var
        Line: Record "KMS Outstanding Order Line" temporary;
        SalesHeader: Record "Sales Header";
        AssemblyHeader: Record "Assembly Header";
        StockKeys: List of [Text];
        StockKey: Text;
    begin
        Line.Copy(TempLine, true);
        Line.Reset();
        Line.SetRange("Source Type", SourceType);
        Line.SetRange("Order No.", OrderNo);
        if Line.FindSet() then
            repeat
                if Line."Is Stock Item" then begin
                    StockKey := StockCalc.MakeKey(Line."No.", Line."Variant Code", Line."Location Code");
                    if not StockKeys.Contains(StockKey) then begin
                        StockKeys.Add(StockKey);
                        StockCalc.Invalidate(Line."No.", Line."Variant Code", Line."Location Code");
                        ReloadStock(Line."No.", Line."Variant Code", Line."Location Code");
                    end;
                end;
            until Line.Next() = 0;
        Line.DeleteAll();
        if TempOrder.Get(SourceType, OrderNo) then
            TempOrder.Delete();

        case SourceType of
            "KMS Order Source"::"Sales Order":
                if SalesHeader.Get(SalesHeader."Document Type"::Order, OrderNo) then
                    if SalesHeader.Status in [SalesHeader.Status::Open, SalesHeader.Status::Released] then
                        BuildSalesOrder(SalesHeader);
            "KMS Order Source"::"Assembly Order":
                if AssemblyHeader.Get(AssemblyHeader."Document Type"::Order, OrderNo) then
                    BuildAssemblyOrder(AssemblyHeader);
        end;
    end;

    local procedure ReloadStock(ItemNo: Code[20]; VariantCode: Code[10]; LocationCode: Code[10])
    var
        Alloc: Record "KMS Lot Allocation" temporary;
    begin
        StockCalc.EnsureLoaded(ItemNo, VariantCode, LocationCode);
        // Put back what other lines have set aside on these lots.
        Alloc.Copy(TempAlloc, true);
        Alloc.Reset();
        Alloc.SetRange("Item No.", ItemNo);
        Alloc.SetRange("Variant Code", VariantCode);
        Alloc.SetRange("Location Code", LocationCode);
        if Alloc.FindSet() then
            repeat
                if TempLot.Get(ItemNo, VariantCode, LocationCode, Alloc."Lot No.") then begin
                    TempLot."Allocated Qty." += Alloc."Quantity (Base)";
                    TempLot.Modify();
                end;
            until Alloc.Next() = 0;
    end;

    // ------------------------------------------------------------------ Navigation

    procedure OpenOrder(SourceType: Enum "KMS Order Source"; OrderNo: Code[20])
    var
        SalesHeader: Record "Sales Header";
        AssemblyHeader: Record "Assembly Header";
    begin
        case SourceType of
            "KMS Order Source"::"Sales Order":
                if SalesHeader.Get(SalesHeader."Document Type"::Order, OrderNo) then
                    Page.Run(Page::"Sales Order", SalesHeader);
            "KMS Order Source"::"Assembly Order":
                if AssemblyHeader.Get(AssemblyHeader."Document Type"::Order, OrderNo) then
                    Page.Run(Page::"Assembly Order", AssemblyHeader);
        end;
    end;

    procedure OpenItem(ItemNo: Code[20])
    var
        Item: Record Item;
    begin
        if Item.Get(ItemNo) then
            Page.Run(Page::"Item Card", Item);
    end;

    procedure OpenPurchaseOrder(PONo: Code[20])
    var
        PurchaseHeader: Record "Purchase Header";
    begin
        if PurchaseHeader.Get(PurchaseHeader."Document Type"::Order, PONo) then
            Page.Run(Page::"Purchase Order", PurchaseHeader);
    end;

    procedure OpenWhseShipments(ShipmentNos: Text)
    var
        WhseShipmentHeader: Record "Warehouse Shipment Header";
    begin
        if ShipmentNos = '' then
            exit;
        WhseShipmentHeader.SetFilter("No.", ConvertStr(DelChr(ShipmentNos, '=', ' '), ',', '|'));
        if WhseShipmentHeader.Count() = 1 then begin
            WhseShipmentHeader.FindFirst();
            Page.Run(Page::"Warehouse Shipment", WhseShipmentHeader);
        end else
            Page.Run(Page::"Warehouse Shipment List", WhseShipmentHeader);
    end;

    procedure OpenAssemblyOrders(OrderNos: Text)
    var
        AssemblyHeader: Record "Assembly Header";
    begin
        if OrderNos = '' then
            exit;
        AssemblyHeader.SetRange("Document Type", AssemblyHeader."Document Type"::Order);
        AssemblyHeader.SetFilter("No.", ConvertStr(DelChr(OrderNos, '=', ' '), ',', '|'));
        if AssemblyHeader.Count() = 1 then begin
            AssemblyHeader.FindFirst();
            Page.Run(Page::"Assembly Order", AssemblyHeader);
        end else
            Page.Run(Page::"Assembly Orders", AssemblyHeader);
    end;

    procedure GetStyle(Colour: Enum "KMS Flag Colour"): Text
    begin
        case Colour of
            "KMS Flag Colour"::Green:
                exit('Favorable');
            "KMS Flag Colour"::Blue:
                exit('StrongAccent');
            "KMS Flag Colour"::Amber:
                exit('Ambiguous');
            "KMS Flag Colour"::Red:
                exit('Unfavorable');
            "KMS Flag Colour"::Grey:
                exit('Subordinate');
        end;
        exit('Standard');
    end;

    // ------------------------------------------------------------------ Helpers

    local procedure LocationMatches(LocationCode: Code[10]): Boolean
    var
        Location: Record Location;
        Matches: Boolean;
    begin
        if Setup."Location Filter" = '' then
            exit(true);
        if LocationCode = '' then
            exit(false);
        if LocationMatchCache.Get(LocationCode, Matches) then
            exit(Matches);
        Location.FilterGroup(2);
        Location.SetFilter(Code, Setup."Location Filter");
        Location.FilterGroup(0);
        Location.SetRange(Code, LocationCode);
        Matches := not Location.IsEmpty();
        LocationMatchCache.Add(LocationCode, Matches);
        exit(Matches);
    end;

    local procedure OrderHasLines(SourceType: Enum "KMS Order Source"; OrderNo: Code[20]): Boolean
    var
        Line: Record "KMS Outstanding Order Line" temporary;
    begin
        Line.Copy(TempLine, true);
        Line.Reset();
        Line.SetRange("Source Type", SourceType);
        Line.SetRange("Order No.", OrderNo);
        exit(not Line.IsEmpty());
    end;

    local procedure DeleteOrderLines(SourceType: Enum "KMS Order Source"; OrderNo: Code[20])
    var
        Line: Record "KMS Outstanding Order Line" temporary;
    begin
        Line.Copy(TempLine, true);
        Line.Reset();
        Line.SetRange("Source Type", SourceType);
        Line.SetRange("Order No.", OrderNo);
        Line.DeleteAll();
    end;

    local procedure GetItem(ItemNo: Code[20]; var Item: Record Item): Boolean
    begin
        if TempItemCache.Get(ItemNo) then begin
            Item := TempItemCache;
            exit(true);
        end;
        Item.SetLoadFields("No.", Description, "Description 2", Type, "Warehouse Class Code", "Replenishment System");
        if not Item.Get(ItemNo) then
            exit(false);
        TempItemCache := Item;
        TempItemCache.Insert();
        exit(true);
    end;

    local procedure GetCustomer(CustomerNo: Code[20]; var Customer: Record Customer): Boolean
    var
        RecRef: RecordRef;
        ShelfLifeText: Text;
        TerritoryText: Text;
    begin
        if CustomerNo = '' then
            exit(false);
        if TempCustomerCache.Get(CustomerNo) then begin
            Customer := TempCustomerCache;
            exit(true);
        end;
        if not Customer.Get(CustomerNo) then
            exit(false);
        RecRef.GetTable(Customer);
        CustomerExpiryCache.Set(CustomerNo, OptionalFields.GetMinExpiryDate(RecRef, Setup."Shelf Life Field Name", ShelfLifeText));
        CustomerShelfLifeCache.Set(CustomerNo, ShelfLifeText);
        TerritoryText := OptionalFields.GetTextByName(RecRef, Setup."Territory Field Name");
        if TerritoryText = '' then
            TerritoryText := Customer."Territory Code";
        CustomerTerritoryCache.Set(CustomerNo, TerritoryText);
        RecRef.Close();
        TempCustomerCache := Customer;
        TempCustomerCache.Insert();
        exit(true);
    end;

    local procedure GetCustomerMinExpiry(CustomerNo: Code[20]): Date
    var
        Customer: Record Customer;
        MinExpiry: Date;
    begin
        if not GetCustomer(CustomerNo, Customer) then
            exit(0D);
        if CustomerExpiryCache.Get(CustomerNo, MinExpiry) then
            exit(MinExpiry);
        exit(0D);
    end;

    local procedure GetUserName(UserSecurityId: Guid): Text[100]
    var
        User: Record User;
    begin
        User.SetLoadFields("User Name");
        if User.Get(UserSecurityId) then
            exit(CopyStr(User."User Name", 1, 100));
        exit('');
    end;

    local procedure GetSalesLineTypeText(var SalesLine: Record "Sales Line"; var Item: Record Item; IsItem: Boolean): Text[30]
    begin
        if SalesLine."Drop Shipment" then
            exit(DropShipmentTxt);
        if SalesLine."Special Order" then
            exit(SpecialOrderTxt);
        if IsItem and (Item.Type <> Item.Type::Inventory) then
            exit(CopyStr(Format(Item.Type), 1, 30));
        exit(CopyStr(Format(SalesLine.Type), 1, 30));
    end;

    local procedure GetWhseShipmentInfo(SourceType: Integer; SourceSubtype: Integer; SourceNo: Code[20]; SourceLineNo: Integer; var QtyBase: Decimal; var ShipmentNos: Text)
    var
        WhseShipmentLine: Record "Warehouse Shipment Line";
    begin
        QtyBase := 0;
        ShipmentNos := '';
        WhseShipmentLine.SetLoadFields("No.", "Qty. Outstanding (Base)");
        WhseShipmentLine.SetRange("Source Type", SourceType);
        WhseShipmentLine.SetRange("Source Subtype", SourceSubtype);
        WhseShipmentLine.SetRange("Source No.", SourceNo);
        WhseShipmentLine.SetRange("Source Line No.", SourceLineNo);
        if WhseShipmentLine.FindSet() then
            repeat
                QtyBase += WhseShipmentLine."Qty. Outstanding (Base)";
                AppendText(ShipmentNos, WhseShipmentLine."No.");
            until WhseShipmentLine.Next() = 0;
    end;

    local procedure SetOrderWhseShipment(var O: Record "KMS Outstanding Order")
    var
        WhseShipmentLine: Record "Warehouse Shipment Line";
        WhseShipmentHeader: Record "Warehouse Shipment Header";
    begin
        WhseShipmentLine.SetLoadFields("No.");
        WhseShipmentLine.SetRange("Source Type", Database::"Sales Line");
        WhseShipmentLine.SetRange("Source Subtype", 1);
        WhseShipmentLine.SetRange("Source No.", O."Order No.");
        if not WhseShipmentLine.FindFirst() then
            exit;
        O."Whse. Shipment No." := WhseShipmentLine."No.";
        if WhseShipmentHeader.Get(WhseShipmentLine."No.") then
            O."Whse. Shipment Status" := CopyStr(Format(WhseShipmentHeader."Document Status"), 1, MaxStrLen(O."Whse. Shipment Status"));
    end;

    /// <summary>PO Expected: the linked PO for drop shipment / special order lines, otherwise the open PO line for the item at the same location with the earliest Expected Receipt Date.</summary>
    local procedure SetPurchaseInfo(var L: Record "KMS Outstanding Order Line"; LinkedPONo: Code[20]; LinkedPOLineNo: Integer)
    var
        PurchaseLine: Record "Purchase Line";
        PurchaseHeader: Record "Purchase Header";
        CacheKey: Text;
        CachedValue: Text;
        FoundNo: Code[20];
        FoundLineNo: Integer;
        FoundDate: Date;
    begin
        if LinkedPONo <> '' then begin
            FoundNo := LinkedPONo;
            FoundLineNo := LinkedPOLineNo;
        end else begin
            if L."No." = '' then
                exit;
            CacheKey := StockCalc.MakeKey(L."No.", L."Variant Code", L."Location Code");
            if PurchaseLineCache.Get(CacheKey, CachedValue) then begin
                if CachedValue = '' then
                    exit;
                FoundNo := CopyStr(SelectStr(1, CachedValue), 1, MaxStrLen(FoundNo));
                Evaluate(FoundLineNo, SelectStr(2, CachedValue));
            end else begin
                PurchaseLine.SetLoadFields("Document No.", "Line No.", "Expected Receipt Date");
                PurchaseLine.SetRange("Document Type", PurchaseLine."Document Type"::Order);
                PurchaseLine.SetRange(Type, PurchaseLine.Type::Item);
                PurchaseLine.SetRange("No.", L."No.");
                PurchaseLine.SetRange("Variant Code", L."Variant Code");
                PurchaseLine.SetRange("Location Code", L."Location Code");
                PurchaseLine.SetFilter("Outstanding Qty. (Base)", '>0');
                if PurchaseLine.FindSet() then
                    repeat
                        if (FoundNo = '') or (PurchaseLine."Expected Receipt Date" < FoundDate) then begin
                            FoundNo := PurchaseLine."Document No.";
                            FoundLineNo := PurchaseLine."Line No.";
                            FoundDate := PurchaseLine."Expected Receipt Date";
                        end;
                    until PurchaseLine.Next() = 0;
                if FoundNo = '' then
                    PurchaseLineCache.Set(CacheKey, '')
                else
                    PurchaseLineCache.Set(CacheKey, FoundNo + ',' + Format(FoundLineNo));
                if FoundNo = '' then
                    exit;
            end;
        end;

        PurchaseLine.Reset();
        PurchaseLine.SetLoadFields("Document No.", "Expected Receipt Date", "Outstanding Quantity");
        if not PurchaseLine.Get(PurchaseLine."Document Type"::Order, FoundNo, FoundLineNo) then
            exit;
        L."PO No." := PurchaseLine."Document No.";
        L."PO Expected" := PurchaseLine."Expected Receipt Date";
        L."PO No. (Outstanding Qty.)" := CopyStr(StrSubstNo(QtyInBracketsTxt, PurchaseLine."Document No.", FormatQty(PurchaseLine."Outstanding Quantity")), 1, MaxStrLen(L."PO No. (Outstanding Qty.)"));
        PurchaseHeader.SetLoadFields("Buy-from Vendor Name", "Purchaser Code");
        if PurchaseHeader.Get(PurchaseHeader."Document Type"::Order, FoundNo) then begin
            L."PO Vendor Name" := PurchaseHeader."Buy-from Vendor Name";
            L."Purchaser Code" := PurchaseHeader."Purchaser Code";
        end;
    end;

    /// <summary>Assembly orders linked to the sales line: assemble-to-order links, plus open assembly orders for the item whose Related_Orders contains the sales order no.</summary>
    local procedure GetAssemblyOrderNos(var SalesLine: Record "Sales Line") Result: Text
    var
        AsmToOrderLink: Record "Assemble-to-Order Link";
        OrderList: List of [Code[20]];
        AsmNo: Code[20];
        RelatedTxt: Text;
    begin
        AsmToOrderLink.SetRange(Type, AsmToOrderLink.Type::Sale);
        AsmToOrderLink.SetRange("Document No.", SalesLine."Document No.");
        AsmToOrderLink.SetRange("Document Line No.", SalesLine."Line No.");
        if AsmToOrderLink.FindSet() then
            repeat
                AppendText(Result, AsmToOrderLink."Assembly Document No.");
            until AsmToOrderLink.Next() = 0;
        if AsmOrdersByItem.Get(SalesLine."No.", OrderList) then
            foreach AsmNo in OrderList do
                if AsmRelatedText.Get(AsmNo, RelatedTxt) then
                    if StrPos(UpperCase(RelatedTxt), UpperCase(SalesLine."Document No.")) > 0 then
                        AppendText(Result, AsmNo);
    end;

    local procedure AddToLot(var LotQty: Dictionary of [Code[50], Decimal]; var LotExpiry: Dictionary of [Code[50], Date]; LotNo: Code[50]; Qty: Decimal; Expiry: Date)
    var
        Existing: Decimal;
    begin
        if LotQty.Get(LotNo, Existing) then
            LotQty.Set(LotNo, Existing + Qty)
        else
            LotQty.Add(LotNo, Qty);
        if not LotExpiry.ContainsKey(LotNo) then
            LotExpiry.Add(LotNo, Expiry);
    end;

    /// <summary>Adds Value to a ", " separated list unless it is already there.</summary>
    local procedure AppendText(var Txt: Text; Value: Text)
    begin
        if Value = '' then
            exit;
        if Txt = '' then begin
            Txt := Value;
            exit;
        end;
        if StrPos(', ' + Txt + ',', ', ' + Value + ',') = 0 then
            Txt += ', ' + Value;
    end;

    local procedure GetFlagText(Colour: Enum "KMS Flag Colour"): Text[10]
    begin
        case Colour of
            "KMS Flag Colour"::None:
                exit('');
            "KMS Flag Colour"::Grey:
                exit(GreyFlagTxt);
        end;
        exit(FlagTxt);
    end;

    /// <summary>Value still to ship, excluding VAT and after invoice discount, in local currency.</summary>
    local procedure CalcUnshippedValueLCY(var SalesHeader: Record "Sales Header"; var SalesLine: Record "Sales Line"): Decimal
    var
        Value: Decimal;
    begin
        if SalesLine.Quantity = 0 then
            exit(0);
        Value := (SalesLine."Line Amount" - SalesLine."Inv. Discount Amount") * SalesLine."Outstanding Quantity" / SalesLine.Quantity;
        if (SalesHeader."Currency Code" <> '') and (SalesHeader."Currency Factor" <> 0) then
            Value := Value / SalesHeader."Currency Factor";
        exit(Round(Value));
    end;

    local procedure CalcMarginPct(Margin: Decimal; Value: Decimal): Decimal
    begin
        if Value = 0 then
            exit(0);
        exit(Round(Margin / Value * 100, 0.1));
    end;

    local procedure FormatQty(Qty: Decimal): Text
    begin
        exit(Format(Qty, 0, '<Precision,0:5><Standard Format,0>'));
    end;

    local procedure FormatDate(Value: Date): Text
    begin
        exit(Format(Value, 0, '<Day,2>/<Month,2>/<Year4>'));
    end;

    local procedure MinDec(A: Decimal; B: Decimal): Decimal
    begin
        if A < B then
            exit(A);
        exit(B);
    end;

    local procedure MaxDec(A: Decimal; B: Decimal): Decimal
    begin
        if A > B then
            exit(A);
        exit(B);
    end;
}
