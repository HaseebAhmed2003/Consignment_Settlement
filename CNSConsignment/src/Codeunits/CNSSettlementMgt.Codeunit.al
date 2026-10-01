codeunit 50202 "CNS Settlement Mgt"
{
    Access = Public;
    Permissions = tabledata "CNS Settlement Header" = rim,
                  tabledata "CNS Approval Entry" = ri;

    var
        AgreementNotActiveErr: Label 'Agreement %1 is %2. Settlements can only be created for active agreements.', Comment = '%1 = agreement no., %2 = status';
        PeriodOutsideAgreementErr: Label 'Agreement %1 does not cover %2..%3.', Comment = '%1 = agreement no., %2 = period start, %3 = period end';
        SettlementExistsErr: Label 'Settlement %1 already exists for agreement %2 and the period starting %3.', Comment = '%1 = settlement no., %2 = agreement no., %3 = period start';
        NotCalculatedErr: Label 'Settlement %1 is %2. Only Calculated settlements can be approved.', Comment = '%1 = settlement no., %2 = status';
        SameUserErr: Label 'You calculated settlement %1, so you can''t approve it. Another user has to approve it.', Comment = '%1 = settlement no.';
        NegativePayoutErr: Label 'The payout for settlement %1 is negative (%2): returns are bigger than sales. Settle it manually with a purchase credit memo to the brand.', Comment = '%1 = settlement no., %2 = payout amount';
        ZeroPayoutErr: Label 'Settlement %1 has nothing to pay out.', Comment = '%1 = settlement no.';
        CreatedMsg: Label 'Settlement %1 was created.', Comment = '%1 = settlement no.';
        ApprovedMsg: Label 'Settlement %1 is approved.', Comment = '%1 = settlement no.';
        PostQst: Label 'Post a purchase invoice of %1 to vendor %2 for settlement %3?', Comment = '%1 = payout amount, %2 = vendor no., %3 = settlement no.';
        NoSeriesCodeTok: Label 'CNS-SET', Locked = true;
        NoSeriesDescriptionLbl: Label 'Consignment settlements';
        NoSeriesStartingNoTok: Label 'CNS-S00001', Locked = true;
        PostedMsg: Label 'Settlement %1 is posted. Purchase invoice %2 was created.', Comment = '%1 = settlement no., %2 = posted invoice no.';

    /// <summary>
    /// Creates a Draft settlement for the calendar month that contains PeriodDate.
    /// </summary>
    procedure CreateSettlement(AgreementNo: Code[20]; PeriodDate: Date): Code[20]
    var
        CNSAgreement: Record "CNS Agreement";
        CNSSetup: Record "CNS Setup";
        CNSSettlementHeader: Record "CNS Settlement Header";
        NoSeries: Codeunit "No. Series";
        PeriodStart: Date;
        PeriodEnd: Date;
        ExistingNo: Code[20];
    begin
        CNSAgreement.Get(AgreementNo);
        if CNSAgreement.Status <> CNSAgreement.Status::Active then
            Error(AgreementNotActiveErr, AgreementNo, CNSAgreement.Status);

        PeriodStart := CalcDate('<-CM>', PeriodDate);
        PeriodEnd := CalcDate('<CM>', PeriodDate);
        if not AgreementCoversPeriod(CNSAgreement, PeriodStart, PeriodEnd) then
            Error(PeriodOutsideAgreementErr, AgreementNo, PeriodStart, PeriodEnd);
        ExistingNo := FindSettlement(AgreementNo, PeriodStart);
        if ExistingNo <> '' then
            Error(SettlementExistsErr, ExistingNo, AgreementNo, PeriodStart);

        CNSSetup.Get();
        CNSSetup.TestField("Settlement Nos.");

        CNSSettlementHeader.Init();
        CNSSettlementHeader."No." := NoSeries.GetNextNo(CNSSetup."Settlement Nos.", PeriodEnd);
        CNSSettlementHeader."Agreement No." := CNSAgreement."No.";
        CNSSettlementHeader."Vendor No." := CNSAgreement."Vendor No.";
        CNSSettlementHeader."Period Start" := PeriodStart;
        CNSSettlementHeader."Period End" := PeriodEnd;
        CNSSettlementHeader.Status := CNSSettlementHeader.Status::Draft;
        CNSSettlementHeader.Insert(true);
        exit(CNSSettlementHeader."No.");
    end;

    procedure CreateSettlementWithMessage(AgreementNo: Code[20]; PeriodDate: Date): Code[20]
    var
        SettlementNo: Code[20];
    begin
        SettlementNo := CreateSettlement(AgreementNo, PeriodDate);
        Message(CreatedMsg, SettlementNo);
        exit(SettlementNo);
    end;

    procedure FindSettlement(AgreementNo: Code[20]; PeriodStart: Date): Code[20]
    var
        CNSSettlementHeader: Record "CNS Settlement Header";
    begin
        CNSSettlementHeader.SetCurrentKey("Agreement No.", "Period Start");
        CNSSettlementHeader.SetRange("Agreement No.", AgreementNo);
        CNSSettlementHeader.SetRange("Period Start", PeriodStart);
        if CNSSettlementHeader.FindFirst() then
            exit(CNSSettlementHeader."No.");
        exit('');
    end;

    procedure AgreementCoversPeriod(CNSAgreement: Record "CNS Agreement"; PeriodStart: Date; PeriodEnd: Date): Boolean
    begin
        if CNSAgreement."Start Date" > PeriodEnd then
            exit(false);
        if (CNSAgreement."End Date" <> 0D) and (CNSAgreement."End Date" < PeriodStart) then
            exit(false);
        exit(true);
    end;

    procedure Calculate(var CNSSettlementHeader: Record "CNS Settlement Header")
    var
        CNSSettlementCalc: Codeunit "CNS Settlement Calc";
    begin
        CNSSettlementCalc.Calculate(CNSSettlementHeader);
    end;

    procedure Approve(var CNSSettlementHeader: Record "CNS Settlement Header")
    begin
        CNSSettlementHeader.LockTable();
        CNSSettlementHeader.Get(CNSSettlementHeader."No.");
        if CNSSettlementHeader.Status <> CNSSettlementHeader.Status::Calculated then
            Error(NotCalculatedErr, CNSSettlementHeader."No.", CNSSettlementHeader.Status);
        if CNSSettlementHeader."Calculated By" = UserId() then
            Error(SameUserErr, CNSSettlementHeader."No.");
        CheckPayout(CNSSettlementHeader);

        // The log insert is what an approver can do and a clerk can't (see the permission sets).
        InsertApprovalEntry(CNSSettlementHeader, "CNS Approval Action"::Approved);

        CNSSettlementHeader."Approved By" := CopyStr(UserId(), 1, MaxStrLen(CNSSettlementHeader."Approved By"));
        CNSSettlementHeader."Approved At" := CurrentDateTime();
        CNSSettlementHeader.Status := CNSSettlementHeader.Status::Approved;
        CNSSettlementHeader.Modify(true);
    end;

    procedure ApproveWithMessage(var CNSSettlementHeader: Record "CNS Settlement Header")
    begin
        Approve(CNSSettlementHeader);
        Message(ApprovedMsg, CNSSettlementHeader."No.");
    end;

    procedure PostWithConfirm(var CNSSettlementHeader: Record "CNS Settlement Header")
    var
        CNSSettlementPost: Codeunit "CNS Settlement Post";
    begin
        if not Confirm(PostQst, false, CNSSettlementHeader."Payout Amount", CNSSettlementHeader."Vendor No.", CNSSettlementHeader."No.") then
            exit;
        CNSSettlementPost.PostSettlement(CNSSettlementHeader);
        Message(PostedMsg, CNSSettlementHeader."No.", CNSSettlementHeader."Posted Invoice No.");
    end;

    procedure CheckPayout(CNSSettlementHeader: Record "CNS Settlement Header")
    begin
        if CNSSettlementHeader."Payout Amount" < 0 then
            Error(NegativePayoutErr, CNSSettlementHeader."No.", CNSSettlementHeader."Payout Amount");
        if CNSSettlementHeader."Payout Amount" = 0 then
            Error(ZeroPayoutErr, CNSSettlementHeader."No.");
    end;

    procedure InsertApprovalEntry(CNSSettlementHeader: Record "CNS Settlement Header"; ApprovalAction: Enum "CNS Approval Action")
    var
        CNSApprovalEntry: Record "CNS Approval Entry";
    begin
        CNSApprovalEntry.Init();
        CNSApprovalEntry."Entry No." := 0;
        CNSApprovalEntry."Settlement No." := CNSSettlementHeader."No.";
        CNSApprovalEntry.Action := ApprovalAction;
        CNSApprovalEntry."User ID" := CopyStr(UserId(), 1, MaxStrLen(CNSApprovalEntry."User ID"));
        CNSApprovalEntry."Date-Time" := CurrentDateTime();
        CNSApprovalEntry."Payout Amount" := CNSSettlementHeader."Payout Amount";
        CNSApprovalEntry.Insert();
    end;

    /// <summary>
    /// Creates the setup record and the settlement number series if they're missing.
    /// </summary>
    procedure EnsureSetup()
    var
        CNSSetup: Record "CNS Setup";
    begin
        if not CNSSetup.Get() then begin
            CNSSetup.Init();
            CNSSetup.Insert();
        end;
        if CNSSetup."Settlement Nos." <> '' then
            exit;
        CreateNoSeries();
        CNSSetup."Settlement Nos." := NoSeriesCodeTok;
        CNSSetup.Modify();
    end;

    local procedure CreateNoSeries()
    var
        NoSeries: Record "No. Series";
        NoSeriesLine: Record "No. Series Line";
    begin
        if not NoSeries.Get(NoSeriesCodeTok) then begin
            NoSeries.Init();
            NoSeries.Code := NoSeriesCodeTok;
            NoSeries.Description := NoSeriesDescriptionLbl;
            NoSeries."Default Nos." := true;
            NoSeries."Manual Nos." := false;
            NoSeries.Insert();
        end;
        NoSeriesLine.SetRange("Series Code", NoSeriesCodeTok);
        if not NoSeriesLine.IsEmpty() then
            exit;
        NoSeriesLine.Init();
        NoSeriesLine."Series Code" := NoSeriesCodeTok;
        NoSeriesLine."Line No." := 10000;
        NoSeriesLine.Validate("Starting No.", NoSeriesStartingNoTok);
        NoSeriesLine."Increment-by No." := 1;
        NoSeriesLine.Insert(true);
    end;
}
