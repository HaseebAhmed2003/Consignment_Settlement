page 50200 "CNS Setup"
{
    Caption = 'Consignment Setup';
    PageType = Card;
    ApplicationArea = All;
    UsageCategory = Administration;
    SourceTable = "CNS Setup";
    InsertAllowed = false;
    DeleteAllowed = false;

    layout
    {
        area(Content)
        {
            group(General)
            {
                Caption = 'General';

                field("Settlement Nos."; Rec."Settlement Nos.")
                {
                }
                field("Payout G/L Account No."; Rec."Payout G/L Account No.")
                {
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(CreateDemoData)
            {
                Caption = 'Create Demo Data';
                ToolTip = 'Creates two demo brands with agreements, items with variants, stock and two months of posted sales, including one return. Safe to run again.';
                Image = CreateDocuments;

                trigger OnAction()
                var
                    CNSDemoData: Codeunit "CNS Demo Data";
                begin
                    CNSDemoData.CreateDemoData();
                end;
            }
            action(ResetDemoData)
            {
                Caption = 'Reset Demo Data';
                ToolTip = 'Deletes all agreements, settlements and approval entries, then creates the demo agreements again. Posted sales and invoices are not touched.';
                Image = Restore;

                trigger OnAction()
                var
                    CNSDemoData: Codeunit "CNS Demo Data";
                begin
                    CNSDemoData.ResetAndCreateDemoData();
                end;
            }
        }
        area(Promoted)
        {
            actionref(CreateDemoData_Promoted; CreateDemoData)
            {
            }
            actionref(ResetDemoData_Promoted; ResetDemoData)
            {
            }
        }
    }

    trigger OnOpenPage()
    var
        CNSSettlementMgt: Codeunit "CNS Settlement Mgt";
    begin
        if not Rec.Get() then begin
            CNSSettlementMgt.EnsureSetup();
            Rec.Get();
        end;
    end;
}
