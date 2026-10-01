permissionset 50200 "CNS CLERK"
{
    Caption = 'Consignment Clerk';
    Assignable = true;

    // Maintains agreements, creates and calculates settlements.
    // Lowercase = indirect: only usable through the codeunits that declare Permissions.
    // No insert on approval entries, which is what stops a clerk from approving.
    Permissions =
        tabledata "CNS Setup" = R,
        tabledata "CNS Agreement" = RIMD,
        tabledata "CNS Commission Tier" = RIMD,
        tabledata "CNS Agreement Item" = RIMD,
        tabledata "CNS Settlement Header" = Rim,
        tabledata "CNS Settlement Line" = Rid,
        tabledata "CNS Approval Entry" = R,
        tabledata "Value Entry" = R,
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
        page "CNS Create Settlement" = X,
        codeunit "CNS Agreement Mgt" = X,
        codeunit "CNS Settlement Calc" = X,
        codeunit "CNS Settlement Mgt" = X,
        codeunit "CNS Create Draft Settlements" = X,
        report "CNS Settlement Statement" = X;
}
