# Schema Overview — Meridian Commerce

Source database: **`MERIDIAN_CENTRAL_DB.DATA`** (read-only)  
All five tables are pre-loaded. Your team has `SELECT` on all of them.

---

## Table: ORDERS

One row per customer order. This is the central fact table for sales analytics.

| Column | Type | Description | Sample values |
|---|---|---|---|
| `order_id` | NUMBER | Primary key | 1, 2, 3 … |
| `customer_id` | NUMBER | FK → CUSTOMERS | 42, 107 … |
| `order_date` | DATE | Date the order was placed | 2025-03-14, 2026-01-02 |
| `channel` | STRING | Sales channel | `Web`, `Mobile App`, `Marketplace`, `Phone` |
| `status` | STRING | Order status (**see quirk below**) | `completed`, `shipped`, `returned`, `cancelled` |
| `total_amount` | NUMBER(12,2) | Order total in USD | 134.99, 489.00 |

**Row count:** ~5,000

**Status domain:**
- `completed` — fulfilled and delivered
- `shipped` — in transit, not yet delivered
- `returned` — order was returned after delivery
- `cancelled` — cancelled before fulfilment

> **Quirk — Revenue definition:** Should revenue include `shipped` orders (in transit) or only `completed`? This is intentionally left ambiguous. Your metric definition and description resolve it — and the eval rewards getting it right.

> **Reconciliation:** `total_amount` equals the sum of its line items in `ORDER_ITEMS`. Revenue computed at the order level and at the line-item level should agree when modeled correctly.

---

## Table: ORDER_ITEMS

One row per product per order. Needed for product-level revenue, units sold, and gross margin.

| Column | Type | Description | Sample values |
|---|---|---|---|
| `order_item_id` | NUMBER | Primary key | 1, 2, 3 … |
| `order_id` | NUMBER | FK → ORDERS | 1, 1, 2 … |
| `product_id` | NUMBER | FK → PRODUCTS | 14, 82 … |
| `quantity` | NUMBER | Units ordered | 1, 2, 3, 4, 5 |
| `unit_price` | NUMBER(10,2) | Sale price per unit (may reflect a discount) | 29.99, 149.00 |
| `discount_pct` | NUMBER(5,2) | Discount applied (0–40); mostly 0 | 0, 10, 25 |

**Row count:** ~12,000

---

## Table: CUSTOMERS

One row per customer account.

| Column | Type | Description | Sample values |
|---|---|---|---|
| `customer_id` | NUMBER | Primary key | 1, 2 … |
| `name` | STRING | Full name | "Jordan Lee", "Sam Rivera" |
| `email` | STRING | Email address | jordan.lee@example.com |
| `signup_date` | DATE | Account creation date | 2024-11-20 |
| `region` | STRING | US region | `West`, `Midwest`, `South`, `Northeast` |
| `segment` | STRING | Lifecycle segment (**see definition below**) | `New`, `Active`, `Lapsed` |

**Row count:** ~1,000  
**Distribution:** West ~38%, South ~25%, Midwest ~23%, Northeast ~14%

**Lifecycle segment definition (point-in-time snapshot, computed at data generation):**
- `New` — signed up within the trailing 90 days from the data generation date
- `Active` — placed at least one order within the trailing 90 days (and is not New)
- `Lapsed` — no order in the trailing 180+ days

This is a **fixed label**, not recomputed live. A good description of this column is one of the levers that improves Cortex Analyst accuracy.

---

## Table: PRODUCTS

One row per product in the catalog.

| Column | Type | Description | Sample values |
|---|---|---|---|
| `product_id` | NUMBER | Primary key | 1, 2 … |
| `name` | STRING | Product display name | `"Audio Wireless 353"` |
| `category` | STRING | Product category | `Electronics`, `Home & Kitchen`, `Apparel`, `Sports & Outdoors`, `Beauty`, `Toys` |
| `subcategory` | STRING | Sub-category within category | "Headphones", "Cookware" |
| `unit_price` | NUMBER(10,2) | Standard list price | 49.99, 299.00 |
| `unit_cost` | NUMBER(10,2) | Product cost (COGS) | 12.50, 254.15 |

