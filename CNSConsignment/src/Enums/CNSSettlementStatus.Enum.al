enum 50201 "CNS Settlement Status"
{
    Extensible = false;
    Caption = 'Settlement Status';

    value(0; Draft)
    {
        Caption = 'Draft';
    }
    value(1; Calculated)
    {
        Caption = 'Calculated';
    }
    value(2; Approved)
    {
        Caption = 'Approved';
    }
    value(3; Posted)
    {
        Caption = 'Posted';
    }
}
