codeunit 50303 "CNS Calculation Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    // Month -2 and month -1 relative to the work date are used as "month 1" and "month 2".

    var
        CNSTestLibrary: Codeunit "CNS Test Library";
        Assert: Codeunit "Library Assert";

    [Test]
    procedure SumsSalesOfAgreementItemsOnly()
    var
        CNSSettlementHeader: Record "CNS Settlement Header";
        ItemNo: Code[20];
        OtherItemNo: Code[20];
        AgreementNo: Code[20];
        Month1: Date;
    begin
        // [GIVEN] two sales of the agreement item and one of an item outside the agreement
        CNSTestLibrary.Initialize();
        Month1 := CNSTestLibrary.MonthStart(-2);
        AgreementNo := CNSTestLibrary.CreateActiveAgreement(ItemNo);
        OtherItemNo := CNSTestLibrary.CreateItem();
        CNSTestLibrary.PostStock(ItemNo, 10, Month1 - 1);
        CNSTestLibrary.PostStock(OtherItemNo, 10, Month1 - 1);
        CNSTestLibrary.PostSale(ItemNo, 2, 100, Month1 + 3);
        CNSTestLibrary.PostSale(ItemNo, 3, 100, Month1 + 10);
        CNSTestLibrary.PostSale(OtherItemNo, 4, 100, Month1 + 10);

        // [WHEN] month 1 is calculated
        CNSSettlementHeader.Get(CNSTestLibrary.CreateSettlement(AgreementNo, Month1));
        CNSTestLibrary.Calculate(CNSSettlementHeader."No.");

        // [THEN] only the agreement item counts: 500 gross, 125 commission, 375 payout
        CNSSettlementHeader.Get(CNSSettlementHeader."No.");
        CNSSettlementHeader.CalcFields("No. of Lines");
        Assert.AreEqual(2, CNSSettlementHeader."No. of Lines", 'One line per sales value entry of the agreement item.');
        Assert.AreEqual(500, CNSSettlementHeader."Gross Sales", 'Gross sales');
        Assert.AreEqual(0, CNSSettlementHeader.Returns, 'Returns');
        Assert.AreEqual(500, CNSSettlementHeader."Net Sales", 'Net sales');
        Assert.AreEqual(125, CNSSettlementHeader."Commission Amount", 'Commission at 25%');
        Assert.AreEqual(375, CNSSettlementHeader."Payout Amount", 'Payout = net - commission');
        Assert.AreEqual(CNSSettlementHeader.Status::Calculated, CNSSettlementHeader.Status, 'Status');
        Assert.AreEqual(UserId(), CNSSettlementHeader."Calculated By", 'Calculated By');
    end;

    [Test]
    procedure ReturnInSameMonthReducesNetSales()
    var
        CNSSettlementHeader: Record "CNS Settlement Header";
        CNSSettlementLine: Record "CNS Settlement Line";
        ItemNo: Code[20];
        AgreementNo: Code[20];
        Month1: Date;
    begin
        CNSTestLibrary.Initialize();
        Month1 := CNSTestLibrary.MonthStart(-2);
        AgreementNo := CNSTestLibrary.CreateActiveAgreement(ItemNo);
        CNSTestLibrary.PostStock(ItemNo, 10, Month1 - 1);
        CNSTestLibrary.PostSale(ItemNo, 4, 100, Month1 + 3);
        CNSTestLibrary.PostSale(ItemNo, -1, 100, Month1 + 8);

        CNSSettlementHeader.Get(CNSTestLibrary.CreateSettlement(AgreementNo, Month1));
        CNSTestLibrary.Calculate(CNSSettlementHeader."No.");

        CNSSettlementHeader.Get(CNSSettlementHeader."No.");
        Assert.AreEqual(400, CNSSettlementHeader."Gross Sales", 'Gross sales');
        Assert.AreEqual(100, CNSSettlementHeader.Returns, 'Returns are shown as a positive amount');
        Assert.AreEqual(300, CNSSettlementHeader."Net Sales", 'Net sales');

        CNSSettlementLine.SetRange("Settlement No.", CNSSettlementHeader."No.");
        CNSSettlementLine.SetFilter("Sales Amount", '<0');
        CNSSettlementLine.FindFirst();
        Assert.AreEqual(-1, CNSSettlementLine.Quantity, 'The return line has a negative quantity.');
    end;

    [Test]
    procedure SalesOutsideThePeriodAreLeftForLater()
    var
        CNSSettlementHeader: Record "CNS Settlement Header";
        ItemNo: Code[20];
        AgreementNo: Code[20];
        Month1: Date;
    begin
        // [GIVEN] one sale in month 1 and one in month 2
        CNSTestLibrary.Initialize();
        Month1 := CNSTestLibrary.MonthStart(-2);
        AgreementNo := CNSTestLibrary.CreateActiveAgreement(ItemNo);
        CNSTestLibrary.PostStock(ItemNo, 10, Month1 - 1);
        CNSTestLibrary.PostSale(ItemNo, 1, 100, Month1 + 3);
        CNSTestLibrary.PostSale(ItemNo, 2, 100, CalcDate('<1M>', Month1) + 3);

        // [WHEN] month 1 is calculated
        CNSSettlementHeader.Get(CNSTestLibrary.CreateSettlement(AgreementNo, Month1));
        CNSTestLibrary.Calculate(CNSSettlementHeader."No.");

        // [THEN] only the month 1 sale is included
        CNSSettlementHeader.Get(CNSSettlementHeader."No.");
        Assert.AreEqual(100, CNSSettlementHeader."Gross Sales", 'The month 2 sale must not be in month 1.');
    end;

    [Test]
    procedure RecalculatingDoesNotDoubleCount()
    var
        CNSSettlementHeader: Record "CNS Settlement Header";
        ItemNo: Code[20];
        AgreementNo: Code[20];
        Month1: Date;
    begin
        CNSTestLibrary.Initialize();
        Month1 := CNSTestLibrary.MonthStart(-2);
        AgreementNo := CNSTestLibrary.CreateActiveAgreement(ItemNo);
        CNSTestLibrary.PostStock(ItemNo, 10, Month1 - 1);
        CNSTestLibrary.PostSale(ItemNo, 3, 100, Month1 + 3);
        CNSSettlementHeader.Get(CNSTestLibrary.CreateSettlement(AgreementNo, Month1));

        // [WHEN] the same settlement is calculated twice
        CNSTestLibrary.Calculate(CNSSettlementHeader."No.");
        CNSTestLibrary.Calculate(CNSSettlementHeader."No.");

        // [THEN] the lines are rebuilt, not added again
        CNSSettlementHeader.Get(CNSSettlementHeader."No.");
        CNSSettlementHeader.CalcFields("No. of Lines");
        Assert.AreEqual(1, CNSSettlementHeader."No. of Lines", 'Lines must be rebuilt on recalculation.');
        Assert.AreEqual(300, CNSSettlementHeader."Gross Sales", 'Gross sales must not double.');
    end;

    [Test]
    procedure NextSettlementSkipsEntriesAlreadyPaid()
    var
        CNSSettlementHeader: Record "CNS Settlement Header";
        ItemNo: Code[20];
        AgreementNo: Code[20];
        Month1: Date;
        Month2: Date;
    begin
        // [GIVEN] month 1 with one sale is posted
        CNSTestLibrary.Initialize();
        Month1 := CNSTestLibrary.MonthStart(-2);
        Month2 := CNSTestLibrary.MonthStart(-1);
        AgreementNo := CNSTestLibrary.CreateActiveAgreement(ItemNo);
        CNSTestLibrary.PostStock(ItemNo, 10, Month1 - 1);
        CNSTestLibrary.PostSale(ItemNo, 3, 100, Month1 + 3);
        CNSTestLibrary.CalculateApprovePost(CNSTestLibrary.CreateSettlement(AgreementNo, Month1));

        // [WHEN] month 2, which has no new sales, is calculated (its date filter starts at the agreement start)
        CNSSettlementHeader.Get(CNSTestLibrary.CreateSettlement(AgreementNo, Month2));
        CNSTestLibrary.Calculate(CNSSettlementHeader."No.");

        // [THEN] the month 1 sale isn't picked up again
        CNSSettlementHeader.Get(CNSSettlementHeader."No.");
        CNSSettlementHeader.CalcFields("No. of Lines");
        Assert.AreEqual(0, CNSSettlementHeader."No. of Lines", 'Entries already on a settlement must be skipped.');
        Assert.AreEqual(0, CNSSettlementHeader."Net Sales", 'Nothing new to settle.');
    end;

    [Test]
    procedure EarlierSettlementMustBePostedFirst()
    var
        ItemNo: Code[20];
        AgreementNo: Code[20];
        Month2SettlementNo: Code[20];
    begin
        CNSTestLibrary.Initialize();
        AgreementNo := CNSTestLibrary.CreateActiveAgreement(ItemNo);
        CNSTestLibrary.CreateSettlement(AgreementNo, CNSTestLibrary.MonthStart(-2));
        Month2SettlementNo := CNSTestLibrary.CreateSettlement(AgreementNo, CNSTestLibrary.MonthStart(-1));

        asserterror CNSTestLibrary.Calculate(Month2SettlementNo);
        Assert.ExpectedError('Settlements must be done in order');
    end;

    [Test]
    procedure OneSettlementPerAgreementAndMonth()
    var
        ItemNo: Code[20];
        AgreementNo: Code[20];
    begin
        CNSTestLibrary.Initialize();
        AgreementNo := CNSTestLibrary.CreateActiveAgreement(ItemNo);
        CNSTestLibrary.CreateSettlement(AgreementNo, CNSTestLibrary.MonthStart(-1));

        // A different day in the same month is still the same month
        asserterror CNSTestLibrary.CreateSettlement(AgreementNo, CNSTestLibrary.MonthStart(-1) + 10);
        Assert.ExpectedError('already exists for agreement');
    end;
}
