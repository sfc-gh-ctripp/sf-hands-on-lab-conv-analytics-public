# Meridian Commerce AI Lab — Participant Reference Kit

You have ~90 minutes to build the best AI agent you can for a fictional online retailer. This folder has everything you need. Here's how to use it.

---

## Start here

Read these two files first — they take about 10 minutes and give you everything you need to make good decisions during the build:

| File | What it gives you |
|---|---|
| **[`business_requirements.md`](business_requirements.md)** | What the agent must do, behavioral rules, and the three scoring categories with weights. Read this first — build decisions that don't serve these requirements won't score points. |
| **[`schema_overview.md`](schema_overview.md)** | Every table, column, sample value, and — critically — the four deliberate ambiguities in the data. Resolving those ambiguities well is how teams separate themselves. |

---

## Build order and where to look

```
1. Explore data          →  schema_overview.md + coco_tips.md (Phase 1 prompts)
2. Semantic view         →  architecture_guide.md (Step 1) — build in Snowsight UI
3. Cortex Search         →  architecture_guide.md (Step 2) — build in Snowsight UI
4. Agent                 →  architecture_guide.md (Step 3 + skeleton)
5. First eval run        →  starter_agent_eval_dataset.sql → architecture_guide.md (Step 4)
6. Iterate               →  coco_tips.md (Phase 5 prompts) + eval scores
```

**[`architecture_guide.md`](architecture_guide.md)** is your primary build reference. It walks you through building the semantic view and Cortex Search service in the Snowsight UI, provides a copy-pasteable skeleton for the agent, a smoke-test query, and the full eval setup including the two critical gotchas.

**[`coco_tips.md`](coco_tips.md)** has ready-to-paste CoCo prompts for every phase. If you're not sure what to ask CoCo, start there.

---

## The eval loop is the competition

Load [`starter_agent_eval_dataset.sql`](starter_agent_eval_dataset.sql) **as soon as your agent compiles** — don't wait until the end. It creates a 3-row ground-truth table with a structured question, a refusal test, and a combined question. Running that eval gives you a score immediately and tells you exactly what to fix.

The teams that run evals early and iterate on the results outperform the teams that only build.

```
chat-test in CoWork → run eval → read scores → fix one thing → re-run → repeat
```

Two quick wins that move scores:

- **Improve metric descriptions** in the semantic view — especially the `revenue` and `segment` definitions.
- **Tighten tool descriptions** in the agent spec — the agent reads these to decide which tool to call. Vague descriptions = wrong tool calls = low `tool_selection_accuracy`.

---

## The four deliberate ambiguities

These are the actual levers the eval rewards. They're documented in [`schema_overview.md`](schema_overview.md) but worth calling out here:

| Ambiguity | Why it matters |
|---|---|
| **Revenue: `completed` only, or `completed + shipped`?** | Your metric definition picks the answer — encode it explicitly in the metric expression and its description. |
| **Return rate denominator** | Returned ÷ what? Non-cancelled orders is the clean business definition. |
| **Gross margin** | Multi-table metric — needs `unit_cost` from PRODUCTS via ORDER_ITEMS. Declare it as a FACT or the metric will fail validation. |
| **`segment` column definition** | New/Active/Lapsed isn't obvious from the name. A good column description here measurably improves Analyst accuracy on cohort questions. |

---

## File reference

| File | When to use it |
|---|---|
| [`business_requirements.md`](business_requirements.md) | Kickoff — understand what you're building and how it's scored |
| [`schema_overview.md`](schema_overview.md) | Throughout — column reference, join map, deliberate ambiguities |
| [`architecture_guide.md`](architecture_guide.md) | Build — skeletons, SQL, eval setup, both critical gotchas |
| [`coco_tips.md`](coco_tips.md) | Build — copy-paste CoCo prompts for every phase |
| [`starter_agent_eval_dataset.sql`](starter_agent_eval_dataset.sql) | As soon as your agent compiles — baseline eval, extend as you iterate |
