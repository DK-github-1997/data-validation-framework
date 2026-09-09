-- Duplicate validation by business key
-- Purpose: identify duplicate records before/after ETL processing.
-- Oracle SQL

SELECT
    customer_id,
    policy_id,
    COUNT(*) AS duplicate_count
FROM target_data
GROUP BY
    customer_id,
    policy_id
HAVING COUNT(*) > 1
ORDER BY duplicate_count DESC;

-- Expected result: no rows when the business key is unique.
