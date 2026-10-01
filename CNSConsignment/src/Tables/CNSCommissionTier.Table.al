table 50202 "CNS Commission Tier"
{
    Caption = 'Consignment Commission Tier';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Agreement No."; Code[20])
        {
            Caption = 'Agreement No.';
            TableRelation = "CNS Agreement";
        }
        field(2; "Line No."; Integer)
        {
            Caption = 'Line No.';
        }
        field(3; "From Amount"; Decimal)
        {
            Caption = 'From Amount';
            ToolTip = 'Specifies the net sales amount where this tier starts. The rate applies to the part of net sales from this amount up to the next tier.';
            MinValue = 0;
            AutoFormatType = 1;

            trigger OnValidate()
            begin
                if "From Amount" < 0 then
                    Error(NegativeFromAmountErr);
                CheckDuplicateFromAmount();
            end;
        }
        field(4; "Commission %"; Decimal)
        {
            Caption = 'Commission %';
            ToolTip = 'Specifies the commission rate the store keeps for net sales inside this tier.';
            MinValue = 0;
            MaxValue = 100;
            DecimalPlaces = 0 : 2;

            trigger OnValidate()
            begin
                // MinValue/MaxValue only stop typing on the page, so code paths are checked here too.
                if ("Commission %" < 0) or ("Commission %" > 100) then
                    Error(CommissionPctRangeErr);
            end;
        }
    }

    keys
    {
        key(PK; "Agreement No.", "Line No.")
        {
            Clustered = true;
        }
        key(FromAmount; "Agreement No.", "From Amount")
        {
        }
    }

    var
        CommissionPctRangeErr: Label 'The commission % must be between 0 and 100.';
        NegativeFromAmountErr: Label 'The from amount can''t be negative.';
        DuplicateFromAmountErr: Label 'Another tier on agreement %1 already starts at %2.', Comment = '%1 = agreement no., %2 = from amount';

    trigger OnInsert()
    var
        LastTier: Record "CNS Commission Tier";
    begin
        TestAgreementDraft();
        // The subpage is sorted by From Amount, so line numbers are given here instead of AutoSplitKey.
        if "Line No." = 0 then begin
            LastTier.SetRange("Agreement No.", "Agreement No.");
            if LastTier.FindLast() then;
            "Line No." := LastTier."Line No." + 10000;
        end;
    end;

    trigger OnModify()
    begin
        TestAgreementDraft();
    end;

    trigger OnDelete()
    begin
        TestAgreementDraft();
    end;

    trigger OnRename()
    begin
        TestAgreementDraft();
    end;

    local procedure TestAgreementDraft()
    var
        CNSAgreement: Record "CNS Agreement";
    begin
        CNSAgreement.Get("Agreement No.");
        CNSAgreement.TestStatusDraft();
    end;

    local procedure CheckDuplicateFromAmount()
    var
        CNSCommissionTier: Record "CNS Commission Tier";
    begin
        CNSCommissionTier.SetRange("Agreement No.", "Agreement No.");
        CNSCommissionTier.SetRange("From Amount", "From Amount");
        CNSCommissionTier.SetFilter("Line No.", '<>%1', "Line No.");
        if not CNSCommissionTier.IsEmpty() then
            Error(DuplicateFromAmountErr, "Agreement No.", "From Amount");
    end;
}
