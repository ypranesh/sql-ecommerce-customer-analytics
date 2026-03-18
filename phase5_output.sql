-- ═══════════════════════════════════════════════
-- Project 1: Customer Segmentation & Retention
-- Dataset:   Olist Brazilian E-Commerce (Kaggle)
-- Phase 5:   Stakeholder Output
-- Queries:   Q13 Create Summary View,
--            Q14 Priority Action Table

-- ═══════════════════════════════════════════════
-- Q13: Final stakeholder summary view
-- Combines RFM segments + churn status + delivery
-- Single source of truth for business decisions
-- ═══════════════════════════════════════════════

CREATE VIEW vw_customer_summary4 AS
WITH delivered_orders AS (
    SELECT
        c.customer_unique_id,
        o.order_id,
        DATE(o.order_purchase_timestamp)                    AS order_day,
        i.price + i.freight_value                           AS order_value,
        DATEDIFF(
            o.order_delivered_customer_date,
            o.order_estimated_delivery_date
        )                                                   AS delivery_delta_days
    FROM olist_customers_dataset c
    JOIN olist_orders_dataset o
        ON c.customer_id = o.customer_id
    JOIN olist_order_items_dataset i
        ON o.order_id = i.order_id
    WHERE o.order_status = 'delivered'
        AND o.order_delivered_customer_date IS NOT NULL
        AND o.order_estimated_delivery_date IS NOT NULL
),
daily_orders AS (
    SELECT
        customer_unique_id,
        order_day,
        SUM(order_value)                                    AS daily_spend,
        AVG(delivery_delta_days)                            AS avg_delta
    FROM delivered_orders
    GROUP BY customer_unique_id, order_day
),
rfm_raw AS (
    SELECT
        customer_unique_id,
        DATEDIFF('2018-10-18', MAX(order_day))              AS recency_days,
        COUNT(order_day)                                    AS frequency,
        ROUND(SUM(daily_spend), 2)                         AS monetary,
        ROUND(AVG(avg_delta), 1)                           AS avg_delivery_delta
    FROM daily_orders
    GROUP BY customer_unique_id
),
rfm_scored AS (
    SELECT
        customer_unique_id,
        recency_days,
        frequency,
        monetary,
        avg_delivery_delta,
        NTILE(5) OVER (ORDER BY recency_days DESC)          AS r_score,
        NTILE(5) OVER (ORDER BY frequency ASC)              AS f_score,
        NTILE(5) OVER (ORDER BY monetary ASC)               AS m_score
    FROM rfm_raw
)
SELECT
    customer_unique_id,
    recency_days,
    frequency,
    monetary,
    avg_delivery_delta,
    r_score,
    f_score,
    m_score,
    CONCAT(r_score, f_score, m_score)                       AS rfm_combined,
    CASE
        WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4
            THEN 'Champion'
        WHEN r_score >= 3 AND f_score >= 3
            THEN 'Loyal'
        WHEN r_score >= 4 AND f_score <= 2
            THEN 'Promising'
        WHEN r_score <= 2 AND f_score >= 3
            THEN 'At Risk'
        WHEN r_score <= 2 AND f_score <= 2 AND m_score >= 3
            THEN 'Needs Attention'
        ELSE
            'Lost'
    END                                                     AS rfm_segment,
    CASE
        WHEN recency_days > 180     THEN 'Churned'
        WHEN recency_days <= 180
         AND recency_days > 90      THEN 'At Risk'
        ELSE                             'Active'
    END                                                     AS churn_status,
    CASE
        WHEN avg_delivery_delta <= 0  THEN 'On Time or Early'
        WHEN avg_delivery_delta <= 7  THEN 'Slightly Late (1-7 days)'
        WHEN avg_delivery_delta <= 14 THEN 'Late (8-14 days)'
        ELSE                               'Very Late (15+ days)'
    END                                                     AS delivery_bucket
FROM rfm_scored;

SELECT
    rfm_segment,
    churn_status,
    delivery_bucket,
    COUNT(*)                                                AS customer_count,
    ROUND(SUM(monetary), 2)                                AS total_revenue,
    ROUND(AVG(monetary), 2)                                AS avg_customer_value,
    ROUND(AVG(avg_delivery_delta), 1)                      AS avg_delivery_delta,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2)      AS pct_of_customers
FROM vw_customer_summary
GROUP BY rfm_segment, churn_status, delivery_bucket
ORDER BY total_revenue DESC
LIMIT 20;