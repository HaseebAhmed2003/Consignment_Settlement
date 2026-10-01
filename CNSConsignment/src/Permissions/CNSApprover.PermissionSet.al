permissionset 50201 "CNS APPROVER"
{
    Caption = 'Consignment Approver';
    Assignable = true;

    // Approves and posts. Can't calculate: no insert/delete on settlement lines, not even indirect.
    // Posting the payout also needs the standard purchase posting permission sets.
    Permissions =
        tabledata "CNS Setup" = R,
        tabledata "CNS Agreement" = R,
        tabledata "CNS Commission Tier" = R,
        tabledata "CNS Agreement Item" = R,
        tabledata "CNS Settlement Header" = Rm,
        tabledata "CNS Settlement Line" = R,
        tabledata "CNS Approval Entry" = Ri,
        table "CNS Setup" = X,
        table "CNS Agreement" = X,
        table "CNS Commission Tier" = X,
        table "CNS Agreement Item" = X,
        table "CNS Settlement Header" = X,
        table "CNS Settlement Line" = X,
        table "CNS Approval Entry" = X,
        table "CNS Tier Breakdown" = X,
        page "CNS Agreement List" = X,
        page "CNS Agreement Card" = X,
        page "CNS Commission Tiers" = X,
        page "CNS Agreement Items" = X,
        page "CNS Settlement List" = X,
        page "CNS Settlement Card" = X,
        page "CNS Settlement Lines" = X,
        page "CNS Approval Entries" = X,
        codeunit "CNS Settlement Calc" = X,
        codeunit "CNS Settlement Mgt" = X,
        codeunit "CNS Settlement Post" = X,
        report "CNS Settlement Statement" = X;
}
