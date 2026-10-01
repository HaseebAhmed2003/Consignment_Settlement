codeunit 50306 "CNS Job Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        CNSTestLibrary: Codeunit "CNS Test Library";
        CNSSettlementMgt: Codeunit "CNS Settlement Mgt";
        CNSCreateDraftSettlements: Codeunit "CNS Create Draft Settlements";
        Assert: Codeunit "Library Assert";

    [Test]
    procedure CreatesDraftForPreviousMonth()
    var
        CNSSettlementHeader: Record "CNS Settlement Header";
        ItemNo: Code[20];
        AgreementNo: Code[20];
    begin
        CNSTestLibrary.Initialize();
        AgreementNo := CNSTestLibrary.CreateActiveAgreement(ItemNo);

        CNSCreateDraftSettlements.CreateForPreviousMonth(WorkDate());

        CNSSettlementHeader.Get(CNSSettlementMgt.FindSettlement(AgreementNo, CNSTestLibrary.MonthStart(-1)));
        Assert.AreEqual(CNSSettlementHeader.Status::Draft, CNSSettlementHeader.Status, 'Status');
        Assert.AreEqual(CalcDate('<CM>', CNSTestLibrary.MonthStart(-1)), CNSSettlementHeader."Period End", 'Period End');
    end;

    [Test]
    procedure RunningTwiceCreatesNothingNew()
    var
        ItemNo: Code[20];
    begin
        CNSTestLibrary.Initialize();
        CNSTestLibrary.CreateActiveAgreement(ItemNo);

        CNSCreateDraftSettlements.CreateForPreviousMonth(WorkDate());
        Assert.AreEqual(0, CNSCreateDraftSettlements.CreateForPreviousMonth(WorkDate()), 'Second run must skip existing settlements.');
    end;

    [Test]
    procedure DraftAgreementsAreSkipped()
    var
        AgreementNo: Code[20];
    begin
        CNSTestLibrary.Initialize();
        AgreementNo := CNSTestLibrary.CreateDraftAgreement();

        CNSCreateDraftSettlements.CreateForPreviousMonth(WorkDate());

        Assert.AreEqual('', CNSSettlementMgt.FindSettlement(AgreementNo, CNSTestLibrary.MonthStart(-1)), 'Only active agreements get settlements.');
    end;

    [Test]
    procedure ParameterStringSetsReferenceDate()
    var
        JobQueueEntry: Record "Job Queue Entry";
        ItemNo: Code[20];
        AgreementNo: Code[20];
        ReferenceDate: Date;
    begin
        // [GIVEN] a job queue entry whose parameter is the first day of the month before the work date
        CNSTestLibrary.Initialize();
        AgreementNo := CNSTestLibrary.CreateActiveAgreement(ItemNo);
        ReferenceDate := CNSTestLibrary.MonthStart(-1);
        JobQueueEntry."Parameter String" := Format(ReferenceDate, 0, 9);

        // [WHEN] the job codeunit runs
        Codeunit.Run(Codeunit::"CNS Create Draft Settlements", JobQueueEntry);

        // [THEN] the settlement is for the month before the parameter date, not before the work date
        Assert.AreNotEqual('', CNSSettlementMgt.FindSettlement(AgreementNo, CNSTestLibrary.MonthStart(-2)), 'Month before the parameter date');
        Assert.AreEqual('', CNSSettlementMgt.FindSettlement(AgreementNo, CNSTestLibrary.MonthStart(-1)), 'Not the month before the work date');
    end;
}
