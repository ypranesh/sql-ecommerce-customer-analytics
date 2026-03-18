-- ═══════════════════════════════════════════════
-- Project 1: Customer Segmentation & Retention
-- Dataset:   Olist Brazilian E-Commerce (Kaggle)
-- Phase 4:   Churn Analysis
-- Queries:   Q10 Churn Flag, Q10b Churn Summary,
--            Q11 Churn by Category,
--            Q12 Delivery Delay vs Churn

-- ═══════════════════════════════════════════════
-- Q10: Churn flag per customer
-- Definition: no purchase in 180 days from last order
-- Reference date: 2018-10-18
-- ═══════════════════════════════════════════════

WITH delivered_orders AS (
    SELECT
        c.customer_unique_id,
        DATE(o.order_purchase_timestamp)                    AS order_day
    FROM olist_customers_dataset c
    JOIN olist_orders_dataset o
        ON c.customer_id = o.customer_id
    WHERE o.order_status = 'delivered'
),
customer_last_order AS (
    SELECT
        customer_unique_id,
        MAX(order_day)                                      AS last_order_date,
        COUNT(order_day)                                    AS total_orders,
        DATEDIFF('2018-10-18', MAX(order_day))              AS recency_days
    FROM delivered_orders
    GROUP BY customer_unique_id
)
SELECT
    customer_unique_id,
    last_order_date,
    total_orders,
    recency_days,
    CASE
        WHEN recency_days > 180 THEN '🔴 Churned'
        WHEN recency_days BETWEEN 90 AND 180 THEN '🟡 At Risk'
        ELSE '🟢 Active'
    END                                                     AS churn_status,
    CASE
        WHEN recency_days > 180 THEN 1 ELSE 0
    END                                                     AS is_churned
FROM customer_last_order
ORDER BY recency_days DESC
LIMIT 20;

-- ═══════════════════════════════════════════════
-- Q10b: Overall churn rate summary
-- ═══════════════════════════════════════════════

WITH delivered_orders AS (
    SELECT
        c.customer_unique_id,
        DATE(o.order_purchase_timestamp)                    AS order_day
    FROM olist_customers_dataset c
    JOIN olist_orders_dataset o
        ON c.customer_id = o.customer_id
    WHERE o.order_status = 'delivered'
),
customer_last_order AS (
    SELECT
        customer_unique_id,
        DATEDIFF('2018-10-18', MAX(order_day))              AS recency_days
    FROM delivered_orders
    GROUP BY customer_unique_id
)
SELECT
    CASE
        WHEN recency_days > 180 THEN '🔴 Churned'
        WHEN recency_days BETWEEN 90 AND 180 THEN '🟡 At Risk'
        ELSE '🟢 Active'
    END                                                     AS churn_status,
    COUNT(*)                                                AS customer_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2)      AS pct_of_customers
FROM customer_last_order
GROUP BY churn_status
ORDER BY customer_count DESC;

-- ═══════════════════════════════════════════════
-- Q11: Churn rate by product category
-- Which categories lose customers fastest?
-- ═══════════════════════════════════════════════

WITH delivered_orders AS (
    SELECT
        c.customer_unique_id,
        o.order_id,
        DATE(o.order_purchase_timestamp)                    AS order_day,
        p.product_category_name
    FROM olist_customers_dataset c
    JOIN olist_orders_dataset o
        ON c.customer_id = o.customer_id
    JOIN olist_order_items_dataset i
        ON o.order_id = i.order_id
    JOIN olist_products_dataset p
        ON i.product_id = p.product_id
    WHERE o.order_status = 'delivered'
        AND p.product_category_name IS NOT NULL
),
customer_category_last AS (
    SELECT
        customer_unique_id,
        product_category_name,
        MAX(order_day)                                      AS last_order_date,
        DATEDIFF('2018-10-18', MAX(order_day))              AS recency_days
    FROM delivered_orders
    GROUP BY customer_unique_id, product_category_name
)
SELECT
    product_category_name,
    COUNT(*)                                                AS total_customers,
    SUM(CASE WHEN recency_days > 180 THEN 1 ELSE 0 END)    AS churned_customers,
    ROUND(
        SUM(CASE WHEN recency_days > 180 THEN 1 ELSE 0 END)
        * 100.0 / COUNT(*), 2
    )                                                       AS churn_rate_pct
FROM customer_category_last
GROUP BY product_category_name
HAVING COUNT(*) >= 100                  -- exclude niche categories
ORDER BY churn_rate_pct DESC
LIMIT 15;

-- ═══════════════════════════════════════════════
-- Q12: Delivery delay vs churn correlation
-- Does a late delivery predict future churn?
-- ═══════════════════════════════════════════════

WITH delivery_data AS (
    SELECT
        c.customer_unique_id,
        o.order_id,
        DATE(o.order_purchase_timestamp)                    AS order_day,
        o.order_estimated_delivery_date,
        o.order_delivered_customer_date,
        DATEDIFF(
            o.order_delivered_customer_date,
            o.order_estimated_delivery_date
        )                                                   AS delivery_delta_days
    FROM olist_customers_dataset c
    JOIN olist_orders_dataset o
        ON c.customer_id = o.customer_id
    WHERE o.order_status = 'delivered'
        AND o.order_delivered_customer_date IS NOT NULL
        AND o.order_estimated_delivery_date IS NOT NULL
),
customer_delivery_profile AS (
    SELECT
        customer_unique_id,
        MAX(order_day)                                      AS last_order_date,
        DATEDIFF('2018-10-18', MAX(order_day))              AS recency_days,
        ROUND(AVG(delivery_delta_days), 1)                  AS avg_delivery_delta,
        SUM(CASE WHEN delivery_delta_days > 0 THEN 1 ELSE 0 END) AS late_deliveries,
        COUNT(order_id)                                     AS total_orders,
        CASE
            WHEN DATEDIFF('2018-10-18', MAX(order_day)) > 180
            THEN 1 ELSE 0
        END                                                 AS is_churned
    FROM delivery_data
    GROUP BY customer_unique_id
)
SELECT
    CASE
        WHEN avg_delivery_delta <= 0  THEN '✅ On Time or Early'
        WHEN avg_delivery_delta <= 7  THEN '🟡 Slightly Late (1-7 days)'
        WHEN avg_delivery_delta <= 14 THEN '🟠 Late (8-14 days)'
        ELSE                               '🔴 Very Late (15+ days)'
    END                                                     AS delivery_bucket,
    COUNT(*)                                                AS customer_count,
    ROUND(AVG(is_churned) * 100, 2)                        AS churn_rate_pct,
    ROUND(AVG(avg_delivery_delta), 1)                       AS avg_days_late,
    ROUND(AVG(recency_days), 0)                             AS avg_recency_days
FROM customer_delivery_profile
GROUP BY delivery_bucket
ORDER BY avg_days_late ASC;
