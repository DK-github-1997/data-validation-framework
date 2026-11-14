-- Incremental-load idempotency pre-check (Oracle SQL)
-- Purpose: detect duplicate source business keys and target collisions before
-- an incremental batch is inserted or merged.
--
-- Example schema assumptions:
--   STG_POLICY_TRANSACTIONS(
--     LOAD_BATCH_ID, TRANSACTION_ID, POLICY_ID, TRANSACTION_DATE, PREMIUM_AMOUNT
--   )
--   FACT_POLICY_TRANSACTIONS(
--     LOAD_BATCH_ID, TRANSACTION_ID, POLICY_ID, TRANSACTION_DATE, PREMIUM_AMOUNT
--   )
--   TRANSACTION_ID is the business key and is protected by a target unique key.
-- Run with :p_batch_id bound to the batch being processed.
--
-- This is a read-only pre-check. It does not insert, update, delete, or retry data.

WITH source_batch AS (
    SELECT
        transaction_id,
        policy_id,
        transaction_date,
        premium_amount
    FROM stg_policy_transactions
    WHERE load_batch_id = :p_batch_id
),
source_duplicate_keys AS (
    SELECT transaction_id
    FROM source_batch
    GROUP BY transaction_id
    HAVING COUNT(*) > 1
),
target_matches AS (
    SELECT
        s.transaction_id,
        CASE
            -- DECODE treats two NULL values as equal in Oracle.
            WHEN DECODE(s.policy_id, t.policy_id, 1, 0) = 1
             AND DECODE(s.transaction_date, t.transaction_date, 1, 0) = 1
             AND DECODE(s.premium_amount, t.premium_amount, 1, 0) = 1
                THEN 0
            ELSE 1
        END AS payload_mismatch
    FROM source_batch s
    JOIN fact_policy_transactions t
      ON t.transaction_id = s.transaction_id
),
source_stats AS (
    SELECT COUNT(*) AS source_row_count
    FROM source_batch
),
target_batch_stats AS (
    SELECT COUNT(*) AS target_batch_row_count
    FROM fact_policy_transactions
    WHERE load_batch_id = :p_batch_id
),
checks AS (
    SELECT
        'SOURCE_BATCH_EMPTY' AS check_name,
        CASE WHEN source_row_count = 0 THEN 1 ELSE 0 END AS issue_count,
        'BLOCKER' AS severity
    FROM source_stats

    UNION ALL

    SELECT
        'SOURCE_DUPLICATE_BUSINESS_KEYS',
        COUNT(*),
        'BLOCKER'
    FROM source_duplicate_keys

    UNION ALL

    SELECT
        'TARGET_KEY_PAYLOAD_MISMATCH',
        COUNT(*),
        'BLOCKER'
    FROM target_matches
    WHERE payload_mismatch = 1

    UNION ALL

    SELECT
        'SAME_KEY_SAME_PAYLOAD_ALREADY_PRESENT',
        COUNT(*),
        'REVIEW'
    FROM target_matches
    WHERE payload_mismatch = 0

    UNION ALL

    SELECT
        'BATCH_ID_ALREADY_PRESENT',
        target_batch_row_count,
        'REVIEW'
    FROM target_batch_stats
)
SELECT
    check_name,
    issue_count,
    severity,
    CASE
        WHEN issue_count = 0 THEN 'PASS'
        WHEN severity = 'BLOCKER' THEN 'BLOCK_LOAD'
        ELSE 'REVIEW_BEFORE_RETRY'
    END AS check_result
FROM checks
ORDER BY
    CASE severity WHEN 'BLOCKER' THEN 1 ELSE 2 END,
    check_name;

-- Operational guidance:
-- 1. Stop the load for any BLOCK_LOAD result; correct source duplicates or
--    investigate a business-key collision before proceeding.
-- 2. For REVIEW results, compare the prior batch/run audit and decide whether
--    to skip already-present rows or reconcile a partial earlier attempt.
-- 3. Keep a UNIQUE constraint on the target business key; this query is not a
--    substitute for database-enforced uniqueness or transaction control.
-- 4. Re-run the pre-check immediately before the load to reduce race windows.
-- 5. Validate source/target row counts and business totals after the load.
