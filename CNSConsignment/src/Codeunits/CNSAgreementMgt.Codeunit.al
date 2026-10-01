codeunit 50200 "CNS Agreement Mgt"
{
    Access = Public;

    var
        NoTiersErr: Label 'Agreement %1 has no commission tiers. Add at least one tier before activating.', Comment = '%1 = agreement no.';
        FirstTierNotZeroErr: Label 'The lowest commission tier on agreement %1 starts at %2. The first tier must start at 0.', Comment = '%1 = agreement no., %2 = from amount';
        NoItemsErr: Label 'Agreement %1 has no items. Add the consignment items before activating.', Comment = '%1 = agreement no.';
        ItemInOtherAgreementErr: Label 'Item %1 is already in active agreement %2 for an overlapping period. An item can only be in one active agreement at a time.', Comment = '%1 = item no., %2 = other agreement no.';
        ActivateQst: Label 'Activate agreement %1? Tiers and items can''t be changed after this.', Comment = '%1 = agreement no.';
        EndQst: Label 'End agreement %1 on %2?', Comment = '%1 = agreement no., %2 = end date';
        EndDateBeforeStartErr: Label 'The end date %1 is before the agreement start date %2.', Comment = '%1 = end date, %2 = start date';

    procedure ActivateWithConfirm(var CNSAgreement: Record "CNS Agreement")
    begin
        if not Confirm(ActivateQst, false, CNSAgreement."No.") then
            exit;
        Activate(CNSAgreement);
    end;

    procedure Activate(var CNSAgreement: Record "CNS Agreement")
    begin
        CNSAgreement.TestStatusDraft();
        CNSAgreement.TestField("Vendor No.");
        CNSAgreement.TestField("Start Date");
        CheckTiers(CNSAgreement."No.");
        CheckItems(CNSAgreement);

        CNSAgreement.Status := CNSAgreement.Status::Active;
        CNSAgreement.Modify(true);
    end;

    procedure EndAgreementWithConfirm(var CNSAgreement: Record "CNS Agreement"; EndDate: Date)
    begin
        if not Confirm(EndQst, false, CNSAgreement."No.", EndDate) then
            exit;
        EndAgreement(CNSAgreement, EndDate);
    end;

    procedure EndAgreement(var CNSAgreement: Record "CNS Agreement"; EndDate: Date)
    begin
        CNSAgreement.TestField(Status, CNSAgreement.Status::Active);
        if EndDate < CNSAgreement."Start Date" then
            Error(EndDateBeforeStartErr, EndDate, CNSAgreement."Start Date");
        // Only allow ending earlier, never extending, so no new overlap can appear.
        if (CNSAgreement."End Date" = 0D) or (EndDate < CNSAgreement."End Date") then
            CNSAgreement."End Date" := EndDate;
        CNSAgreement.Status := CNSAgreement.Status::Ended;
        CNSAgreement.Modify(true);
    end;

    local procedure CheckTiers(AgreementNo: Code[20])
    var
        CNSCommissionTier: Record "CNS Commission Tier";
    begin
        CNSCommissionTier.SetCurrentKey("Agreement No.", "From Amount");
        CNSCommissionTier.SetRange("Agreement No.", AgreementNo);
        if not CNSCommissionTier.FindFirst() then
            Error(NoTiersErr, AgreementNo);
        if CNSCommissionTier."From Amount" <> 0 then
            Error(FirstTierNotZeroErr, AgreementNo, CNSCommissionTier."From Amount");
    end;

    local procedure CheckItems(CNSAgreement: Record "CNS Agreement")
    var
        CNSAgreementItem: Record "CNS Agreement Item";
        OtherAgreementNo: Code[20];
    begin
        CNSAgreementItem.SetRange("Agreement No.", CNSAgreement."No.");
        if not CNSAgreementItem.FindSet() then
            Error(NoItemsErr, CNSAgreement."No.");
        repeat
            OtherAgreementNo := FindOverlappingAgreement(CNSAgreementItem."Item No.", CNSAgreement);
            if OtherAgreementNo <> '' then
                Error(ItemInOtherAgreementErr, CNSAgreementItem."Item No.", OtherAgreementNo);
        until CNSAgreementItem.Next() = 0;
    end;

    local procedure FindOverlappingAgreement(ItemNo: Code[20]; CNSAgreement: Record "CNS Agreement"): Code[20]
    var
        OtherItem: Record "CNS Agreement Item";
        OtherAgreement: Record "CNS Agreement";
    begin
        OtherItem.SetCurrentKey("Item No.");
        OtherItem.SetRange("Item No.", ItemNo);
        OtherItem.SetFilter("Agreement No.", '<>%1', CNSAgreement."No.");
        if OtherItem.FindSet() then
            repeat
                if OtherAgreement.Get(OtherItem."Agreement No.") then
                    if OtherAgreement.Status = OtherAgreement.Status::Active then
                        if PeriodsOverlap(CNSAgreement."Start Date", CNSAgreement."End Date", OtherAgreement."Start Date", OtherAgreement."End Date") then
                            exit(OtherAgreement."No.");
            until OtherItem.Next() = 0;
        exit('');
    end;

    local procedure PeriodsOverlap(Start1: Date; End1: Date; Start2: Date; End2: Date): Boolean
    begin
        // A blank end date means the agreement runs indefinitely.
        if End1 = 0D then
            End1 := DMY2Date(31, 12, 9999);
        if End2 = 0D then
            End2 := DMY2Date(31, 12, 9999);
        exit((Start1 <= End2) and (Start2 <= End1));
    end;
}
