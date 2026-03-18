-- ═══════════════════════════════════════════════
-- Project 1: Customer Segmentation & Retention
-- Dataset:   Olist Brazilian E-Commerce (Kaggle)
-- Phase 2:   Customer Behaviour Metrics
-- Queries:   Q4 Lifetime Metrics, Q5 Days Between
--            Purchases, Q6 Review Scores

-- ═══════════════════════════════════════════════
-- Q4: Customer lifetime metrics
-- Total orders, spend, AOV per customer
-- ═══════════════════════════════════════════════

SELECT
    c.customer_unique_id,
    COUNT(DISTINCT o.order_id)                          AS total_orders,
    ROUND(SUM(i.price + i.freight_value), 2)            AS total_spend,
    ROUND(SUM(i.price + i.freight_value) 
          / COUNT(DISTINCT o.order_id), 2)              AS avg_order_value,
    MIN(o.order_purchase_timestamp)                     AS first_order_date,
    MAX(o.order_purchase_timestamp)                     AS last_order_date,
    DATEDIFF(
        MAX(o.order_purchase_timestamp),
        MIN(o.order_purchase_timestamp)
    )                                                   AS customer_lifespan_days
FROM olist_customers_dataset c
JOIN olist_orders_dataset o 
    ON c.customer_id = o.customer_id
JOIN olist_order_items_dataset i 
    ON o.order_id = i.order_id
WHERE o.order_status = 'delivered'
GROUP BY c.customer_unique_id
ORDER BY total_spend DESC
LIMIT 20;

-- ═══════════════════════════════════════════════
-- Q5: Inter-purchase interval per customer
-- Only meaningful for repeat buyers
-- ═══════════════════════════════════════════════

WITH ranked_orders AS (
    SELECT
        c.customer_unique_id,
        o.order_purchase_timestamp                          AS order_date,
        ROW_NUMBER() OVER (
            PARTITION BY c.customer_unique_id
            ORDER BY o.order_purchase_timestamp
        )                                                   AS order_rank,
        LAG(o.order_purchase_timestamp) OVER (
            PARTITION BY c.customer_unique_id
            ORDER BY o.order_purchase_timestamp
        )                                                   AS prev_order_date
    FROM olist_customers_dataset c
    JOIN olist_orders_dataset o 
        ON c.customer_id = o.customer_id
    WHERE o.order_status = 'delivered'
),
intervals AS (
    SELECT
        customer_unique_id,
        order_rank,
        order_date,
        prev_order_date,
        DATEDIFF(order_date, prev_order_date)               AS days_since_prev_order
    FROM ranked_orders
    WHERE prev_order_date IS NOT NULL
)
SELECT
    customer_unique_id,
    COUNT(*)                                                AS repeat_purchase_count,
    ROUND(AVG(days_since_prev_order), 0)                   AS avg_days_between_orders,
    MIN(days_since_prev_order)                             AS min_days_between_orders,
    MAX(days_since_prev_order)                             AS max_days_between_orders
FROM intervals
GROUP BY customer_unique_id
ORDER BY repeat_purchase_count DESC
LIMIT 20;
-- ═══════════════════════════════════════════════
-- Q6: Avg review score per customer
-- Satisfaction signal for churn correlation later
-- ═══════════════════════════════════════════════

WITH customer_reviews AS (
    SELECT
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id)                          AS total_orders,
        COUNT(r.review_score)                               AS reviews_given,
        ROUND(AVG(r.review_score), 2)                       AS avg_review_score,
        SUM(CASE WHEN r.review_score <= 2 THEN 1 ELSE 0 END) AS low_score_count,
        SUM(CASE WHEN r.review_score = 5 THEN 1 ELSE 0 END)  AS five_star_count
    FROM olist_customers_dataset c
    JOIN olist_orders_dataset o 
        ON c.customer_id = o.customer_id
    LEFT JOIN olist_order_reviews_dataset r 
        ON o.order_id = r.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
)
SELECT
    avg_review_score,
    COUNT(*)                                                AS customer_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2)    AS pct_of_customers
FROM customer_reviews
WHERE reviews_given > 0
GROUP BY avg_review_score
ORDER BY avg_review_score DESC;
