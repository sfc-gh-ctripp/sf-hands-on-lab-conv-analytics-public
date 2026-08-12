# Architecture Guide

## What You're Building

```
MERIDIAN_CENTRAL_DB.DATA          Your team workspace (MERIDIAN_TEAM_<X>_DB)
┌──────────────────────┐          ┌─────────────────────────────────────────┐
│ CUSTOMERS            │          │ ANALYTICS schema                        │
│ ORDERS               │──────────│   MERIDIAN_SALES  (semantic view)       │
│ ORDER_ITEMS          │          │   SUPPORT_TICKETS_SEARCH  (search svc)  │
│ PRODUCTS             │          │                                         │
│ SUPPORT_TICKETS      │          │ AGENTS schema                           │
└──────────────────────┘          │   MERIDIAN_ASSISTANT  (Cortex Agent)    │
                                  └─────────────────────────────────────────┘
```

**Build order:** semantic view → search service → agent → eval loop.

---

## Step 1 — Semantic View (Cortex Analyst)

A semantic view teaches LLMs the business meaning of your data: which columns are metrics, which are dimensions, how to compute things like revenue and return rate. The better your descriptions and metric definitions, the better Analyst answers questions.

**Create in:** `MERIDIAN_TEAM_<X>_DB.ANALYTICS`, name it `MERIDIAN_SALES`.

### Build in Snowsight

Go to **Snowsight → AI & ML → Analyst → + Create with Autopilot**.

1. Select four tables from `MERIDIAN_CENTRAL_DB.DATA`: `ORDERS`, `ORDER_ITEMS`, `CUSTOMERS`, `PRODUCTS`.
2. Autopilot generates a starting view — **don't just save it.** Review what it produced and customize:
   - **Metrics:** Are Total Revenue, Average Order Value, Units Sold present? Check the status filter on revenue — should it include `shipped` orders or only `completed`? Your definition here drives your score on revenue questions.
   - **Dimensions:** Is `channel`, `region`, `category`, `segment` included? The `segment` column (New/Active/Lapsed) is a lifecycle label — make sure its description explains what each value means, because Analyst reads descriptions verbatim.
   - **Descriptions:** Every metric and dimension description should be specific, not generic. "Total revenue" is not a description. "Sum of total_amount for orders with status = completed" is.
3. **Stretch metrics** (after core is solid): Gross Margin requires joining ORDER_ITEMS to PRODUCTS for `unit_cost`. Return Rate's denominator is ambiguous — define it explicitly.
4. Save to `MERIDIAN_TEAM_<X>_DB.ANALYTICS.MERIDIAN_SALES`.

---

## Step 2 — Cortex Search Service

A Cortex Search service indexes your support ticket text for semantic similarity search. The agent queries it when a user asks something that requires ticket content.

**Create in:** `MERIDIAN_TEAM_<X>_DB.ANALYTICS`, name it `SUPPORT_TICKETS_SEARCH`.

### Build in Snowsight

Go to **Snowsight → AI & ML → Search → + Create**.

1. **Select Table or view**
2. **Source table:** `MERIDIAN_CENTRAL_DB.DATA.SUPPORT_TICKETS`.
3. **Toggle on Multi-index search** - select Learn more to understand the specifics
4. **Pick columns:** Select `subject`, `body`, and `resolution_notes` at least (feel free to try more). Indexing all three makes ticket subjects *and* resolution patterns searchable — not just the complaint body. This matters for combined eval questions like "how are returns resolved?", which require resolution notes to be in the index.
5. **Filter attributes:** Add `category`, `status`, `order_id`, `customer_id` so the agent can narrow searches by these fields.
6. **Warehouse:** `MERIDIAN_WH`. **Target lag:** `1 day` (the source data is static for this lab).
7. Save to `MERIDIAN_TEAM_<X>_DB.ANALYTICS.SUPPORT_TICKETS_SEARCH`.

Wait 1–2 minutes for the first sync. Check status in Snowsight or:

```sql
SHOW CORTEX SEARCH SERVICES IN SCHEMA MERIDIAN_TEAM_A_DB.ANALYTICS;
```
---

