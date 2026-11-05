-- Source-to-target data freshness SLA check (Oracle SQL)
-- Purpose: flag when the target's latest business update timestamp is behind
-- the source by more than the agreed freshness threshold.
--
-- Example assumptions:
--   SOURCE_SCHEMA.SOURCE_TABLE and TARGET_SCHEMA.TARGET_TABLE both contain
--   LAST_UPDATE_TS columns of type DATE.
--   Adjust object names, column names, and SLA minutes for your environment.

WITH parameters AS (
    SELECT 60 AS max_lag_minutes
    FROM dual
),
source_watermark AS (
    SELECT MAX(last_update_ts) AS source_max_update_ts
    FROM source_schema.source_table
),
target_watermark AS (
    SELECT MAX(last_update_ts) AS target_max_update_ts
    FROM target_schema.target_table
),
comparison AS (
    SELECT
        s.source_max_update_ts,
        t.target_max_update_ts,
        p.max_lag_minutes,
        CASE
            WHEN s.source_max_update_ts IS NULL THEN NULL
            WHEN t.target_max_update_ts IS NULL THEN NULL
            ELSE ROUND(
                (CAST(s.source_max_update_ts AS DATE)
                 - CAST(t.target_max_update_ts AS DATE)) * 24 * 60,
                2
            )
        END AS source_target_lag_minutes
    FROM source_watermark s
    CROSS JOIN target_watermark t
    CROSS JOIN parameters p
)
SELECT
    source_max_update_ts,
    target_max_update_ts,
    max_lag_minutes,
    source_target_lag_minutes,
    CASE
        WHEN source_max_update_ts IS NULL THEN 'NO_SOURCE_DATA'
        WHEN target_max_update_ts IS NULL THEN 'TARGET_EMPTY'
        WHEN source_target_lag_minutes < 0 THEN 'TARGET_AHEAD_REVIEW'
        WHEN source_target_lag_minutes > max_lag_minutes THEN 'FAIL_STALE'
        ELSE 'PASS'
    END AS freshness_status
FROM comparison;

-- Operational guidance:
-- 1. Run after the expected ETL completion window, not while a load is in progress.
-- 2. A negative lag means the target timestamp is ahead of the source; verify
--    timezone consistency, source corrections, and target backfills.
-- 3. A PASS confirms timestamp freshness only; pair it with row-count and
--    business-key reconciliation to validate completeness and correctness.
-- 4. Replace the sample 60-minute SLA with the dataset's agreed business SLA.
