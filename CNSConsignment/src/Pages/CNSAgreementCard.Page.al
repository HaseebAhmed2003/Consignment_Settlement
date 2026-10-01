page 50202 "CNS Agreement Card"
{
    Caption = 'Consignment Agreement';
    PageType = Card;
    ApplicationArea = All;
    UsageCategory = None;
    SourceTable = "CNS Agreement";

    layout
    {
        area(Content)
        {
            group(General)
            {
                Caption = 'General';
                Editable = IsDraft;

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
            part(Tiers; "CNS Commission Tiers")
            {
                Caption = 'Commission Tiers';
                SubPageLink = "Agreement No." = field("No.");
                Editable = IsDraft;
            }
            part(Items; "CNS Agreement Items")
            {
                Caption = 'Items';
                SubPageLink = "Agreement No." = field("No.");
                Editable = IsDraft;
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(Activate)
            {
                Caption = 'Activate';
                ToolTip = 'Checks the tiers and items and makes the agreement active. Tiers and items are locked after this.';
                Image = ReleaseDoc;
                Enabled = IsDraft;

                trigger OnAction()
                var
                    CNSAgreementMgt: Codeunit "CNS Agreement Mgt";
                begin
                    CNSAgreementMgt.ActivateWithConfirm(Rec);
                    CurrPage.Update(false);
                end;
            }
            action(EndAgreement)
            {
                Caption = 'End Agreement';
                ToolTip = 'Ends the agreement on the work date (or on its end date, if that is earlier). Sales after the end date are no longer settled.';
                Image = Stop;
                Enabled = IsActive;

                trigger OnAction()
                var
                    CNSAgreementMgt: Codeunit "CNS Agreement Mgt";
                begin
                    CNSAgreementMgt.EndAgreementWithConfirm(Rec, WorkDate());
                    CurrPage.Update(false);
                end;
            }
            action(CreateSettlement)
            {
                Caption = 'Create Settlement';
                ToolTip = 'Creates a draft settlement for this agreement for a month you choose.';
                Image = NewDocument;
                Enabled = IsActive;

                trigger OnAction()
                var
                    CNSCreateSettlement: Page "CNS Create Settlement";
                begin
                    CNSCreateSettlement.SetAgreement(Rec."No.");
                    CNSCreateSettlement.RunModal();
                end;
            }
        }
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
        area(Promoted)
        {
            group(Category_Process)
            {
                Caption = 'Process';

                actionref(Activate_Promoted; Activate)
                {
                }
                actionref(EndAgreement_Promoted; EndAgreement)
                {
                }
                actionref(CreateSettlement_Promoted; CreateSettlement)
                {
                }
                actionref(Settlements_Promoted; Settlements)
                {
                }
            }
        }
    }

    var
        IsDraft: Boolean;
        IsActive: Boolean;

    trigger OnAfterGetCurrRecord()
    begin
        IsDraft := Rec.Status = Rec.Status::Draft;
        IsActive := Rec.Status = Rec.Status::Active;
    end;

    trigger OnNewRecord(BelowxRec: Boolean)
    begin
        IsDraft := true;
        IsActive := false;
    end;
}