## Step 3 — Cortex Agent

The agent wires the two tools together with instructions on when to use each one - feel free to use the below skeleton OR leverage the UI to walkthrough each piece.

**Create in:** `MERIDIAN_TEAM_<X>_DB.AGENTS`

### Skeleton

```sql
CREATE OR REPLACE AGENT MERIDIAN_TEAM_A_DB.AGENTS.MERIDIAN_ASSISTANT
  COMMENT = 'Meridian Commerce AI assistant.'
  FROM SPECIFICATION $$
models:
  orchestration: auto

orchestration:
  budget:
    seconds: 40
    tokens: 16000

instructions:
  response: |
    TODO: How should the agent answer? What tone? What should it always cite?
    Example: "Answer concisely using only data from your tools. Always state whether
    a number came from sales data or support tickets. If a value is unavailable, say so."

  orchestration: |
    TODO: When to use each tool? What is out of scope?
    Example: "Use sales_analyst for revenue, orders, products, margins, and customer data.
    Use support_search for support tickets, complaints, and resolutions.
    Decline questions outside Meridian Commerce sales or support data."

  sample_questions:
    - question: "What was our total revenue?"
    - question: "What are the most common reasons customers contact support?"
    - question: "Which product category has the highest return rate?"

tools:
  - tool_spec:
      type: "cortex_analyst_text_to_sql"
      name: "sales_analyst"
      description: |
        TODO: Describe what this tool answers. The agent reads this description to decide
        which tool to call. Be specific about the metrics and dimensions it covers.
        Example: "Structured sales analytics for Meridian Commerce: revenue, AOV, orders
        by channel, units sold, gross margin, return rate, top products, and breakdowns
        by region, segment, category, and time."

  - tool_spec:
      type: "cortex_search"
      name: "support_search"
      description: |
        TODO: Describe what this tool searches.
        Example: "Semantic search over Meridian customer support tickets,
        including complaint text, category, status, and resolution notes."

tool_resources:
  sales_analyst:
    semantic_view: "MERIDIAN_TEAM_A_DB.ANALYTICS.MERIDIAN_SALES"  # update with your view name
    execution_environment:
      type: "warehouse"
      warehouse: "MERIDIAN_WH"
  support_search:
    name: "MERIDIAN_TEAM_A_DB.ANALYTICS.SUPPORT_TICKETS_SEARCH"   # update with your service name
    id_column: "ticket_id"
    title_column: "subject"
    max_results: 5
$$;
```

### Chat with your agent

Go to **Snowsight → AI & ML → Agents** and open your agent. The "Preview in Snowflake CoWork" link opens the CoWork chat interface. You can also test via SQL:

```sql
SELECT TRY_PARSE_JSON(
  SNOWFLAKE.CORTEX.DATA_AGENT_RUN(
    'MERIDIAN_TEAM_A_DB.AGENTS.MERIDIAN_ASSISTANT',
    $${"messages":[{"role":"user","content":[{"type":"text","text":"What was our total revenue?"}]}]}$$
  )
) AS response;
```

---

## Step 4 — Cortex Agent Evaluations

Evals are the build loop. Run them early and often — they tell you exactly where the agent is failing.

### How it works

1. **Ground-truth table** — a table with two columns:
   - `query_text` (VARCHAR): the question to ask the agent
   - `ground_truth` (VARIANT): a JSON object with the expected answer rubric and expected tool calls

2. **Metrics computed:**
   - `answer_correctness` — does the answer match the expected output? (0–1)
   - `logical_consistency` — is the answer internally coherent? (0–1, reference-free)
   - `tool_selection_accuracy` — did the agent call the right tools? (0–1)

3. **Run the eval** from the **AGENTS schema** (critical — see gotcha below).

### Ground-truth format

```json
{
  "ground_truth_output": "Describe the expected answer: the value, tolerance, what to include/exclude.",
  "ground_truth_invocations": [
    {"tool_name": "sales_analyst"}
  ]
}
```

- For questions requiring **no tools** (refusals), use `"ground_truth_invocations": []`.
- For combined questions, list both tools: `[{"tool_name":"sales_analyst"}, {"tool_name":"support_search"}]`.
- `tool_selection_accuracy` penalizes extra tool calls — if your agent sometimes calls a tool twice, allow for that.

