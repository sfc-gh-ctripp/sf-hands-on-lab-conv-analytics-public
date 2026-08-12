# CoCo Tips — Using Cortex Code for This Lab

Cortex Code (CoCo) is your AI coding assistant throughout the build. It has direct access to your Snowflake connection and can generate, validate, and run SQL for you.

---

## General tips

- **Give CoCo context upfront.** Start a task by telling it what you're building and what schema you're targeting. Paste in relevant snippets from `schema_overview.md` or your current SQL when you want CoCo to reason about it.
- **Iterate, don't perfect.** Paste partial output back in and ask CoCo to fix a specific problem — it's faster than trying to write the ideal prompt the first time.
- **Use skills.** CoCo has specialized skills for agents and semantic views. Use `/cortex-agent` for agent work and `/semantic-studio` for semantic view work — they load step-by-step workflows.

---

## Phase 1 — Explore the data

**Understand the tables:**
```
Look at the tables in MERIDIAN_CENTRAL_DB.DATA.
Show me: row counts for each table, a sample from ORDERS (5 rows), 
and the distinct values for orders.status and orders.channel.
```

**Check FK integrity:**
```
In MERIDIAN_CENTRAL_DB.DATA, verify that every order_id in ORDER_ITEMS 
exists in ORDERS, and every customer_id in ORDERS exists in CUSTOMERS.
Show any mismatches.
```

**Quick metrics sanity:**
```
Using MERIDIAN_CENTRAL_DB.DATA, compute:
- Total revenue (SUM of total_amount for completed and shipped orders)
- Average order value for the same set
- Order count by channel (all statuses)
```

---

## Phase 2 — Build the semantic view

Build the semantic view in **Snowsight → AI & ML → Semantic Views → + Create → Autopilot**. Select the four tables, review what Autopilot generates, and customize. See `reference/architecture_guide.md` Step 1 for guidance on what to look for.

**Invoke the skill for guided help:**
```
/semantic-studio
```

**Fix a validation error:**
```
When I run this semantic view through Cortex Analyst it fails with 
"Calculation referred to undefined logical column name: total_amount".
Here is my current METRICS block: [paste block].
How do I fix this?
```
> CoCo knows the fix: declare `total_amount` as a FACT and reference the fact name in the METRIC.

**Add a stretch metric (gross margin):**
```
Add a gross_margin metric to my semantic view.
It needs to join ORDER_ITEMS to PRODUCTS to get unit_cost.
The formula is: SUM((unit_price * quantity * (1 - discount_pct/100)) - (quantity * unit_cost))
for completed and shipped orders.
Remind me which columns need to be declared as FACTS first.
```

**Smoke-test the view:**
```
Run SEMANTIC_VIEW(MERIDIAN_TEAM_A_DB.ANALYTICS.MERIDIAN_SALES METRICS total_revenue)
and compare to a direct SQL query: SELECT SUM(total_amount) FROM MERIDIAN_CENTRAL_DB.DATA.ORDERS
WHERE status IN ('completed','shipped').
They should match.
```

---

## Phase 3 — Create the Cortex Search service

Build the search service in **Snowsight → AI & ML → Cortex Search → + Create**. See `reference/architecture_guide.md` Step 2 for field selection guidance.

**Check sync status:**
```
Show me the status of CORTEX SEARCH SERVICES in schema MERIDIAN_TEAM_A_DB.ANALYTICS.
Is SUPPORT_TICKETS_SEARCH ready?
```

---

## Phase 4 — Write the agent spec

**Invoke the skill for guided help:**
```
/cortex-agent
```

**Generate an agent spec:**
```
Using the skeleton in reference/architecture_guide.md, create an agent
MERIDIAN_TEAM_A_DB.AGENTS.MERIDIAN_ASSISTANT that:
- Uses sales_analyst (cortex_analyst_text_to_sql) over MERIDIAN_TEAM_A_DB.ANALYTICS.MERIDIAN_SALES
- Uses support_search (cortex_search) over MERIDIAN_TEAM_A_DB.ANALYTICS.SUPPORT_TICKETS_SEARCH
- Instructs the agent to: answer only Meridian Commerce sales and support questions,
  always cite whether a number came from sales data or support tickets, and 
  politely decline out-of-scope questions (weather, general knowledge, etc.)
```

**Improve tool descriptions:**
```
The agent is calling support_search when it should use sales_analyst for a revenue question.
Here is my current tool description for sales_analyst: [paste].
Suggest a more specific description that makes it clearer this tool handles structured 
metrics like revenue, AOV, return rate, units sold, and breakdowns by channel/region/category.
```

**Test with SQL:**
```
Use DATA_AGENT_RUN to test my agent MERIDIAN_TEAM_A_DB.AGENTS.MERIDIAN_ASSISTANT 
with the question: "What was our total revenue?"
Show me the full response.
```

---

## Phase 5 — Run and interpret agent evals

**Load the starter eval dataset:**
```
The SQL below creates MERIDIAN_TEAM_A_DB.ANALYTICS.AGENT_EVAL_STARTER.
Replace 'MERIDIAN_TEAM_A_DB' with my actual team database and run it.

[paste the contents of starter_agent_eval_dataset.sql here]
```

**Run an eval via the cortex-agent skill:**
```
/cortex-agent

Run a Cortex Agent evaluation on MERIDIAN_TEAM_A_DB.AGENTS.MERIDIAN_ASSISTANT
using the ground-truth table MERIDIAN_TEAM_A_DB.ANALYTICS.AGENT_EVAL_STARTER.
Column mapping: query_text → query_text, ground_truth → ground_truth.
Run from the AGENTS schema.
```

**Interpret eval output:**
```
Here are my Cortex Agent eval results: [paste output].
For each row where answer_correctness < 0.8 or tool_selection_accuracy < 0.8,
explain what likely went wrong and suggest a concrete fix 
(semantic view description, metric definition, agent instructions, or tool description).
```

**Diagnose a tool selection problem:**
```
My eval shows tool_selection_accuracy = 0.33 on this question: [question].
ground_truth_invocations was [{"tool_name":"sales_analyst"}] but the agent 
called support_search instead.
Here is my agent spec: [paste].
What change would fix the tool routing?
```

**Extend the eval dataset:**
```
I want to add 3 more rows to MERIDIAN_TEAM_A_DB.ANALYTICS.AGENT_EVAL_STARTER.
Add eval rows for:
1. "What is the average order value by region?" — should use sales_analyst
2. "Are there patterns in how shipping complaints get resolved?" — should use support_search
3. "What is our return rate for Electronics, and what do customers say in product quality tickets?" — should use both tools
Base the ground_truth_output on the Meridian Commerce data we've been working with.
```

---

## Useful CoCo shortcuts

| What you want | What to type |
|---|---|
| Guided semantic view workflow | `/semantic-studio` |
| Guided agent + eval workflow | `/cortex-agent` |
| Look up a Snowflake concept | Ask CoCo directly: "How does [concept] work?" |
| Run a quick SQL check | Just ask — CoCo executes SQL directly |
| Validate SQL without running | "Compile-check this SQL without running it" |
| Compare two metric values | "Run both queries and tell me if they match" |
