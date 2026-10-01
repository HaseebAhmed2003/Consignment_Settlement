page 50204 "CNS Agreement Items"
{
    Caption = 'Agreement Items';
    PageType = ListPart;
    ApplicationArea = All;
    SourceTable = "CNS Agreement Item";
    DelayedInsert = true;

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field("Item No."; Rec."Item No.")
                {
                }
                field("Item Description"; Rec."Item Description")
                {
                }
            }
        }
    }
}