### Running the eval

**Option 1 — Snowsight UI:** Snowsight → AI & ML → Agents → your agent → *Evaluations* tab → *Create evaluation* → point it at your ground-truth table.

**Option 2 — CoCo:** Use the `cortex-agent` skill:
```
/cortex-agent  →  "Run an evaluation against my agent using the table MERIDIAN_TEAM_A_DB.ANALYTICS.AGENT_EVAL_STARTER"
```

**Option 3 — SQL (advanced):** Stage a config YAML and call `EXECUTE_AI_EVALUATION`.

Config YAML template:
```yaml
dataset:
  dataset_type: "CORTEX AGENT"
  table_name: "MERIDIAN_TEAM_A_DB.ANALYTICS.AGENT_EVAL_STARTER"
  dataset_name: "MY_EVAL_INPUT"
  column_mapping:
    query_text: "query_text"
    ground_truth: "ground_truth"

evaluation:
  agent_params:
    agent_name: "MERIDIAN_TEAM_A_DB.AGENTS.MERIDIAN_ASSISTANT"
    agent_type: "CORTEX AGENT"
  run_params:
    label: "My team eval run"
  source_metadata:
    type: "dataset"
    dataset_name: "MY_EVAL_INPUT"

metrics:
  - "answer_correctness"
  - "tool_selection_accuracy"
  - "logical_consistency"
```

```sql
-- Stage and run (must run from your AGENTS schema — see gotcha #1 below):
USE SCHEMA MERIDIAN_TEAM_A_DB.AGENTS;
CREATE OR REPLACE STAGE MY_EVAL_STAGE;
-- Upload eval_config.yaml via Snowsight: Stages UI → select your stage → Upload.

-- Start the eval:
CALL EXECUTE_AI_EVALUATION(
  'START',
  OBJECT_CONSTRUCT('run_name', 'my-eval-run'),
  '@MERIDIAN_TEAM_A_DB.AGENTS.MY_EVAL_STAGE/eval_config.yaml'
);

-- Check status (poll until STATUS = COMPLETED):
CALL EXECUTE_AI_EVALUATION(
  'STATUS',
  OBJECT_CONSTRUCT('run_name', 'my-eval-run'),
  '@MERIDIAN_TEAM_A_DB.AGENTS.MY_EVAL_STAGE/eval_config.yaml'
);
```

> **If EXECUTE_AI_EVALUATION fails with "Dataset version already exists":**
> ```sql
> DROP DATASET IF EXISTS MERIDIAN_TEAM_A_DB.AGENTS.MY_EVAL_INPUT;
> -- Then re-run EXECUTE_AI_EVALUATION('START', ...) above.
> ```
> A failed eval leaves a stuck DATASET object that blocks retries. Drop it and re-run.

### ⚠ Critical gotchas

**1. Run the eval from the agent's own schema.**  
Before running: `USE SCHEMA MERIDIAN_TEAM_A_DB.AGENTS;`  
If you run from any other schema, metric computation fails (HTTP 422) even though output rows still appear. All metric scores will be null.

**2. Metric expressions must reference declared facts/dimensions.**  
`SUM(orders.total_amount)` in a METRIC block will fail Cortex Analyst validation — declare `orders.order_amount AS orders.total_amount` in FACTS first, then reference `orders.order_amount` in your metric expression.

### Starter eval dataset

Load `reference/starter_agent_eval_dataset.sql` — it creates `MERIDIAN_TEAM_A_DB.ANALYTICS.AGENT_EVAL_STARTER` with three examples (a structured fact, a combined question, and an out-of-scope refusal). Run it as a baseline immediately after your agent compiles, then extend the table as you iterate.

---

## Iteration loop

```
Build → chat-test → run eval → read scores → improve → re-run eval → repeat
        (CoWork)   (Evaluations tab or SQL)  (descriptions, metrics, instructions)
```

The teams that iterate with evals outperform the teams that only build. Start evals early — even a three-row starter dataset tells you whether the agent is calling the right tools.
