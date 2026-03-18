-- ═══════════════════════════════════════════════
-- Project 1: Customer Segmentation & Retention
-- Dataset:   Olist Brazilian E-Commerce (Kaggle)
-- Phase 3:   RFM Segmentation
-- Queries:   Q7 RFM Raw, Q8 RFM Scoring,
--            Q9 Segment Labels, Q9b Segment Summary

-- ═══════════════════════════════════════════════
-- Q7: RFM raw values per customer
-- Recency, Frequency, Monetary base calculation
-- ═══════════════════════════════════════════════

WITH delivered_orders AS (
    SELECT
        c.customer_unique_id,
        o.order_id,
        o.order_purchase_timestamp,
        i.price + i.freight_value                           AS order_value
    FROM olist_customers_dataset c
    JOIN olist_orders_dataset o
        ON c.customer_id = o.customer_id
    JOIN olist_order_items_dataset i
        ON o.order_id = i.order_id
    WHERE o.order_status = 'delivered'
),
-- Deduplicate same-day orders (flagged in Q5)
daily_orders AS (
    SELECT
        customer_unique_id,
        DATE(order_purchase_timestamp)                      AS order_day,
        SUM(order_value)                                    AS daily_spend
    FROM delivered_orders
    GROUP BY customer_unique_id, DATE(order_purchase_timestamp)
)
SELECT
    customer_unique_id,
    DATEDIFF('2018-10-18', MAX(order_day))                  AS recency_days,
    COUNT(order_day)                                        AS frequency,
    ROUND(SUM(daily_spend), 2)                              AS monetary
FROM daily_orders
GROUP BY customer_unique_id
ORDER BY monetary DESC
LIMIT 20;

-- ═══════════════════════════════════════════════
-- Q8: RFM scoring — NTILE quintiles (1 to 5)
-- Note: Recency is INVERTED — lower days = better
-- ═══════════════════════════════════════════════

WITH delivered_orders AS (
    SELECT
        c.customer_unique_id,
        o.order_id,
        o.order_purchase_timestamp,
        i.price + i.freight_value                           AS order_value
    FROM olist_customers_dataset c
    JOIN olist_orders_dataset o
        ON c.customer_id = o.customer_id
    JOIN olist_order_items_dataset i
        ON o.order_id = i.order_id
    WHERE o.order_status = 'delivered'
),
daily_orders AS (
    SELECT
        customer_unique_id,
        DATE(order_purchase_timestamp)                      AS order_day,
        SUM(order_value)                                    AS daily_spend
    FROM delivered_orders
    GROUP BY customer_unique_id, DATE(order_purchase_timestamp)
),
rfm_raw AS (
    SELECT
        customer_unique_id,
        DATEDIFF('2018-10-18', MAX(order_day))              AS recency_days,
        COUNT(order_day)                                    AS frequency,
        ROUND(SUM(daily_spend), 2)                         AS monetary
    FROM daily_orders
    GROUP BY customer_unique_id
),
rfm_scored AS (
    SELECT
        customer_unique_id,
        recency_days,
        frequency,
        monetary,
        -- Recency: INVERTED — fewer days since last order = higher score
        NTILE(5) OVER (ORDER BY recency_days DESC)          AS r_score,
        -- Frequency & Monetary: higher = better
        NTILE(5) OVER (ORDER BY frequency ASC)              AS f_score,
        NTILE(5) OVER (ORDER BY monetary ASC)               AS m_score
    FROM rfm_raw
)
SELECT
    customer_unique_id,
    recency_days,
    frequency,
    monetary,
    r_score,
    f_score,
    m_score,
    CONCAT(r_score, f_score, m_score)                       AS rfm_combined
FROM rfm_scored
ORDER BY monetary DESC
LIMIT 20;

-- ═══════════════════════════════════════════════
-- Q9b: Segment summary — size and value
-- ═══════════════════════════════════════════════

WITH delivered_orders AS (
    SELECT
        c.customer_unique_id,
        o.order_id,
        o.order_purchase_timestamp,
        i.price + i.freight_value                           AS order_value
    FROM olist_customers_dataset c
    JOIN olist_orders_dataset o
        ON c.customer_id = o.customer_id
    JOIN olist_order_items_dataset i
        ON o.order_id = i.order_id
    WHERE o.order_status = 'delivered'
),
daily_orders AS (
    SELECT
        customer_unique_id,
        DATE(order_purchase_timestamp)                      AS order_day,
        SUM(order_value)                                    AS daily_spend
    FROM delivered_orders
    GROUP BY customer_unique_id, DATE(order_purchase_timestamp)
),
rfm_raw AS (
    SELECT
        customer_unique_id,
        DATEDIFF('2018-10-18', MAX(order_day))              AS recency_days,
        COUNT(order_day)                                    AS frequency,
        ROUND(SUM(daily_spend), 2)                         AS monetary
    FROM daily_orders
    GROUP BY customer_unique_id
),
rfm_scored AS (
    SELECT
        customer_unique_id,
        recency_days,
        frequency,
        monetary,
        NTILE(5) OVER (ORDER BY recency_days DESC)          AS r_score,
        NTILE(5) OVER (ORDER BY frequency ASC)              AS f_score,
        NTILE(5) OVER (ORDER BY monetary ASC)               AS m_score
    FROM rfm_raw
),
segmented AS (
    SELECT
        customer_unique_id,
        monetary,
        CASE
            WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4
                THEN '🏆 Champion'
            WHEN r_score >= 3 AND f_score >= 3
                THEN '🔄 Loyal'
            WHEN r_score >= 4 AND f_score <= 2
                THEN '🌱 Promising'
            WHEN r_score <= 2 AND f_score >= 3
                THEN '⚠️ At Risk'
            WHEN r_score <= 2 AND f_score <= 2 AND m_score >= 3
                THEN '💤 Needs Attention'
            ELSE
                '👋 Lost'
        END AS segment
    FROM rfm_scored
)
SELECT
    segment,
    COUNT(*)                                                AS customer_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2)     AS pct_of_customers,
    ROUND(SUM(monetary), 2)                                AS total_revenue,
    ROUND(AVG(monetary), 2)                                AS avg_customer_value,
    ROUND(SUM(monetary) * 100.0 / SUM(SUM(monetary)) OVER(), 2) AS pct_of_revenue
FROM segmented
GROUP BY segment
ORDER BY total_revenue DESC;
