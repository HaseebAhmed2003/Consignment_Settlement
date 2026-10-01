table 50200 "CNS Setup"
{
    Caption = 'Consignment Setup';
    DataClassification = CustomerContent;
    DrillDownPageId = "CNS Setup";
    LookupPageId = "CNS Setup";

    fields
    {
        field(1; "Primary Key"; Code[10])
        {
            Caption = 'Primary Key';
            DataClassification = SystemMetadata;
            AllowInCustomizations = Never;
        }
        field(2; "Settlement Nos."; Code[20])
        {
            Caption = 'Settlement Nos.';
            ToolTip = 'Specifies the number series for consignment settlements.';
            TableRelation = "No. Series";
        }
        field(3; "Payout G/L Account No."; Code[20])
        {
            Caption = 'Payout G/L Account No.';
            ToolTip = 'Specifies the G/L account used on the payout purchase invoice to the brand.';
            TableRelation = "G/L Account" where("Account Type" = const(Posting), Blocked = const(false));
        }
    }

    keys
    {
        key(PK; "Primary Key")
        {
            Clustered = true;
        }
    }
}
