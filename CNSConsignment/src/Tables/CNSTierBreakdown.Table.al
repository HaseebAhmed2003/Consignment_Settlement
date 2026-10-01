table 50207 "CNS Tier Breakdown"
{
    Caption = 'Consignment Tier Breakdown';
    TableType = Temporary;
    DataClassification = SystemMetadata;

    fields
    {
        field(1; "Line No."; Integer)
        {
            Caption = 'Line No.';
        }
        field(2; "From Amount"; Decimal)
        {
            Caption = 'From Amount';
            AutoFormatType = 1;
        }
        field(3; "To Amount"; Decimal)
        {
            Caption = 'To Amount';
            AutoFormatType = 1;
        }
        field(4; "Commission %"; Decimal)
        {
            Caption = 'Commission %';
            DecimalPlaces = 0 : 2;
        }
        field(5; "Amount in Tier"; Decimal)
        {
            Caption = 'Amount in Tier';
            AutoFormatType = 1;
        }
        field(6; "Commission Amount"; Decimal)
        {
            Caption = 'Commission Amount';
            AutoFormatType = 1;
        }
    }

    keys
    {
        key(PK; "Line No.")
        {
            Clustered = true;
        }
    }
}
