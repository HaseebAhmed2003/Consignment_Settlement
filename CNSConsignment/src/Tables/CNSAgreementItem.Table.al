table 50203 "CNS Agreement Item"
{
    Caption = 'Consignment Agreement Item';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Agreement No."; Code[20])
        {
            Caption = 'Agreement No.';
            TableRelation = "CNS Agreement";
        }
        field(2; "Item No."; Code[20])
        {
            Caption = 'Item No.';
            ToolTip = 'Specifies an item sold on consignment under this agreement. All variants of the item are included.';
            TableRelation = Item;
            NotBlank = true;
        }
        field(3; "Item Description"; Text[100])
        {
            Caption = 'Item Description';
            ToolTip = 'Specifies the item description.';
            FieldClass = FlowField;
            CalcFormula = lookup(Item.Description where("No." = field("Item No.")));
            Editable = false;
        }
    }

    keys
    {
        key(PK; "Agreement No.", "Item No.")
        {
            Clustered = true;
        }
        key(Item; "Item No.")
        {
        }
    }

    trigger OnInsert()
    begin
        TestAgreementDraft();
    end;

    trigger OnModify()
    begin
        TestAgreementDraft();
    end;

    trigger OnDelete()
    begin
        TestAgreementDraft();
    end;

    trigger OnRename()
    begin
        TestAgreementDraft();
    end;

    local procedure TestAgreementDraft()
    var
        CNSAgreement: Record "CNS Agreement";
    begin
        CNSAgreement.Get("Agreement No.");
        CNSAgreement.TestStatusDraft();
    end;
}
