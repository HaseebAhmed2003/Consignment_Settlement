# CNS Consignment Settlement: design

Written before any code. Anything I changed later is marked **(changed during build)**.

## The business problem

The store sells brands on consignment. The brand owns the stock until it sells; at month end the
store pays the brand what was sold, minus the store's commission. Today this is done in a
spreadsheet from a sales export, which makes it easy to pay a sale twice or miss a return.

The extension calculates a monthly settlement per brand from posted sales, gets it approved by a
second person, and posts the payout as a normal purchase invoice to the brand.

## Business rules

1. **Each brand is a Vendor.** Store sales are posted to one customer, the "Store Cash Customer".
   Who the end customer was doesn't matter here.
2. **Agreement items are an explicit list.** An agreement has a list of items. An item can only be
   in one *active* agreement at a time (checked on overlapping dates when activating).
3. **Commission is progressive (tiered), like income tax.** Each tier has a From Amount and a
   rate; the rate applies only to the part of net sales inside that tier.
   Example: 0–100,000 at 25%, above 100,000 at 20%. Net sales 150,000 →
   100,000 × 25% + 50,000 × 20% = 25,000 + 10,000 = **35,000**. The first tier must start at 0.
4. **What counts as a sale:** Value Entries with Item Ledger Entry Type = Sale, Adjustment = No,
   using Sales Amount (Actual). Sales credit memos produce negative amounts, so returns come in
   automatically with a minus sign.
5. **A late return goes into the next settlement.** A posted settlement is never reopened. If a
   bag sold in December is returned in January, the January settlement is lower.
6. **No double payment.** Every settlement line stores the Value Entry No. it came from. An entry
   already on any settlement line is skipped.
7. **A negative or zero payout is not posted.** If returns are bigger than sales, the settlement
   shows a negative payout and Approve/Post stop with a clear message. Getting money back from the
   brand is done manually with a purchase credit memo (known limitation).
8. **Segregation of duties.** The user who calculated a settlement can't approve it.
9. **Payout posting.** The payout is a purchase invoice with one G/L account line, using the
   account in CNS Setup. Whether the store should recognise gross sales or only commission as
   revenue is a finance policy question and is out of scope (limitation).
10. **Scope:** local currency only, monthly periods, one store.

## Decisions made while designing

### Which value entries a settlement picks up
- Filter: the agreement's items, Posting Date from the agreement Start Date to the settlement's
  Period End (or the agreement End Date if that is earlier), Sales Amount (Actual) ≠ 0, and not
  already on a settlement line.
- Starting at the agreement start instead of the period start means anything that was missed
  (for example a return backdated into a month that is already posted) is caught by the next
  settlement instead of being lost.
- To keep that safe, settlements for one agreement must be done **in order**: Calculate stops if
  an earlier settlement for the same agreement isn't posted yet.
- Entries with Sales Amount (Actual) = 0 are skipped. These are shipment entries that aren't
  invoiced yet; the invoice creates its own value entry later.
- Line quantity = −Invoiced Quantity, so a sale shows as positive and a return as negative.
- Returns are stored on the header as a positive number; Net = Gross − Returns.

### Commission rounding (changed from the spec code)
The spec rounds the total once. I round each tier's amount and add them up, so the tier lines on
the statement always add up to the commission total. With 25%/20% on normal amounts the result is
the same.

### Tier breakdown for the report
The commission function can fill a temporary table "CNS Tier Breakdown" (one row per tier: from,
to, rate, amount in tier, commission). Calculation uses the plain version, the report uses the
one with the breakdown.

### Agreement changes
Tiers and items can only be changed while the agreement is Draft. Actions: Activate (checks
below) and End Agreement. Activation checks:
- at least one tier, the lowest tier starts at 0, rates between 0 and 100, no two tiers with the
  same From Amount. **(changed during build)** The rate range is checked in OnValidate:
  MinValue/MaxValue only apply to typing on a page, a test showed code could set 101.
- at least one item
- End Date (if filled) after Start Date
- none of the items is in another active agreement with overlapping dates (blank End Date = open)

### Creating settlements
A settlement is one agreement + one calendar month. It's created by the **Create Settlement**
action (agreement + month) or by the monthly job, never by typing into an empty card. Two
settlements for the same agreement and month are not allowed.

### Permissions and the clerk/approver split
Following what worked in the PRX project: users get **indirect** permission on the settlement
tables, and only the codeunits that need to change them declare `Permissions`.

| | Settlement header | Lines | Approval entries | Agreements |
|---|---|---|---|---|
| CNS CLERK | R, indirect i m | R, indirect i d | R | RIMD |
| CNS APPROVER | R, indirect m | R | R, indirect i | R |

- Calculate needs indirect insert/delete on lines → only the clerk can calculate.
- Approve and Post insert into a log table **CNS Approval Entry** → only the approver can do that.
  If a clerk runs Approve, it fails on the log insert even though the header modify is allowed.
- On top of that, Approve checks Approved By ≠ Calculated By, which covers a user who has both
  sets (or SUPER).
