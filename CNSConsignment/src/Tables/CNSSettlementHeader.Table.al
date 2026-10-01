table 50204 "CNS Settlement Header"
{
    Caption = 'Consignment Settlement';
    DataClassification = CustomerContent;
    DrillDownPageId = "CNS Settlement List";
    LookupPageId = "CNS Settlement List";
    // OnDelete removes the lines, which users only hold indirectly.
    Permissions = tabledata "CNS Settlement Line" = rd;

    fields
    {
        field(1; "No."; Code[20])
        {
            Caption = 'No.';
            ToolTip = 'Specifies the settlement number. It is also used as the vendor invoice number on the payout invoice.';
        }
        field(2; "Agreement No."; Code[20])
        {
            Caption = 'Agreement No.';
            ToolTip = 'Specifies the consignment agreement being settled.';
            TableRelation = "CNS Agreement";
        }
        field(3; "Vendor No."; Code[20])
        {
            Caption = 'Vendor No.';
            ToolTip = 'Specifies the brand (vendor) that receives the payout.';
            TableRelation = Vendor;
        }
        field(4; "Vendor Name"; Text[100])
        {
            Caption = 'Vendor Name';
            ToolTip = 'Specifies the brand name.';
            FieldClass = FlowField;
            CalcFormula = lookup(Vendor.Name where("No." = field("Vendor No.")));
            Editable = false;
        }
        field(5; "Period Start"; Date)
        {
            Caption = 'Period Start';
            ToolTip = 'Specifies the first day of the settlement month.';
        }
        field(6; "Period End"; Date)
        {
            Caption = 'Period End';
            ToolTip = 'Specifies the last day of the settlement month. The payout invoice is posted on this date.';
        }
        field(7; Status; Enum "CNS Settlement Status")
        {
            Caption = 'Status';
            ToolTip = 'Specifies where the settlement is in the Draft, Calculated, Approved, Posted workflow.';
        }
        field(10; "Gross Sales"; Decimal)
        {
            Caption = 'Gross Sales';
            ToolTip = 'Specifies the total of the sales lines (positive sales amounts).';
            AutoFormatType = 1;
        }
        field(11; Returns; Decimal)
        {
            Caption = 'Returns';
            ToolTip = 'Specifies the total of the returned sales, shown as a positive amount.';
            AutoFormatType = 1;
        }
        field(12; "Net Sales"; Decimal)
        {
            Caption = 'Net Sales';
            ToolTip = 'Specifies gross sales minus returns. Commission is calculated on this amount.';
            AutoFormatType = 1;
        }
        field(13; "Commission Amount"; Decimal)
        {
            Caption = 'Commission Amount';
            ToolTip = 'Specifies the commission the store keeps, calculated with the agreement''s tiers.';
            AutoFormatType = 1;
        }
        field(14; "Payout Amount"; Decimal)
        {
            Caption = 'Payout Amount';
            ToolTip = 'Specifies the amount paid to the brand: net sales minus commission.';
            AutoFormatType = 1;
        }
        field(20; "Calculated By"; Code[50])
        {
            Caption = 'Calculated By';
            ToolTip = 'Specifies the user who last calculated the settlement.';
            DataClassification = EndUserIdentifiableInformation;
        }
        field(21; "Calculated At"; DateTime)
        {
            Caption = 'Calculated At';
            ToolTip = 'Specifies when the settlement was last calculated.';
        }
        field(22; "Approved By"; Code[50])
        {
            Caption = 'Approved By';
            ToolTip = 'Specifies the user who approved the settlement.';
            DataClassification = EndUserIdentifiableInformation;
        }
        field(23; "Approved At"; DateTime)
        {
            Caption = 'Approved At';
            ToolTip = 'Specifies when the settlement was approved.';
        }
        field(30; "Posted Invoice No."; Code[20])
        {
            Caption = 'Posted Invoice No.';
            ToolTip = 'Specifies the posted purchase invoice that paid out this settlement.';
            TableRelation = "Purch. Inv. Header";
        }
        field(31; "No. of Lines"; Integer)
        {
            Caption = 'No. of Lines';
            ToolTip = 'Specifies how many value entries are included in the settlement.';
            FieldClass = FlowField;
            CalcFormula = count("CNS Settlement Line" where("Settlement No." = field("No.")));
            Editable = false;
        }
    }

    keys
    {
        key(PK; "No.")
        {
            Clustered = true;
        }
        key(AgreementPeriod; "Agreement No.", "Period Start")
        {
        }
    }

    var
        PostedLockedErr: Label 'Settlement %1 is posted and can no longer be changed.', Comment = '%1 = settlement no.';
        CannotRenameErr: Label 'Settlements cannot be renamed.';
        CannotDeleteErr: Label 'Settlement %1 is %2. Only Draft or Calculated settlements can be deleted.', Comment = '%1 = settlement no., %2 = status';

    trigger OnModify()
    var
        StoredSettlement: Record "CNS Settlement Header";
    begin
        // Check the stored record: xRec isn't reliable when the change comes from code.
        if StoredSettlement.Get("No.") then
            if StoredSettlement.Status = StoredSettlement.Status::Posted then
                Error(PostedLockedErr, "No.");
    end;

    trigger OnDelete()
    var
        StoredSettlement: Record "CNS Settlement Header";
        CNSSettlementLine: Record "CNS Settlement Line";
    begin
        if StoredSettlement.Get("No.") then
            if not (StoredSettlement.Status in [StoredSettlement.Status::Draft, StoredSettlement.Status::Calculated]) then
                Error(CannotDeleteErr, "No.", StoredSettlement.Status);
        CNSSettlementLine.SetRange("Settlement No.", "No.");
        CNSSettlementLine.DeleteAll();
    end;

    trigger OnRename()
    begin
        Error(CannotRenameErr);
    end;
}
