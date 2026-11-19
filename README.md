# KM-DEV-SALES – Outstanding Orders Report

Business Central extension for **salespeople**: the **Outstanding Orders Report** (search "Outstanding Orders
Report") lists open and released sales orders and assembly orders at SPEKE1, with stock, purchase order and margin
information on every line, plus the reservation tools.

It is a **separate, standalone extension**. It does not depend on the Order Release Worksheet (BC-Order-Release) and
cannot create warehouse shipments, picks or assembly orders.

## Objects (ID range 77500–77599)

| Object | Purpose |
|---|---|
| Table 77500 `KMS Sales Report Setup` / Page 77500 | Setup (search "Outstanding Orders Report Setup") |
| Table 77501 `KMS Outstanding Order` | Temporary: one row per order |
| Table 77502 `KMS Outstanding Order Line` | Temporary: the order's lines |
| Table 77503 `KMS Lot Stock` | Temporary: free pickable stock per item / location / lot |
| Table 77504 `KMS Lot Allocation` | Temporary: lots set aside by Suggest or a typed Qty. to Reserve |
| Query 77500 `KMS Whse. Qty by Bin Lot` | Warehouse entry totals by bin and lot |
| Enums 77500–77504 | Reservation mode, order status, line status, flag colour, document type |
| Page 77501 `KMS Outstanding Orders` | The report (orders on top) |
| Page 77502 `KMS Outstanding Order Lines` | Order Lines section under it |
| Codeunit 77500 `KMS Outstanding Orders Mgt.` | Build, statuses, Suggest / Reserve / Cancel / Reduce |
| Codeunit 77501 `KMS Stock Calculation` | Pickable-bin stock per lot |
| Codeunit 77502 `KMS Reservation Mgt.` | Creates / cancels reservations; runs one order per transaction |
| Codeunit 77503 `KMS Optional Fields` | Reads existing custom fields by name or number (see below) |
| Permission set 77500 `KMS SALES REPORT` | For salespeople: report + reservation actions only |
| Permission set 77501 `KMS SALES RPT ADMIN` | Adds the Setup page |

## What it shows

- **Orders:** Open and Released sales orders, plus assembly orders (any status). Only lines at the Setup
  location filter (default SPEKE1). Every order is shown; filter on Salesperson Code or Region Territory.
  Newest order at the top. Orders fully on a shipment and pick are hidden until **Show / Hide Fully Picking Orders**.
- **Lines:** every line type (item, drop shipment, special order, non-inventory, charge (item), G/L account,
  resource). Stock columns and reservation are only for stocked item lines; other lines are display only.
- **Line columns:** Quantity, Shipped, Invoiced and Outstanding Quantity, Unit Price, Unit Cost, Unshipped Value
  (excl. VAT, LCY), Margin (LCY and %), PO Expected, PO No. (Outstanding Qty.), PO Vendor Name, Purchaser Code, and
  the stock / lot / reservation columns from the worksheet.
- **Order columns:** as the worksheet, plus Margin, and **Whse. Shipment Status** (Partially Picked, Completely
  Picked...).
- **Statuses and colours:** same ranking as the worksheet (Fully on Shipment → Customer Blocked → Location Not
  Set Up → Ready / Ready but before PDD → Reserve Lines → Short-Dated Stock Only → Awaiting Put-away → Ready (Part
  Shipment) / Below Min. Value / Partial Stock (Ship Complete) → No Stock (Partly on Shipment) → No Stock).

## Reservation (kept from the worksheet)

Suggest, Reserve, Cancel Suggested Qty., Cancel Reservation(s) and Reduce to Pickable, for an order, a line, or (in
Bulk Actions) all orders. Free stock = pickable bins − open picks − reserved but not yet on a pick. Lots are chosen
lots on the order first, then FEFO, honouring the customer's minimum shelf life (typing more asks to confirm
short-dated stock). Expired lots are never used. Lots go on the stock side only; the sales line's Item Tracking
Lines stay empty. Reserve on All Orders runs each order in its own transaction.

## Existing custom fields

KM-DEV-SALES has no dependencies. It reads these existing fields at run time, by the name or number set in Setup,
and leaves the column blank if the field does not exist:

| Setup field | Default | Table |
|---|---|---|
| Warehouse Note | `Warehouse Note` | Sales Header |
| Created By field no. | `50006` (falls back to the user who created the order) | Sales Header |
| Min. Remaining Shelf Life | `Min. Remaining Shelf Life` (date formula or days) | Customer |
| Related Orders | `Related_Orders` | Assembly Header |
| Region Territory | `Region Territory` (falls back to Territory Code) | Customer |

## Build and deploy

Same as BC-Order-Release. Every push to `main` or `feature/*` runs the **CI/CD** workflow (AL-Go for GitHub), which
compiles against **BC 28.5 GB** (`.AL-Go/settings.json`) with CodeCop and UICop. The `.app` is in the run's
**Artifacts**.

1. Download the Apps artifact → `Kays Medical_KM-DEV-SALES_<version>.app`.
2. **Sandbox:** Extension Management → Manage → Upload Extension → Deploy.
3. Open **Outstanding Orders Report Setup** once (creates the setup record), check the location filter and field
   names, assign **KMS SALES REPORT** to salespeople alongside their normal sales permissions, and test.
4. When signed off, repeat in **production**.

## Test in a sandbox before production

- Reserve / Cancel / Reduce on a lot-tracked item: check Reservation Entries and that the sales line's Item
  Tracking Lines stay empty.
- An order whose lines already have lots on Item Tracking Lines.
- Assembly order components.
- Reserve on All Orders with one order that will fail (e.g. item set to Reserve = Never).
