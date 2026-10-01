codeunit 50203 "CNS Settlement Post"
{
    Access = Public;
    Permissions = tabledata "CNS Settlement Header" = rm,
                  tabledata "CNS Approval Entry" = ri;

    var
        NotApprovedErr: Label 'Settlement %1 is %2. Only Approved settlements can be posted.', Comment = '%1 = settlement no., %2 = status';

    /// <summary>
    /// Posts the payout as a purchase invoice to the brand and marks the settlement Posted.
    /// Everything runs in one transaction: if posting fails, nothing is saved.
    /// </summary>
    procedure PostSettlement(var Settlement: Record "CNS Settlement Header")
    var
        Setup: Record "CNS Setup";
        PurchHeader: Record "Purchase Header";
        PurchLine: Record "Purchase Line";
        PurchInvHeader: Record "Purch. Inv. Header";
        CNSSettlementMgt: Codeunit "CNS Settlement Mgt";
        PurchPost: Codeunit "Purch.-Post";
    begin
        Settlement.LockTable();
        Settlement.Get(Settlement."No.");
        if Settlement.Status <> Settlement.Status::Approved then
            Error(NotApprovedErr, Settlement."No.", Settlement.Status);
        CNSSettlementMgt.CheckPayout(Settlement);
        Setup.Get();
        Setup.TestField("Payout G/L Account No.");

        PurchHeader.Init();
        PurchHeader."Document Type" := PurchHeader."Document Type"::Invoice;
        PurchHeader.Insert(true);
        PurchHeader.Validate("Buy-from Vendor No.", Settlement."Vendor No.");
        PurchHeader.Validate("Posting Date", Settlement."Period End");
        // BC refuses a second invoice with the same vendor invoice no., which also guards against paying twice.
        PurchHeader.Validate("Vendor Invoice No.", Settlement."No.");
        PurchHeader.Modify(true);

        PurchLine.Init();
        PurchLine."Document Type" := PurchHeader."Document Type";
        PurchLine."Document No." := PurchHeader."No.";
        PurchLine."Line No." := 10000;
        PurchLine.Insert(true);
        PurchLine.Validate(Type, PurchLine.Type::"G/L Account");
        PurchLine.Validate("No.", Setup."Payout G/L Account No.");
        PurchLine.Validate(Quantity, 1);
        PurchLine.Validate("Direct Unit Cost", Settlement."Payout Amount");
        PurchLine.Modify(true);

        PurchHeader.Invoice := true;
        PurchPost.SetSuppressCommit(true);
        PurchPost.Run(PurchHeader);

        PurchInvHeader.SetRange("Pre-Assigned No.", PurchHeader."No.");
        PurchInvHeader.FindFirst();

        CNSSettlementMgt.InsertApprovalEntry(Settlement, "CNS Approval Action"::Posted);
        Settlement."Posted Invoice No." := PurchInvHeader."No.";
        Settlement.Status := Settlement.Status::Posted;
        Settlement.Modify(true);
    end;
}
