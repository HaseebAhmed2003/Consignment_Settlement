codeunit 50305 "CNS Permission Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    // Data is set up with full rights, then the session is limited to one permission set
    // with "Permissions Mock" before the action runs.

    var
        CNSTestLibrary: Codeunit "CNS Test Library";
        PermissionsMock: Codeunit "Permissions Mock";
        Assert: Codeunit "Library Assert";

    [Test]
    procedure ClerkCanCalculate()
    var
        CNSSettlementHeader: Record "CNS Settlement Header";
        SettlementNo: Code[20];
    begin
        SettlementNo := CreateSettlementWithSale();

        PermissionsMock.Set('CNS CLERK');
        CNSTestLibrary.Calculate(SettlementNo);
        PermissionsMock.ClearAssignments();

        CNSSettlementHeader.Get(SettlementNo);
        Assert.AreEqual(CNSSettlementHeader.Status::Calculated, CNSSettlementHeader.Status, 'The clerk should be able to calculate.');
    end;

    [Test]
    procedure ClerkCannotApprove()
    var
        SettlementNo: Code[20];
    begin
        // [GIVEN] a settlement calculated by someone else, so only permissions can stop the clerk
        SettlementNo := CreateSettlementWithSale();
        CNSTestLibrary.Calculate(SettlementNo);
        CNSTestLibrary.SetCalculatedByOtherUser(SettlementNo);

        // [WHEN] a user with only CNS CLERK approves
        PermissionsMock.Set('CNS CLERK');
        asserterror CNSTestLibrary.Approve(SettlementNo);
        PermissionsMock.ClearAssignments();

        // [THEN] the approval log insert is refused
        Assert.ExpectedErrorCode('DB:ClientInsertDenied');
    end;

    [Test]
    procedure ApproverCannotCalculate()
    var
        SettlementNo: Code[20];
    begin
        // [GIVEN] a calculated settlement, so recalculating has lines to delete
        SettlementNo := CreateSettlementWithSale();
        CNSTestLibrary.Calculate(SettlementNo);

        PermissionsMock.Set('CNS APPROVER');
        asserterror CNSTestLibrary.Calculate(SettlementNo);
        PermissionsMock.ClearAssignments();

        Assert.ExpectedErrorCode('DB:ClientDeleteDenied');
    end;

    [Test]
    procedure ApproverCanApprove()
    var
        CNSSettlementHeader: Record "CNS Settlement Header";
        SettlementNo: Code[20];
    begin
        SettlementNo := CreateSettlementWithSale();
        CNSTestLibrary.Calculate(SettlementNo);
        CNSTestLibrary.SetCalculatedByOtherUser(SettlementNo);

        PermissionsMock.Set('CNS APPROVER');
        CNSTestLibrary.Approve(SettlementNo);
        PermissionsMock.ClearAssignments();

        CNSSettlementHeader.Get(SettlementNo);
        Assert.AreEqual(CNSSettlementHeader.Status::Approved, CNSSettlementHeader.Status, 'The approver should be able to approve.');
    end;

    local procedure CreateSettlementWithSale(): Code[20]
    var
        ItemNo: Code[20];
        AgreementNo: Code[20];
        Month: Date;
    begin
        CNSTestLibrary.Initialize();
        Month := CNSTestLibrary.MonthStart(-1);
        AgreementNo := CNSTestLibrary.CreateActiveAgreement(ItemNo);
        CNSTestLibrary.PostStock(ItemNo, 10, Month - 1);
        CNSTestLibrary.PostSale(ItemNo, 2, 100, Month + 5);
        exit(CNSTestLibrary.CreateSettlement(AgreementNo, Month));
    end;
}
