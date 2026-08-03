#Architecture/Flow for data validation
# author Dnyaneshvar Khairnar
    

sql/
│
├── ddl/
│   ├── 01_create_dimension_tables.sql
│   ├── 02_create_fact_table.sql
│   ├── 03_constraints.sql
│   ├── 04_indexes.sql
│   ├── 05_views.sql
│   └── 06_materialized_views.sql
│
├── dml/
│   ├── 01_load_dim_customer.sql
│   ├── 02_load_dim_product.sql
│   ├── 03_load_dim_date.sql
│   ├── 04_load_dim_region.sql
│   ├── 05_load_fact_sales.sql
│   └── 06_incremental_load.sql
│
├── procedures/
│   ├── load_sales_dw.sql
│   ├── merge_customer_scd.sql
│   └── etl_logging.sql
│
├── analytics/
│   ├── sales_analysis.sql
│   ├── customer_analysis.sql
│   ├── region_analysis.sql
│   ├── product_analysis.sql
│   └── dashboard_queries.sql
│
├── validation/
│   ├── pre_deployment_validation.sql
│   ├── post_deployment_validation.sql
│   ├── data_reconciliation.sql
│   ├── data_quality_checks.sql
│   ├── foreign_key_validation.sql
│   ├── row_count_validation.sql
│   ├── duplicate_validation.sql
│   ├── null_validation.sql
│   └── business_validation.sql
│
└── utility/
    ├── cleanup.sql
    ├── truncate_tables.sql
    └── rollback.sql


---

# 📋 validation/pre_deployment_validation.sql


-- Source Row Count
SELECT COUNT(*) AS source_count
FROM stg_sales;

-- Duplicate Orders
SELECT order_id,
       COUNT(*)
FROM stg_sales
GROUP BY order_id
HAVING COUNT(*)>1;

-- Null Validation
SELECT *
FROM stg_sales
WHERE customer_id IS NULL
OR product_id IS NULL
OR sales_amount IS NULL;

-- Negative Sales
SELECT *
FROM stg_sales
WHERE sales_amount<0;

-- Invalid Quantity
SELECT *
FROM stg_sales
WHERE quantity<=0;
```

---

# 📋 validation/post_deployment_validation.sql


-- Target Row Count
SELECT COUNT(*)
FROM fact_sales;

-- Foreign Key Validation
SELECT *
FROM fact_sales f
WHERE NOT EXISTS
(
SELECT 1
FROM dim_customer c
WHERE c.customer_id=f.customer_id
);

-- Duplicate Orders
SELECT order_id,
COUNT(*)
FROM fact_sales
GROUP BY order_id
HAVING COUNT(*)>1;

-- Null Check
SELECT *
FROM fact_sales
WHERE customer_id IS NULL
OR product_id IS NULL
OR date_id IS NULL;

-- Revenue Validation
SELECT SUM(sales_amount)
FROM fact_sales;
```

---

# 📋 validation/data_reconciliation.sql




-- Row Count
SELECT
(SELECT COUNT(*) FROM stg_sales) Source_Count,
(SELECT COUNT(*) FROM fact_sales) Target_Count
FROM dual;

-- Revenue Comparison
SELECT
(SELECT SUM(sales_amount) FROM stg_sales) Source_Revenue,
(SELECT SUM(sales_amount) FROM fact_sales) Target_Revenue
FROM dual;

-- Customer Count
SELECT
COUNT(DISTINCT customer_id)
FROM stg_sales;

SELECT
COUNT(DISTINCT customer_id)
FROM fact_sales;

-- Product Count
SELECT
COUNT(DISTINCT product_id)
FROM stg_sales;

SELECT
COUNT(DISTINCT product_id)
FROM fact_sales;
```

---

# 📋 validation/data_quality_checks.sql


-- Duplicate Customers
SELECT customer_id,
COUNT(*)
FROM dim_customer
GROUP BY customer_id
HAVING COUNT(*)>1;

-- Duplicate Products
SELECT product_id,
COUNT(*)
FROM dim_product
GROUP BY product_id
HAVING COUNT(*)>1;

-- Invalid Prices
SELECT *
FROM dim_product
WHERE price<=0;

-- Future Dates
SELECT *
FROM dim_date
WHERE full_date>SYSDATE;

-- Negative Quantity
SELECT *
FROM fact_sales
WHERE quantity<=0;

-- Negative Revenue
SELECT *
FROM fact_sales
WHERE sales_amount<0;
```

---

# 📋 validation/foreign_key_validation.sql


-- Customer Validation
SELECT *
FROM fact_sales f
LEFT JOIN dim_customer c
ON f.customer_id=c.customer_id
WHERE c.customer_id IS NULL;

-- Product Validation
SELECT *
FROM fact_sales f
LEFT JOIN dim_product p
ON f.product_id=p.product_id
WHERE p.product_id IS NULL;

-- Date Validation
SELECT *
FROM fact_sales f
LEFT JOIN dim_date d
ON f.date_id=d.date_id
WHERE d.date_id IS NULL;

-- Region Validation
SELECT *
FROM fact_sales f
LEFT JOIN dim_region r
ON f.region_id=r.region_id
WHERE r.region_id IS NULL;
```

---

# 📋 validation/business_validation.sql


-- Monthly Revenue
SELECT
d.month_name,
SUM(f.sales_amount)
FROM fact_sales f
JOIN dim_date d
ON f.date_id=d.date_id
GROUP BY d.month_name;

-- Region Revenue
SELECT
r.region_name,
SUM(f.sales_amount)
FROM fact_sales f
JOIN dim_region r
ON f.region_id=r.region_id
GROUP BY r.region_name;

-- Top Products
SELECT
p.product_name,
SUM(f.sales_amount) revenue
FROM fact_sales f
JOIN dim_product p
ON f.product_id=p.product_id
GROUP BY p.product_name
ORDER BY revenue DESC;

-- Top Customers
SELECT
c.customer_name,
SUM(f.sales_amount) revenue
FROM fact_sales f
JOIN dim_customer c
ON f.customer_id=c.customer_id
GROUP BY c.customer_name
ORDER BY revenue DESC;
```

---

# 📋 utility/truncate_tables.sql


TRUNCATE TABLE fact_sales;

TRUNCATE TABLE dim_customer;

TRUNCATE TABLE dim_product;

TRUNCATE TABLE dim_date;

TRUNCATE TABLE dim_region;
```

---

# 📋 utility/cleanup.sql


DELETE FROM fact_sales;
DELETE FROM dim_customer;
DELETE FROM dim_product;
DELETE FROM dim_date;
DELETE FROM dim_region;

COMMIT;
```

---

# 📋 analytics/dashboard_queries.sql


-- KPI 1
SELECT SUM(sales_amount) Total_Revenue
FROM fact_sales;

-- KPI 2
SELECT COUNT(DISTINCT customer_id) Customers
FROM fact_sales;

-- KPI 3
SELECT COUNT(order_id) Orders
FROM fact_sales;

-- KPI 4
SELECT AVG(sales_amount) Average_Order_Value
FROM fact_sales;

