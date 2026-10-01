codeunit 50302 "CNS Agreement Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        CNSTestLibrary: Codeunit "CNS Test Library";
        Assert: Codeunit "Library Assert";

    [Test]
    procedure ActivateNeedsTiers()
    var
        AgreementNo: Code[20];
    begin
        CNSTestLibrary.Initialize();
        AgreementNo := CNSTestLibrary.CreateDraftAgreement();
        CNSTestLibrary.AddItem(AgreementNo, CNSTestLibrary.CreateItem());

        asserterror CNSTestLibrary.Activate(AgreementNo);
        Assert.ExpectedError('has no commission tiers');
    end;

    [Test]
    procedure FirstTierMustStartAtZero()
    var
        AgreementNo: Code[20];
    begin
        CNSTestLibrary.Initialize();
        AgreementNo := CNSTestLibrary.CreateDraftAgreement();
        CNSTestLibrary.AddTier(AgreementNo, 1000, 25);
        CNSTestLibrary.AddItem(AgreementNo, CNSTestLibrary.CreateItem());

        asserterror CNSTestLibrary.Activate(AgreementNo);
        Assert.ExpectedError('The first tier must start at 0');
    end;

    [Test]
    procedure ActivateNeedsItems()
    var
        AgreementNo: Code[20];
    begin
        CNSTestLibrary.Initialize();
        AgreementNo := CNSTestLibrary.CreateDraftAgreement();
        CNSTestLibrary.AddTier(AgreementNo, 0, 25);

        asserterror CNSTestLibrary.Activate(AgreementNo);
        Assert.ExpectedError('has no items');
    end;

    [Test]
    procedure ItemCannotBeInTwoOverlappingActiveAgreements()
    var
        ItemNo: Code[20];
        SecondAgreementNo: Code[20];
    begin
        // [GIVEN] an active open-ended agreement with an item
        CNSTestLibrary.Initialize();
        CNSTestLibrary.CreateActiveAgreement(ItemNo);

        // [WHEN] a second agreement with the same item and an overlapping period is activated
        SecondAgreementNo := CNSTestLibrary.CreateDraftAgreement(CNSTestLibrary.CreateVendor(), CNSTestLibrary.MonthStart(-1), 0D);
        CNSTestLibrary.AddTier(SecondAgreementNo, 0, 30);
        CNSTestLibrary.AddItem(SecondAgreementNo, ItemNo);
        asserterror CNSTestLibrary.Activate(SecondAgreementNo);

        // [THEN] it is refused
        Assert.ExpectedError('is already in active agreement');
    end;

    [Test]
    procedure SameItemAllowedInLaterAgreementAfterEnd()
    var
        CNSAgreement: Record "CNS Agreement";
        FirstAgreementNo: Code[20];
        SecondAgreementNo: Code[20];
        ItemNo: Code[20];
    begin
        // [GIVEN] the first agreement for the item ends before the second one starts
        CNSTestLibrary.Initialize();
        FirstAgreementNo := CNSTestLibrary.CreateDraftAgreement(CNSTestLibrary.CreateVendor(), CNSTestLibrary.MonthStart(-6), CNSTestLibrary.MonthStart(-3) - 1);
        CNSTestLibrary.AddTier(FirstAgreementNo, 0, 25);
        ItemNo := CNSTestLibrary.CreateItem();
        CNSTestLibrary.AddItem(FirstAgreementNo, ItemNo);
        CNSTestLibrary.Activate(FirstAgreementNo);

        SecondAgreementNo := CNSTestLibrary.CreateDraftAgreement(CNSTestLibrary.CreateVendor(), CNSTestLibrary.MonthStart(-3), 0D);
        CNSTestLibrary.AddTier(SecondAgreementNo, 0, 30);
        CNSTestLibrary.AddItem(SecondAgreementNo, ItemNo);

        // [WHEN] the second agreement is activated
        CNSTestLibrary.Activate(SecondAgreementNo);

        // [THEN] it is active
        CNSAgreement.Get(SecondAgreementNo);
        Assert.AreEqual(CNSAgreement.Status::Active, CNSAgreement.Status, 'Periods don''t overlap, so this is allowed.');
    end;

    [Test]
    procedure EndDateMustBeAfterStartDate()
    var
        CNSAgreement: Record "CNS Agreement";
    begin
        CNSTestLibrary.Initialize();
        CNSAgreement.Get(CNSTestLibrary.CreateDraftAgreement());
        asserterror CNSAgreement.Validate("End Date", CNSAgreement."Start Date" - 1);
        Assert.ExpectedError('The end date must be after the start date.');
    end;

    [Test]
    procedure CommissionPercentAbove100IsRefused()
    var
        CNSCommissionTier: Record "CNS Commission Tier";
    begin
        CNSTestLibrary.Initialize();
        CNSCommissionTier."Agreement No." := CNSTestLibrary.CreateDraftAgreement();
        asserterror CNSCommissionTier.Validate("Commission %", 101);
        Assert.ExpectedError('The commission % must be between 0 and 100.');
    end;

    [Test]
    procedure TiersAreLockedOnceActive()
    var
        ItemNo: Code[20];
        AgreementNo: Code[20];
    begin
        CNSTestLibrary.Initialize();
        AgreementNo := CNSTestLibrary.CreateActiveAgreement(ItemNo);

        asserterror CNSTestLibrary.AddTier(AgreementNo, 500000, 10);
        Assert.ExpectedError('Status must be equal to ''Draft''');
    end;
}
