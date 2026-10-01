table 50206 "CNS Approval Entry"
{
    Caption = 'Consignment Approval Entry';
    DataClassification = CustomerContent;
    DrillDownPageId = "CNS Approval Entries";
    LookupPageId = "CNS Approval Entries";

    fields
    {
        field(1; "Entry No."; Integer)
        {
            Caption = 'Entry No.';
            ToolTip = 'Specifies the entry number.';
            AutoIncrement = true;
        }
        field(2; "Settlement No."; Code[20])
        {
            Caption = 'Settlement No.';
            ToolTip = 'Specifies the settlement.';
            TableRelation = "CNS Settlement Header";
        }
        field(3; "Action"; Enum "CNS Approval Action")
        {
            Caption = 'Action';
            ToolTip = 'Specifies what was done: approved or posted.';
        }
        field(4; "User ID"; Code[50])
        {
            Caption = 'User ID';
            ToolTip = 'Specifies the user who did it.';
            DataClassification = EndUserIdentifiableInformation;
        }
        field(5; "Date-Time"; DateTime)
        {
            Caption = 'Date-Time';
            ToolTip = 'Specifies when it was done.';
        }
        field(6; "Payout Amount"; Decimal)
        {
            Caption = 'Payout Amount';
            ToolTip = 'Specifies the payout amount at that moment.';
            AutoFormatType = 1;
        }
    }

    keys
    {
        key(PK; "Entry No.")
        {
            Clustered = true;
        }
        key(Settlement; "Settlement No.")
        {
        }
    }
}
