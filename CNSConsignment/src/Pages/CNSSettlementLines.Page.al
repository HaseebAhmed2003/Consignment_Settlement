page 50207 "CNS Settlement Lines"
{
    Caption = 'Settlement Lines';
    PageType = ListPart;
    ApplicationArea = All;
    SourceTable = "CNS Settlement Line";
    Editable = false;

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field("Posting Date"; Rec."Posting Date")
                {
                }
                field("Document No."; Rec."Document No.")
                {
                }
                field("Item No."; Rec."Item No.")
                {
                }
                field("Variant Code"; Rec."Variant Code")
                {
                }
                field(Quantity; Rec.Quantity)
                {
                }
                field("Sales Amount"; Rec."Sales Amount")
                {
                }
                field("Value Entry No."; Rec."Value Entry No.")
                {
                }
            }
        }
    }
}