**Row count:** ~200  
**Category distribution:** Electronics 56, Home & Kitchen 40, Apparel 34, Sports & Outdoors 32, Beauty 21, Toys 17

> **Quirk — Gross margin varies by category:** Electronics has a low margin (~15%); Beauty is much higher (~60%). A gross-margin-by-category breakdown will show real variation — this is a multi-table metric that tests join modeling. To compute gross margin, you need `unit_cost` from PRODUCTS joined through ORDER_ITEMS.

---

## Table: SUPPORT_TICKETS

One row per customer support ticket. This is the table indexed by Cortex Search.

| Column | Type | Description | Sample values |
|---|---|---|---|
| `ticket_id` | NUMBER | Primary key | 1, 2 … |
| `customer_id` | NUMBER | FK → CUSTOMERS | 42 … |
| `order_id` | NUMBER (nullable) | FK → ORDERS; null for non-order tickets | 1034, NULL |
| `created_date` | DATE | Ticket creation date | 2025-09-12 |
| `category` | STRING | Ticket category | `Shipping`, `Returns`, `Product Quality`, `Billing`, `Account`, `Other` |
| `subject` | STRING | One-line ticket subject | "Order hasn't arrived after 10 days" |
| `body` | TEXT | Full ticket text | Free text, category-distinct language |
| `status` | STRING | Ticket status | `open`, `pending`, `resolved`, `closed` |
| `resolution_notes` | TEXT (nullable) | Resolution details; null when ticket is open | "Replacement shipped" |

**Row count:** ~500  
**Category distribution:** Shipping 125, Returns 110, Product Quality 100, Billing 74, Account 55, Other 36

> **What Cortex Search indexes:** The search service indexes a concatenated `search_text` field combining `subject`, `body`, and `resolution_notes`. This makes ticket subjects and resolution patterns searchable, not just complaint bodies.

> **Ticket text is category-distinct.** Shipping tickets use language about delivery delays and tracking; Returns tickets reference refund policies and fit issues; Product Quality tickets mention defects and breakage. This vocabulary separation is what makes Cortex Search useful — keyword-matching alone would work; semantic search does better.

> **Cross-domain link:** A portion of tickets reference `returned` orders and specific product categories. "Which category drives the most returns?" reconciles against the structured side and is a natural combined question for the evaluation.

---

## Join map

```
CUSTOMERS ──┐
            │ orders.customer_id → customers.customer_id
            ▼
          ORDERS ──────────────────────────────────────────────► SUPPORT_TICKETS
                 order_items.order_id → orders.order_id          (ticket.order_id → orders.order_id)
                 ▼
              ORDER_ITEMS
                 order_items.product_id → products.product_id
                 ▼
              PRODUCTS
```

SUPPORT_TICKETS is **not** joined into the semantic view — it's a separate search corpus. The cross-domain insight (e.g. return rate by category vs. ticket themes) comes from combining the Cortex Analyst and Cortex Search tools in the agent.

---

## Deliberate ambiguities (the levers that eval rewards)

| Ambiguity | What's left open | How to resolve it |
|---|---|---|
| **Revenue status** | `completed` only, or `completed + shipped`? | Pick one and encode it in your `total_revenue` metric definition + comment. |
| **Return rate denominator** | Divide returned by what? All orders? Non-cancelled? | The cleaner business definition: returned ÷ non-cancelled (completed+shipped+returned). |
| **Gross margin** | Requires `unit_cost` from PRODUCTS via ORDER_ITEMS | Multi-table fact; declare `unit_cost` as a FACT and join through order_items. |
| **Lifecycle segment** | Raw definition is not obvious from the column name alone | A good `segment` column description that explains New/Active/Lapsed improves Analyst answers about cohort questions. |
