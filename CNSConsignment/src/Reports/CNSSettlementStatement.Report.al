report 50200 "CNS Settlement Statement"
{
    Caption = 'Consignment Settlement Statement';
    ApplicationArea = All;
    UsageCategory = ReportsAndAnalysis;
    DefaultRenderingLayout = StatementWord;

    dataset
    {
        dataitem(Settlement; "CNS Settlement Header")
        {
            RequestFilterFields = "No.", "Agreement No.", "Period Start";
            column(CompanyName; CompanyProperty.DisplayName())
            {
            }
            column(SettlementNo; "No.")
            {
                IncludeCaption = true;
            }
            column(AgreementNo; "Agreement No.")
            {
                IncludeCaption = true;
            }
            column(VendorNo; "Vendor No.")
            {
                IncludeCaption = true;
            }
            column(VendorName; VendorName)
            {
            }
            column(PeriodStart; Format("Period Start"))
            {
            }
            column(PeriodEnd; Format("Period End"))
            {
            }
            column(Status; Format(Status))
            {
            }
            column(GrossSales; FormatAmount("Gross Sales"))
            {
            }
            column(Returns; FormatAmount(Returns))
            {
            }
            column(NetSales; FormatAmount("Net Sales"))
            {
            }
            column(CommissionAmount; FormatAmount("Commission Amount"))
            {
            }
            column(PayoutAmount; FormatAmount("Payout Amount"))
            {
            }
            column(ApprovedBy; "Approved By")
            {
            }
            column(PostedInvoiceNo; "Posted Invoice No.")
            {
            }
            dataitem(Tier; Integer)
            {
                DataItemTableView = sorting(Number);
                column(TierFrom; FormatAmount(TempCNSTierBreakdown."From Amount"))
                {
                }
                column(TierTo; TierToText)
                {
                }
                column(TierRate; Format(TempCNSTierBreakdown."Commission %") + ' %')
                {
                }
                column(TierAmount; FormatAmount(TempCNSTierBreakdown."Amount in Tier"))
                {
                }
                column(TierCommission; FormatAmount(TempCNSTierBreakdown."Commission Amount"))
                {
                }

                trigger OnPreDataItem()
                begin
                    SetRange(Number, 1, TempCNSTierBreakdown.Count());
                end;

                trigger OnAfterGetRecord()
                begin
                    if Number = 1 then
                        TempCNSTierBreakdown.FindSet()
                    else
                        TempCNSTierBreakdown.Next();
                    if TempCNSTierBreakdown."To Amount" = 0 then
                        TierToText := AndAboveLbl
                    else
                        TierToText := FormatAmount(TempCNSTierBreakdown."To Amount");
                end;
            }
            dataitem(Line; "CNS Settlement Line")
            {
                DataItemLink = "Settlement No." = field("No.");
                DataItemTableView = sorting("Settlement No.", "Line No.");
                column(LinePostingDate; Format("Posting Date"))
                {
                }
                column(LineDocumentNo; "Document No.")
                {
                }
                column(LineItemNo; "Item No.")
                {
                }
                column(LineVariantCode; "Variant Code")
                {
                }
                column(LineQuantity; Format(Quantity))
                {
                }
                column(LineSalesAmount; FormatAmount("Sales Amount"))
                {
                }
            }

            trigger OnPreDataItem()
            begin
                // The Word layout shows one settlement per document.
                if Count() > 1 then
                    Error(OneSettlementErr);
            end;

            trigger OnAfterGetRecord()
            var
                Vendor: Record Vendor;
                CNSSettlementCalc: Codeunit "CNS Settlement Calc";
            begin
                VendorName := '';
                if Vendor.Get("Vendor No.") then
                    VendorName := Vendor.Name;
                // Same function as the calculation, so the tier lines match the commission on the settlement.
                CNSSettlementCalc.CalcCommission("Agreement No.", "Net Sales", TempCNSTierBreakdown);
            end;
        }
    }

    rendering
    {
        layout(StatementWord)
        {
            Type = Word;
            LayoutFile = 'src/Layouts/CNSSettlementStatement.docx';
            Caption = 'Settlement statement (Word)';
        }
    }

    labels
    {
        TitleLbl = 'Consignment Settlement Statement';
        PeriodLbl = 'Period';
        VendorLbl = 'Brand';
        GrossSalesLbl = 'Gross sales';
        ReturnsLbl = 'Returns';
        NetSalesLbl = 'Net sales';
        CommissionLbl = 'Commission';
        PayoutLbl = 'Payout';
        TierFromLbl = 'From';
        TierToLbl = 'To';
        TierRateLbl = 'Rate';
        TierAmountLbl = 'Sales in tier';
        TierCommissionLbl = 'Commission';
        LineDateLbl = 'Date';
        LineDocumentLbl = 'Document';
        LineItemLbl = 'Item';
        LineVariantLbl = 'Variant';
        LineQuantityLbl = 'Quantity';
        LineAmountLbl = 'Amount';
        PostedInvoiceLbl = 'Payout invoice';
        ApprovedByLbl = 'Approved by';
        StatusLbl = 'Status';
        LinesLbl = 'Sales and returns';
    }

    var
        TempCNSTierBreakdown: Record "CNS Tier Breakdown";
        VendorName: Text[100];
        TierToText: Text;
        AndAboveLbl: Label 'and above';
        OneSettlementErr: Label 'Print one settlement at a time. Filter on the settlement number.';

    local procedure FormatAmount(Amount: Decimal): Text
    begin
        exit(Format(Amount, 0, '<Precision,2:2><Standard Format,0>'));
    end;
}
