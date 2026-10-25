with market_comparison AS (
  /* market_comparison: puts each claim next to its car type's average claim, so a claim can be judged against its peers. A window function is used instead of GROUP BY so every individual claim row is kept.
   (Note: avg_claim_by_car_type is not used in later CTEs.) */
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
  /* client_totals: the CEO wants to compare clients, not single claims,so claims are added up per client. Grouping by car_type as well keeps car type for the report, but a client can appear once per car type. */
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
  /*client_details: client_totals only has IDs. This joins client and address
   to get the name and state the report needs, and the state is required
   to rank within each state in the next step. */
  select
    c.id as client_id,
    c.first_name || ' ' || c.last_name as client_name,
    a.state,
    ct.car_type,
    ct.total_claimed
  from
    client_totals ct
    Inner join client c on ct.client_id = c.id
    inner join address a on c.address_id = a.id
),
ranked_clients as (
  /* ranked_clients: ranks clients within each state, highest total first.
   It must be a separate CTE because WHERE runs before window functions,
   so state_rank can only be filtered in the final SELECT.
   RANK() is used so clients with equal totals share a place. */
  select
    *,
    rank() over (
      partition by state
      order by
        total_claimed desc
    ) as state_rank
  from
    client_details
)
select
  /* Final output: top 2 per state, renamed to match the report format. */
  client_name as "Client Name",
  state as "State",
  car_type as "Car Type",
  round(total_claimed, 2) as "Total Claimed",
  state_rank as "State Rank"
from
  ranked_clients
where
  state_rank <= 2
order by
  state,
  state_rank;