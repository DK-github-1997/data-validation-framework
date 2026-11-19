-- SCD Type 2 dimension integrity checks (Oracle SQL)
-- Purpose: identify invalid effective-date ranges, overlapping versions,
-- multiple current rows, and current-flag inconsistencies.
--
-- Example schema assumptions:
--   DIM_CUSTOMER_SCD2(
--     CUSTOMER_SK NUMBER, CUSTOMER_ID NUMBER,
--     EFFECTIVE_START_DATE DATE, EFFECTIVE_END_DATE DATE,
--     CURRENT_FLAG CHAR(1)
--   )
--   CUSTOMER_SK is a unique surrogate key.
--   Validity intervals are half-open: [EFFECTIVE_START_DATE, EFFECTIVE_END_DATE).
--   DATE '9999-12-31' is the configured end-date sentinel for the current row.
-- Adjust the sample object names and sentinel to match the target warehouse.
--
-- Read-only validation: this query does not modify dimension records.

WITH base AS (
    SELECT
        customer_sk,
        customer_id,
        effective_start_date,
        effective_end_date,
        current_flag
    FROM dim_customer_scd2
),
valid_periods AS (
    SELECT
        customer_sk,
        customer_id,
        effective_start_date,
        effective_end_date
    FROM base
    WHERE effective_start_date IS NOT NULL
      AND effective_end_date IS NOT NULL
      AND effective_start_date < effective_end_date
),
violations AS (
    SELECT
        'NULL_BUSINESS_KEY' AS check_name,
        customer_id,
        customer_sk AS record_id,
        CAST(NULL AS NUMBER) AS related_record_id,
        'CUSTOMER_ID is NULL' AS issue_detail,
        'BLOCKER' AS severity
    FROM base
    WHERE customer_id IS NULL

    UNION ALL

    SELECT
        'INVALID_EFFECTIVE_RANGE',
        customer_id,
        customer_sk,
        CAST(NULL AS NUMBER),
        CASE
            WHEN effective_start_date IS NULL THEN 'EFFECTIVE_START_DATE is NULL'
            WHEN effective_end_date IS NULL THEN 'EFFECTIVE_END_DATE is NULL'
            ELSE 'START_DATE must be earlier than END_DATE'
        END,
        'BLOCKER'
    FROM base
    WHERE effective_start_date IS NULL
       OR effective_end_date IS NULL
       OR effective_start_date >= effective_end_date

    UNION ALL

    SELECT
        'MULTIPLE_CURRENT_ROWS',
        customer_id,
        CAST(NULL AS NUMBER),
        CAST(NULL AS NUMBER),
        'CURRENT_ROW_COUNT=' ||
            TO_CHAR(SUM(CASE WHEN current_flag = 'Y' THEN 1 ELSE 0 END)),
        'BLOCKER'
    FROM base
    GROUP BY customer_id
    HAVING SUM(CASE WHEN current_flag = 'Y' THEN 1 ELSE 0 END) > 1

    UNION ALL

    SELECT
        'OVERLAPPING_EFFECTIVE_PERIODS',
        a.customer_id,
        a.customer_sk,
        b.customer_sk,
        'Effective-date intervals overlap',
        'BLOCKER'
    FROM valid_periods a
    JOIN valid_periods b
      ON b.customer_id = a.customer_id
     AND a.customer_sk < b.customer_sk
     AND a.effective_start_date < b.effective_end_date
     AND b.effective_start_date < a.effective_end_date

    UNION ALL

    SELECT
        'INVALID_CURRENT_FLAG',
        customer_id,
        customer_sk,
        CAST(NULL AS NUMBER),
        'CURRENT_FLAG must be Y or N',
        'BLOCKER'
    FROM base
    WHERE current_flag IS NULL
       OR current_flag NOT IN ('Y', 'N')

    UNION ALL

    SELECT
        'CURRENT_FLAG_END_DATE_MISMATCH',
        customer_id,
        customer_sk,
        CAST(NULL AS NUMBER),
        'Current flag does not match the configured end-date sentinel',
        'BLOCKER'
    FROM base
    WHERE (current_flag = 'Y'
           AND effective_end_date <> DATE '9999-12-31')
       OR (current_flag = 'N'
           AND effective_end_date = DATE '9999-12-31')
)
SELECT
    check_name,
    customer_id,
    record_id,
    related_record_id,
    issue_detail,
    severity,
    'FAIL' AS check_result
FROM violations
ORDER BY
    check_name,
    customer_id,
    record_id,
    related_record_id;

-- Operational guidance:
-- 1. Expect no rows when all SCD Type 2 integrity checks pass.
-- 2. Correct invalid ranges before investigating overlap findings.
-- 3. The overlap predicate uses half-open intervals, so a row ending exactly
--    when the next row starts is valid and is not reported as an overlap.
-- 4. A business key may legitimately have no current row when the entity is
--    retired; this query checks multiple current rows, not mandatory existence.
-- 5. Run after the dimension load completes and retain findings with the batch
--    audit record for troubleshooting and release validation.
