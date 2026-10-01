# CNS Consignment Settlement

A Business Central AL extension for stores that sell brands on consignment. Each month it works
out what the store owes each brand from posted sales, takes the store's tiered commission,
gets the settlement approved by a second person and posts the payout as a purchase invoice.

Design and business rules: [DESIGN.md](DESIGN.md). A 5-page illustrated walkthrough of the demo, run with two real users, is in [docs/CNS_Illustrated_Walkthrough.pdf](docs/CNS_Illustrated_Walkthrough.pdf).

## What it does

- **Agreements per brand (vendor)** with an explicit item list and progressive commission
  tiers. Activation checks: at least one tier, the first one starting at 0, rates 0–100, at
  least one item, end date after start date, and no item in another active agreement for an
  overlapping period. Tiers and items are locked once the agreement is active.
- **Monthly settlements** built from Value Entries (Sale, not adjustment, Sales Amount (Actual)).
  Credit memos come in as returns. Every line keeps its Value Entry No., and an entry already
  on a settlement is never used again. A return posted after a month was settled is picked up
  by the next settlement; posted settlements are never reopened.
- **Workflow:** Draft → Calculated → Approved → Posted. The user who calculated can't approve.
  Zero and negative payouts are stopped with a clear message.
- **Payout posting:** a purchase invoice to the brand on the period end date, one line to the
  payout G/L account from setup, vendor invoice no. = settlement no. The brand's default
  dimension (BRAND) flows to the vendor ledger and G/L entries. Invoice and settlement update
  are one transaction.
- **Settlement Statement** report with a Word layout: totals, commission per tier, and every
  sale/return line.
- **Monthly job:** codeunit 50204 creates Draft settlements for the previous month for every
  active agreement (skips ones that exist). Also available as an action on the settlement list.
- **Permission sets:** `CNS CLERK` (agreements, create and calculate) and `CNS APPROVER`
  (approve and post). Settlement tables are only writable through the codeunits (indirect
  permissions).

## Standard BC vs this extension

| Need | Standard BC | With this extension |
|---|---|---|
| Who owns which items | Item vendor no. only | Agreement with item list and date range, one active agreement per item |
| Commission | Not available for consignment | Progressive tiers per agreement, breakdown on the statement |
| What to pay the brand | Manual: export sales, spreadsheet | Calculated from value entries, returns included automatically |
| Paying a sale twice | Nothing stops it | Value entry numbers stored, used entries skipped, vendor invoice no. = settlement no. |
| Late returns | Easy to miss | Land in the next settlement |
| Four-eyes check | Approval workflows exist, but nothing ties them to a payout calculation | Calculated by ≠ approved by, enforced by permissions and a check |
| Payout | Manual purchase invoice | Posted from the settlement, with BRAND dimension |
| Brand statement | None | Word report per settlement |
| Month-end routine | Manual | Job Queue creates the drafts |

## Tested environment

- Business Central 28.5 on-premises (US), CRONUS USA demo company, work date 1/27/2028
- AL runtime 17.0; compiled with CodeCop, UICop and PerTenantExtensionCop (no warnings)
- Manually tested with two Windows users:
  - receiver1: D365 BASIC, D365 PURCH DOC, EDIT, D365 PURCH DOC, POST, D365 JOBS, VIEW and **CNS CLERK**
  - manager1: the same standard sets and **CNS APPROVER**

## Project structure

```
CNSConsignment/        main app  (object IDs 50200-50299)
CNSConsignment.Test/   test app  (object IDs 50300-50349)
docs/                  illustrated walkthrough (PDF)
```

## Installation

1. Open `CNSConsignment.code-workspace` in VS Code with the AL Language extension.
2. Update `.vscode/launch.json` in both folders for your server (defaults: `localhost`, port
   7049, instance `BC280`, Windows authentication).
3. Download symbols and publish the main app, then the test app. The test app needs Microsoft's
   Application Test Library, Library Assert, Any and Permissions Mock.
4. On install, the setup record and number series `CNS-SET` are created.
5. Open **Consignment Setup** and choose **Create Demo Data** (two brands, BRAND dimension, three
   items with variants, stock, sales in the month before the work date and the work date month,
   one return). It also fills the payout G/L account from General Posting Setup.
   **Reset Demo Data** clears agreements and settlements and creates the agreements again.
6. Assign `CNS CLERK` / `CNS APPROVER` on top of the users' purchasing permission sets.

### Monthly job

Create a Job Queue Entry: Object Type to Run = Codeunit, Object ID to Run = 50204, recurring
monthly. Leave **Parameter String** blank to use today's date, or put a date as `yyyy-mm-dd`
to settle the month before that date (useful in CRONUS, where the data is in 2028).
**On-premises the Job Queue only runs if the task scheduler is enabled on the server instance**
(`EnableTaskScheduler` in the server configuration).

## Tests

39 tests, all passing in the AL Test Tool (page 130451):

| Codeunit | Tests | Covers |
|---|---|---|
| 50301 CNS Commission Tests | 8 | Below/at threshold, across two and three tiers, zero/negative, breakdown, no tiers |
| 50302 CNS Agreement Tests | 8 | Activation checks, overlapping agreements, dates, rate range, locked tiers |
| 50303 CNS Calculation Tests | 7 | Sums, returns, period limits, recalculation, no double counting, order, one per month |
| 50304 CNS Workflow Tests | 8 | Status rules, approval, posting amount and dimension, posted settlement locked, zero payout |
| 50305 CNS Permission Tests | 4 | Clerk calculates but can't approve; approver approves but can't calculate (Permissions Mock) |
| 50306 CNS Job Tests | 4 | Previous month drafts, idempotent, draft agreements skipped, Parameter String date |


## Known limitations

- Local currency only, monthly periods, one store.
- A negative payout (returns bigger than sales) is not posted. It needs a manual purchase
  credit memo to the brand; the settlement shows the amount.
- Whether the store should recognise gross sales or only its commission as revenue is a
  finance policy question. The extension only posts the payout to the brand.
- The statement prints one settlement at a time.
- Settlements for an agreement must be calculated in order (an earlier unposted one blocks).
- Consignment stock in the demo is carried at zero cost; the extension doesn't change how
  stock is valued.
- All variants of an item belong to the agreement; excluding a variant would need a small change.
