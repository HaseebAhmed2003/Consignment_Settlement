codeunit 50301 "CNS Commission Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    // Tier maths only. Tiers: 0 at 25%, 100,000 at 20% (the example from the spec).

    var
        CNSTestLibrary: Codeunit "CNS Test Library";
        CNSSettlementCalc: Codeunit "CNS Settlement Calc";
        Assert: Codeunit "Library Assert";

    [Test]
    procedure BelowThresholdUsesFirstRate()
    begin
        // 50,000 × 25%
        Assert.AreEqual(12500, CNSSettlementCalc.CalcCommission(CreateSpecTiers(), 50000), 'Below the threshold only the first rate applies.');
    end;

    [Test]
    procedure ExactlyAtThreshold()
    begin
        // 100,000 × 25%; nothing in the second tier yet
        Assert.AreEqual(25000, CNSSettlementCalc.CalcCommission(CreateSpecTiers(), 100000), 'At the threshold the second tier has nothing in it.');
    end;

    [Test]
    procedure AcrossTwoTiers()
    begin
        // 100,000 × 25% + 50,000 × 20% = 35,000
        Assert.AreEqual(35000, CNSSettlementCalc.CalcCommission(CreateSpecTiers(), 150000), 'Spec example: 150,000 gives 35,000.');
    end;

    [Test]
    procedure ThreeTiers()
    var
        AgreementNo: Code[20];
    begin
        // 100,000 × 25% + 100,000 × 20% + 50,000 × 15% = 52,500
        AgreementNo := CreateSpecTiers();
        CNSTestLibrary.AddTier(AgreementNo, 200000, 15);
        Assert.AreEqual(52500, CNSSettlementCalc.CalcCommission(AgreementNo, 250000), 'Each rate applies to its own band only.');
    end;

    [Test]
    procedure ZeroNetSalesGivesZero()
    begin
        Assert.AreEqual(0, CNSSettlementCalc.CalcCommission(CreateSpecTiers(), 0), 'No sales, no commission.');
    end;

    [Test]
    procedure NegativeNetSalesGivesZero()
    begin
        Assert.AreEqual(0, CNSSettlementCalc.CalcCommission(CreateSpecTiers(), -1500), 'Commission is never negative.');
    end;

    [Test]
    procedure BreakdownAddsUpToTotal()
    var
        TempCNSTierBreakdown: Record "CNS Tier Breakdown";
        Commission: Decimal;
    begin
        Commission := CNSSettlementCalc.CalcCommission(CreateSpecTiers(), 150000, TempCNSTierBreakdown);

        Assert.RecordCount(TempCNSTierBreakdown, 2);
        TempCNSTierBreakdown.FindFirst();
        Assert.AreEqual(100000, TempCNSTierBreakdown."Amount in Tier", 'First tier holds 100,000.');
        Assert.AreEqual(25000, TempCNSTierBreakdown."Commission Amount", 'First tier commission.');
        TempCNSTierBreakdown.FindLast();
        Assert.AreEqual(50000, TempCNSTierBreakdown."Amount in Tier", 'Second tier holds the rest.');
        Assert.AreEqual(0, TempCNSTierBreakdown."To Amount", 'The last tier has no upper limit.');
        TempCNSTierBreakdown.CalcSums("Commission Amount");
        Assert.AreEqual(Commission, TempCNSTierBreakdown."Commission Amount", 'Tier lines must add up to the total.');
    end;

    [Test]
    procedure NoTiersIsAnError()
    var
        AgreementNo: Code[20];
    begin
        CNSTestLibrary.Initialize();
        AgreementNo := CNSTestLibrary.CreateDraftAgreement();
        asserterror CNSSettlementCalc.CalcCommission(AgreementNo, 1000);
        Assert.ExpectedError('has no commission tiers');
    end;

    local procedure CreateSpecTiers(): Code[20]
    var
        AgreementNo: Code[20];
    begin
        CNSTestLibrary.Initialize();
        AgreementNo := CNSTestLibrary.CreateDraftAgreement();
        CNSTestLibrary.AddTier(AgreementNo, 0, 25);
        CNSTestLibrary.AddTier(AgreementNo, 100000, 20);
        exit(AgreementNo);
    end;
}
