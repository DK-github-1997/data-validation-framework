-- Source-to-target amount reconciliation
-- Portfolio example: identify amount differences after an ETL load.
-- Replace table/column names with project-specific objects.

WITH source_totals AS (
    SELECT business_date,
           SUM(amount) AS source_amount
    FROM source_transactions
    GROUP BY business_date
),
target_totals AS (
    SELECT business_date,
           SUM(amount) AS target_amount
    FROM target_transactions
    GROUP BY business_date
)
SELECT COALESCE(s.business_date, t.business_date) AS business_date,
       NVL(s.source_amount, 0) AS source_amount,
       NVL(t.target_amount, 0) AS target_amount,
       ROUND(NVL(t.target_amount, 0) - NVL(s.source_amount, 0), 2) AS amount_difference,
       CASE
           WHEN ABS(NVL(t.target_amount, 0) - NVL(s.source_amount, 0)) < 0.01
               THEN 'PASS'
           ELSE 'FAIL'
       END AS reconciliation_status
FROM source_totals s
FULL OUTER JOIN target_totals t
  ON s.business_date = t.business_date
ORDER BY business_date;
