# Assignment

## Brief

Write the SQL statements for the following questions.

## Instructions

Write your SQL answers in the code blocks below each question. Check your work against the solution key at the bottom. To share your work, post in **#peer-reviews** on Discord. For questions, post in **#questions**.

### Question 1

Using the `claim` and `car` tables, write a SQL query to return a table containing `id, claim_date, travel_time, claim_amt` from `claim`, and `car_type, car_use` from `car`. Use an appropriate join based on the `car_id`.

Answer:

```sql
select
  cl.id,
  cl.claim_date,
  cl.travel_time,
  cl.claim_amt,
  c.car_type,
  c.car_use
from
  claim cl
  inner join car c on cl.car_id = c.id

```

### Question 2

Write a SQL query to compute the running total of the `travel_time` column for each `car_id` in the `claim` table. The resulting table should contain `id, car_id, travel_time, running_total`.

Answer:

```sql
 select
  id,
  car_id,
  travel_time,
  sum(travel_time) OVER (
    partition by car_id
    order by
      id
  ) as running_total
from
  claim
order by
  car_id
```

### Question 3

Using a Common Table Expression (CTE), write a SQL query to return a table containing `id, resale_value, car_use` from `car`, where the car resale value is less than the average resale value for the car use.

Answer:

```sql
with resale as (
    select
      car_use,
      avg (resale_value) as avg_resale_value
    from
      car
    GROUP by
      car_use
  )
SELECT
  c.id,
  c.resale_value,
  c.car_use,
  resale.avg_resale_value
from
  car c
  inner join resale on c.car_use = resale.car_use
where
  resale_value < avg_resale_value
order by
  c.id;
```

# **Level Up: The Insurance Auditor Project**

**Scenario:** You are the Lead Data Analyst for "SafeDrive Insurance". The CEO suspects that certain car types in specific cities are disproportionately expensive.

**Final Goal:** Build a single SQL script (using CTEs) that produces a table with: Client Name, State, Car Type, Total Claimed, State Rank — showing only the **top 2 highest-claiming clients per state**.

---

> ### 🪜 Stepping Stones — build the solution one layer at a time
>
> Don't try to write the full query in one go. Each step below produces a runnable query you can verify before moving to the next. If a step breaks, you only need to look at what just changed.

---

### Step 1 — Understand the landscape

Before writing any CTEs, answer these questions by running simple queries:

- How many unique `car_type` values are in the `car` table? (`SELECT DISTINCT car_type FROM car`)
- How many unique `state` values are in the `address` table?
- Do all clients have an address? (`SELECT COUNT(*) FROM client LEFT JOIN address ON client.address_id = address.id WHERE address.id IS NULL`)

Write those queries here:

```sql
-- Your exploration queries
SELECT
  DISTINCT car_type
from
  car;
SELECT
  count(DISTINCT state)
from
  address;
select
  count(*)
from
  client cli
  left join address a on cli.address_id = a.id
where
  a.id IS NULL;
```

---

### Step 2 — Market comparison (CTE 1)

**Human logic:** For every claim, we want to see its amount *and* the average amount for its car type side-by-side. We can't do this with `GROUP BY` (that would collapse all claims into one row per car type). We need a window function — `AVG() OVER (PARTITION BY car_type)` — which calculates the average per car type but keeps every individual claim row intact.

Write a query (no CTE yet) that joins `claim` and `car`, and adds a column `avg_claim_by_car_type` using a window function:

```sql
-- Step 2: Your query here

select
  cl.id,
  cl.client_id,
  c.car_type,
  cl.claim_amt,
  AVG (cl.claim_amt) over (partition by c.car_type) as avg_claim_by_car_type
from
  claim cl
  inner join car c on cl.car_id = c.id

```

<details>
<summary>💡 Step 2 hint</summary>

```sql
SELECT
    cl.id,
    cl.claim_amt,
    ca.car_type,
    AVG(cl.claim_amt) OVER (PARTITION BY ca.car_type) AS avg_claim_by_car_type
FROM claim cl
INNER JOIN car ca ON cl.car_id = ca.id;
```

**Check:** You should see the same `avg_claim_by_car_type` repeated across all rows with the same `car_type`. That's correct — every "Sedan" row shows the average for all Sedans.

</details>

---

### Step 3 — Client totals (CTE 2)

**Human logic:** The CEO wants to compare clients, not individual claims. A client with 10 small claims might matter more than a client with 1 large claim. So we need to *add up* all claims per client. This is a `GROUP BY` — we collapse claims into one row per client.

