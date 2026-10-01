page 50208 "CNS Approval Entries"
{
    Caption = 'Consignment Approval Entries';
    PageType = List;
    ApplicationArea = All;
    UsageCategory = History;
    SourceTable = "CNS Approval Entry";
    Editable = false;

    layout
    {
        area(Content)
        {
            repeater(Entries)
            {
                field("Entry No."; Rec."Entry No.")
                {
                }
                field("Settlement No."; Rec."Settlement No.")
                {
                }
                field(Action; Rec.Action)
                {
                }
                field("User ID"; Rec."User ID")
                {
                }
                field("Date-Time"; Rec."Date-Time")
                {
                }
                field("Payout Amount"; Rec."Payout Amount")
                {
                }
            }
        }
    }
}
