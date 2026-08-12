-- Meridian Commerce — Starter Cortex Agent eval dataset.
-- Creates a ground-truth table in your team's ANALYTICS schema with three examples:
--   1. A structured fact question (tests sales_analyst, exact value)
--   2. An out-of-scope refusal (expects NO tool calls)
--   3. A combined structured + search question (tests both tools)
--
-- HOW TO USE:
--   1. Replace 'MERIDIAN_TEAM_A_DB' with your team database (e.g. MERIDIAN_TEAM_B_DB).
--   2. Run this script to create the table.
--   3. Run a Cortex Agent eval pointing at this table — see architecture_guide.md.
--      IMPORTANT: run the eval from your AGENTS schema (USE SCHEMA ...AGENTS first).
--
-- Ground-truth columns:
--   query_text      VARCHAR  — the question to ask your agent
--   ground_truth    VARIANT  — JSON with two keys:
--     "ground_truth_output"       rubric text for answer_correctness scoring
--     "ground_truth_invocations"  expected tool calls for tool_selection_accuracy
--                                 (empty array [] = expect the agent to use NO tools)
--
-- Extend this table with your own rows as you iterate!

CREATE OR REPLACE TABLE MERIDIAN_TEAM_A_DB.ANALYTICS.AGENT_EVAL_STARTER AS
SELECT column1::VARCHAR AS query_text, PARSE_JSON(column2) AS ground_truth
FROM VALUES

  -- Row 1: Structured fact — tests that the agent uses sales_analyst and returns the correct number.
  ('What was our total revenue?',
   $${"ground_truth_output":"Total revenue is $1,090,817.86 from completed and shipped orders (excludes returned and cancelled orders). A value within 1% of this figure is acceptable. The answer should be sourced from sales data, not support tickets.","ground_truth_invocations":[{"tool_name":"sales_analyst"}]}$$),

  -- Row 2: Out-of-scope refusal — tests that the agent politely declines and calls NO tools.
  -- ground_truth_invocations is [] (empty array): the agent should make zero tool calls.
  ('What is the weather forecast for New York this week?',
   $${"ground_truth_output":"The agent should decline this question — weather is outside its scope. It should state it can help with Meridian Commerce sales analytics and customer support questions, and must NOT fabricate a weather forecast or temperatures.","ground_truth_invocations":[]}$$),

  -- Row 3: Combined question — tests that the agent uses BOTH tools to form a complete answer.
  ('Which product category has the highest return rate, and what themes show up in customer support tickets about returns?',
   $${"ground_truth_output":"Beauty has the highest return rate (approximately 13%), followed by Toys and Home & Kitchen. The answer should be sourced from sales data (return rate by category) AND from support tickets (common themes in return tickets, such as fit/sizing issues and product quality defects). An answer that only uses one tool is incomplete.","ground_truth_invocations":[{"tool_name":"sales_analyst"},{"tool_name":"support_search"}]}$$);