The catch: we can't do this in the same step as Step 2, because Step 2 uses a window function (which needs all rows), while this step uses `GROUP BY` (which collapses rows). We separate them into two CTEs.

Wrap your Step 2 query in a CTE called `market_comparison`, then write a second CTE called `client_totals` that groups by `client_id` and sums `claim_amt`:

```sql
-- Step 3: Your query here (MODEL ANSWER)
WITH market_comparison AS (
    -- paste Step 2 query here
),
client_totals AS (
    SELECT client_id, SUM(claim_amt) AS total_claimed
    FROM market_comparison
    GROUP BY client_id
)
SELECT * FROM client_totals LIMIT 10;

-- Step 3: my answer
with market_comparison AS (
    select
        cl.id,
        cl.client_id,
        c.car_type,
        cl.claim_amt,
        AVG (cl.claim_amt) over (partition by c.car_type) as avg_claim_by_car_type
    from
        claim cl
        inner join car c on cl.car_id = c.id
  ),
  client_totals AS (
  select 
        client_id,
        car_type,
        sum(claim_amt) as total_claimed
        
        from market_comparison 
        group by client_id, car_type --keeps car type for the report but means a client can appear once per car type
        
  )
  
select * from client_totals 
order by client_id

```

<details>
<summary>💡 Step 3 hint</summary>

```sql
WITH market_comparison AS (
    SELECT
        cl.id, cl.claim_amt, cl.client_id,
        ca.car_type,
        AVG(cl.claim_amt) OVER (PARTITION BY ca.car_type) AS avg_claim_by_car_type
    FROM claim cl
    INNER JOIN car ca ON cl.car_id = ca.id
),
client_totals AS (
    SELECT client_id, car_type, SUM(claim_amt) AS total_claimed
    FROM market_comparison
    GROUP BY client_id, car_type
)
SELECT * FROM client_totals LIMIT 10;
```

**Check:** Each row should represent one client. The same client_id should not appear twice.

</details>

---

### Step 4 — Add names and locations (CTE 3)

**Human logic:** Right now we only have client IDs and totals — no names or states. We need to join `client` (for the name) and `address` (for the state). This is a pure join step — no aggregation, no window functions.

Add a third CTE called `client_details` that joins `client_totals` to `client` and `address`:

```sql
-- Step 4: Add this CTE after client_totals
client_details AS (
    SELECT
        c.first_name || ' ' || c.last_name AS client_name,
        a.state,
        ct.car_type,
        ct.total_claimed
    FROM client_totals ct
    INNER JOIN client c ON ct.client_id = c.id
    INNER JOIN address a ON c.address_id = a.id
)
SELECT * FROM client_details LIMIT 10;

-- My answer:

with market_comparison AS (
    select
      cl.id,
      cl.client_id,
      c.car_type,
      cl.claim_amt,
      AVG (cl.claim_amt) over (partition by c.car_type) as avg_claim_by_car_type
    from
      claim cl
      inner join car c on cl.car_id = c.id
  ),
  client_totals AS (
    select
      client_id,
      car_type,
      sum(claim_amt) as total_claimed
    from
      market_comparison
    group by
      client_id,
      car_type --keeps car type for the report but means a client can appear once per car type
  ),
  client_details as (
    select
      c.id as client_id,
      c.first_name || ' ' || c.last_name as client_name,
      a.state,
      ct.car_type,
      ct.total_claimed
    from
      client_totals ct
      Inner join client c on ct.client_id = c.id
      inner join address a on c.address_id = a.id )
    select
      *
    from
      client_details
    order by client_id;
```

**Check:** You should now see client names and states alongside their totals.

---

### Step 5 — Rank within each state (CTE 4) and filter

**Human logic:** We want to find the top 2 clients *per state* — not the top 2 overall. This requires `RANK() OVER (PARTITION BY state ...)` to reset the ranking for each state. Once we have the rank column, we filter with `WHERE state_rank <= 2`.

**Why can't we just put `WHERE state_rank <= 2` directly?** Because `RANK()` is calculated after the data is assembled — `WHERE` runs too early, before the rank is computed. The solution: put the ranking in a CTE, then filter in the final `SELECT`.

Add a fourth CTE called `ranked_clients` and write the final SELECT:

```sql
-- Step 5: Complete query
ranked_clients AS (
    SELECT *,
        RANK() OVER (PARTITION BY state ORDER BY total_claimed DESC) AS state_rank
    FROM client_details
)
SELECT
    client_name AS "Client Name",
    state       AS "State",
    car_type    AS "Car Type",
    ROUND(total_claimed, 2) AS "Total Claimed",
    state_rank  AS "State Rank"
FROM ranked_clients
WHERE state_rank <= 2
ORDER BY state, state_rank;
```

