page 50201 "CNS Agreement List"
{
    Caption = 'Consignment Agreements';
    PageType = List;
    ApplicationArea = All;
    UsageCategory = Lists;
    SourceTable = "CNS Agreement";
    CardPageId = "CNS Agreement Card";
    Editable = false;

    layout
    {
        area(Content)
        {
            repeater(Agreements)
            {
                field("No."; Rec."No.")
                {
                }
                field("Vendor No."; Rec."Vendor No.")
                {
                }
                field("Vendor Name"; Rec."Vendor Name")
                {
                }
                field(Description; Rec.Description)
                {
                }
                field("Start Date"; Rec."Start Date")
                {
                }
                field("End Date"; Rec."End Date")
                {
                }
                field(Status; Rec.Status)
                {
                }
            }
        }
    }

    actions
    {
        area(Navigation)
        {
            action(Settlements)
            {
                Caption = 'Settlements';
                ToolTip = 'Shows the settlements for this agreement.';
                Image = Payment;
                RunObject = page "CNS Settlement List";
                RunPageLink = "Agreement No." = field("No.");
            }
        }
    }
}
