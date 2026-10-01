codeunit 50304 "CNS Workflow Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    // Draft -> Calculated -> Approved -> Posted, and posting the payout.

    var
        CNSTestLibrary: Codeunit "CNS Test Library";
        Assert: Codeunit "Library Assert";

    [Test]
    procedure ApproveNeedsCalculatedStatus()
    var
        ItemNo: Code[20];
        SettlementNo: Code[20];
    begin
        CNSTestLibrary.Initialize();
        SettlementNo := CNSTestLibrary.CreateSettlement(CNSTestLibrary.CreateActiveAgreement(ItemNo), CNSTestLibrary.MonthStart(-1));

        asserterror CNSTestLibrary.Approve(SettlementNo);
        Assert.ExpectedError('Only Calculated settlements can be approved');
    end;

    [Test]
    procedure AnotherUserCanApprove()
    var
        CNSSettlementHeader: Record "CNS Settlement Header";
        CNSApprovalEntry: Record "CNS Approval Entry";
        SettlementNo: Code[20];
    begin
        // [GIVEN] a calculated settlement that someone else calculated
        SettlementNo := CreateCalculatedSettlement(3, 100);
        CNSTestLibrary.SetCalculatedByOtherUser(SettlementNo);

        // [WHEN] the current user approves
        CNSTestLibrary.Approve(SettlementNo);

        // [THEN] it is approved, stamped and logged
        CNSSettlementHeader.Get(SettlementNo);
        Assert.AreEqual(CNSSettlementHeader.Status::Approved, CNSSettlementHeader.Status, 'Status');
        Assert.AreEqual(UserId(), CNSSettlementHeader."Approved By", 'Approved By');
        CNSApprovalEntry.SetRange("Settlement No.", SettlementNo);
        CNSApprovalEntry.SetRange(Action, CNSApprovalEntry.Action::Approved);
        Assert.RecordCount(CNSApprovalEntry, 1);
    end;

    [Test]
    procedure CannotRecalculateAfterApproval()
    var
        SettlementNo: Code[20];
    begin
        SettlementNo := CreateCalculatedSettlement(3, 100);
        CNSTestLibrary.SetCalculatedByOtherUser(SettlementNo);
        CNSTestLibrary.Approve(SettlementNo);

        asserterror CNSTestLibrary.Calculate(SettlementNo);
        Assert.ExpectedError('Only Draft or Calculated settlements can be calculated');
    end;

    [Test]
    procedure PostNeedsApproval()
    var
        SettlementNo: Code[20];
    begin
        SettlementNo := CreateCalculatedSettlement(3, 100);

        asserterror CNSTestLibrary.Post(SettlementNo);
        Assert.ExpectedError('Only Approved settlements can be posted');
    end;

    [Test]
    procedure PostCreatesVendorInvoiceWithBrandDimension()
    var
        CNSSettlementHeader: Record "CNS Settlement Header";
        CNSSetup: Record "CNS Setup";
        PurchInvHeader: Record "Purch. Inv. Header";
        VendorLedgerEntry: Record "Vendor Ledger Entry";
        GLEntry: Record "G/L Entry";
        DimensionValue: Record "Dimension Value";
        DefaultDimension: Record "Default Dimension";
        DimensionSetEntry: Record "Dimension Set Entry";
        LibraryDimension: Codeunit "Library - Dimension";
        SettlementNo: Code[20];
    begin
        // [GIVEN] the brand vendor has a default BRAND-style dimension
        SettlementNo := CreateCalculatedSettlement(4, 100);
        CNSSettlementHeader.Get(SettlementNo);
        LibraryDimension.CreateDimWithDimValue(DimensionValue);
        LibraryDimension.CreateDefaultDimensionVendor(DefaultDimension, CNSSettlementHeader."Vendor No.", DimensionValue."Dimension Code", DimensionValue.Code);

        // [WHEN] it is approved by someone else and posted
        CNSTestLibrary.SetCalculatedByOtherUser(SettlementNo);
        CNSTestLibrary.Approve(SettlementNo);
        CNSTestLibrary.Post(SettlementNo);

        // [THEN] the settlement is Posted with the invoice number
        CNSSettlementHeader.Get(SettlementNo);
        Assert.AreEqual(CNSSettlementHeader.Status::Posted, CNSSettlementHeader.Status, 'Status');
        PurchInvHeader.Get(CNSSettlementHeader."Posted Invoice No.");
        Assert.AreEqual(CNSSettlementHeader."Vendor No.", PurchInvHeader."Buy-from Vendor No.", 'Invoice vendor');
        Assert.AreEqual(SettlementNo, PurchInvHeader."Vendor Invoice No.", 'The settlement no. is the vendor invoice no.');
        Assert.AreEqual(CNSSettlementHeader."Period End", PurchInvHeader."Posting Date", 'Posted on the last day of the period');

        // [THEN] the vendor ledger entry is the payout (400 - 25% = 300) and carries the dimension
        VendorLedgerEntry.SetRange("Document No.", PurchInvHeader."No.");
        VendorLedgerEntry.FindFirst();
        VendorLedgerEntry.CalcFields(Amount);
        Assert.AreEqual(-300, VendorLedgerEntry.Amount, 'Payout amount on the vendor ledger entry');
        DimensionSetEntry.Get(VendorLedgerEntry."Dimension Set ID", DimensionValue."Dimension Code");
        Assert.AreEqual(DimensionValue.Code, DimensionSetEntry."Dimension Value Code", 'Vendor ledger entry dimension');

        // [THEN] so does the G/L entry on the payout account
        CNSSetup.Get();
        GLEntry.SetRange("Document No.", PurchInvHeader."No.");
        GLEntry.SetRange("G/L Account No.", CNSSetup."Payout G/L Account No.");
        GLEntry.FindFirst();
        Assert.AreEqual(300, GLEntry.Amount, 'G/L amount on the payout account');
        DimensionSetEntry.Get(GLEntry."Dimension Set ID", DimensionValue."Dimension Code");
        Assert.AreEqual(DimensionValue.Code, DimensionSetEntry."Dimension Value Code", 'G/L entry dimension');
    end;

    [Test]
    procedure PostedSettlementIsLocked()
    var
        CNSSettlementHeader: Record "CNS Settlement Header";
        SettlementNo: Code[20];
    begin
        SettlementNo := CreateCalculatedSettlement(2, 100);
        CNSTestLibrary.SetCalculatedByOtherUser(SettlementNo);
        CNSTestLibrary.Approve(SettlementNo);
        CNSTestLibrary.Post(SettlementNo);

        CNSSettlementHeader.Get(SettlementNo);
        CNSSettlementHeader."Payout Amount" += 1;
        asserterror CNSSettlementHeader.Modify(true);
        Assert.ExpectedError('is posted and can no longer be changed');
    end;

    [Test]
    procedure PostedSettlementCannotBeDeleted()
    var
        CNSSettlementHeader: Record "CNS Settlement Header";
        SettlementNo: Code[20];
    begin
        SettlementNo := CreateCalculatedSettlement(2, 100);
        CNSTestLibrary.SetCalculatedByOtherUser(SettlementNo);
        CNSTestLibrary.Approve(SettlementNo);
        CNSTestLibrary.Post(SettlementNo);

        CNSSettlementHeader.Get(SettlementNo);
        asserterror CNSSettlementHeader.Delete(true);
        Assert.ExpectedError('Only Draft or Calculated settlements can be deleted');
    end;

    [Test]
    procedure ZeroPayoutIsNotApproved()
    var
        ItemNo: Code[20];
        SettlementNo: Code[20];
    begin
        // A month without sales has nothing to pay
        CNSTestLibrary.Initialize();
        SettlementNo := CNSTestLibrary.CreateSettlement(CNSTestLibrary.CreateActiveAgreement(ItemNo), CNSTestLibrary.MonthStart(-1));
        CNSTestLibrary.Calculate(SettlementNo);
        CNSTestLibrary.SetCalculatedByOtherUser(SettlementNo);

        asserterror CNSTestLibrary.Approve(SettlementNo);
        Assert.ExpectedError('has nothing to pay out');
    end;

    local procedure CreateCalculatedSettlement(Qty: Decimal; UnitPrice: Decimal) SettlementNo: Code[20]
    var
        ItemNo: Code[20];
        AgreementNo: Code[20];
        Month: Date;
    begin
        CNSTestLibrary.Initialize();
        Month := CNSTestLibrary.MonthStart(-1);
        AgreementNo := CNSTestLibrary.CreateActiveAgreement(ItemNo);
        CNSTestLibrary.PostStock(ItemNo, 10, Month - 1);
        CNSTestLibrary.PostSale(ItemNo, Qty, UnitPrice, Month + 5);
        SettlementNo := CNSTestLibrary.CreateSettlement(AgreementNo, Month);
        CNSTestLibrary.Calculate(SettlementNo);
    end;
}
