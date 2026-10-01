page 50206 "CNS Settlement Card"
{
    Caption = 'Consignment Settlement';
    PageType = Document;
    ApplicationArea = All;
    UsageCategory = None;
    SourceTable = "CNS Settlement Header";
    InsertAllowed = false;
    Editable = false;

    layout
    {
        area(Content)
        {
            group(General)
            {
                Caption = 'General';

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
                    StyleExpr = StatusStyle;
                }
            }
            group(Amounts)
            {
                Caption = 'Amounts';

                field("Gross Sales"; Rec."Gross Sales")
                {
                }
                field(Returns; Rec.Returns)
                {
                }
                field("Net Sales"; Rec."Net Sales")
                {
                    Style = Strong;
                }
                field("Commission Amount"; Rec."Commission Amount")
                {
                }
                field("Payout Amount"; Rec."Payout Amount")
                {
                    Style = Strong;
                }
                field("No. of Lines"; Rec."No. of Lines")
                {
                }
            }
            part(Lines; "CNS Settlement Lines")
            {
                Caption = 'Lines';
                SubPageLink = "Settlement No." = field("No.");
            }
            group(Workflow)
            {
                Caption = 'Calculation and Approval';

                field("Calculated By"; Rec."Calculated By")
                {
                }
                field("Calculated At"; Rec."Calculated At")
                {
                }
                field("Approved By"; Rec."Approved By")
                {
                }
                field("Approved At"; Rec."Approved At")
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
            action(Calculate)
            {
                Caption = 'Calculate';
                ToolTip = 'Collects the posted sales and returns for the agreement items and calculates commission and payout. Can be repeated until the settlement is approved.';
                Image = Calculate;

                trigger OnAction()
                var
                    CNSSettlementMgt: Codeunit "CNS Settlement Mgt";
                begin
                    CNSSettlementMgt.Calculate(Rec);
                    CurrPage.Update(false);
                end;
            }
            action(Approve)
            {
                Caption = 'Approve';
                ToolTip = 'Approves the calculated settlement. The user who calculated it can''t approve it.';
                Image = Approve;

                trigger OnAction()
                var
                    CNSSettlementMgt: Codeunit "CNS Settlement Mgt";
                begin
                    CNSSettlementMgt.ApproveWithMessage(Rec);
                    CurrPage.Update(false);
                end;
            }
            action(Post)
            {
                Caption = 'Post Payout';
                ToolTip = 'Posts a purchase invoice to the brand for the payout amount. The settlement is locked afterwards.';
                Image = Post;

                trigger OnAction()
                var
                    CNSSettlementMgt: Codeunit "CNS Settlement Mgt";
                begin
                    CNSSettlementMgt.PostWithConfirm(Rec);
                    CurrPage.Update(false);
                end;
            }
            action(Statement)
            {
                Caption = 'Settlement Statement';
                ToolTip = 'Prints the statement for the brand: sales, returns, commission per tier and payout.';
                Image = PrintReport;

                trigger OnAction()
                var
                    CNSSettlementHeader: Record "CNS Settlement Header";
                begin
                    CNSSettlementHeader.SetRange("No.", Rec."No.");
                    Report.Run(Report::"CNS Settlement Statement", true, false, CNSSettlementHeader);
                end;
            }
        }
        area(Navigation)
        {
            action(ApprovalEntries)
            {
                Caption = 'Approval Entries';
                ToolTip = 'Shows who approved and posted this settlement.';
                Image = Approvals;
                RunObject = page "CNS Approval Entries";
                RunPageLink = "Settlement No." = field("No.");
            }
            action(PostedInvoice)
            {
                Caption = 'Posted Invoice';
                ToolTip = 'Opens the posted payout invoice.';
                Image = PostedOrder;
                RunObject = page "Posted Purchase Invoice";
                RunPageLink = "No." = field("Posted Invoice No.");
            }
            action(Agreement)
            {
                Caption = 'Agreement';
                ToolTip = 'Opens the consignment agreement.';
                Image = Agreement;
                RunObject = page "CNS Agreement Card";
                RunPageLink = "No." = field("Agreement No.");
            }
        }
        area(Promoted)
        {
            group(Category_Process)
            {
                Caption = 'Process';

                actionref(Calculate_Promoted; Calculate)
                {
                }
                actionref(Approve_Promoted; Approve)
                {
                }
                actionref(Post_Promoted; Post)
                {
                }
            }
            group(Category_Report)
            {
                Caption = 'Report';

                actionref(Statement_Promoted; Statement)
                {
                }
            }
            group(Category_Navigate)
            {
                Caption = 'Related';

                actionref(ApprovalEntries_Promoted; ApprovalEntries)
                {
                }
                actionref(PostedInvoice_Promoted; PostedInvoice)
                {
                }
            }
        }
    }

    var
        StatusStyle: Text;

    trigger OnAfterGetRecord()
    begin
        case Rec.Status of
            Rec.Status::Approved:
                StatusStyle := 'Favorable';
            Rec.Status::Posted:
                StatusStyle := 'Subordinate';
            else
                StatusStyle := 'Standard';
        end;
    end;
}
