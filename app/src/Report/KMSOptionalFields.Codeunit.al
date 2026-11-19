codeunit 77503 "KMS Optional Fields"
{
    // Reads custom fields that other extensions add (Warehouse Note, Created By, Min. Remaining Shelf Life,
    // Related_Orders, Region Territory) by name or number at run time. If a field does not exist, the
    // value is blank, so KM-DEV-SALES needs no dependency on those extensions.

    var
        FieldNoCache: Dictionary of [Text, Integer];

    procedure GetTextByName(var RecRef: RecordRef; FieldName: Text): Text
    begin
        exit(GetTextByNo(RecRef, FindFieldNo(RecRef.Number(), FieldName)));
    end;

    procedure GetTextByNo(var RecRef: RecordRef; FieldNo: Integer): Text
    var
        FldRef: FieldRef;
    begin
        if FieldNo <= 0 then
            exit('');
        if not RecRef.FieldExist(FieldNo) then
            exit('');
        FldRef := RecRef.Field(FieldNo);
        if FldRef.Class() = FieldClass::FlowField then
            FldRef.CalcField();
        exit(Format(FldRef.Value()));
    end;

    /// <summary>Today plus the customer's minimum remaining shelf life (a date formula or a number of days). 0D when there is none.</summary>
    procedure GetMinExpiryDate(var RecRef: RecordRef; FieldName: Text; var DisplayText: Text): Date
    var
        FldRef: FieldRef;
        ShelfLife: DateFormula;
        Value: Variant;
        Days: Integer;
        DaysDec: Decimal;
        FieldNo: Integer;
    begin
        DisplayText := '';
        FieldNo := FindFieldNo(RecRef.Number(), FieldName);
        if FieldNo <= 0 then
            exit(0D);
        FldRef := RecRef.Field(FieldNo);
        if FldRef.Class() = FieldClass::FlowField then
            FldRef.CalcField();
        DisplayText := Format(FldRef.Value());
        Value := FldRef.Value();
        case FldRef.Type() of
            FieldType::DateFormula:
                begin
                    ShelfLife := Value;
                    if Format(ShelfLife) = '' then
                        exit(0D);
                    exit(CalcDate(ShelfLife, Today()));
                end;
            FieldType::Integer:
                begin
                    Days := Value;
                    if Days <= 0 then
                        exit(0D);
                    exit(Today() + Days);
                end;
            FieldType::Decimal:
                begin
                    DaysDec := Value;
                    if DaysDec <= 0 then
                        exit(0D);
                    exit(Today() + Round(DaysDec, 1));
                end;
        end;
        exit(0D);
    end;

    procedure FieldExists(TableNo: Integer; FieldName: Text): Boolean
    begin
        exit(FindFieldNo(TableNo, FieldName) > 0);
    end;

    local procedure FindFieldNo(TableNo: Integer; FieldName: Text): Integer
    var
        Field: Record Field;
        CacheKey: Text;
        FoundNo: Integer;
    begin
        if FieldName = '' then
            exit(0);
        CacheKey := Format(TableNo) + '|' + FieldName;
        if FieldNoCache.Get(CacheKey, FoundNo) then
            exit(FoundNo);

        Field.SetRange(TableNo, TableNo);
        Field.SetFilter(ObsoleteState, '<>%1', Field.ObsoleteState::Removed);
        Field.SetRange(FieldName, CopyStr(FieldName, 1, MaxStrLen(Field.FieldName)));
        if not Field.FindFirst() then begin
            Field.SetRange(FieldName);
            Field.SetRange("Field Caption", CopyStr(FieldName, 1, MaxStrLen(Field."Field Caption")));
            if not Field.FindFirst() then
                Field."No." := 0;
        end;
        FoundNo := Field."No.";
        FieldNoCache.Add(CacheKey, FoundNo);
        exit(FoundNo);
    end;
}
