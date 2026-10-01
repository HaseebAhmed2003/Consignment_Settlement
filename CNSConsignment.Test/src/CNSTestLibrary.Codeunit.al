codeunit 50300 "CNS Test Library"
{
    // Shared helpers. Every test makes its own vendor, items and agreement, so the tests don't
    // depend on each other or on the demo data.

    var
        LibraryPurchase: Codeunit "Library - Purchase";
        LibraryInventory: Codeunit "Library - Inventory";
        LibrarySales: Codeunit "Library - Sales";
        LibraryERM: Codeunit "Library - ERM";
        LibraryUtility: Codeunit "Library - Utility";
        CNSSettlementMgt: Codeunit "CNS Settlement Mgt";
        CNSSettlementCalc: Codeunit "CNS Settlement Calc";
        OtherUserTok: Label 'OTHER.USER', Locked = true;
        MonthFormulaTok: Label '<-CM%1M>', Locked = true;

    procedure Initialize()
    var
        CNSSetup: Record "CNS Setup";
    begin
        CNSSettlementMgt.EnsureSetup();
        CNSSetup.Get();
        if CNSSetup."Payout G/L Account No." = '' then begin
            CNSSetup."Payout G/L Account No." := LibraryERM.CreateGLAccountNoWithDirectPosting();
            CNSSetup.Modify();
        end;
        LibrarySales.SetStockoutWarning(false);
        LibrarySales.SetCreditWarningsToNoWarnings();
        LibrarySales.SetExactCostReversingMandatory(false);
    end;

    /// <summary>First day of the month, Offset months away from the work date's month.</summary>
    procedure MonthStart(Offset: Integer): Date
    begin
        exit(CalcDate(StrSubstNo(MonthFormulaTok, Format(Offset, 0, '<Sign,1><Integer>')), WorkDate()));
    end;

    procedure CreateVendor(): Code[20]
    var
        Vendor: Record Vendor;
        CNSSetup: Record "CNS Setup";
        GLAccount: Record "G/L Account";
        VATPostingSetup: Record "VAT Posting Setup";
    begin
        LibraryPurchase.CreateVendor(Vendor);
        // The library gives the vendor a new VAT business group, which has no usable posting setup
        // with the payout account in CRONUS USA. Use a combination that exists and isn't blocked.
        CNSSetup.Get();
        GLAccount.Get(CNSSetup."Payout G/L Account No.");
        VATPostingSetup.SetRange("VAT Prod. Posting Group", GLAccount."VAT Prod. Posting Group");
        VATPostingSetup.SetRange(Blocked, false);
        if VATPostingSetup.FindFirst() then begin
            Vendor.Validate("VAT Bus. Posting Group", VATPostingSetup."VAT Bus. Posting Group");
            Vendor.Modify(true);
        end;
        exit(Vendor."No.");
    end;

    procedure CreateItem(): Code[20]
    var
        Item: Record Item;
    begin
        LibraryInventory.CreateItemWithUnitPriceAndUnitCost(Item, 100, 0);
        exit(Item."No.");
    end;

    /// <summary>Draft agreement for a new vendor, starting 3 months before the work date's month.</summary>
    procedure CreateDraftAgreement(): Code[20]
    begin
        exit(CreateDraftAgreement(CreateVendor(), MonthStart(-3), 0D));
    end;

    procedure CreateDraftAgreement(VendorNo: Code[20]; StartDate: Date; EndDate: Date): Code[20]
    var
        CNSAgreement: Record "CNS Agreement";
    begin
        CNSAgreement.Init();
        CNSAgreement."No." := LibraryUtility.GenerateGUID();
        CNSAgreement.Insert(true);
        CNSAgreement.Validate("Vendor No.", VendorNo);
        CNSAgreement.Validate("Start Date", StartDate);
        CNSAgreement.Validate("End Date", EndDate);
        CNSAgreement.Modify(true);
        exit(CNSAgreement."No.");
    end;

    procedure AddTier(AgreementNo: Code[20]; FromAmount: Decimal; CommissionPct: Decimal)
    var
        CNSCommissionTier: Record "CNS Commission Tier";
    begin
        CNSCommissionTier.Init();
        CNSCommissionTier."Agreement No." := AgreementNo;
        CNSCommissionTier.Validate("From Amount", FromAmount);
        CNSCommissionTier.Validate("Commission %", CommissionPct);
        CNSCommissionTier.Insert(true);
    end;

    procedure AddItem(AgreementNo: Code[20]; ItemNo: Code[20])
    var
        CNSAgreementItem: Record "CNS Agreement Item";
    begin
        CNSAgreementItem.Init();
        CNSAgreementItem."Agreement No." := AgreementNo;
        CNSAgreementItem.Validate("Item No.", ItemNo);
        CNSAgreementItem.Insert(true);
    end;

    procedure Activate(AgreementNo: Code[20])
    var
        CNSAgreement: Record "CNS Agreement";
        CNSAgreementMgt: Codeunit "CNS Agreement Mgt";
    begin
        CNSAgreement.Get(AgreementNo);
        CNSAgreementMgt.Activate(CNSAgreement);
    end;

    /// <summary>Active agreement with the spec's tiers (0 at 25%, 100,000 at 20%) and one new item.</summary>
    procedure CreateActiveAgreement(var ItemNo: Code[20]): Code[20]
    var
        AgreementNo: Code[20];
    begin
        AgreementNo := CreateDraftAgreement();
        AddTier(AgreementNo, 0, 25);
        AddTier(AgreementNo, 100000, 20);
        ItemNo := CreateItem();
        AddItem(AgreementNo, ItemNo);
        Activate(AgreementNo);
        exit(AgreementNo);
    end;

    procedure PostStock(ItemNo: Code[20]; Qty: Decimal; PostingDate: Date)
    var
        Item: Record Item;
    begin
        Item.Get(ItemNo);
        LibraryInventory.PostItemJournalLine(
            "Item Journal Template Type"::Item, "Item Ledger Entry Type"::"Positive Adjmt.", Item, GetLocation(), '', '', Qty, PostingDate, 0);
    end;

    /// <summary>Posts a sales invoice (positive Qty) or credit memo (negative Qty) for one item line. Returns the posted document no.</summary>
    procedure PostSale(ItemNo: Code[20]; Qty: Decimal; UnitPrice: Decimal; PostingDate: Date): Code[20]
    var
        Customer: Record Customer;
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";
    begin
        LibrarySales.CreateCustomer(Customer);
        Customer.Validate("Location Code", GetLocation());
        Customer.Modify(true);
        if Qty > 0 then
            LibrarySales.CreateSalesHeader(SalesHeader, SalesHeader."Document Type"::Invoice, Customer."No.")
        else
            LibrarySales.CreateSalesHeader(SalesHeader, SalesHeader."Document Type"::"Credit Memo", Customer."No.");
        SalesHeader.Validate("Posting Date", PostingDate);
        SalesHeader.Modify(true);
        LibrarySales.CreateSalesLine(SalesLine, SalesHeader, SalesLine.Type::Item, ItemNo, Abs(Qty));
        SalesLine.Validate("Unit Price", UnitPrice);
        SalesLine.Modify(true);
        exit(LibrarySales.PostSalesDocument(SalesHeader, true, true));
    end;

    procedure CreateSettlement(AgreementNo: Code[20]; PeriodDate: Date): Code[20]
    begin
        exit(CNSSettlementMgt.CreateSettlement(AgreementNo, PeriodDate));
    end;

    procedure Calculate(SettlementNo: Code[20])
    var
        CNSSettlementHeader: Record "CNS Settlement Header";
    begin
        CNSSettlementHeader.Get(SettlementNo);
        CNSSettlementCalc.Calculate(CNSSettlementHeader);
    end;

    /// <summary>Pretends someone else calculated, so the current user may approve.</summary>
    procedure SetCalculatedByOtherUser(SettlementNo: Code[20])
    var
        CNSSettlementHeader: Record "CNS Settlement Header";
    begin
        CNSSettlementHeader.Get(SettlementNo);
        CNSSettlementHeader."Calculated By" := OtherUserTok;
        CNSSettlementHeader.Modify();
    end;

    procedure Approve(SettlementNo: Code[20])
    var
        CNSSettlementHeader: Record "CNS Settlement Header";
    begin
        CNSSettlementHeader.Get(SettlementNo);
        CNSSettlementMgt.Approve(CNSSettlementHeader);
    end;

    procedure Post(SettlementNo: Code[20])
    var
        CNSSettlementHeader: Record "CNS Settlement Header";
        CNSSettlementPost: Codeunit "CNS Settlement Post";
    begin
        CNSSettlementHeader.Get(SettlementNo);
        CNSSettlementPost.PostSettlement(CNSSettlementHeader);
    end;

    /// <summary>Calculate, approve (as "another user") and post.</summary>
    procedure CalculateApprovePost(SettlementNo: Code[20])
    begin
        Calculate(SettlementNo);
        SetCalculatedByOtherUser(SettlementNo);
        Approve(SettlementNo);
        Post(SettlementNo);
    end;

    local procedure GetLocation(): Code[10]
    var
        InventorySetup: Record "Inventory Setup";
        Location: Record Location;
    begin
        InventorySetup.Get();
        if not InventorySetup."Location Mandatory" then
            exit('');
        Location.SetRange("Use As In-Transit", false);
        Location.SetRange("Bin Mandatory", false);
        Location.SetRange("Require Shipment", false);
        Location.SetRange("Require Pick", false);
        Location.SetRange("Require Receive", false);
        Location.SetRange("Require Put-away", false);
        Location.FindFirst();
        exit(Location.Code);
    end;
}
