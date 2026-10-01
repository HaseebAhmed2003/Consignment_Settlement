page 50203 "CNS Commission Tiers"
{
    Caption = 'Commission Tiers';
    PageType = ListPart;
    ApplicationArea = All;
    SourceTable = "CNS Commission Tier";
    SourceTableView = sorting("Agreement No.", "From Amount");
    DelayedInsert = true;

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field("From Amount"; Rec."From Amount")
                {
                }
                field("Commission %"; Rec."Commission %")
                {
                }
            }
        }
    }
}