- Posting also needs the standard purchase posting permissions (as in PRX: D365 PURCH DOC, POST
  and D365 JOBS, VIEW).

### Locking
- Header OnModify: if the stored record is Posted → error.
- Header OnDelete: only Draft or Calculated can be deleted; lines are deleted with it.

### Posting
User-supplied `PostSettlement` code, with:
- `Validate` on every field so BC's normal logic runs (vendor defaults, dimensions, G/L checks).
- `SetSuppressCommit(true)` so the invoice and the settlement update are one transaction.
- The posted invoice is found by `Pre-Assigned No.` (the unposted invoice number).
- Vendor Invoice No. = settlement number, so BC's duplicate vendor invoice check also stops a
  second payout for the same settlement.
- Posting Date = Period End.

### BRAND dimension
Standard BC: dimension BRAND with one value per brand, set as a Default Dimension on each vendor.
The payout invoice picks it up from the vendor, so vendor ledger and G/L entries carry it. No code
in the extension for this; the demo data codeunit only sets it up.

### Payout G/L account
Demo data fills it with the Purch. Account from General Posting Setup for the demo vendor's and
demo item's posting groups. Before relying on it I post one manual purchase invoice to that
account to make sure it is postable.

### Monthly job
Codeunit "CNS Create Draft Settlements" (TableNo = Job Queue Entry). It creates Draft
settlements for the previous month for every active agreement, skipping ones that exist.
- The reference date is WorkDate, unless the Job Queue Entry's Parameter String holds a date.
  Needed because a job queue session uses the real date (2026), while CRONUS data is in 2028.
- Also available as a manual action on the settlement list.
- On-premises the Job Queue only runs if the task scheduler is enabled on the server instance.

### Report
"CNS Settlement Statement", Word layout: settlement header, gross, returns, net, commission per
tier, payout. **(changed during build)** One settlement per run: a repeating section around the
whole statement didn't render in BC 28.5, so the header binds to the first settlement and the
report refuses a filter with more than one.

### Demo data (dates relative to the work date)
- Month 1 = month before the work date, month 2 = work date month.
- Two brands (vendors) with BRAND values, agreements, tiers and items with variants
  (handbag black/tan, scarf in two colours).
- Stock by item journal positive adjustment.
- Posted sales invoices to the Store Cash Customer in both months; one brand crosses its tier.
- One sales credit memo in month 2 for an item sold in month 1.
- Reset and rebuild with one action. Posted ledger entries can't be deleted in BC, so reset clears
  the extension's own data (agreements, settlements) and recreates the agreements; sales are only
  posted the first time.

## Objects

Main app 50200–50299:

| Type | ID | Name |
|---|---|---|
| Enum | 50200 | CNS Agreement Status (Draft, Active, Ended) |
| Enum | 50201 | CNS Settlement Status (Draft, Calculated, Approved, Posted) |
| Enum | 50202 | CNS Approval Action (Approved, Posted) |
| Table | 50200 | CNS Setup |
| Table | 50201 | CNS Agreement |
| Table | 50202 | CNS Commission Tier |
| Table | 50203 | CNS Agreement Item |
| Table | 50204 | CNS Settlement Header |
| Table | 50205 | CNS Settlement Line |
| Table | 50206 | CNS Approval Entry |
| Table | 50207 | CNS Tier Breakdown (temporary) |
| Page | 50200–50210 | Setup, Agreement List/Card, Tiers and Items subpages, Settlement List/Card, Lines subpage, Approval Entries, Create Settlement dialog |
| Codeunit | 50200 | CNS Agreement Mgt |
| Codeunit | 50201 | CNS Settlement Calc |
| Codeunit | 50202 | CNS Settlement Mgt |
| Codeunit | 50203 | CNS Settlement Post |
| Codeunit | 50204 | CNS Create Draft Settlements |
| Codeunit | 50205 | CNS Install |
| Codeunit | 50206 | CNS Demo Data |
| Report | 50200 | CNS Settlement Statement |
| Permission set | 50200 / 50201 | CNS CLERK / CNS APPROVER |

Test app 50300–50349.

## Checked against the BC 28.5 symbols before writing code

- Value Entry: Item Ledger Entry Type (enum), Adjustment, Sales Amount (Actual), Variant Code,
  Document No., Invoiced Quantity, Posting Date all exist.
- Codeunit 90 "Purch.-Post" has `SetSuppressCommit(Boolean)`.
- Purch. Inv. Header has "Pre-Assigned No." (Code[20]); Vendor Invoice No. is Code[35].
- Job Queue Entry has "Parameter String" (Text[250]).
- Codeunit "No. Series" (Business Foundation) has `GetNextNo(Code[20], Date)`.
- Item Jnl.-Post Line has `RunWithCheck`.
- General Posting Setup has "Purch. Account".
- Test libraries: Library - Sales (130509) has CreateSalesHeader/CreateSalesLine/PostSalesDocument;
  Library - Inventory has CreateItemVariant; Library - Dimension has CreateDefaultDimensionVendor.