---

**Submission:** Assemble all four CTEs into one script, save it as a `.sql` file with comments on each CTE explaining *why* it exists (not just what it does). Share in **#peer-reviews** on Discord, or keep it in your own notes if self-studying.

---

## **✅ Solutions**

*Attempt all questions before expanding the solutions below.*

<details>
<summary>Click to reveal — Questions 1–3 Solutions</summary>

### Question 1

**Why `INNER JOIN`?** We only want claims that have a matching car record. If a claim somehow had a `car_id` pointing to a non-existent car, an INNER JOIN automatically excludes it — keeping our results clean. The car's `id` and the claim's `car_id` are the shared key that connects the two tables.

```sql
SELECT 
    cl.id, 
    cl.claim_date, 
    cl.travel_time, 
    cl.claim_amt,
    c.car_type, 
    c.car_use 
FROM claim cl
INNER JOIN car c ON cl.car_id = c.id;
```

### Question 2

**Why `PARTITION BY car_id`?** Without `PARTITION BY`, the running total would keep growing across *all* cars — claims from Car 1 and Car 2 would pile into the same counter. `PARTITION BY car_id` tells the database: "Reset the total counter each time the car_id changes." Each car gets its own independent running total, like separate bank accounts.

**Why `ORDER BY id`?** A running total only makes sense if the rows are visited in a consistent order. `ORDER BY id` ensures we always add claims in the same sequence, giving us a stable, predictable total at each row.

```sql
SELECT 
    id,
    car_id,
    travel_time,
    SUM(travel_time) OVER (PARTITION BY car_id ORDER BY id) AS running_total
FROM claim;
```

### Question 3

**Why a CTE instead of a simple `WHERE`?** Because we can't calculate an average *and* filter by that same average in one step — SQL's execution order doesn't allow it (`WHERE` runs before `GROUP BY`, so the average doesn't exist yet when the filter tries to use it). The CTE solves this by splitting the work: Step 1 (inside `AvgResale`) calculates the average per `car_use`. Step 2 (the outer `SELECT`) uses that pre-calculated average as a filter. The CTE is just a named, reusable intermediate result.

```sql
WITH AvgResale AS (
    SELECT 
        car_use,
        AVG(resale_value) AS avg_resale_value
    FROM car
    GROUP BY car_use
)
SELECT 
    c.id,
    c.resale_value,
    c.car_use
FROM car c
JOIN AvgResale a ON c.car_use = a.car_use
WHERE c.resale_value < a.avg_resale_value;
```

</details>

<details>
<summary>Click to reveal — Level Up: Insurance Auditor Project Solution</summary>

### How would you attack this from a blank page?

Don't try to imagine the whole query at once. Decompose it:

- **Step 1 — read each requirement and ask: what is the smallest fact it needs?** Requirement 1 needs "average claim per car type" → that's one CTE. Requirement 2 needs "total claims per client" and then "rank within state" → that's a couple more.
- **Step 2 — build one CTE per requirement.** Write it, run it *alone* (`SELECT * FROM ...` on just that piece), and check the output looks sensible.
- **Step 3 — chain them.** Once each piece works, connect them with `WITH ... , ...` and write the final SELECT.

That is exactly how the solution below was built — it looks intimidating as a finished block, but it's just four small, individually-tested queries stacked together.

> **A subtlety to be aware of:** this solution groups by `(client_id, car_type)`, so a client who claims on two different car types appears twice, once per car type. That means the "top 2 per state" is really the top 2 *(client, car type)* combinations — your output can show the same client twice, which is why it may differ from a strict "top 2 clients" reading of the brief.

### Complete SQL Solution for Insurance Auditor Project

