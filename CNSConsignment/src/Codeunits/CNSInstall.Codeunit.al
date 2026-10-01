codeunit 50205 "CNS Install"
{
    Subtype = Install;
    Access = Internal;

    trigger OnInstallAppPerCompany()
    var
        CNSSettlementMgt: Codeunit "CNS Settlement Mgt";
    begin
        CNSSettlementMgt.EnsureSetup();
    end;
}
