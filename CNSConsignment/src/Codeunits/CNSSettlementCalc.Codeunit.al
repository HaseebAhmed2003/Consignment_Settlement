codeunit 50201 "CNS Settlement Calc"
{
    Access = Public;
    // Clerks only hold these indirectly, so lines can only be written through this codeunit.
    Permissions = tabledata "CNS Settlement Header" = rm,
                  tabledata "CNS Settlement Line" = rid;

    var
        NoTiersErr: Label 'Agreement %1 has no commission tiers.', Comment = '%1 = agreement no.';
        WrongStatusErr: Label 'Settlement %1 is %2. Only Draft or Calculated settlements can be calculated.', Comment = '%1 = settlement no., %2 = status';
        AgreementDraftErr: Label 'Agreement %1 is still a draft. Activate it before calculating settlements.', Comment = '%1 = agreement no.';
        EarlierNotPostedErr: Label 'Settlement %1 for an earlier period (%2) of agreement %3 is not posted yet. Settlements must be done in order.', Comment = '%1 = settlement no., %2 = period start, %3 = agreement no.';

    /// <summary>
    /// Rebuilds the settlement lines from posted sales value entries and works out the totals.
    /// </summary>
    procedure Calculate(var CNSSettlementHeader: Record "CNS Settlement Header")
    var
        CNSAgreement: Record "CNS Agreement";
        CNSAgreementItem: Record "CNS Agreement Item";
        CNSSettlementLine: Record "CNS Settlement Line";
        ToDate: Date;
        LineNo: Integer;
    begin
        CNSSettlementHeader.LockTable();
        CNSSettlementHeader.Get(CNSSettlementHeader."No.");
        if not (CNSSettlementHeader.Status in [CNSSettlementHeader.Status::Draft, CNSSettlementHeader.Status::Calculated]) then
            Error(WrongStatusErr, CNSSettlementHeader."No.", CNSSettlementHeader.Status);

        CNSAgreement.Get(CNSSettlementHeader."Agreement No.");
        if CNSAgreement.Status = CNSAgreement.Status::Draft then
            Error(AgreementDraftErr, CNSAgreement."No.");
        CheckEarlierSettlementsPosted(CNSSettlementHeader);

        CNSSettlementLine.SetRange("Settlement No.", CNSSettlementHeader."No.");
        CNSSettlementLine.DeleteAll();

        CNSSettlementHeader."Gross Sales" := 0;
        CNSSettlementHeader.Returns := 0;

        ToDate := CNSSettlementHeader."Period End";
        if (CNSAgreement."End Date" <> 0D) and (CNSAgreement."End Date" < ToDate) then
            ToDate := CNSAgreement."End Date";

        CNSAgreementItem.SetRange("Agreement No.", CNSAgreement."No.");
        if CNSAgreementItem.FindSet() then
            repeat
                AddItemEntries(CNSSettlementHeader, CNSAgreementItem."Item No.", CNSAgreement."Start Date", ToDate, LineNo);
            until CNSAgreementItem.Next() = 0;

        CNSSettlementHeader."Net Sales" := CNSSettlementHeader."Gross Sales" - CNSSettlementHeader.Returns;
        CNSSettlementHeader."Commission Amount" := CalcCommission(CNSAgreement."No.", CNSSettlementHeader."Net Sales");
        CNSSettlementHeader."Payout Amount" := CNSSettlementHeader."Net Sales" - CNSSettlementHeader."Commission Amount";
        CNSSettlementHeader."Calculated By" := CopyStr(UserId(), 1, MaxStrLen(CNSSettlementHeader."Calculated By"));
        CNSSettlementHeader."Calculated At" := CurrentDateTime();
        CNSSettlementHeader.Status := CNSSettlementHeader.Status::Calculated;
        CNSSettlementHeader.Modify(true);
    end;

    /// <summary>
    /// Progressive commission: each tier's rate applies only to the part of net sales inside that tier.
    /// </summary>
    procedure CalcCommission(AgreementNo: Code[20]; NetSales: Decimal): Decimal
    var
        TempCNSTierBreakdown: Record "CNS Tier Breakdown";
    begin
        exit(CalcCommission(AgreementNo, NetSales, TempCNSTierBreakdown));
    end;

    /// <summary>
    /// Same as above, and also returns one breakdown row per tier for the statement.
    /// </summary>
    procedure CalcCommission(AgreementNo: Code[20]; NetSales: Decimal; var TempCNSTierBreakdown: Record "CNS Tier Breakdown") Commission: Decimal
    var
        Tier: Record "CNS Commission Tier";
        NextTier: Record "CNS Commission Tier";
        UpperBound: Decimal;
        Portion: Decimal;
        TierCommission: Decimal;
        TierEnd: Decimal;
        BreakdownLineNo: Integer;
    begin
        TempCNSTierBreakdown.Reset();
        TempCNSTierBreakdown.DeleteAll();

        Tier.SetCurrentKey("Agreement No.", "From Amount");
        Tier.SetRange("Agreement No.", AgreementNo);
        if not Tier.FindSet() then
            Error(NoTiersErr, AgreementNo);
        repeat
            NextTier.Copy(Tier);
            if NextTier.Next() = 0 then begin
                TierEnd := 0; // the last tier has no upper limit
                UpperBound := NetSales;
            end else begin
                TierEnd := NextTier."From Amount";
                UpperBound := NextTier."From Amount";
            end;
            if UpperBound > NetSales then
                UpperBound := NetSales;

            Portion := UpperBound - Tier."From Amount";
            if Portion < 0 then
                Portion := 0;
            // Rounded per tier so the statement lines add up to the total.
            TierCommission := Round(Portion * Tier."Commission %" / 100, 0.01);
            Commission += TierCommission;

            TempCNSTierBreakdown.Init();
            BreakdownLineNo += 1;
            TempCNSTierBreakdown."Line No." := BreakdownLineNo;
            TempCNSTierBreakdown."From Amount" := Tier."From Amount";
            TempCNSTierBreakdown."To Amount" := TierEnd;
            TempCNSTierBreakdown."Commission %" := Tier."Commission %";
            TempCNSTierBreakdown."Amount in Tier" := Portion;
            TempCNSTierBreakdown."Commission Amount" := TierCommission;
            TempCNSTierBreakdown.Insert();
        until Tier.Next() = 0;
    end;

    local procedure AddItemEntries(var CNSSettlementHeader: Record "CNS Settlement Header"; ItemNo: Code[20]; FromDate: Date; ToDate: Date; var LineNo: Integer)
    var
        ValueEntry: Record "Value Entry";
        CNSSettlementLine: Record "CNS Settlement Line";
    begin
        ValueEntry.SetLoadFields("Entry No.", "Item No.", "Variant Code", "Posting Date", "Document No.", "Invoiced Quantity", "Sales Amount (Actual)");
        ValueEntry.SetCurrentKey("Item No.", "Posting Date", "Item Ledger Entry Type");
        ValueEntry.SetRange("Item No.", ItemNo);
        ValueEntry.SetRange("Posting Date", FromDate, ToDate);
        ValueEntry.SetRange("Item Ledger Entry Type", ValueEntry."Item Ledger Entry Type"::Sale);
        ValueEntry.SetRange(Adjustment, false);
        // Shipped but not invoiced entries have no actual amount yet; the invoice adds its own entry.
        ValueEntry.SetFilter("Sales Amount (Actual)", '<>0');
        if not ValueEntry.FindSet() then
            exit;
        repeat
            if not IsAlreadySettled(ValueEntry."Entry No.") then begin
                LineNo += 10000;
                CNSSettlementLine.Init();
                CNSSettlementLine."Settlement No." := CNSSettlementHeader."No.";
                CNSSettlementLine."Line No." := LineNo;
                CNSSettlementLine."Value Entry No." := ValueEntry."Entry No.";
                CNSSettlementLine."Item No." := ValueEntry."Item No.";
                CNSSettlementLine."Variant Code" := ValueEntry."Variant Code";
                CNSSettlementLine."Posting Date" := ValueEntry."Posting Date";
                CNSSettlementLine."Document No." := ValueEntry."Document No.";
                CNSSettlementLine.Quantity := -ValueEntry."Invoiced Quantity";
                CNSSettlementLine."Sales Amount" := ValueEntry."Sales Amount (Actual)";
                CNSSettlementLine.Insert();

                if ValueEntry."Sales Amount (Actual)" > 0 then
                    CNSSettlementHeader."Gross Sales" += ValueEntry."Sales Amount (Actual)"
                else
                    CNSSettlementHeader.Returns -= ValueEntry."Sales Amount (Actual)";
            end;
        until ValueEntry.Next() = 0;
    end;

    local procedure IsAlreadySettled(ValueEntryNo: Integer): Boolean
    var
        CNSSettlementLine: Record "CNS Settlement Line";
    begin
        // This settlement's own lines were deleted first, so any match is on another settlement.
        CNSSettlementLine.SetCurrentKey("Value Entry No.");
        CNSSettlementLine.SetRange("Value Entry No.", ValueEntryNo);
        exit(not CNSSettlementLine.IsEmpty());
    end;

    local procedure CheckEarlierSettlementsPosted(CNSSettlementHeader: Record "CNS Settlement Header")
    var
        EarlierSettlement: Record "CNS Settlement Header";
    begin
        EarlierSettlement.SetCurrentKey("Agreement No.", "Period Start");
        EarlierSettlement.SetRange("Agreement No.", CNSSettlementHeader."Agreement No.");
        EarlierSettlement.SetFilter("Period Start", '<%1', CNSSettlementHeader."Period Start");
        EarlierSettlement.SetFilter(Status, '<>%1', EarlierSettlement.Status::Posted);
        if EarlierSettlement.FindFirst() then
            Error(EarlierNotPostedErr, EarlierSettlement."No.", EarlierSettlement."Period Start", CNSSettlementHeader."Agreement No.");
    end;
}
