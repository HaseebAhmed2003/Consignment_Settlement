table 50205 "CNS Settlement Line"
{
    Caption = 'Consignment Settlement Line';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Settlement No."; Code[20])
        {
            Caption = 'Settlement No.';
            TableRelation = "CNS Settlement Header";
        }
        field(2; "Line No."; Integer)
        {
            Caption = 'Line No.';
        }
        field(3; "Value Entry No."; Integer)
        {
            Caption = 'Value Entry No.';
            ToolTip = 'Specifies the value entry this line was taken from. An entry can only be on one settlement.';
            TableRelation = "Value Entry";
        }
        field(4; "Item No."; Code[20])
        {
            Caption = 'Item No.';
            ToolTip = 'Specifies the item sold or returned.';
            TableRelation = Item;
        }
        field(5; "Variant Code"; Code[10])
        {
            Caption = 'Variant Code';
            ToolTip = 'Specifies the item variant.';
            TableRelation = "Item Variant".Code where("Item No." = field("Item No."));
        }
        field(6; "Posting Date"; Date)
        {
            Caption = 'Posting Date';
            ToolTip = 'Specifies the posting date of the sale or return.';
        }
        field(7; "Document No."; Code[20])
        {
            Caption = 'Document No.';
            ToolTip = 'Specifies the posted sales invoice or credit memo.';
        }
        field(8; Quantity; Decimal)
        {
            Caption = 'Quantity';
            ToolTip = 'Specifies the quantity. Returns are negative.';
            DecimalPlaces = 0 : 5;
        }
        field(9; "Sales Amount"; Decimal)
        {
            Caption = 'Sales Amount';
            ToolTip = 'Specifies the sales amount from the value entry. Returns are negative.';
            AutoFormatType = 1;
        }
    }

    keys
    {
        key(PK; "Settlement No.", "Line No.")
        {
            Clustered = true;
            SumIndexFields = "Sales Amount";
        }
        key(ValueEntry; "Value Entry No.")
        {
        }
    }
}
