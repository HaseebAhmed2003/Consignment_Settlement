table 50201 "CNS Agreement"
{
    Caption = 'Consignment Agreement';
    DataClassification = CustomerContent;
    DrillDownPageId = "CNS Agreement List";
    LookupPageId = "CNS Agreement List";

    fields
    {
        field(1; "No."; Code[20])
        {
            Caption = 'No.';
            ToolTip = 'Specifies the agreement number.';
            NotBlank = true;
        }
        field(2; "Vendor No."; Code[20])
        {
            Caption = 'Vendor No.';
            ToolTip = 'Specifies the brand (vendor) that owns the consignment stock and receives the payout.';
            TableRelation = Vendor;

            trigger OnValidate()
            begin
                TestStatusDraft();
                CalcFields("Vendor Name");
            end;
        }
        field(3; "Vendor Name"; Text[100])
        {
            Caption = 'Vendor Name';
            ToolTip = 'Specifies the brand name.';
            FieldClass = FlowField;
            CalcFormula = lookup(Vendor.Name where("No." = field("Vendor No.")));
            Editable = false;
        }
        field(4; Description; Text[100])
        {
            Caption = 'Description';
            ToolTip = 'Specifies a short description of the agreement.';
        }
        field(5; "Start Date"; Date)
        {
            Caption = 'Start Date';
            ToolTip = 'Specifies the first day sales count towards this agreement.';

            trigger OnValidate()
            begin
                TestStatusDraft();
                CheckDates();
            end;
        }
        field(6; "End Date"; Date)
        {
            Caption = 'End Date';
            ToolTip = 'Specifies the last day sales count towards this agreement. Leave blank if the agreement has no end date. On an active agreement, use End Agreement instead.';

            trigger OnValidate()
            begin
                TestStatusDraft();
                CheckDates();
            end;
        }
        field(7; Status; Enum "CNS Agreement Status")
        {
            Caption = 'Status';
            ToolTip = 'Specifies whether the agreement is a draft, active or ended. Use the Activate and End Agreement actions to change it.';
            Editable = false;
        }
    }

    keys
    {
        key(PK; "No.")
        {
            Clustered = true;
        }
        key(Vendor; "Vendor No.", "Start Date")
        {
        }
    }

    fieldgroups
    {
        fieldgroup(DropDown; "No.", "Vendor No.", Description, Status)
        {
        }
    }

    var
        EndBeforeStartErr: Label 'The end date must be after the start date.';

    trigger OnDelete()
    var
        CNSCommissionTier: Record "CNS Commission Tier";
        CNSAgreementItem: Record "CNS Agreement Item";
    begin
        TestStatusDraft();
        CNSCommissionTier.SetRange("Agreement No.", "No.");
        CNSCommissionTier.DeleteAll();
        CNSAgreementItem.SetRange("Agreement No.", "No.");
        CNSAgreementItem.DeleteAll();
    end;

    procedure TestStatusDraft()
    begin
        TestField(Status, Status::Draft);
    end;

    local procedure CheckDates()
    begin
        if ("Start Date" <> 0D) and ("End Date" <> 0D) and ("End Date" <= "Start Date") then
            Error(EndBeforeStartErr);
    end;
}