```sql
-- =============================================================================
-- SafeDrive Insurance: Comprehensive Claims Analysis Report
-- Lead Data Analyst: Insurance Auditor Project
-- Purpose: Identify high-risk clients by car type and state
-- =============================================================================

-- REQUIREMENT 1: Market Comparison
-- Calculate average claim amount for each car_type to establish market baseline
WITH market_comparison AS (
    SELECT 
        cl.id AS claim_id,
        cl.claim_amt,
        cl.car_id,
        cl.client_id,
        ca.car_type,
        -- Window function: Average claim amount per car type (Market Comparison)
        AVG(cl.claim_amt) OVER (PARTITION BY ca.car_type) AS avg_claim_by_car_type
    FROM claim cl
    INNER JOIN car ca ON cl.car_id = ca.id
),

-- REQUIREMENT 2: Aggregate total claims per client
-- Group claims by client to calculate total exposure per client
client_claim_totals AS (
    SELECT 
        mc.client_id,
        mc.car_type,
        -- Sum all claim amounts for each client
        SUM(mc.claim_amt) AS total_claimed
    FROM market_comparison mc
    GROUP BY mc.client_id, mc.car_type
),

-- Join client information to get name and state details
client_with_details AS (
    SELECT 
        c.id AS client_id,
        -- Concatenate first and last name for full client name
        c.first_name || ' ' || c.last_name AS client_name,
        a.state,
        cct.car_type,
        cct.total_claimed
    FROM client_claim_totals cct
    INNER JOIN client c ON cct.client_id = c.id
    INNER JOIN address a ON c.address_id = a.id
),

-- REQUIREMENT 2: Risk Ranking
-- Rank clients within each state by their total claim amounts
ranked_clients AS (
    SELECT 
        client_name,
        state,
        car_type,
        total_claimed,
        -- Window function: Rank clients within state (highest claims = rank 1)
        RANK() OVER (PARTITION BY state ORDER BY total_claimed DESC) AS state_rank
    FROM client_with_details
)

-- REQUIREMENT 3 & 4: Efficiency Filter + Final Output
-- Show only top 2 highest-claiming clients per state
SELECT 
    client_name AS "Client Name",
    state AS "State",
    car_type AS "Car Type",
    ROUND(total_claimed, 2) AS "Total Claimed",
    state_rank AS "State Rank"
FROM ranked_clients
-- Filter: Only top 2 clients per state (Efficiency requirement)
WHERE state_rank <= 2
ORDER BY state, state_rank;

-- =============================================================================
-- BUSINESS INSIGHTS FROM THIS QUERY:
-- 
-- 1. Market Comparison (CTE 1): Establishes baseline claim amounts by car type
--    to identify which vehicle categories are disproportionately expensive
-- 
-- 2. Risk Ranking (CTE 3 & 4): Identifies highest-risk clients within each 
--    state, enabling targeted investigation and risk management
-- 
-- 3. Efficiency (Final WHERE): Focuses executive attention on top 2 clients
--    per state, reducing noise and highlighting critical risk factors
-- 
-- 4. Geographic Analysis: State-level partitioning reveals regional patterns
--    that may indicate fraud, regional risk factors, or market anomalies
-- =============================================================================
```

## Technical Breakdown — Plain English

### Why four CTEs?

Each CTE solves one problem that must be solved before the next can begin. You can't skip steps because each step depends on the one before it.

| CTE | The problem it solves | Plain-English explanation |
|---|---|---|
| `market_comparison` | We need each claim's amount *and* the average for its car type in the same row | `AVG() OVER (PARTITION BY car_type)` calculates the average per car type but keeps every individual claim row intact — unlike `GROUP BY`, which would merge all claims into one row per type and lose the detail we need |
| `client_claim_totals` | We need one total per client, not one row per claim | `GROUP BY client_id` collapses multiple claim rows into a single "total claimed" row per client |
| `client_with_details` | We only have client IDs so far — we need names and states | A pure join step: no aggregation, just connecting client IDs to names and addresses |
| `ranked_clients` | We need to rank clients within each state | `RANK() OVER (PARTITION BY state ...)` gives rank 1 to the highest-claiming client in each state, rank 2 to the second, and so on. If two clients tie, they share the same rank and the next rank is skipped — so two clients tied at rank 1 are followed by rank 3, not rank 2 |

### Why not do it all in one query?

The two main operations — the window function (Step 1, needs all rows) and the `GROUP BY` (Step 2, collapses rows) — are incompatible in a single query step. You must calculate the window values first, then collapse. CTEs make this separation explicit and readable.

### Why `INNER JOIN` throughout?

We only want clients who have claims *and* have a valid address on record. If any link in the chain is missing (no car, no client, no address), the row is excluded. This keeps the output clean and trustworthy — every row in the final report is a complete, verified record.

## Expected Output Format 

| Client Name | State | Car Type | Total Claimed | State Rank |
|-------------|-------|----------|---------------|------------|
| John Smith  | CA    | Sedan    | 15000.00     | 1          |
| Jane Doe    | CA    | SUV      | 12500.00     | 2          |
| Bob Wilson  | NY    | Truck    | 18000.00     | 1          |
| Alice Brown | NY    | Sedan    | 14000.00     | 2          |

This solution directly addresses the CEO's concern about disproportionately expensive car types in specific cities by providing actionable insights into high-risk client profiles across geographic regions.

</details>
