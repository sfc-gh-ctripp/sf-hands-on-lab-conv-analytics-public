# Meridian Commerce — AI Assistant Brief

**From:** Head of Analytics, Meridian Commerce  
**To:** AI Engineering Team  
**Re:** Internal AI assistant — build brief

---

## About Meridian Commerce

Meridian Commerce is a US online retailer founded in 2021. A few facts that will help you reason about the data:

- **West Coast is the largest market.** The West region consistently leads in order volume and revenue.
- **Q4 is the peak season.** Order volume roughly doubles in October–December relative to the rest of the year. Seasonal breakdowns matter.
- **Electronics is high-volume but tight-margin.** It's the top category by revenue, but Beauty and Apparel earn significantly more per sale. Gross margin analysis is interesting specifically because of this contrast.
- **The customer base skews recent.** The company has grown quickly; a large share of customers signed up in the past 12 months and are still in the New or Active lifecycle segment.

---

## Background

Meridian Commerce sells consumer products online across four channels (Web, Mobile App, Marketplace, Phone) and four US regions (West, Midwest, South, Northeast). Our data team maintains five production tables covering customers, products, orders, order line items, and customer support tickets.

We need an AI assistant that anyone on the commercial or operations team can talk to — in plain English, without writing SQL.

---

## What the Agent Must Do

### 1. Answer structured sales questions

The agent must handle questions about our business metrics from the sales data. Examples of the *type* of questions it needs to answer:

- Revenue and order volume, overall and broken down by channel, region, product category, or time period
- Average order value and how it varies across segments
- Units sold and top-performing products
- Return rates and what's driving them
- Gross margin by product category
- Customer counts and lifecycle mix (New, Active, Lapsed)

**The agent should produce specific numbers, not vague ranges.** If it says "revenue was approximately $X," the number should be correct.

### 2. Answer support ticket questions

The agent must search through our support ticket history and answer questions like:

- What are the most common complaint categories?
- What do customers say in shipping or returns tickets?
- Are there patterns in how we resolve certain types of complaints?
- Which ticket categories are currently open or unresolved?

**Answers should be grounded in actual ticket text**, not general knowledge about e-commerce support.

### 3. Handle questions that need both

Some questions span both data sources. For example: "Which product category has the highest return rate, and what do customers say in support tickets about returns?" The agent should use both its structured data tool and its search tool to form a complete answer.

---

## Behavioral Expectations

| Requirement | Detail |
|---|---|
| **Stay on scope** | Only answer questions about Meridian Commerce sales and support data. Politely decline anything outside that scope (market data, general knowledge, personal advice, weather). |
| **Cite your sources** | State whether a number came from sales data or support tickets. Don't mix them without being explicit. |
| **No fabrication** | If data isn't available, say so. Never invent numbers. |
| **Concise** | Business users don't need long explanations. Lead with the answer. |

---

## Scoring

At the end of the session, each team's agent will be evaluated across three categories:

| Category | Weight |
|---|---|
| Structured data questions (Cortex Analyst) | **50%** |
| Unstructured / support questions (Cortex Search) | **30%** |
| Combined or multi-step questions | **20%** |

Teams are **not** given the exact questions in advance. The scoring reflects how well your agent handles the types of questions listed above.

**The teams that run Cortex Agent evaluations during the build — and use the results to improve — consistently outperform teams that only build.**

---

## Data Access

All source data is pre-loaded and read-only in `MERIDIAN_CENTRAL_DB.DATA`. Your team's workspace is:

```
MERIDIAN_TEAM_<X>_DB
├── ANALYTICS    ← build your semantic view and search service here
└── AGENTS       ← create your agent here
```

See `schema_overview.md` for the full table and column reference.
