-- Source-to-target row-count reconciliation by business date
-- Purpose: identify missing or unexpected rows after a batch/incremental load.
-- Replace the example table and column names with your environment's names.
-- Run after the target load has completed.

WITH source_counts AS (
    SELECT
        business_date,
        COUNT(*) AS source_row_count
    FROM source_schema.source_table
    WHERE business_date >= DATE '2026-10-01'
      AND business_date <  DATE '2026-11-01'
    GROUP BY business_date
),
target_counts AS (
    SELECT
        business_date,
        COUNT(*) AS target_row_count
    FROM target_schema.target_table
    WHERE business_date >= DATE '2026-10-01'
      AND business_date <  DATE '2026-11-01'
    GROUP BY business_date
)
SELECT
    COALESCE(s.business_date, t.business_date) AS business_date,
    COALESCE(s.source_row_count, 0) AS source_row_count,
    COALESCE(t.target_row_count, 0) AS target_row_count,
    COALESCE(t.target_row_count, 0)
        - COALESCE(s.source_row_count, 0) AS row_count_difference,
    CASE
        WHEN s.business_date IS NULL THEN 'TARGET_ONLY'
        WHEN t.business_date IS NULL THEN 'SOURCE_ONLY'
        WHEN s.source_row_count = t.target_row_count THEN 'PASS'
        ELSE 'FAIL'
    END AS reconciliation_status
FROM source_counts s
FULL OUTER JOIN target_counts t
    ON s.business_date = t.business_date
ORDER BY business_date;

-- Operational notes:
-- 1. Use the same business-date window and timezone on both sides.
-- 2. Investigate FAIL, SOURCE_ONLY, and TARGET_ONLY dates before closing the batch.
-- 3. Row counts alone do not prove record-level correctness; pair this with key and
--    amount/hash reconciliation where the business process requires it.
