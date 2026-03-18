Use new_schema;

-- ═══════════════════════════════════════════════
-- Project 1: Customer Segmentation & Retention
-- Dataset:   Olist Brazilian E-Commerce (Kaggle)
-- Phase 1:   Data Exploration & Quality Check
-- Queries:   Q1 Null Check, Q2 Date Range, 
--            Q3 Join Integrity

-- ═══════════════════════════════════════════════
-- Q1: Row counts & null check across all 5 tables
-- ═══════════════════════════════════════════════

SELECT 'orders' AS table_name,
       COUNT(*) AS total_rows,
       SUM(CASE WHEN customer_id IS NULL THEN 1 ELSE 0 END) AS null_customer_id,
       SUM(CASE WHEN order_status IS NULL THEN 1 ELSE 0 END) AS null_status,
       SUM(CASE WHEN order_purchase_timestamp IS NULL THEN 1 ELSE 0 END) AS null_purchase_date,
       SUM(CASE WHEN order_delivered_customer_date IS NULL THEN 1 ELSE 0 END) AS null_delivery_date
FROM olist_orders_dataset

UNION ALL

SELECT 'order_items',
       COUNT(*),
       SUM(CASE WHEN order_id IS NULL THEN 1 ELSE 0 END),
       SUM(CASE WHEN product_id IS NULL THEN 1 ELSE 0 END),
       SUM(CASE WHEN price IS NULL THEN 1 ELSE 0 END),
       SUM(CASE WHEN freight_value IS NULL THEN 1 ELSE 0 END)
FROM olist_order_items_dataset

UNION ALL

SELECT 'customers',
       COUNT(*),
       SUM(CASE WHEN customer_id IS NULL THEN 1 ELSE 0 END),
       SUM(CASE WHEN customer_unique_id IS NULL THEN 1 ELSE 0 END),
       SUM(CASE WHEN customer_state IS NULL THEN 1 ELSE 0 END),
       0
FROM olist_customers_dataset

UNION ALL

SELECT 'reviews',
       COUNT(*),
       SUM(CASE WHEN order_id IS NULL THEN 1 ELSE 0 END),
       SUM(CASE WHEN review_score IS NULL THEN 1 ELSE 0 END),
       SUM(CASE WHEN review_creation_date IS NULL THEN 1 ELSE 0 END),
       0
FROM olist_order_reviews_dataset

UNION ALL

SELECT 'products',
       COUNT(*),
       SUM(CASE WHEN product_id IS NULL THEN 1 ELSE 0 END),
       SUM(CASE WHEN product_category_name IS NULL THEN 1 ELSE 0 END),
       0,
       0
FROM olist_products_dataset;

-- ═══════════════════════════════════════════════
-- Q2: Date range & order status distribution
-- ═══════════════════════════════════════════════

SELECT
    MIN(order_purchase_timestamp)                    AS earliest_order,
    MAX(order_purchase_timestamp)                    AS latest_order,
    DATEDIFF(
        MAX(order_purchase_timestamp),
        MIN(order_purchase_timestamp)
    )                                                AS date_span_days,
    COUNT(*)                                         AS total_orders,
    COUNT(DISTINCT customer_id)                      AS unique_customers
FROM olist_orders_dataset;

-- Status breakdown
SELECT
    order_status,
    COUNT(*)                                         AS order_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS pct_of_total
FROM olist_orders_dataset
GROUP BY order_status
ORDER BY order_count DESC;

-- ═══════════════════════════════════════════════
-- Q3: Join integrity check across tables
-- ═══════════════════════════════════════════════

-- Orders with no matching customer
SELECT 'orders → customers' AS join_check,
       COUNT(*) AS orphaned_records
FROM olist_orders_dataset o
LEFT JOIN olist_customers_dataset c ON o.customer_id = c.customer_id
WHERE c.customer_id IS NULL

UNION ALL

-- Orders with no matching items
SELECT 'orders → items',
       COUNT(*)
FROM olist_orders_dataset o
LEFT JOIN olist_order_items_dataset i ON o.order_id = i.order_id
WHERE i.order_id IS NULL

UNION ALL

-- Orders with no matching review
SELECT 'orders → reviews',
       COUNT(*)
FROM olist_orders_dataset o
LEFT JOIN olist_order_reviews_dataset r ON o.order_id = r.order_id
WHERE r.order_id IS NULL

UNION ALL

-- Items with no matching product
SELECT 'items → products',
       COUNT(*)
FROM olist_order_items_dataset i
LEFT JOIN olist_products_dataset p ON i.product_id = p.product_id
WHERE p.product_id IS NULL;
