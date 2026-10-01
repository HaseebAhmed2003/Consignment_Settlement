codeunit 50206 "CNS Demo Data"
{
    Access = Internal;

    // Month 1 = the month before the work date, month 2 = the work date's month.
    // Luna crosses its 10,000 tier in month 1; month 2 has a return of a bag sold in month 1.

    var
        LunaVendorTok: Label 'CNS-LUNA', Locked = true;
        LunaNameTok: Label 'Luna Leather Co.', Locked = true;
        SaffronVendorTok: Label 'CNS-SAFFRON', Locked = true;
        SaffronNameTok: Label 'Saffron Silk House', Locked = true;
        CustomerTok: Label 'CNS-CASH', Locked = true;
        CustomerNameTok: Label 'Store Cash Customer', Locked = true;
        BrandDimTok: Label 'BRAND', Locked = true;
        BrandDimNameTok: Label 'Brand', Locked = true;
        LunaDimValueTok: Label 'LUNA', Locked = true;
        SaffronDimValueTok: Label 'SAFFRON', Locked = true;
        HandbagTok: Label 'CNS-BAG01', Locked = true;
        HandbagNameTok: Label 'Luna Classic Handbag', Locked = true;
        WalletTok: Label 'CNS-WAL01', Locked = true;
        WalletNameTok: Label 'Luna Leather Wallet', Locked = true;
        ScarfTok: Label 'CNS-SCF01', Locked = true;
        ScarfNameTok: Label 'Saffron Silk Scarf', Locked = true;
        BlackTok: Label 'BLACK', Locked = true;
        TanTok: Label 'TAN', Locked = true;
        RedTok: Label 'RED', Locked = true;
        BlueTok: Label 'BLUE', Locked = true;
        LunaAgreementTok: Label 'AGR-LUNA', Locked = true;
        SaffronAgreementTok: Label 'AGR-SAFFRON', Locked = true;
        StockDocTok: Label 'CNS-STOCK', Locked = true;
        NoSourceVendorErr: Label 'No existing vendor with posting groups was found to copy settings from.';
        NoSourceCustomerErr: Label 'No existing customer with posting groups was found to copy settings from.';
        NoSourceItemErr: Label 'No existing inventory item with posting groups was found to copy settings from.';
        NoLocationErr: Label 'Locations are mandatory in Inventory Setup, but no location without warehouse handling was found.';
        DoneMsg: Label 'Demo data is ready. Agreements %1 and %2, sales from %3 to %4.', Comment = '%1, %2 = agreement nos., %3 = first date, %4 = last date';
        ResetQst: Label 'This deletes all consignment agreements, settlements and approval entries in this company and creates the demo agreements again. Posted sales and invoices stay. Continue?';

    procedure CreateDemoData()
    var
        CNSSettlementMgt: Codeunit "CNS Settlement Mgt";
        Month1: Date;
        Month2: Date;
    begin
        Month1 := CalcDate('<-CM-1M>', WorkDate());
        Month2 := CalcDate('<-CM>', WorkDate());

        CNSSettlementMgt.EnsureSetup();
        CreateBrandDimension();
        CreateVendor(LunaVendorTok, LunaNameTok, LunaDimValueTok);
        CreateVendor(SaffronVendorTok, SaffronNameTok, SaffronDimValueTok);
        CreateCustomer();
        CreateItem(HandbagTok, HandbagNameTok, 1500, LunaVendorTok);
        CreateVariant(HandbagTok, BlackTok, 'Black');
        CreateVariant(HandbagTok, TanTok, 'Tan');
        CreateItem(WalletTok, WalletNameTok, 250, LunaVendorTok);
        CreateItem(ScarfTok, ScarfNameTok, 180, SaffronVendorTok);
        CreateVariant(ScarfTok, RedTok, 'Red');
        CreateVariant(ScarfTok, BlueTok, 'Blue');
        SetPayoutAccount();

        CreateAgreements(CalcDate('<-1M>', Month1));

        // Ledger entries can't be deleted, so the stock and sales are only posted once.
        if not SalesAlreadyPosted() then begin
            PostStock(Month1 - 1);
            PostSales(Month1, Month2);
        end;

        Message(DoneMsg, LunaAgreementTok, SaffronAgreementTok, Month1, CalcDate('<CM>', Month2));
    end;

    procedure ResetAndCreateDemoData()
    begin
        if not Confirm(ResetQst, false) then
            exit;
        DeleteExtensionData();
        CreateDemoData();
    end;

    local procedure DeleteExtensionData()
    var
        CNSSettlementLine: Record "CNS Settlement Line";
        CNSSettlementHeader: Record "CNS Settlement Header";
        CNSApprovalEntry: Record "CNS Approval Entry";
        CNSAgreementItem: Record "CNS Agreement Item";
        CNSCommissionTier: Record "CNS Commission Tier";
        CNSAgreement: Record "CNS Agreement";
    begin
        // Without triggers on purpose: posted settlements and active agreements are normally locked.
        CNSSettlementLine.DeleteAll(false);
        CNSSettlementHeader.DeleteAll(false);
        CNSApprovalEntry.DeleteAll(false);
        CNSAgreementItem.DeleteAll(false);
        CNSCommissionTier.DeleteAll(false);
        CNSAgreement.DeleteAll(false);
    end;

    local procedure CreateBrandDimension()
    var
        Dimension: Record Dimension;
    begin
        if not Dimension.Get(BrandDimTok) then begin
            Dimension.Init();
            Dimension.Code := BrandDimTok;
            Dimension.Name := BrandDimNameTok;
            Dimension.Insert(true);
        end;
        CreateDimensionValue(LunaDimValueTok, LunaNameTok);
        CreateDimensionValue(SaffronDimValueTok, SaffronNameTok);
    end;

    local procedure CreateDimensionValue(ValueCode: Code[20]; ValueName: Text[50])
    var
        DimensionValue: Record "Dimension Value";
    begin
        if DimensionValue.Get(BrandDimTok, ValueCode) then
            exit;
        DimensionValue.Init();
        DimensionValue."Dimension Code" := BrandDimTok;
        DimensionValue.Code := ValueCode;
        DimensionValue.Name := ValueName;
        DimensionValue.Insert(true);
    end;

    local procedure CreateVendor(VendorNo: Code[20]; VendorName: Text[100]; BrandValue: Code[20])
    var
        SourceVendor: Record Vendor;
        Vendor: Record Vendor;
        DefaultDimension: Record "Default Dimension";
    begin
        if not Vendor.Get(VendorNo) then begin
            SourceVendor.SetFilter("Gen. Bus. Posting Group", '<>%1', '');
            SourceVendor.SetFilter("Vendor Posting Group", '<>%1', '');
            SourceVendor.SetRange(Blocked, SourceVendor.Blocked::" ");
            SourceVendor.SetRange("Currency Code", '');
            if not SourceVendor.FindFirst() then
                Error(NoSourceVendorErr);

            Vendor.Init();
            Vendor."No." := VendorNo;
            Vendor.Insert(true);
            Vendor.Validate(Name, VendorName);
            Vendor.Validate("Gen. Bus. Posting Group", SourceVendor."Gen. Bus. Posting Group");
            Vendor.Validate("Vendor Posting Group", SourceVendor."Vendor Posting Group");
            Vendor.Validate("VAT Bus. Posting Group", SourceVendor."VAT Bus. Posting Group");
            Vendor.Validate("Payment Terms Code", SourceVendor."Payment Terms Code");
            Vendor.Validate("Tax Liable", false);
            Vendor.Modify(true);
        end;

        // Standard BC default dimension: every document for this vendor gets BRAND automatically.
        if DefaultDimension.Get(Database::Vendor, VendorNo, BrandDimTok) then
            exit;
        DefaultDimension.Init();
        DefaultDimension."Table ID" := Database::Vendor;
        DefaultDimension."No." := VendorNo;
        DefaultDimension.Validate("Dimension Code", BrandDimTok);
        DefaultDimension.Validate("Dimension Value Code", BrandValue);
        DefaultDimension.Validate("Value Posting", DefaultDimension."Value Posting"::"Same Code");
        DefaultDimension.Insert(true);
    end;

    local procedure CreateCustomer()
    var
        SourceCustomer: Record Customer;
        Customer: Record Customer;
    begin
        if Customer.Get(CustomerTok) then
            exit;
        SourceCustomer.SetFilter("Gen. Bus. Posting Group", '<>%1', '');
        SourceCustomer.SetFilter("Customer Posting Group", '<>%1', '');
        SourceCustomer.SetRange(Blocked, SourceCustomer.Blocked::" ");
        SourceCustomer.SetRange("Currency Code", '');
        if not SourceCustomer.FindFirst() then
            Error(NoSourceCustomerErr);

        Customer.Init();
        Customer."No." := CustomerTok;
        Customer.Insert(true);
        Customer.Validate(Name, CustomerNameTok);
        Customer.Validate("Gen. Bus. Posting Group", SourceCustomer."Gen. Bus. Posting Group");
        Customer.Validate("Customer Posting Group", SourceCustomer."Customer Posting Group");
        Customer.Validate("VAT Bus. Posting Group", SourceCustomer."VAT Bus. Posting Group");
        Customer.Validate("Payment Terms Code", SourceCustomer."Payment Terms Code");
        Customer.Validate("Tax Liable", false);
        Customer.Validate("Location Code", GetDemoLocation());
        Customer.Modify(true);
    end;

    local procedure CreateItem(ItemNo: Code[20]; ItemDescription: Text[100]; UnitPrice: Decimal; VendorNo: Code[20])
    var
        SourceItem: Record Item;
        Item: Record Item;
    begin
        if Item.Get(ItemNo) then
            exit;
        SourceItem.SetRange(Type, SourceItem.Type::Inventory);
        SourceItem.SetFilter("Gen. Prod. Posting Group", '<>%1', '');
        SourceItem.SetFilter("Inventory Posting Group", '<>%1', '');
        SourceItem.SetFilter("Base Unit of Measure", '<>%1', '');
        SourceItem.SetRange(Blocked, false);
        if not SourceItem.FindFirst() then
            Error(NoSourceItemErr);

        Item.Init();
        Item."No." := ItemNo;
        Item.Insert(true);
        Item.Validate(Description, ItemDescription);
        Item.Validate(Type, Item.Type::Inventory);
        Item.Validate("Base Unit of Measure", SourceItem."Base Unit of Measure");
        Item.Validate("Gen. Prod. Posting Group", SourceItem."Gen. Prod. Posting Group");
        Item.Validate("Inventory Posting Group", SourceItem."Inventory Posting Group");
        Item.Validate("VAT Prod. Posting Group", SourceItem."VAT Prod. Posting Group");
        Item.Validate("Tax Group Code", SourceItem."Tax Group Code");
        Item.Validate("Costing Method", Item."Costing Method"::FIFO);
        // Consignment stock belongs to the brand, so the store carries it at zero cost.
        Item.Validate("Unit Cost", 0);
        Item.Validate("Unit Price", UnitPrice);
        Item.Validate("Vendor No.", VendorNo);
        Item.Modify(true);
    end;

    local procedure CreateVariant(ItemNo: Code[20]; VariantCode: Code[10]; VariantDescription: Text[100])
    var
        ItemVariant: Record "Item Variant";
    begin
        if ItemVariant.Get(ItemNo, VariantCode) then
            exit;
        ItemVariant.Init();
        ItemVariant."Item No." := ItemNo;
        ItemVariant.Code := VariantCode;
        ItemVariant.Description := VariantDescription;
        ItemVariant.Insert(true);
    end;

    local procedure SetPayoutAccount()
    var
        CNSSetup: Record "CNS Setup";
        Vendor: Record Vendor;
        Item: Record Item;
        GeneralPostingSetup: Record "General Posting Setup";
    begin
        CNSSetup.Get();
        if CNSSetup."Payout G/L Account No." <> '' then
            exit;
        Vendor.Get(LunaVendorTok);
        Item.Get(HandbagTok);
        if not GeneralPostingSetup.Get(Vendor."Gen. Bus. Posting Group", Item."Gen. Prod. Posting Group") then
            exit;
        CNSSetup."Payout G/L Account No." := GeneralPostingSetup."Purch. Account";
        CNSSetup.Modify();
    end;

    local procedure CreateAgreements(StartDate: Date)
    var
        CNSAgreement: Record "CNS Agreement";
    begin
        if not CNSAgreement.Get(LunaAgreementTok) then begin
            CreateAgreement(LunaAgreementTok, LunaVendorTok, 'Luna handbags and wallets', StartDate);
            AddTier(LunaAgreementTok, 0, 25);
            AddTier(LunaAgreementTok, 10000, 20);
            AddItem(LunaAgreementTok, HandbagTok);
            AddItem(LunaAgreementTok, WalletTok);
            ActivateAgreement(LunaAgreementTok);
        end;
        if not CNSAgreement.Get(SaffronAgreementTok) then begin
            CreateAgreement(SaffronAgreementTok, SaffronVendorTok, 'Saffron silk scarves', StartDate);
            AddTier(SaffronAgreementTok, 0, 30);
            AddItem(SaffronAgreementTok, ScarfTok);
            ActivateAgreement(SaffronAgreementTok);
        end;
    end;

    local procedure CreateAgreement(AgreementNo: Code[20]; VendorNo: Code[20]; AgreementDescription: Text[100]; StartDate: Date)
    var
        CNSAgreement: Record "CNS Agreement";
    begin
        CNSAgreement.Init();
        CNSAgreement."No." := AgreementNo;
        CNSAgreement.Insert(true);
        CNSAgreement.Validate("Vendor No.", VendorNo);
        CNSAgreement.Validate(Description, AgreementDescription);
        CNSAgreement.Validate("Start Date", StartDate);
        CNSAgreement.Modify(true);
    end;

    local procedure AddTier(AgreementNo: Code[20]; FromAmount: Decimal; CommissionPct: Decimal)
    var
        CNSCommissionTier: Record "CNS Commission Tier";
        LineNo: Integer;
    begin
        CNSCommissionTier.SetRange("Agreement No.", AgreementNo);
        if CNSCommissionTier.FindLast() then
            LineNo := CNSCommissionTier."Line No.";
        CNSCommissionTier.Init();
        CNSCommissionTier."Agreement No." := AgreementNo;
        CNSCommissionTier."Line No." := LineNo + 10000;
        CNSCommissionTier.Validate("From Amount", FromAmount);
        CNSCommissionTier.Validate("Commission %", CommissionPct);
        CNSCommissionTier.Insert(true);
    end;

    local procedure AddItem(AgreementNo: Code[20]; ItemNo: Code[20])
    var
        CNSAgreementItem: Record "CNS Agreement Item";
    begin
        CNSAgreementItem.Init();
        CNSAgreementItem."Agreement No." := AgreementNo;
        CNSAgreementItem.Validate("Item No.", ItemNo);
        CNSAgreementItem.Insert(true);
    end;

    local procedure ActivateAgreement(AgreementNo: Code[20])
    var
        CNSAgreement: Record "CNS Agreement";
        CNSAgreementMgt: Codeunit "CNS Agreement Mgt";
    begin
        CNSAgreement.Get(AgreementNo);
        CNSAgreementMgt.Activate(CNSAgreement);
    end;

    local procedure SalesAlreadyPosted(): Boolean
    var
        CustLedgerEntry: Record "Cust. Ledger Entry";
    begin
        CustLedgerEntry.SetRange("Customer No.", CustomerTok);
        exit(not CustLedgerEntry.IsEmpty());
    end;

    local procedure PostStock(PostingDate: Date)
    begin
        PostPositiveAdjustment(HandbagTok, BlackTok, 10, PostingDate);
        PostPositiveAdjustment(HandbagTok, TanTok, 10, PostingDate);
        PostPositiveAdjustment(WalletTok, '', 10, PostingDate);
        PostPositiveAdjustment(ScarfTok, RedTok, 15, PostingDate);
        PostPositiveAdjustment(ScarfTok, BlueTok, 15, PostingDate);
    end;

    local procedure PostPositiveAdjustment(ItemNo: Code[20]; VariantCode: Code[10]; Qty: Decimal; PostingDate: Date)
    var
        ItemJournalLine: Record "Item Journal Line";
        ItemJnlPostLine: Codeunit "Item Jnl.-Post Line";
    begin
        ItemJournalLine.Init();
        ItemJournalLine.Validate("Posting Date", PostingDate);
        ItemJournalLine.Validate("Entry Type", ItemJournalLine."Entry Type"::"Positive Adjmt.");
        ItemJournalLine."Document No." := StockDocTok;
        ItemJournalLine.Validate("Item No.", ItemNo);
        ItemJournalLine.Validate("Variant Code", VariantCode);
        ItemJournalLine.Validate("Location Code", GetDemoLocation());
        ItemJournalLine.Validate(Quantity, Qty);
        ItemJournalLine.Validate("Unit Amount", 0);
        ItemJnlPostLine.RunWithCheck(ItemJournalLine);
    end;

    local procedure PostSales(Month1: Date; Month2: Date)
    var
        SalesHeader: Record "Sales Header";
        TanBagInvoiceNo: Code[20];
    begin
        // Month 1, Luna: 3 black bags + 2 wallets = 5,000, then 5 tan bags = 7,500. Total 12,500.
        CreateSalesDocument(SalesHeader, SalesHeader."Document Type"::Invoice, Month1 + 4);
        AddSalesLine(SalesHeader, HandbagTok, BlackTok, 3, 1500, 0);
        AddSalesLine(SalesHeader, WalletTok, '', 2, 250, 0);
        PostSalesDocument(SalesHeader);

        CreateSalesDocument(SalesHeader, SalesHeader."Document Type"::Invoice, Month1 + 17);
        AddSalesLine(SalesHeader, HandbagTok, TanTok, 5, 1500, 0);
        TanBagInvoiceNo := PostSalesDocument(SalesHeader);

        // Month 1, Saffron: 4 red + 3 blue scarves = 1,260.
        CreateSalesDocument(SalesHeader, SalesHeader."Document Type"::Invoice, Month1 + 9);
        AddSalesLine(SalesHeader, ScarfTok, RedTok, 4, 180, 0);
        AddSalesLine(SalesHeader, ScarfTok, BlueTok, 3, 180, 0);
        PostSalesDocument(SalesHeader);

        // Month 2, Luna: 2 black bags = 3,000.
        CreateSalesDocument(SalesHeader, SalesHeader."Document Type"::Invoice, Month2 + 11);
        AddSalesLine(SalesHeader, HandbagTok, BlackTok, 2, 1500, 0);
        PostSalesDocument(SalesHeader);

        // Month 2, Saffron: 5 red scarves = 900.
        CreateSalesDocument(SalesHeader, SalesHeader."Document Type"::Invoice, Month2 + 7);
        AddSalesLine(SalesHeader, ScarfTok, RedTok, 5, 180, 0);
        PostSalesDocument(SalesHeader);

        // Month 2: one tan bag from month 1 comes back (credit memo applied to the original sale).
        CreateSalesDocument(SalesHeader, SalesHeader."Document Type"::"Credit Memo", Month2 + 19);
        AddSalesLine(SalesHeader, HandbagTok, TanTok, 1, 1500, FindSaleEntry(TanBagInvoiceNo, HandbagTok, TanTok));
        PostSalesDocument(SalesHeader);
    end;

    local procedure CreateSalesDocument(var SalesHeader: Record "Sales Header"; DocumentType: Enum "Sales Document Type"; PostingDate: Date)
    begin
        Clear(SalesHeader);
        SalesHeader.Init();
        SalesHeader."Document Type" := DocumentType;
        SalesHeader.Insert(true);
        SalesHeader.Validate("Sell-to Customer No.", CustomerTok);
        SalesHeader.Validate("Posting Date", PostingDate);
        SalesHeader.Validate("Document Date", PostingDate);
        SalesHeader.Validate("External Document No.", SalesHeader."No.");
        SalesHeader.Modify(true);
    end;

    local procedure AddSalesLine(SalesHeader: Record "Sales Header"; ItemNo: Code[20]; VariantCode: Code[10]; Qty: Decimal; UnitPrice: Decimal; ApplFromItemEntry: Integer)
    var
        SalesLine: Record "Sales Line";
        LineNo: Integer;
    begin
        SalesLine.SetRange("Document Type", SalesHeader."Document Type");
        SalesLine.SetRange("Document No.", SalesHeader."No.");
        if SalesLine.FindLast() then
            LineNo := SalesLine."Line No.";

        SalesLine.Init();
        SalesLine."Document Type" := SalesHeader."Document Type";
        SalesLine."Document No." := SalesHeader."No.";
        SalesLine."Line No." := LineNo + 10000;
        SalesLine.Insert(true);
        SalesLine.Validate(Type, SalesLine.Type::Item);
        SalesLine.Validate("No.", ItemNo);
        SalesLine.Validate("Variant Code", VariantCode);
        SalesLine.Validate("Location Code", SalesHeader."Location Code");
        SalesLine.Validate(Quantity, Qty);
        SalesLine.Validate("Unit Price", UnitPrice);
        if ApplFromItemEntry <> 0 then
            SalesLine.Validate("Appl.-from Item Entry", ApplFromItemEntry);
        SalesLine.Modify(true);
    end;

    local procedure PostSalesDocument(var SalesHeader: Record "Sales Header"): Code[20]
    var
        SalesPost: Codeunit "Sales-Post";
    begin
        if SalesHeader."Document Type" = SalesHeader."Document Type"::"Credit Memo" then
            SalesHeader.Receive := true
        else
            SalesHeader.Ship := true;
        SalesHeader.Invoice := true;
        SalesPost.Run(SalesHeader);
        exit(SalesHeader."Last Posting No.");
    end;

    local procedure FindSaleEntry(InvoiceNo: Code[20]; ItemNo: Code[20]; VariantCode: Code[10]): Integer
    var
        ItemLedgerEntry: Record "Item Ledger Entry";
        SalesInvoiceHeader: Record "Sales Invoice Header";
        ValueEntry: Record "Value Entry";
    begin
        // The item ledger entry belongs to the shipment, so go through the invoice's value entries.
        SalesInvoiceHeader.Get(InvoiceNo);
        ValueEntry.SetRange("Document No.", SalesInvoiceHeader."No.");
        ValueEntry.SetRange("Item No.", ItemNo);
        ValueEntry.SetRange("Variant Code", VariantCode);
        ValueEntry.FindFirst();
        ItemLedgerEntry.Get(ValueEntry."Item Ledger Entry No.");
        exit(ItemLedgerEntry."Entry No.");
    end;

    local procedure GetDemoLocation(): Code[10]
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
        if not Location.FindFirst() then
            Error(NoLocationErr);
        exit(Location.Code);
    end;
}
