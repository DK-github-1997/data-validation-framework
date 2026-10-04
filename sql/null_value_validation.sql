-- Null-value validation for mandatory business columns.
-- Returns only rows that require investigation.

SELECT
    COUNT(*) AS invalid_row_count,
    CASE
        WHEN COUNT(*) = 0 THEN 'PASS'
        ELSE 'FAIL'
    END AS validation_status
FROM target_customer
WHERE customer_id IS NULL
   OR customer_status IS NULL
   OR business_date IS NULL;

-- Optional diagnostic detail:
SELECT
    COUNT(*) AS null_customer_id_rows
FROM target_customer
WHERE customer_id IS NULL;
