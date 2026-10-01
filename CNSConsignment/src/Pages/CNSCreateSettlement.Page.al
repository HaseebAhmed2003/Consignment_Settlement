page 50209 "CNS Create Settlement"
{
    Caption = 'Create Settlement';
    PageType = StandardDialog;
    ApplicationArea = All;

    layout
    {
        area(Content)
        {
            field(AgreementNo; AgreementNo)
            {
                Caption = 'Agreement No.';
                ToolTip = 'Specifies the active agreement to settle.';
                TableRelation = "CNS Agreement" where(Status = const(Active));
            }
            field(PeriodDate; PeriodDate)
            {
                Caption = 'Month';
                ToolTip = 'Specifies any date in the month to settle. The settlement covers the whole calendar month.';
            }
        }
    }

    var
        AgreementNo: Code[20];
        PeriodDate: Date;

    trigger OnOpenPage()
    begin
        if PeriodDate = 0D then
            PeriodDate := CalcDate('<-CM-1M>', WorkDate());
    end;

    trigger OnQueryClosePage(CloseAction: Action): Boolean
    var
        CNSSettlementMgt: Codeunit "CNS Settlement Mgt";
    begin
        if CloseAction <> Action::OK then
            exit(true);
        CNSSettlementMgt.CreateSettlementWithMessage(AgreementNo, PeriodDate);
        exit(true);
    end;

    procedure SetAgreement(NewAgreementNo: Code[20])
    begin
        AgreementNo := NewAgreementNo;
    end;
}
