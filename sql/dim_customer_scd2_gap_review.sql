-- Oracle SQL: review gaps between consecutive SCD Type 2 versions.
-- Complements dim_customer_scd2_integrity_check.sql by identifying periods
-- where one version ends before the next version begins.
--
-- Assumptions:
--   DIM_CUSTOMER_SCD2(CUSTOMER_SK, CUSTOMER_ID,
--     EFFECTIVE_START_DATE, EFFECTIVE_END_DATE, CURRENT_FLAG)
--   Validity intervals are half-open: [start_date, end_date).
--   DATE '9999-12-31' is the configured current-row end-date sentinel.
--
-- Read-only review query. A gap is a REVIEW finding, not automatically a defect:
-- inactive periods, terminated relationships, or source-system inactivity may
-- legitimately create gaps. Confirm the business rule before treating it as a
-- load blocker.

WITH valid_versions AS (
    SELECT
        customer_sk,
        customer_id,
        effective_start_date,
        effective_end_date,
        current_flag
    FROM dim_customer_scd2
    WHERE customer_id IS NOT NULL
      AND effective_start_date IS NOT NULL
      AND effective_end_date IS NOT NULL
      AND effective_start_date < effective_end_date
),
sequenced_versions AS (
    SELECT
        customer_sk,
        customer_id,
        effective_start_date,
        effective_end_date,
        current_flag,
        LEAD(customer_sk) OVER (
            PARTITION BY customer_id
            ORDER BY effective_start_date, customer_sk
        ) AS next_customer_sk,
        LEAD(effective_start_date) OVER (
            PARTITION BY customer_id
            ORDER BY effective_start_date, customer_sk
        ) AS next_start_date
    FROM valid_versions
)
SELECT
    customer_id,
    customer_sk AS previous_customer_sk,
    effective_start_date AS previous_start_date,
    effective_end_date AS previous_end_date,
    next_customer_sk,
    next_start_date,
    next_start_date - effective_end_date AS gap_days,
    'REVIEW' AS finding_severity,
    'Confirm whether the business key was legitimately inactive' AS review_action
FROM sequenced_versions
WHERE next_start_date IS NOT NULL
  AND effective_end_date < next_start_date
ORDER BY customer_id, effective_start_date;

-- Interpretation:
-- 1. No rows means no gaps were found between the valid consecutive versions.
-- 2. end_date = next_start_date is continuous under the half-open interval rule.
-- 3. end_date > next_start_date is an overlap; use the companion integrity check.
-- 4. Invalid or NULL date ranges are excluded here and must be handled by the
--    companion integrity check before relying on this gap review.
-- 5. Retain the result with the ETL batch ID and investigate only against the
--    source history and the dimension's agreed business-effective-date rules.
