codeunit 50204 "CNS Create Draft Settlements"
{
    Access = Public;
    TableNo = "Job Queue Entry";

    // Run monthly from a Job Queue Entry. A date in Parameter String (yyyy-mm-dd) replaces the
    // work date as the reference date: background sessions use today's date, not the work date.
    trigger OnRun()
    var
        ReferenceDate: Date;
    begin
        ReferenceDate := WorkDate();
        if Rec."Parameter String" <> '' then
            if not Evaluate(ReferenceDate, Rec."Parameter String", 9) then
                Error(InvalidParameterErr, Rec."Parameter String");
        CreateForPreviousMonth(ReferenceDate);
    end;

    var
        InvalidParameterErr: Label 'Parameter String "%1" is not a date. Use the format yyyy-mm-dd, or leave it blank to use the work date.', Comment = '%1 = parameter string';
        CreatedMsg: Label '%1 draft settlements were created for %2..%3.', Comment = '%1 = count, %2 = period start, %3 = period end';

    /// <summary>
    /// Creates a Draft settlement for the month before ReferenceDate for every active agreement
    /// that covers that month. Agreements that already have one are skipped, so it's safe to rerun.
    /// </summary>
    procedure CreateForPreviousMonth(ReferenceDate: Date) Created: Integer
    var
        CNSAgreement: Record "CNS Agreement";
        CNSSettlementMgt: Codeunit "CNS Settlement Mgt";
        PeriodStart: Date;
        PeriodEnd: Date;
    begin
        PeriodStart := CalcDate('<-CM-1M>', ReferenceDate);
        PeriodEnd := CalcDate('<CM>', PeriodStart);

        CNSAgreement.SetRange(Status, CNSAgreement.Status::Active);
        if CNSAgreement.FindSet() then
            repeat
                if CNSSettlementMgt.AgreementCoversPeriod(CNSAgreement, PeriodStart, PeriodEnd) then
                    if CNSSettlementMgt.FindSettlement(CNSAgreement."No.", PeriodStart) = '' then begin
                        CNSSettlementMgt.CreateSettlement(CNSAgreement."No.", PeriodStart);
                        Created += 1;
                    end;
            until CNSAgreement.Next() = 0;
    end;

    procedure CreateForPreviousMonthWithMessage(ReferenceDate: Date)
    var
        PeriodStart: Date;
        Created: Integer;
    begin
        Created := CreateForPreviousMonth(ReferenceDate);
        PeriodStart := CalcDate('<-CM-1M>', ReferenceDate);
        Message(CreatedMsg, Created, PeriodStart, CalcDate('<CM>', PeriodStart));
    end;
}
