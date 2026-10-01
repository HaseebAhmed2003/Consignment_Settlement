page 50205 "CNS Settlement List"
{
    Caption = 'Consignment Settlements';
    PageType = List;
    ApplicationArea = All;
    UsageCategory = Lists;
    SourceTable = "CNS Settlement Header";
    CardPageId = "CNS Settlement Card";
    Editable = false;
    InsertAllowed = false;

    layout
    {
        area(Content)
        {
            repeater(Settlements)
            {
                field("No."; Rec."No.")
                {
                }
                field("Agreement No."; Rec."Agreement No.")
                {
                }
                field("Vendor No."; Rec."Vendor No.")
                {
                }
                field("Vendor Name"; Rec."Vendor Name")
                {
                }
                field("Period Start"; Rec."Period Start")
                {
                }
                field("Period End"; Rec."Period End")
                {
                }
                field(Status; Rec.Status)
                {
                }
                field("Net Sales"; Rec."Net Sales")
                {
                }
                field("Commission Amount"; Rec."Commission Amount")
                {
                }
                field("Payout Amount"; Rec."Payout Amount")
                {
                }
                field("Posted Invoice No."; Rec."Posted Invoice No.")
                {
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(CreateSettlement)
            {
                Caption = 'Create Settlement';
                ToolTip = 'Creates a draft settlement for one agreement and month.';
                Image = NewDocument;

                trigger OnAction()
                var
                    CNSCreateSettlement: Page "CNS Create Settlement";
                begin
                    CNSCreateSettlement.RunModal();
                    CurrPage.Update(false);
                end;
            }
            action(CreateDrafts)
            {
                Caption = 'Create Drafts for Last Month';
                ToolTip = 'Creates draft settlements for the month before the work date for every active agreement that doesn''t have one yet. The same thing the monthly job queue entry does.';
                Image = CreateDocuments;

                trigger OnAction()
                var
                    CNSCreateDraftSettlements: Codeunit "CNS Create Draft Settlements";
                begin
                    CNSCreateDraftSettlements.CreateForPreviousMonthWithMessage(WorkDate());
                    CurrPage.Update(false);
                end;
            }
        }
        area(Promoted)
        {
            actionref(CreateSettlement_Promoted; CreateSettlement)
            {
            }
            actionref(CreateDrafts_Promoted; CreateDrafts)
            {
            }
        }
    }
}
